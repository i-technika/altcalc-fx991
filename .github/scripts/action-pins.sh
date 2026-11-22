#!/usr/bin/env bash
# CI·로컬: 워크플로에서 커밋 SHA로 고정한 액션(#88)을 GitHub API로 확인한다.
#
# 사용: bash .github/scripts/action-pins.sh <verify|outdated> [워크플로 파일...]
#   verify   — `uses: <owner>/<repo>@<sha> # vX.Y.Z` 줄마다 SHA가 그 태그가 가리키는 커밋인지 확인한다.
#              어긋나거나 조회하지 못하면 실패한다. Sub-issue CI·Milestone CI의 Linux 잡이 돌린다.
#   outdated — 액션마다 고정한 버전, 같은 주 버전의 최신 릴리스, 더 높은 주 버전의 최신 릴리스와 그 커밋 SHA를 보여 준다.
#              갱신 절차(README "CI 액션 고정 버전 올리기")의 첫 단계다. 새 릴리스가 있어도 실패하지 않는다.
#   파일을 주지 않으면 .github/workflows의 *.yml·*.yaml 전부를 본다(저장소 루트에서 실행).
#
# gh CLI가 필요하다(로그인했거나 GH_TOKEN이 있어야 한다 — 공개 저장소 조회라 권한은 필요 없다).
# 테스트는 ACTION_PINS_GH에 가짜 gh 경로를 넣는다.
#
# 역할 나눔: 모든 uses:가 "SHA 40자리 + 같은 줄 끝 # vX.Y.Z" 형식인지, 같은 액션을 모든 워크플로에서 같게 고정했는지는
#   test/unit/ci_actions_test.dart가 오프라인으로 검사한다. 이 스크립트는 그 형식이 아닌 uses: 줄을 만나면 실패만 한다.
#   여기서는 오프라인으로 알 수 없는 것(주석의 태그가 정말 그 SHA인지, 새 릴리스가 있는지)만 본다.
set -euo pipefail

gh=${ACTION_PINS_GH:-gh}

fail() {
  echo "::error::$*" >&2
  exit 1
}

usage() {
  echo "사용: bash .github/scripts/action-pins.sh <verify|outdated> [워크플로 파일...]" >&2
  exit 2
}

mode=${1:-}
case $mode in
  verify | outdated) shift ;;
  *) usage ;;
esac

if [ $# -eq 0 ]; then
  shopt -s nullglob
  set -- .github/workflows/*.yml .github/workflows/*.yaml
  shopt -u nullglob
  [ $# -gt 0 ] || fail ".github/workflows에 워크플로가 없다 — 저장소 루트에서 실행할 것"
fi

# 정규식은 변수에 담아 쓴다 — [[ =~ ]] 오른쪽에 직접 적으면 bash 버전에 따라 따옴표·역슬래시 해석이 다르다.
# YAML처럼 `uses:` 뒤에 공백이 있어야 키이고, 앞에 공백이 있는 `#`만 주석이다 (ci_actions_test.dart의 줄 추출과 같은 규칙).
uses_key='^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]'
pinned="^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]+['\"]?([^@[:space:]'\"#]+)@([0-9a-f]{40})['\"]?[[:space:]]+#[[:space:]]*(v[0-9]+\.[0-9]+\.[0-9]+)([[:space:]].*)?$"
release_tag='^v[0-9]+\.[0-9]+\.[0-9]+$'

# 고정 목록: "owner/repo sha tag" 한 줄씩, 처음 나온 순서대로 중복 없이 (bash 3.2에는 연관 배열이 없어 문자열로 모은다)
pins=""
for file in "$@"; do
  [ -f "$file" ] || fail "$file 이 없다"
  n=0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    line=${line%$'\r'} # core.autocrlf=true 체크아웃의 CRLF
    [[ $line =~ $uses_key ]] || continue
    [[ $line =~ $pinned ]] ||
      fail "$file:$n: 커밋 SHA(40자리)로 고정하고 같은 줄 끝에 '# vX.Y.Z'를 적어야 한다 — ${line#"${line%%[![:space:]]*}"}"
    action=${BASH_REMATCH[2]}
    sha=${BASH_REMATCH[3]}
    tag=${BASH_REMATCH[4]}
    # 하위 경로 액션(owner/repo/path)도 태그·릴리스는 owner/repo의 것이다
    owner=${action%%/*}
    rest=${action#*/}
    [ "$rest" != "$action" ] && [ -n "$owner" ] && [ -n "${rest%%/*}" ] ||
      fail "$file:$n: owner/repo 형식의 액션이 아니다 — $action"
    entry="$owner/${rest%%/*} $sha $tag"
    case $'\n'"$pins" in
      *$'\n'"$entry"$'\n'*) ;;
      *) pins+="$entry"$'\n' ;;
    esac
  done <"$file"
done
[ -n "$pins" ] || fail "고정된 액션(uses:)이 없다: $*"

# gh는 표준 입력을 읽지 않게 막는다 — 아래 반복문이 고정 목록을 표준 입력으로 읽는다
gh_api() {
  "$gh" api "$@" </dev/null
}

if [ "$mode" = verify ]; then
  errors=0
  while read -r repo sha tag; do
    # refs/tags/를 붙여 같은 이름의 브랜치와 헷갈리지 않게 한다. 주석 달린 태그도 태그 객체가 아니라 커밋 SHA가 나온다.
    if ! actual=$(gh_api "repos/$repo/commits/refs/tags/$tag" --jq .sha); then
      echo "::error::$repo 의 태그 $tag 를 조회하지 못했다 (태그가 없거나 gh 인증·네트워크 문제)"
      errors=$((errors + 1))
    elif [ "$actual" != "$sha" ]; then
      echo "::error::$repo 의 $tag 는 $actual 인데 워크플로는 $sha 로 고정했다 — 주석의 버전이나 SHA를 바로잡을 것"
      errors=$((errors + 1))
    else
      echo "확인: $repo@$sha = $tag"
    fi
  done <<<"${pins%$'\n'}"
  [ "$errors" -eq 0 ] || fail "고정 SHA 확인 실패 ${errors}건"
  echo "고정 SHA가 모두 태그와 일치한다"
  exit 0
fi

# outdated: 액션(owner/repo)마다 한 번 조회한다

# 버전 $1이 $2보다 높은가 (vX.Y.Z끼리)
newer_than() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" = "$1" ]
}

newer=0
done_repos=$'\n'
while read -r repo sha tag; do
  case $done_repos in *$'\n'"$repo"$'\n'*) continue ;; esac
  done_repos+="$repo"$'\n'
  # 릴리스(초안·사전 릴리스 제외)의 vX.Y.Z 태그만 본다. 최신 100개면 충분하다(새 것부터 나온다).
  releases=$(gh_api "repos/$repo/releases?per_page=100" --jq '.[] | select((.draft or .prerelease) | not) | .tag_name') ||
    fail "$repo 의 릴리스 목록을 조회하지 못했다 (gh 인증·네트워크 확인)"
  releases=$(printf '%s\n' "$releases" | grep -E "$release_tag" | sort -V || true)
  [ -n "$releases" ] || fail "$repo 에 vX.Y.Z 형식의 릴리스가 없다"
  major=${tag%%.*}
  same_major=$(printf '%s\n' "$releases" | grep -E "^$major\." | tail -n 1 || true)
  overall=$(printf '%s\n' "$releases" | tail -n 1)

  # 이 저장소를 고정한 모든 버전 (ci_actions_test가 하나로 맞추게 하지만, 그 검사 전에 돌려도 다 보이게)
  fixed=$(printf '%s' "$pins" | awk -v r="$repo" '$1 == r { print $3 }' | sort -uV)
  highest_fixed=$(printf '%s\n' "$fixed" | tail -n 1)
  line="$repo: 고정 $(printf '%s' "$fixed" | tr '\n' ' ')"
  line=${line% }
  found=false
  # 같은 주 버전의 새 릴리스(그대로 올려도 되는 갱신)와 더 높은 주 버전(검토가 필요한 갱신)을 따로 알린다
  # (같은 주 버전의 최신이 전체 최신이면 sort -u로 한 번만 본다. 태그는 공백 없는 vX.Y.Z라 단어 분리가 안전하다)
  for candidate in $(printf '%s\n%s\n' "$same_major" "$overall" | grep . | sort -uV); do
    newer_than "$candidate" "$highest_fixed" || continue
    new_sha=$(gh_api "repos/$repo/commits/refs/tags/$candidate" --jq .sha) ||
      fail "$repo 의 태그 $candidate 를 조회하지 못했다"
    if [ "${candidate%%.*}" = "$major" ]; then
      line+=" → $candidate ($new_sha)"
    else
      line+=" → $candidate ($new_sha, 주 버전 변경 — 그 버전 action.yml의 runs.using 확인·_minVersions 갱신)"
    fi
    found=true
    newer=$((newer + 1))
  done
  $found || line+=" — 최신"
  echo "$line"
done <<<"${pins%$'\n'}"

if [ "$newer" -eq 0 ]; then
  echo "모든 액션이 최신 릴리스로 고정돼 있다"
else
  echo "새 릴리스 ${newer}건 — README \"CI 액션 고정 버전 올리기\" 절차로 올린다"
fi

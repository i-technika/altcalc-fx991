#!/usr/bin/env bash
# CI·로컬: 워크플로에서 커밋 SHA로 고정한 액션(#88)을 GitHub API로 확인한다.
#
# 사용: bash .github/scripts/action-pins.sh <verify|outdated> [워크플로 파일...]
#   verify   — `uses: <owner>/<repo>@<sha> # vX.Y.Z` 줄마다 확인하고, 하나라도 문제가 있으면 실패한다.
#              - SHA가 그 태그가 가리키는 커밋인가
#              - 그 버전에 해당하는 GitHub 보안 권고(Advisory Database의 검토된 GHSA, 철회된 것 제외)가 없는가.
#                예외 목록(.github/action-advisories-ignore)에 기한 안으로 적힌 권고는 경고만 낸다.
#              Sub-issue CI·Milestone CI의 `Verify Action Pins` 잡이 돌린다.
#   outdated — 액션마다 고정한 버전, 같은 주 버전의 최신 릴리스, 더 높은 주 버전의 최신 릴리스와 그 커밋 SHA,
#              고정한 버전에 해당하는 보안 권고를 보여 준다. 갱신 절차(README "CI 액션 고정 버전 올리기")의 첫 단계다.
#              새 릴리스나 권고가 있어도 실패하지 않는다(조회 실패만 실패).
#   파일을 주지 않으면 .github/workflows의 *.yml·*.yaml 전부를 본다(저장소 루트에서 실행).
#
# gh CLI가 필요하다(로그인했거나 GH_TOKEN이 있어야 한다 — 공개 정보 조회라 권한은 필요 없다).
# 조회는 일시 장애에 대비해 세 번까지 시도한다(HTTP 404처럼 다시 해도 같은 실패는 바로 멈춘다).
# 테스트용 환경 변수: ACTION_PINS_GH(가짜 gh 경로), ACTION_PINS_RETRY_DELAY(재시도 간격 초),
#   ACTION_PINS_IGNORE(예외 목록 경로), ACTION_PINS_TODAY(오늘 날짜 YYYY-MM-DD).
#
# 역할 나눔: 모든 uses:가 "SHA 40자리 + 같은 줄 끝 # vX.Y.Z" 형식인지, 같은 액션을 모든 워크플로에서 같게 고정했는지,
#   Node 24 최소 버전 이상인지는 test/unit/ci_actions_test.dart가 오프라인으로 검사한다.
#   이 스크립트는 그 형식이 아닌 uses: 줄을 만나면 실패만 한다(받아들이는 줄이 같은지는 action_pins_script_test가 대조한다).
#   여기서는 오프라인으로 알 수 없는 것(주석의 태그가 정말 그 SHA인지, 권고·새 릴리스가 있는지)만 본다.
set -euo pipefail

gh=${ACTION_PINS_GH:-gh}
retry_delay=${ACTION_PINS_RETRY_DELAY:-5}
ignore_file=${ACTION_PINS_IGNORE:-.github/action-advisories-ignore}
today=${ACTION_PINS_TODAY:-$(date -u +%Y-%m-%d)}

# 오류·경고는 표준 오류로 낸다. GitHub Actions 안에서만 `::error::`·`::warning::`을 붙여 실행 주석으로 보이게 한다.
error() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::error::$*" >&2
  else
    echo "오류: $*" >&2
  fi
}

warning() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::warning::$*" >&2
  else
    echo "경고: $*" >&2
  fi
}

fail() {
  error "$@"
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

# 버전 정렬(sort -V)을 못 하면 outdated의 판정이 조용히 틀어지므로 먼저 확인한다 (GNU·최근 BSD sort는 지원한다)
printf 'v1.10.0\nv1.9.0\n' | sort -V >/dev/null 2>&1 || fail "sort -V(버전 정렬)를 지원하지 않는 sort다"

if [ $# -eq 0 ]; then
  shopt -s nullglob
  set -- .github/workflows/*.yml .github/workflows/*.yaml
  shopt -u nullglob
  [ $# -gt 0 ] || fail ".github/workflows에 워크플로가 없다 — 저장소 루트에서 실행할 것"
fi

# 정규식은 변수에 담아 쓴다 — [[ =~ ]] 오른쪽에 직접 적으면 bash 버전에 따라 따옴표·역슬래시 해석이 다르다.
# 줄 안의 공백은 스페이스·탭([[:blank:]])만 본다. YAML처럼 `uses:` 뒤에 공백이 있어야 키이고, 앞에 공백이 있는 `#`만 주석이다.
# 값은 따옴표 없음·작은따옴표·큰따옴표 중 하나로, 여닫는 따옴표가 같아야 한다(test/support/workflows.dart의 줄 추출과 같은 규칙).
uses_key='^[[:blank:]]*(-[[:blank:]]+)?uses:[[:blank:]]'
pinned="^[[:blank:]]*(-[[:blank:]]+)?uses:[[:blank:]]+([^@[:space:]'\"#]+@[^[:space:]'\"]+|'[^@[:space:]'\"#]+@[^[:space:]'\"]+'|\"[^@[:space:]'\"#]+@[^[:space:]'\"]+\")[[:blank:]]+#[[:blank:]]*(v[0-9]+\.[0-9]+\.[0-9]+)([[:blank:]].*)?$"
action_sha='^([^@]+)@([0-9a-f]{40})$'
release_tag='^v[0-9]+\.[0-9]+\.[0-9]+$'
ignore_entry='^(GHSA(-[23456789cfghjmpqrvwx]{4}){3})[[:blank:]]+([0-9]{4}-[0-9]{2}-[0-9]{2})[[:blank:]]+([^[:blank:]].*)$'

# 고정 목록: "owner/repo sha tag" 한 줄씩, 처음 나온 순서대로 중복 없이 (bash 3.2에는 연관 배열이 없어 문자열로 모은다)
pins=""
for file in "$@"; do
  [ -f "$file" ] || fail "$file 이 없다"
  n=0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    line=${line%$'\r'} # core.autocrlf=true 체크아웃의 CRLF
    [[ $line =~ $uses_key ]] || continue
    trimmed=${line#"${line%%[![:space:]]*}"}
    format_error="$file:$n: 커밋 SHA(40자리)로 고정하고 같은 줄 끝에 '# vX.Y.Z'를 적어야 한다 — $trimmed"
    [[ $line =~ $pinned ]] || fail "$format_error"
    value=${BASH_REMATCH[2]}
    tag=${BASH_REMATCH[3]}
    value=${value#[\'\"]}
    value=${value%[\'\"]}
    [[ $value =~ $action_sha ]] || fail "$format_error"
    action=${BASH_REMATCH[1]}
    sha=${BASH_REMATCH[2]}
    # 하위 경로 액션(owner/repo/path)도 태그·릴리스·권고는 owner/repo의 것이다
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

# 권고 예외 목록: "GHSA-id 기한(YYYY-MM-DD) 사유" 한 줄씩 (# 주석·빈 줄 허용). 파일이 없으면 예외 없음.
# 고친 릴리스가 아직 없거나 이 저장소가 쓰지 않는 기능에만 해당하는 권고를, 사유와 기한을 적고 잠시 넘기는 용도다.
# 형식이 틀린 줄은 실패한다(오타로 예외가 조용히 무시되지 않게). 기한이 지난 예외는 없는 것으로 본다.
ignores="" # "GHSA-id 기한" 줄들
if [ -f "$ignore_file" ]; then
  n=0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    line=${line%$'\r'}
    case $line in '' | '#'*) continue ;; esac
    [[ $line =~ $ignore_entry ]] ||
      fail "$ignore_file:$n: 'GHSA-xxxx-xxxx-xxxx YYYY-MM-DD 사유' 형식이 아니다 — $line"
    ignores+="${BASH_REMATCH[1]} ${BASH_REMATCH[3]}"$'\n'
  done <"$ignore_file"
fi

# 권고 id가 기한 안의 예외인지. 예외면 기한을 출력하고 0, 아니면(없거나 기한 지남) 1.
# 기한 지난 예외는 경고를 남긴다 — 다시 검토하고 기한을 늘리거나 지울 것.
ignored_until() {
  local id until
  while read -r id until; do
    [ "$id" = "$1" ] || continue
    if [[ $until < $today ]]; then
      warning "$ignore_file 의 $id 예외는 기한($until)이 지났다 — 다시 검토할 것"
      return 1
    fi
    echo "$until"
    return 0
  done <<<"$ignores"
  return 1
}

# gh api 호출. 표준 입력은 막는다(아래 반복문이 고정 목록을 표준 입력으로 읽는다).
# 세 번까지 시도하고, 마지막 시도의 오류 출력만 보인다. HTTP 404(태그·저장소 없음)는 다시 해도 같으므로 바로 멈춘다.
gh_err=$(mktemp)
trap 'rm -f "$gh_err"' EXIT
gh_api() {
  local attempt=1 out
  while :; do
    if out=$("$gh" api "$@" </dev/null 2>"$gh_err"); then
      printf '%s\n' "$out"
      return 0
    fi
    if [ "$attempt" -ge 3 ] || grep -q 'HTTP 404' "$gh_err"; then
      cat "$gh_err" >&2
      return 1
    fi
    attempt=$((attempt + 1))
    sleep "$retry_delay"
  done
}

# 버전 tag(vX.Y.Z)에 해당하는 보안 권고 "GHSA-… (심각도) 요약" 줄들. 조회 실패는 1로 끝난다.
# Advisory Database는 기본으로 검토된(reviewed) 권고만 주지만, 철회된(withdrawn) 권고도 섞여 나오므로 거른다.
advisories() {
  gh_api "advisories?ecosystem=actions&affects=$1@${2#v}&per_page=100" \
    --jq '.[] | select(.withdrawn_at == null) | "\(.ghsa_id) (\(.severity)) \(.summary)"'
}

if [ "$mode" = verify ]; then
  errors=0
  while read -r repo sha tag; do
    # refs/tags/를 붙여 같은 이름의 브랜치와 헷갈리지 않게 한다. 주석 달린 태그도 태그 객체가 아니라 커밋 SHA가 나온다.
    if ! actual=$(gh_api "repos/$repo/commits/refs/tags/$tag" --jq .sha); then
      error "$repo 의 태그 $tag 를 조회하지 못했다 (태그가 없거나 gh 인증·네트워크 문제)"
      errors=$((errors + 1))
      continue
    fi
    if [ "$actual" != "$sha" ]; then
      error "$repo 의 $tag 는 $actual 인데 워크플로는 $sha 로 고정했다 — 주석의 버전이나 SHA를 바로잡을 것"
      errors=$((errors + 1))
      continue
    fi
    if ! found=$(advisories "$repo" "$tag"); then
      error "$repo $tag 의 보안 권고를 조회하지 못했다 (gh 인증·네트워크 문제)"
      errors=$((errors + 1))
      continue
    fi
    blocking=0
    if [ -n "$found" ]; then
      while IFS= read -r advisory; do
        if until=$(ignored_until "${advisory%% *}"); then
          warning "$repo $tag 의 보안 권고를 예외 목록에 따라 $until 까지 넘긴다: $advisory"
        else
          error "$repo $tag 에 보안 권고가 있다: $advisory — 고친 릴리스로 올리거나, 없으면 $ignore_file 에 사유·기한을 적을 것 (README \"CI 액션 고정 버전 올리기\")"
          blocking=$((blocking + 1))
        fi
      done <<<"$found"
    fi
    if [ "$blocking" -gt 0 ]; then
      errors=$((errors + 1))
      continue
    fi
    if [ -n "$found" ]; then
      echo "확인: $repo@$sha = $tag (예외로 넘긴 권고만 있음)"
    else
      echo "확인: $repo@$sha = $tag (보안 권고 없음)"
    fi
  done <<<"${pins%$'\n'}"
  [ "$errors" -eq 0 ] || fail "고정 액션 확인 실패 ${errors}건"
  echo "고정 SHA가 모두 태그와 일치하고, 넘기지 않은 보안 권고가 없다"
  exit 0
fi

# outdated: 액션(owner/repo)마다 한 번 조회한다

# 버전 $1이 $2보다 높은가 (vX.Y.Z끼리)
newer_than() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" = "$1" ]
}

newer=0
flagged=0
done_repos=$'\n'
while read -r repo _ _; do
  case $done_repos in *$'\n'"$repo"$'\n'*) continue ;; esac
  done_repos+="$repo"$'\n'
  # 릴리스(초안·사전 릴리스 제외)의 vX.Y.Z 태그만 본다. 최신 100개면 충분하다(새 것부터 나온다).
  releases=$(gh_api "repos/$repo/releases?per_page=100" --jq '.[] | select((.draft or .prerelease) | not) | .tag_name') ||
    fail "$repo 의 릴리스 목록을 조회하지 못했다 (gh 인증·네트워크 확인)"
  # grep의 "일치 없음"(1)만 넘기고 sort의 실패는 드러나게 한다
  releases=$(printf '%s\n' "$releases" | { grep -E "$release_tag" || true; } | sort -V)
  [ -n "$releases" ] || fail "$repo 에 vX.Y.Z 형식의 릴리스가 없다"

  # 이 저장소를 고정한 모든 버전 (ci_actions_test가 하나로 맞추게 하지만, 그 검사 전에 돌려도 다 보이게)
  fixed=$(printf '%s' "$pins" | awk -v r="$repo" '$1 == r { print $3 }' | sort -uV)
  highest_fixed=$(printf '%s\n' "$fixed" | tail -n 1)
  # 주 버전은 가장 높은 고정을 기준으로 한다 (고정이 여러 개여도 그 주 버전의 새 릴리스를 놓치지 않게)
  major=${highest_fixed%%.*}
  same_major=$(printf '%s\n' "$releases" | { grep -E "^$major\." || true; } | tail -n 1)
  overall=$(printf '%s\n' "$releases" | tail -n 1)

  line="$repo: 고정 $(printf '%s' "$fixed" | tr '\n' ' ')"
  line=${line% }
  found=false
  # 같은 주 버전의 새 릴리스(그대로 올려도 되는 갱신)와 더 높은 주 버전(검토가 필요한 갱신)을 따로 알린다
  # (같은 주 버전의 최신이 전체 최신이면 sort -u로 한 번만 본다. 태그는 공백 없는 vX.Y.Z라 단어 분리가 안전하다)
  for candidate in $(printf '%s\n%s\n' "$same_major" "$overall" | { grep . || true; } | sort -uV); do
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

  for tag in $fixed; do
    list=$(advisories "$repo" "$tag") || fail "$repo $tag 의 보안 권고를 조회하지 못했다"
    [ -n "$list" ] || continue
    blocking=false
    while IFS= read -r advisory; do
      if until=$(ignored_until "${advisory%% *}"); then
        echo "  ! $tag 보안 권고(예외 목록, $until 까지): $advisory"
      else
        echo "  ! $tag 보안 권고: $advisory"
        blocking=true
      fi
    done <<<"$list"
    ! $blocking || flagged=$((flagged + 1))
  done
done <<<"${pins%$'\n'}"

if [ "$newer" -eq 0 ]; then
  echo "모든 액션이 최신 릴리스로 고정돼 있다"
else
  echo "새 릴리스 ${newer}건 — README \"CI 액션 고정 버전 올리기\" 절차로 올린다"
fi
if [ "$flagged" -gt 0 ]; then
  echo "보안 권고가 있는 고정 ${flagged}건 — 마일스톤 점검을 기다리지 말고 바로 서브이슈로 올린다"
fi

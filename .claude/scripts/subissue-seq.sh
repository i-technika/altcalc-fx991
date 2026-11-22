#!/usr/bin/env bash
# 서브이슈 제목 순번([M<N>-<순번>]) 도우미 (#110).
# 여러 세션이 동시에 후속 이슈를 만들면 같은 순번을 집을 수 있어(과거 M1-39~47 중복),
# 순번 발급·생성·충돌 검사·양보를 이 스크립트 한 번의 호출로 끝낸다.
#
# 사용법 (안내·경고는 stderr):
#   create <M1> <제목> [gh issue create 추가 인자...]
#       다음 순번으로 "[M1-<순번>] <제목>" 이슈를 만들고 검사한다. 먼저 만든 이슈와 겹치면 새 순번으로 양보한다.
#       stdout: "<이슈번호> <최종 순번>". 추가 인자에 --title·--repo는 넣을 수 없다(스크립트가 정한다).
#       예) create M1 "미리보기 프리셋 추가" --body-file f.md --label sub-issue --milestone "..." --project "..."
#   ensure <이슈번호>
#       이미 있는 이슈의 순번을 검사하고, 먼저 만든 이슈와 겹치면 양보한다. (/fix-issue 착수 시)
#       stdout: "<이슈번호> <최종 순번>"
#   next <M1>
#       닫힌 이슈까지 포함한 최댓값 + 1을 출력한다 (예: M1-57). 조회만 한다.
#   check <M1-56> <이슈번호> [--strict]
#       번호가 더 작은(먼저 만든) 이슈가 같은 순번이면 충돌(exit 3). 번호가 큰 쪽의 중복은 경고만 한다.
#       --strict: 번호와 관계없이 다른 이슈와 겹치면 충돌. 조회만 하고 제목은 바꾸지 않는다. stdout: "OK: ..."
#
# 충돌 규칙: 처음 만든 순번은 "작은 번호가 이긴다". 양보로 바꾼 순번은 생성 뒤에 끼어든 것이라
# 이미 검사를 통과한 큰 번호 이슈를 뺏을 수 있으므로, 모든 이슈와 겹치지 않아야 통과한다(--strict).
# 두 이슈가 동시에 양보하면 같은 순번을 계속 고를 수 있어, 재시도부터는 순번에 무작위 오프셋과 무작위 대기를 둔다
# (순번에 빈 번호가 생길 수 있으나 중복보다 낫다).
#
# 종료 코드:
#   0 성공
#   1 실패 — 이슈를 만들거나 제목을 바꾸지 않았다 (gh 오류, 목록 반영 시간 초과 등)
#   2 인자·형식 오류 — 아무것도 바꾸지 않았다 (check에서 그 이슈 제목이 그 순번이 아닌 경우 포함)
#   3 순번 충돌 (check만)
#   4 이슈를 만들었거나 제목을 바꿨지만 검사를 끝내지 못함 — stdout "<이슈번호> <현재 순번>".
#     나중에 `ensure <이슈번호>`로 마무리한다 (양보 재시도 소진도 여기에 해당).
set -euo pipefail
# $(...) 안은 기본적으로 set -e를 물려받지 않아 gh 실패가 빈 목록으로 묻힌다 (bash 4.4+).
# macOS 기본 bash 3.2에는 이 옵션이 없어 넘어가지만, 함수들이 실패를 `|| return`으로 직접 돌려주므로 동작은 같다.
# (`||` 문맥에서 불린 함수 안에서는 set -e가 꺼지므로, 실패할 수 있는 대입마다 명시적으로 처리한다.)
shopt -s inherit_errexit 2>/dev/null || true

REPO=i-technika/altcalc-fx991
# 이슈 목록 조회 한도. 받은 개수가 한도에 닿으면 오래된 이슈가 빠졌을 수 있어 실패한다.
LIMIT="${SUBISSUE_SEQ_LIMIT:-5000}"
# 양보 재시도 상한
MAX_TRIES=8
# 목록 반영 지연 시 재조회 간격과 양보 재시도 무작위 대기의 상한(초). 테스트는 0으로 둔다.
RETRY_DELAY="${SUBISSUE_SEQ_RETRY_DELAY:-2}"
# 테스트에서 재시도 오프셋을 재현 가능하게 고정하는 난수 시드 (평소에는 비워 둔다)
if [ -n "${SUBISSUE_SEQ_RANDOM_SEED:-}" ]; then RANDOM="$SUBISSUE_SEQ_RANDOM_SEED"; fi

# 테스트용 가짜 gh 훅 (test/unit/subissue_seq_test.dart). 평소에는 실제 gh를 쓴다.
# 훅을 지정했는데 파일이 없으면 실제 gh로 넘어가지 않고 실패한다 — 테스트가 실제 저장소에 이슈를 만들지 않게.
gh_cmd() {
  if [ -n "${SUBISSUE_SEQ_FAKE_GH+x}" ]; then
    [ -f "$SUBISSUE_SEQ_FAKE_GH" ] || { echo "가짜 gh 훅 파일이 없습니다: $SUBISSUE_SEQ_FAKE_GH" >&2; return 1; }
    bash "$SUBISSUE_SEQ_FAKE_GH" "$@"
  else
    gh "$@"
  fi
}

usage_error() {
  echo "$*" >&2
  echo "사용법: $0 create <M1> <제목> [gh 인자...] | ensure <이슈번호> | next <M1> | check <M1-56> <이슈번호> [--strict]" >&2
  exit 2
}

valid_ms() { [[ "$1" =~ ^M[0-9]+$ ]]; }
valid_seq() { [[ "$1" =~ ^M[0-9]+-[0-9]+$ ]]; }
valid_num() { [[ "$1" =~ ^[1-9][0-9]*$ ]]; }

# 모든 상태의 이슈를 "번호<TAB>제목"으로 출력한다. (jq 정규식 대신 셸에서 거른다 — Git Bash의 역슬래시 변환 회피)
list_issues() {
  local out count
  out=$(gh_cmd issue list -R "$REPO" --state all -L "$LIMIT" --json number,title \
    --jq '.[] | "\(.number)\t\(.title)"') || return 1
  count=$(printf '%s' "$out" | grep -c '' || true)
  if [ "$count" -ge "$LIMIT" ]; then
    echo "이슈가 조회 한도($LIMIT)에 닿아 일부가 빠졌을 수 있습니다 — SUBISSUE_SEQ_LIMIT을 올리세요" >&2
    return 1
  fi
  printf '%s\n' "$out"
}

# 제목의 순번 (없으면 빈 값)
seq_of_title() { printf '%s\n' "$1" | sed -nE 's/^\[(M[0-9]+-[0-9]+)\] .*/\1/p'; }
# 제목에서 순번 접두사를 뺀 본문
body_of_title() { printf '%s\n' "$1" | sed -E 's/^\[M[0-9]+-[0-9]+\] //'; }

# max_from <목록> <M1> → 그 마일스톤 순번의 최댓값 (없으면 0)
max_from() {
  local max
  max=$(printf '%s\n' "$1" | cut -f2 | sed -nE "s/^\[$2-([0-9]+)\] .*/\1/p" | sort -n | tail -1)
  echo "${max:-0}"
}

# title_from <목록> <번호> → 제목 (없으면 빈 값)
title_from() { printf '%s\n' "$1" | awk -F'\t' -v n="$2" '$1 + 0 == n + 0 { print substr($0, length($1) + 2); exit }'; }

# number_of_title <목록> <제목> → 그 제목을 가진 가장 큰 이슈 번호 (없으면 빈 값)
# 제목은 역슬래시가 들어 있을 수 있어 -v 대신 환경 변수로 넘긴다(-v는 이스케이프를 해석한다).
number_of_title() {
  printf '%s\n' "$1" | T="$2" awk -F'\t' 'substr($0, length($1) + 2) == ENVIRON["T"] { n = $1 } END { if (n) print n }'
}

# 방금 만들거나 고친 이슈가 목록에 보일 때까지 다시 조회한다 (GitHub 목록 반영 지연 대비).
# list_until <번호> <기대 제목 접두사> → 목록. 끝내 보이지 않으면 1.
list_until() {
  local list i
  for i in 1 2 3 4 5; do
    list=$(list_issues) || return 1
    case "$(title_from "$list" "$1")" in
      "$2"*) printf '%s\n' "$list"; return 0 ;;
    esac
    sleep "$RETRY_DELAY"
  done
  echo "#$1의 제목이 '$2'(으)로 시작하는 것이 목록에 반영되지 않았습니다" >&2
  return 1
}

# conflicts_in <목록> <순번> <번호> → "작은번호들|큰번호들" (각 "#N " 나열)
conflicts_in() {
  printf '%s\n' "$1" | awk -F'\t' -v s="[$2] " -v n="$3" '
    index($2, s) == 1 && $1 + 0 < n + 0 { lo = lo "#" $1 " " }
    index($2, s) == 1 && $1 + 0 > n + 0 { hi = hi "#" $1 " " }
    END { print lo "|" hi }'
}

# judge <목록> <순번> <번호> <strict 0|1> → 0 통과 / 3 충돌
judge() {
  local both lower higher
  both=$(conflicts_in "$1" "$2" "$3") || return 1
  lower="${both%%|*}" higher="${both#*|}"
  if [ -n "$lower" ] || { [ "$4" = 1 ] && [ -n "$higher" ]; }; then
    echo "충돌: [$2]를 #$3 말고 ${lower}${higher}도 사용 중" >&2
    return 3
  fi
  if [ -n "$higher" ]; then
    echo "경고: 나중에 만든 ${higher}도 [$2]를 씁니다 — 열린 이슈면 착수할 때 ensure로 양보시키고," \
      "이미 머지된 닫힌 이슈면 커밋·PR 제목에 순번이 남아 있으니 사람이 어느 쪽을 바꿀지 정하세요" >&2
  fi
  return 0
}

# renumber <번호>: 새 순번으로 제목을 바꾸고 --strict 검사를 통과할 때까지 반복한다.
# 반환: 0(stdout "<번호> <순번>") / 1(아무것도 안 바꿈) / 4(바꿨지만 미완료, stdout "<번호> <현재 순번>")
renumber() {
  local num="$1" list title seq body ms new rc i cur=""
  for ((i = 1; i <= MAX_TRIES; i++)); do
    if [ "$i" -gt 1 ]; then
      # 함께 양보하는 다른 이슈와 박자가 어긋나도록 무작위로 기다린다
      sleep "$((RANDOM % (RETRY_DELAY + 1)))"
    fi
    list=$(list_issues) || break
    title=$(title_from "$list" "$num")
    seq=$(seq_of_title "$title")
    if [ -z "$seq" ]; then
      echo "#$num 제목에 순번이 없습니다: $title" >&2
      [ -n "$cur" ] && break
      return 2
    fi
    body=$(body_of_title "$title")
    ms="${seq%-*}"
    # 첫 시도는 최댓값 + 1, 재시도부터는 무작위 오프셋(0~2)으로 동시에 양보하는 이슈와 같은 순번을 피한다
    new="$ms-$(($(max_from "$list" "$ms") + 1 + (i > 1 ? RANDOM % 3 : 0)))"
    if ! gh_cmd issue edit "$num" -R "$REPO" --title "[$new] $body" >/dev/null; then
      echo "#$num 제목 변경 실패" >&2
      break
    fi
    cur="$new"
    echo "#$num: [$seq] → [$new]" >&2
    list=$(list_until "$num" "[$new] ") || break
    rc=0
    judge "$list" "$new" "$num" 1 || rc=$?
    case "$rc" in
      0) echo "$num $new"; return 0 ;;
      3) ;;
      *) break ;;
    esac
  done
  if [ -z "$cur" ]; then
    return 1
  fi
  echo "#$num의 순번을 [$cur](으)로 바꿨지만 검사를 끝내지 못했습니다 — 나중에 ensure $num 으로 마무리하세요" >&2
  echo "$num $cur"
  return 4
}

# ensure <번호> [기대 순번]: 현재 순번 검사 → 충돌이면 양보.
# 기대 순번을 주면(방금 만든 이슈) 목록에 보일 때까지 기다린다.
# 반환: 0·4(stdout "<번호> <순번>") / 1 / 2
ensure() {
  local num="$1" list title seq rc=0
  if [ -n "${2:-}" ]; then
    list=$(list_until "$num" "[$2] ") || return 1
  else
    list=$(list_issues) || return 1
  fi
  title=$(title_from "$list" "$num")
  [ -n "$title" ] || { echo "#$num 이슈를 찾지 못했습니다" >&2; return 2; }
  seq=$(seq_of_title "$title")
  [ -n "$seq" ] || { echo "#$num 제목에 순번이 없습니다: $title" >&2; return 2; }
  judge "$list" "$seq" "$num" 0 || rc=$?
  case "$rc" in
    0) echo "$num $seq" ;;
    3) echo "#$num이 양보합니다" >&2; renumber "$num" || return $? ;;
    *) return "$rc" ;;
  esac
}

cmd="${1:-}"
[ $# -gt 0 ] && shift
case "$cmd" in
  create)
    [ $# -ge 2 ] || usage_error "create에는 마일스톤 접두사와 제목이 필요합니다"
    ms="$1" body="$2"; shift 2
    valid_ms "$ms" || usage_error "마일스톤 접두사 형식이 아닙니다(예: M1): $ms"
    [ -n "$body" ] || usage_error "제목이 비었습니다"
    [[ "$body" =~ ^\[ ]] && usage_error "제목에 [순번] 접두사를 붙이지 마세요 — 스크립트가 붙입니다: $body"
    for a in "$@"; do
      case "$a" in
        -t | --title | --title=* | -R | --repo | --repo=*)
          usage_error "추가 인자에 제목·저장소($a)를 넣을 수 없습니다 — 스크립트가 정합니다" ;;
      esac
    done
    # 목록은 변수로 먼저 받는다 — 인자 안의 $(...) 실패는 set -e가 잡지 못해 빈 목록으로 M?-1을 발급하게 된다.
    list=$(list_issues)
    seq="$ms-$(($(max_from "$list" "$ms") + 1))"
    full="[$seq] $body"
    if ! url=$(gh_cmd issue create -R "$REPO" --title "$full" "$@"); then
      # gh는 이슈를 만든 뒤 프로젝트 추가 등에서 실패할 수 있다 → 정확한 제목으로 생성 여부를 확인한다
      num=""
      if list=$(list_issues); then num=$(number_of_title "$list" "$full"); fi
      if [ -n "$num" ]; then
        echo "gh issue create가 실패했지만 #$num [$seq]은 만들어졌습니다 — ensure $num 으로 마무리하세요" >&2
        echo "$num $seq"
        exit 4
      fi
      echo "이슈 생성 실패 (목록에서도 찾지 못함)" >&2
      exit 1
    fi
    num="${url##*/}"
    if ! valid_num "$num"; then
      echo "생성 결과에서 이슈 번호를 읽지 못했습니다: $url — gh issue list로 확인하세요" >&2
      exit 1
    fi
    echo "생성: #$num [$seq] $body ($url)" >&2
    rc=0
    ensure "$num" "$seq" || rc=$?
    case "$rc" in
      0 | 4) exit "$rc" ;;
      *)
        echo "#$num [$seq]은 만들어졌지만 순번 검사를 끝내지 못했습니다 — ensure $num 으로 마무리하세요" >&2
        echo "$num $seq"
        exit 4
        ;;
    esac
    ;;
  ensure)
    { [ $# -eq 1 ] && valid_num "$1"; } || usage_error "ensure에는 이슈 번호 하나가 필요합니다"
    ensure "$1"
    ;;
  next)
    { [ $# -eq 1 ] && valid_ms "$1"; } || usage_error "next에는 마일스톤 접두사(예: M1)가 필요합니다"
    list=$(list_issues)
    echo "$1-$(($(max_from "$list" "$1") + 1))"
    ;;
  check)
    { [ $# -ge 2 ] && [ $# -le 3 ]; } || usage_error "check에는 순번과 이슈 번호가 필요합니다"
    valid_seq "$1" || usage_error "순번 형식이 아닙니다(예: M1-56, 대괄호 없이): $1"
    valid_num "$2" || usage_error "이슈 번호 형식이 아닙니다: $2"
    strict=0
    if [ $# -eq 3 ]; then
      [ "$3" = --strict ] || usage_error "알 수 없는 옵션: $3"
      strict=1
    fi
    # 번호·순번 확인은 재시도 없이 한 번 조회로 한다 (번호를 잘못 넣었을 때 기다리지 않게)
    list=$(list_issues)
    case "$(title_from "$list" "$2")" in
      "[$1] "*) ;;
      *) echo "#$2의 제목이 [$1](으)로 시작하지 않습니다 — 순번·번호를 확인하세요" >&2; exit 2 ;;
    esac
    judge "$list" "$1" "$2" "$strict"
    echo "OK: [$1] #$2"
    ;;
  *)
    usage_error "알 수 없는 명령: ${cmd:-(없음)}"
    ;;
esac

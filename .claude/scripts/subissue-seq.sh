#!/usr/bin/env bash
# 서브이슈 제목 순번([M<N>-<순번>]) 도우미 (#110).
# 여러 세션이 동시에 후속 이슈를 만들면 같은 순번을 집을 수 있어(과거 M1-39~47 중복),
# 순번 발급·생성·충돌 검사·양보를 이 스크립트 한 번의 호출로 끝낸다.
#
# 사용법 (stdout 마지막 줄 = "<이슈번호> <순번>", 안내·경고는 stderr):
#   create <M1> <제목> [gh issue create 추가 인자...]
#       다음 순번으로 "[M1-<순번>] <제목>" 이슈를 만들고 검사한다. 먼저 만든 이슈와 겹치면 새 순번으로 양보한다.
#       예) create M1 "미리보기 프리셋 추가" --body-file f.md --label sub-issue --milestone "..." --project "..."
#   ensure <이슈번호>
#       이미 있는 이슈의 순번을 검사하고, 먼저 만든 이슈와 겹치면 양보한다. (/fix-issue 착수 시)
#   next <M1>
#       닫힌 이슈까지 포함한 최댓값 + 1 (예: M1-57). 조회만 한다.
#   check <M1-56> <이슈번호> [--strict]
#       번호가 더 작은(먼저 만든) 이슈가 같은 순번이면 충돌. 번호가 큰 쪽의 중복은 경고만 한다.
#       --strict: 번호와 관계없이 다른 이슈와 겹치면 충돌 (양보로 바꾼 순번의 검사용).
#
# 충돌 규칙: 처음 만든 순번은 "작은 번호가 이긴다". 양보로 바꾼 순번은 생성 뒤에 끼어든 것이라
# 이미 검사를 통과한 큰 번호 이슈를 뺏을 수 있으므로, 모든 이슈와 겹치지 않아야 통과한다(--strict).
#
# 종료 코드: 0 성공 / 2 인자·형식 오류 / 3 순번 충돌(check만) / 1 그 밖의 실패(gh 실패, 재시도 초과 등).
# 충돌이 아닌 실패에서는 제목을 바꾸지 않고 멈춘다 — 일시적 실패에 멀쩡한 순번을 버리지 않게.
set -euo pipefail
# $(...) 안은 기본적으로 set -e를 물려받지 않아 gh 실패가 빈 목록으로 묻힌다 (bash 4.4+).
# macOS 기본 bash 3.2에는 이 옵션이 없어 넘어가지만, 함수들이 실패를 `|| return 1`로 직접 돌려주므로 동작은 같다.
shopt -s inherit_errexit 2>/dev/null || true

REPO=i-technika/altcalc-fx991
# 이슈 목록 조회 한도. 받은 개수가 한도에 닿으면 오래된 이슈가 빠졌을 수 있어 실패한다.
LIMIT="${SUBISSUE_SEQ_LIMIT:-5000}"
# 양보 재시도 상한
MAX_TRIES=5
# 목록 반영 지연 시 재조회 간격(초). 테스트는 0으로 둔다.
RETRY_DELAY="${SUBISSUE_SEQ_RETRY_DELAY:-2}"

# 테스트용 가짜 gh 훅 (test/unit/subissue_seq_test.dart). 평소에는 실제 gh를 쓴다.
gh_cmd() {
  if [ -n "${SUBISSUE_SEQ_FAKE_GH:-}" ]; then
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
    echo "이슈가 조회 한도($LIMIT)에 닿아 일부가 빠졌을 수 있습니다 — LIMIT을 올리세요" >&2
    return 1
  fi
  printf '%s\n' "$out"
}

# 제목의 순번 (없으면 빈 값)
seq_of_title() { printf '%s\n' "$1" | sed -nE 's/^\[(M[0-9]+-[0-9]+)\] .*/\1/p'; }
# 제목에서 순번 접두사를 뺀 본문
body_of_title() { printf '%s\n' "$1" | sed -E 's/^\[M[0-9]+-[0-9]+\] //'; }

# next_from <목록> <M1> → M1-<최댓값+1>
next_from() {
  local max
  max=$(printf '%s\n' "$1" | cut -f2 | sed -nE "s/^\[$2-([0-9]+)\] .*/\1/p" | sort -n | tail -1)
  echo "$2-$(( ${max:-0} + 1 ))"
}

# title_from <목록> <번호> → 제목 (없으면 빈 값)
title_from() { printf '%s\n' "$1" | awk -F'\t' -v n="$2" '$1 + 0 == n + 0 { print substr($0, length($1) + 2); exit }'; }

# 방금 만들거나 고친 이슈가 목록에 보일 때까지 다시 조회한다 (GitHub 목록 반영 지연 대비).
# list_until <번호> <기대 제목 접두사> → 목록
# 주의: `||`로 불리는 함수 안에서는 set -e가 꺼지므로 실패를 명시적으로 돌려준다.
list_until() {
  local list i
  for i in 1 2 3 4 5; do
    list=$(list_issues) || return 1
    case "$(title_from "$list" "$1")" in
      "$2"*) printf '%s\n' "$list"; return 0 ;;
    esac
    sleep "$RETRY_DELAY"
  done
  echo "#$1의 제목이 '$2'(으)로 시작하지 않습니다 — 순번·번호가 맞는지 확인하세요" >&2
  return 2
}

# check_seq <순번> <번호> <strict 0|1> → 0 통과 / 3 충돌 / 그 밖 실패
check_seq() {
  local seq="$1" num="$2" strict="$3" list lower higher
  list=$(list_until "$num" "[$seq] ") || return $?
  lower=$(printf '%s\n' "$list" | awk -F'\t' -v s="[$seq] " -v n="$num" \
    'index($2, s) == 1 && $1 + 0 < n + 0 { printf "#%s ", $1 }')
  higher=$(printf '%s\n' "$list" | awk -F'\t' -v s="[$seq] " -v n="$num" \
    'index($2, s) == 1 && $1 + 0 > n + 0 { printf "#%s ", $1 }')
  if [ -n "$lower" ] || { [ "$strict" = 1 ] && [ -n "$higher" ]; }; then
    echo "충돌: [$seq]를 ${lower}${higher}이(가) 이미 사용 중 → #$num이 양보합니다" >&2
    return 3
  fi
  if [ -n "$higher" ]; then
    echo "경고: 나중에 만든 ${higher}도 [$seq]를 씁니다 — 그 이슈를 착수할 때 ensure로 양보시키세요" >&2
  fi
  return 0
}

# renumber <번호>: 새 순번으로 제목을 바꾸고 --strict 검사를 통과할 때까지 반복한다.
renumber() {
  local num="$1" list title seq body new rc i
  for ((i = 1; i <= MAX_TRIES; i++)); do
    list=$(list_issues) || return 1
    title=$(title_from "$list" "$num")
    seq=$(seq_of_title "$title")
    [ -n "$seq" ] || { echo "#$num 제목에 순번이 없습니다: $title" >&2; return 2; }
    body=$(body_of_title "$title")
    new=$(next_from "$list" "${seq%-*}")
    gh_cmd issue edit "$num" -R "$REPO" --title "[$new] $body" >/dev/null || return 1
    echo "#$num: [$seq] → [$new]" >&2
    rc=0
    check_seq "$new" "$num" 1 || rc=$?
    case "$rc" in
      0) echo "$num $new"; return 0 ;;
      3) continue ;;
      *) return "$rc" ;;
    esac
  done
  echo "#$num 순번 양보를 ${MAX_TRIES}회 시도했지만 계속 충돌합니다 — 수동으로 확인하세요" >&2
  return 1
}

# ensure <번호> [기대 순번]: 현재 순번 검사 → 충돌이면 양보
# 기대 순번을 주면(방금 만든 이슈) 목록에 보일 때까지 기다린다.
ensure() {
  local num="$1" list title seq rc=0
  if [ -n "${2:-}" ]; then
    list=$(list_until "$num" "[$2] ") || return $?
  else
    list=$(list_issues) || return 1
  fi
  title=$(title_from "$list" "$num")
  [ -n "$title" ] || { echo "#$num 이슈를 찾지 못했습니다" >&2; return 2; }
  seq=$(seq_of_title "$title")
  [ -n "$seq" ] || { echo "#$num 제목에 순번이 없습니다: $title" >&2; return 2; }
  check_seq "$seq" "$num" 0 || rc=$?
  case "$rc" in
    0) echo "$num $seq" ;;
    3) renumber "$num" ;;
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
    # 목록은 변수로 먼저 받는다 — 인자 안의 $(...) 실패는 set -e가 잡지 못해 빈 목록으로 M?-1을 발급하게 된다.
    list=$(list_issues)
    seq=$(next_from "$list" "$ms")
    url=$(gh_cmd issue create -R "$REPO" --title "[$seq] $body" "$@")
    num="${url##*/}"
    valid_num "$num" || { echo "생성 결과에서 이슈 번호를 읽지 못했습니다: $url" >&2; exit 1; }
    echo "생성: #$num [$seq] $body ($url)" >&2
    ensure "$num" "$seq"
    ;;
  ensure)
    [ $# -eq 1 ] && valid_num "$1" || usage_error "ensure에는 이슈 번호 하나가 필요합니다"
    ensure "$1"
    ;;
  next)
    [ $# -eq 1 ] && valid_ms "$1" || usage_error "next에는 마일스톤 접두사(예: M1)가 필요합니다"
    list=$(list_issues)
    next_from "$list" "$1"
    ;;
  check)
    [ $# -ge 2 ] && [ $# -le 3 ] || usage_error "check에는 순번과 이슈 번호가 필요합니다"
    valid_seq "$1" || usage_error "순번 형식이 아닙니다(예: M1-56, 대괄호 없이): $1"
    valid_num "$2" || usage_error "이슈 번호 형식이 아닙니다: $2"
    strict=0
    if [ $# -eq 3 ]; then
      [ "$3" = --strict ] || usage_error "알 수 없는 옵션: $3"
      strict=1
    fi
    check_seq "$1" "$2" "$strict"
    echo "OK: [$1] #$2"
    ;;
  *)
    usage_error "알 수 없는 명령: ${cmd:-(없음)}"
    ;;
esac

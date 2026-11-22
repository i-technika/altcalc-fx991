#!/usr/bin/env bash
# 서브이슈 제목 순번([M<N>-<순번>]) 도우미.
# 여러 세션이 동시에 후속 이슈를 만들면 같은 순번을 집을 수 있어(과거 M1-39~47 중복),
# 생성 직전에 다음 순번을 구하고 생성 직후 충돌을 검사한다.
#
# 사용법:
#   bash .claude/scripts/subissue-seq.sh next M1              # → M1-56 (닫힌 이슈 포함 최댓값 + 1)
#   bash .claude/scripts/subissue-seq.sh check M1-56 <이슈번호>  # 더 먼저 만든 이슈가 같은 순번이면 실패(exit 1)
#
# 충돌 시 규칙: 이슈 번호가 큰(나중에 만든) 쪽이 양보한다 → next로 새 순번을 받아 제목을 고치고 다시 check한다.
set -euo pipefail

REPO=i-technika/altcalc-fx991

# 모든 상태의 이슈를 "번호<TAB>제목"으로 출력한다. (jq 정규식 대신 셸에서 거른다 — Git Bash의 역슬래시 변환 회피)
list_issues() {
  gh issue list -R "$REPO" --state all -L 1000 --json number,title \
    --jq '.[] | "\(.number)\t\(.title)"'
}

case "${1:-}" in
  next)
    ms="${2:?마일스톤 접두사를 지정하세요 (예: M1)}"
    max=$(list_issues | cut -f2 | sed -nE "s/^\[$ms-([0-9]+)\].*/\1/p" | sort -n | tail -1)
    echo "$ms-$(( ${max:-0} + 1 ))"
    ;;
  check)
    seq="${2:?순번을 지정하세요 (예: M1-56)}"
    num="${3:?방금 만든 이슈 번호를 지정하세요}"
    others=$(list_issues | awk -F'\t' -v s="[$seq]" -v n="$num" \
      'index($2, s) == 1 && $1 + 0 != n + 0 && $1 + 0 < n + 0 { printf "#%s ", $1 }')
    if [ -n "$others" ]; then
      echo "충돌: [$seq]를 먼저 만든 ${others}이(가) 이미 사용 중 → #$num의 순번을 next로 다시 받으세요" >&2
      exit 1
    fi
    echo "OK: [$seq] #$num"
    ;;
  *)
    echo "사용법: $0 next <M1> | check <M1-56> <이슈번호>" >&2
    exit 2
    ;;
esac

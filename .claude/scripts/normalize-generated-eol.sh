#!/usr/bin/env bash
# 생성 플러그인 파일을 .gitattributes(eol=lf)에 맞게 LF로 다시 받는다 (#67).
#
# #67 이전에 체크아웃한 작업 트리는 이 파일들이 CRLF로 남아 있어, Flutter가 LF로 다시 쓰면
# 내용 차이 없이 "수정됨"으로 보인다. 그 상태로 생성 파일을 실제로 바꾸는 브랜치로 전환·머지하면
# "local changes would be overwritten"으로 막힐 수 있으므로, 전환·머지 전에 한 번 실행한다.
# Flutter가 다시 쓰기 전·후 어느 때 실행해도 된다. 내용이 실제로 바뀐 파일이 있으면 아무것도 하지 않고 중단한다.
#
# 사용: bash .claude/scripts/normalize-generated-eol.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# .gitattributes에서 eol=lf를 받는 추적 생성 파일 (목록을 여기 따로 적지 않는다)
mapfile -t files < <(
  git ls-files -- linux/flutter windows/flutter macos/Flutter |
    git check-attr --stdin eol |
    sed -n 's/: eol: lf$//p'
)
if [ "${#files[@]}" -eq 0 ]; then
  echo "eol=lf 대상 생성 파일이 없습니다. .gitattributes를 확인하세요." >&2
  exit 1
fi

# 줄바꿈만 다른 파일은 git diff에서 차이가 없다. 차이가 보이면 진짜 변경이므로 건드리지 않는다.
if ! git diff --quiet -- "${files[@]}" || ! git diff --cached --quiet -- "${files[@]}"; then
  echo "내용이 실제로 바뀐 생성 파일이 있어 중단합니다. 커밋하거나 되돌린 뒤 다시 실행하세요:" >&2
  git diff --stat HEAD -- "${files[@]}" >&2
  exit 1
fi

# 지운 뒤 다시 받아야 stat이 깨끗한 파일도 LF로 새로 쓰이고, 인덱스의 크기 기록도 LF 기준으로 바뀐다.
rm -f -- "${files[@]}"
git checkout -- "${files[@]}"
echo "LF로 다시 받음: ${#files[@]}개"
git status --short -- "${files[@]}"

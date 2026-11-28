#!/usr/bin/env bash
# 생성 플러그인 파일을 .gitattributes(eol=lf)에 맞게 LF로 다시 받는다 (#67).
#
# #67 이전에 체크아웃한 작업 트리는 이 파일들이 CRLF로 남아 있어, Flutter가 LF로 다시 쓰면
# 내용 차이 없이 "수정됨"으로 보인다. #67이 들어온 브랜치로 전환·머지한 **뒤** 한 번 실행한다.
# (#67 이전 브랜치에서 전환·머지가 막히면, 7개 파일의 `git diff`가 비어 있는지 보고 그 파일만
#  `git checkout --` 한다 — CLAUDE.md "로컬 개발 환경 메모" 참조.)
# Flutter가 다시 쓰기 전·후 어느 때 실행해도 된다. 내용이 실제로 바뀐 파일이 있으면 아무것도 하지 않고 중단한다.
#
# 사용 (Windows는 Git Bash, macOS 기본 bash 3.2에서도 동작): bash .claude/scripts/normalize-generated-eol.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# eol=lf 속성을 받는 추적 파일 중 생성 플러그인 파일만 고른다 (대상 목록은 .gitattributes가 정한다).
# -z로 읽어 공백·비ASCII 경로도 그대로 다룬다. 출력 형식: <경로>\0eol\0<값>\0
attrs=$(git ls-files -z | git check-attr -z --stdin eol | tr '\0' '\n') # git 실패는 pipefail로 멈춘다
files=()
while IFS= read -r path && IFS= read -r _attr && IFS= read -r value; do
  if [ "$value" = lf ]; then
    case "$path" in
      */generated_plugin* | */GeneratedPluginRegistrant.*) files+=("$path") ;;
    esac
  fi
done <<<"$attrs"
if [ "${#files[@]}" -eq 0 ]; then
  echo "eol=lf 대상 생성 파일이 없습니다. #67(.gitattributes)이 들어온 브랜치인지 확인하세요." >&2
  exit 1
fi

# 줄바꿈만 다른 파일은 git diff에서 차이가 없다. 차이가 보이면 진짜 변경이므로 건드리지 않는다.
if ! git diff --quiet -- "${files[@]}" || ! git diff --cached --quiet -- "${files[@]}"; then
  echo "내용이 실제로 바뀐 생성 파일이 있어 중단합니다. 커밋하거나 되돌린 뒤 다시 실행하세요:" >&2
  git diff --stat HEAD -- "${files[@]}" >&2
  exit 1
fi

# 다른 git 작업(VS Code 등)이 인덱스를 잡고 있으면 checkout이 실패하므로, 지우기 전에 확인한다.
lock=$(git rev-parse --git-path index.lock)
if [ -e "$lock" ]; then
  echo "다른 git 작업이 진행 중입니다($lock). 끝난 뒤 다시 실행하세요." >&2
  exit 1
fi

# 지운 뒤 다시 받아야 stat이 깨끗한 파일도 LF로 새로 쓰이고, 인덱스의 크기 기록도 LF 기준으로 바뀐다.
# checkout이 실패해도 파일이 지워진 채 남지 않게, 실패하면 인덱스에서 다시 받아 둔다(내용은 인덱스와 같다).
restore() {
  echo "다시 받기에 실패했습니다. 복구를 시도합니다: git checkout -- <생성 파일>" >&2
  git checkout -- "${files[@]}" || echo "복구도 실패했습니다. 직접 'git checkout -- ${files[*]}'를 실행하세요." >&2
}
trap restore ERR
rm -f -- "${files[@]}"
git checkout -- "${files[@]}"
trap - ERR
echo "LF로 다시 받음: ${#files[@]}개"
git status --short -- "${files[@]}"

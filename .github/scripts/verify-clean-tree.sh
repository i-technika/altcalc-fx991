#!/usr/bin/env bash
# CI: pub get·test·build 뒤 작업 트리가 깨끗한지 확인한다 (#67).
#
# 사용: bash .github/scripts/verify-clean-tree.sh [경로...]
#   경로를 주면 그 경로만 검사한다 (macOS 잡처럼 빌드가 다른 파일을 정당하게 바꿀 수 있는 곳).
#
# 실패 원인 후보:
#   - 생성 플러그인 파일이 줄바꿈만 달라 수정됨 → .gitattributes(eol=lf)가 깨짐. 아래 eol 표를 본다.
#   - 생성 파일 내용이 실제로 바뀜 → 의존성을 바꾸고 재생성된 파일을 커밋하지 않음.
#   - 무시되지 않은 새 생성물 → .gitignore 누락.
#   - pubspec.lock이 바뀜 → pubspec.yaml을 고치고 다시 받은 pubspec.lock을 커밋하지 않음.
#     CI와 로컬의 Flutter SDK는 pubspec.yaml의 environment.flutter로 같은 버전에 고정되어 있으므로(#78)
#     SDK 차이 탓으로 돌려 통과시키지 않는다.
set -euo pipefail

status=$(git status --porcelain -- "$@")
if [ -z "$status" ]; then
  echo "작업 트리 깨끗함${*:+ (검사 범위: $*)}"
  exit 0
fi

echo "$status"
echo "--- 생성 플러그인 파일 줄바꿈 (i/=저장소, w/=작업본, attr/=속성)"
git ls-files --eol -- linux/flutter windows/flutter macos/Flutter |
  grep -E 'generated_plugin|GeneratedPluginRegistrant' || true
echo "--- 내용 차이"
git diff --stat -- "$@" || true

if printf '%s\n' "$status" | grep -q ' pubspec\.lock$'; then
  echo "::error::pubspec.lock이 바뀌었다. 고정된 SDK(pubspec.yaml의 environment.flutter)로 로컬에서 flutter pub get을 실행해 갱신된 pubspec.lock을 커밋할 것 (#78)."
  # head가 먼저 닫혀 git이 SIGPIPE로 끝나도 pipefail로 여기서 멈추지 않게 한다
  { git diff -- pubspec.lock || true; } | head -40 || true
  # lock 말고 다른 변경도 있으면 아래 일반 오류 안내도 함께 낸다
  printf '%s\n' "$status" | grep -qv ' pubspec\.lock$' || exit 1
fi

echo "::error::빌드 뒤 작업 트리가 깨끗하지 않다 (#67). 위 eol 표와 내용 차이로 원인(줄바꿈 속성·생성 파일 커밋 누락·.gitignore 누락)을 확인할 것."
exit 1

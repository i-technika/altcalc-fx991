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
# pubspec.lock만 바뀐 경우는 CI의 Flutter SDK 버전이 로컬과 달라 SDK가 고정하는 의존성 버전이 바뀐 것일 수 있어
# 경고만 하고 통과시킨다 (이 검사의 목적인 줄바꿈 회귀와 관계가 없다).
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

if [ "$status" = " M pubspec.lock" ]; then
  echo "::warning::pubspec.lock만 바뀌었다. CI와 로컬의 Flutter SDK 버전 차이일 수 있다 — 필요하면 로컬에서 갱신해 커밋할 것."
  git diff -- pubspec.lock | head -40
  exit 0
fi

echo "::error::빌드 뒤 작업 트리가 깨끗하지 않다 (#67). 위 eol 표와 내용 차이로 원인(줄바꿈 속성·생성 파일 커밋 누락·.gitignore 누락)을 확인할 것."
exit 1

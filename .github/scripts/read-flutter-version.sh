#!/usr/bin/env bash
# CI: pubspec.yaml의 environment.flutter(고정 Flutter SDK 버전, #78)를 읽는다 (#90).
#
# 사용: bash .github/scripts/read-flutter-version.sh [pubspec 경로]
#   표준 출력에는 버전(X.Y.Z)만 내보낸다. GitHub Actions에서는 단계 출력 `version`으로도 내보내고,
#   워크플로가 이 값을 subosito/flutter-action의 `flutter-version`으로 넘긴다.
#
# 왜 직접 읽나: 액션의 `flutter-version-file: pubspec.yaml`은 yq로 값을 읽는다. Windows 러너에는 yq가 없어
#   액션이 매번 `choco install yq`를 실행했고, Chocolatey 저장소 장애·요청 제한이 곧 Windows 빌드 실패였다.
#   Linux·macOS 러너의 yq도 러너 이미지에 미리 깔려 있다는 것에 기대는 의존이라, 모든 잡이 이 스크립트를 쓴다.
#   외부 명령 없이 bash 내장 기능만 쓴다(macOS의 bash 3.2 포함) — 러너마다 다른 awk·sed 구현에 기대지 않는다.
#
# 읽는 형태: 최상위 `environment:` 블록 바로 아래 키인 `flutter: X.Y.Z` 한 줄
#   (따옴표·줄 끝 주석·CRLF·파일 첫머리 BOM 허용).
#   YAML 해석기가 아니라 줄 단위로 이 형태만 찾는다. 알아볼 수 있는 다른 표기(범위 `^`·`>=`, 채널 이름,
#   `3.50`·`3.50.x`, 여러 줄로 이어지는 값, 탭으로 시작하는 줄, 흐름 표기 `environment: {…}`, 같은 키·블록 두 번)는 실패시킨다.
#   - 값이 비면 액션이 최신 stable을 설치하고, `3.50`·`3.50.x`는 액션이 접두 일치로 그 계열의 최신 패치를 고른다.
#     그 버전이 고정값과 다르면 뒤의 `flutter pub get`이 SDK 제약 오류로 실패해 원인을 찾기 어렵다.
#   - 줄 단위로는 구별하지 못하는 YAML 구조도 있다(여러 줄 따옴표 값 안의 가짜 블록, 여러 줄에 걸친 흐름 표기 등).
#     이런 경우를 막는 것은 test/unit/flutter_sdk_pin_test.dart의 대조다(실제 pubspec.yaml에서 읽은 값이
#     YAML 해석과 같은지 — Linux 잡의 `flutter test`에서 돈다). pub이 읽은 고정값과 다른 버전이 설치되면
#     `flutter pub get`도 실패하지만, pub이 environment.flutter를 아예 읽지 못하는 형태에서는 그 검사가 없다.
set -euo pipefail

file=${1:-pubspec.yaml}

# 오류는 표준 오류로 낸다(표준 출력은 버전 전용). Actions는 표준 오류의 `::error::`도 주석으로 표시한다.
fail() {
  echo "::error::$*" >&2
  exit 1
}

[ -f "$file" ] || fail "$file 이 없다 — 저장소 체크아웃 뒤에, 패키지 루트에서 실행할 것"

# 정규식은 변수에 담아 쓴다 — [[ =~ ]] 오른쪽에 직접 적으면 bash 버전에 따라 따옴표·역슬래시 해석이 다르다
top_level='^[^[:space:]#]'                      # 들여쓰기 없는 줄(주석 제외) = 최상위 키나 문서 구분자
env_key='^environment:[[:space:]]*(#.*)?$'      # 블록 표기의 environment: (값이 같은 줄에 없음)
child='^( +)[^[:space:]#]'                      # 공백으로 들여쓴 내용 줄 (빈 줄·주석 줄 제외)
flutter_key='^ +flutter:([[:space:]].*)?$'
has_content='[^[:space:]]'
# 정확한 버전만(앞자리 0 없음) — 액션은 `3.50`·`3.50.x`도 받지만 접두 일치로 다른 패치를 고른다
exact='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
bom=$'\xef\xbb\xbf'

in_env=false
env_blocks=0
indent=""
flutter_last=false # 바로 앞의 키 줄이 flutter였는가 (값이 다음 줄로 이어지는지 보려고)
count=0
version=""
first=true
# `|| [ -n "$line" ]`: 마지막 줄에 줄바꿈이 없어도 읽는다
while IFS= read -r line || [ -n "$line" ]; do
  if $first; then
    line=${line#"$bom"} # UTF-8 BOM (pub은 파일을 읽을 때 BOM을 벗긴다)
    first=false
  fi
  line=${line%$'\r'} # core.autocrlf=true 체크아웃(Windows 잡)의 CRLF
  if [[ $line =~ $top_level ]]; then
    if [[ $line =~ $env_key ]]; then
      in_env=true
      indent=""
      env_blocks=$((env_blocks + 1))
    else
      in_env=false
    fi
    continue
  fi
  $in_env || continue
  # 탭으로 시작하는 줄(주석 줄 포함)은 YAML에서 들여쓰기 오류다.
  # 공백 들여쓰기 뒤의 탭은 블록 스칼라의 내용일 수 있어 해당하지 않는다.
  if [[ $line == $'\t'* && $line =~ $has_content ]]; then
    fail "$file 의 environment 블록에 탭으로 시작하는 줄이 있다 — YAML은 들여쓰기에 탭을 쓸 수 없다"
  fi
  [[ $line =~ $child ]] || continue
  lead=${BASH_REMATCH[1]}
  # 블록의 첫 내용 줄 들여쓰기가 environment의 키 깊이다. 깊이가 다른 줄은 앞 키의 값이 이어지는 줄이므로 키로 보지 않는다.
  # (블록에 다시 들어오면 indent가 비어 첫 줄이 항상 키 깊이가 되므로, flutter_last는 여기서만 초기화하면 된다)
  [ -n "$indent" ] || indent=$lead
  if [ "$lead" != "$indent" ]; then
    ! $flutter_last || fail "$file 의 environment.flutter 값이 다음 줄로 이어진다 — 'flutter: X.Y.Z' 한 줄로 적을 것"
    continue
  fi
  flutter_last=false
  [[ $line =~ $flutter_key ]] || continue
  flutter_last=true

  value=${BASH_REMATCH[1]:-}
  value=${value%%[[:space:]]#*}              # 줄 끝 주석 (YAML: 공백 뒤의 #)
  value=${value#"${value%%[![:space:]]*}"}   # 앞 공백
  value=${value%"${value##*[![:space:]]}"}   # 뒤 공백
  case $value in
    \"*\")
      value=${value#\"}
      value=${value%\"}
      ;;
    \'*\')
      value=${value#\'}
      value=${value%\'}
      ;;
  esac
  version=$value
  count=$((count + 1))
done <"$file"

[ "$env_blocks" -le 1 ] || fail "$file 에 최상위 environment: 블록이 ${env_blocks}개다 — 하나만 둘 것"
if [ "$count" -eq 0 ]; then
  fail "$file 에서 environment.flutter를 찾지 못했다 — 최상위 'environment:' 아래에 'flutter: X.Y.Z' 한 줄로 적을 것 (키 따옴표·흐름 표기 {…}는 읽지 않는다, #78)"
elif [ "$count" -gt 1 ]; then
  fail "$file 의 environment에 flutter: 줄이 ${count}개다 — 하나만 둘 것"
fi
[[ $version =~ $exact ]] ||
  fail "$file 의 environment.flutter가 정확한 버전(X.Y.Z)이 아니다: '$version' — 범위·채널 이름·앞자리 0은 쓰지 않는다 (#78)"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "version=$version" >>"$GITHUB_OUTPUT"
fi
echo "$version"

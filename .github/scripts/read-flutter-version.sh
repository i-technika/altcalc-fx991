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
#   (따옴표·줄 끝 주석·CRLF 허용). 그 밖의 표기(범위 `^`·`>=`, 채널 이름, 흐름 표기 `{…}`, 같은 키 두 번)는
#   추측하지 않고 실패한다 — 값이 비면 액션이 최신 stable을 설치해 고정이 조용히 풀리기 때문이다.
#   읽은 값이 YAML 해석과 같은지는 test/unit/flutter_sdk_pin_test.dart가 대조한다.
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
child='^([[:space:]]+)[^[:space:]#]'            # 들여쓴 내용 줄 (빈 줄·주석 줄 제외)
flutter_key='^[[:space:]]+flutter:([[:space:]].*)?$'
exact='^[0-9]+\.[0-9]+\.[0-9]+$'                # 정확한 버전만 — 액션은 범위 표기를 받지 않는다

in_env=false
indent=""
count=0
version=""
# `|| [ -n "$line" ]`: 마지막 줄에 줄바꿈이 없어도 읽는다
while IFS= read -r line || [ -n "$line" ]; do
  line=${line%$'\r'} # core.autocrlf=true 체크아웃(Windows 잡)의 CRLF
  if [[ $line =~ $top_level ]]; then
    if [[ $line =~ $env_key ]]; then
      in_env=true
      indent=""
    else
      in_env=false
    fi
    continue
  fi
  $in_env || continue
  [[ $line =~ $child ]] || continue
  lead=${BASH_REMATCH[1]}
  # 블록의 첫 내용 줄 들여쓰기가 environment의 키 깊이다. 더 깊은 줄은 다른 값의 일부이므로 키로 보지 않는다.
  [ -n "$indent" ] || indent=$lead
  [ "$lead" = "$indent" ] || continue
  [[ $line =~ $flutter_key ]] || continue

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

if [ "$count" -eq 0 ]; then
  fail "$file 에서 environment.flutter를 찾지 못했다 — 최상위 'environment:' 아래에 'flutter: X.Y.Z' 한 줄로 적을 것 (#78)"
elif [ "$count" -gt 1 ]; then
  fail "$file 의 environment에 flutter: 줄이 $count개다 — 하나만 둘 것"
fi
[[ $version =~ $exact ]] ||
  fail "$file 의 environment.flutter가 정확한 버전(X.Y.Z)이 아니다: '$version' — 범위·채널 이름은 쓰지 않는다 (#78)"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "version=$version" >>"$GITHUB_OUTPUT"
fi
echo "$version"

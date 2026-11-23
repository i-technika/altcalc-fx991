#!/usr/bin/env bash
# CI: 릴리스 APK(R8 축소)에서 새 API 수준 전용 참조가 정해진 격리 클래스 밖으로 새지 않았는지 검사한다 (#109).
#
# 사용: bash .github/scripts/verify-api-isolation.sh <APK> <mapping.txt>
#   APK         — `flutter build apk --release`가 만든 APK (R8로 축소·난독화된 dex가 들어 있다)
#   mapping.txt — 같은 빌드의 R8 이름 대응표 (build/app/outputs/mapping/release/mapping.txt)
#   ANDROID_HOME(또는 ANDROID_SDK_ROOT)의 Android SDK가 있어야 한다:
#     build-tools의 dexdump·aapt2(가장 높은 버전), APK의 compileSdk 플랫폼의 data/api-versions.xml.
#
# 왜: R8은 늘 실행되는 메서드에 API 36 전용 타입 참조를 인라인할 수 있다. 그러면 API 35 이하 기기에서
#   클래스 검증·로딩이 실패할 수 있다(Flutter 엔진이 같은 이유로 Api34Impl에 가두는 NoClassDefFoundError, flutter#192231).
#   소스의 @RequiresApi 중첩 object + @DoNotInline 격리(#95)가 R8 뒤에도 유지되는지는 dex를 열어 봐야 안다.
#
# 규칙(.github/api-isolation-rules, 바꾸려면 API_ISOLATION_RULES):
#   guard-api <N> — api-versions.xml에서 API N 이상에 추가된 클래스·메서드·필드를 "검사 대상 참조"로 삼는다.
#   allow <glob>  — 원래(난독화 전) 클래스 이름 glob. 검사 대상 참조는 이 클래스들 안에만 있어야 한다.
#   dex의 클래스 이름은 mapping.txt로 원래 이름으로 되돌려 맞춘다(대응표에 없으면 dex 이름 그대로).
#   프레임워크 클래스 이름 그대로 dex에 든 클래스(api-versions.xml에 있는 이름이고, 대응표에 R8 합성 표시가 있거나 대응표에 없음)는
#   R8 API 스텁이라 늘 허용한다.
#
# 출력: 검사 대상 참조가 있는 클래스마다 "허용|허용(R8 스텁)|위반 <원래 이름> (dex <dex 이름>)"과 그 참조 목록.
#
# 검사가 헛돌지 않게 다음 경우에도 실패한다:
#   - mapping.txt가 비었거나 없음(R8이 돌지 않은 빌드), APK에 dex가 없음
#   - api-versions.xml에 guard-api 이상 항목이 하나도 없음(플랫폼이 낮거나 형식이 바뀜)
#   - APK의 minSdk가 guard-api 이상(격리할 대상이 없어 규칙을 다시 정해야 함)
#   - dex 전체에서 검사 대상 참조를 하나도 찾지 못함(앱에 API 36 코드가 있으므로, 0개면 dexdump 출력 형식 변화를 의심한다)
#
# 한계: 참조는 dex에 적힌 그대로(선언 클래스 기준) 맞춘다. 하위 클래스 타입으로 부른 새 메서드
#   (예: API N에 View에 추가된 메서드를 TextView로 호출)는 메서드로는 못 잡는다 — 그 경우에도 R8은 보통 호출을
#   API 아웃라인으로 옮기고, 새 타입이 들어간 시그니처·캐스트는 타입으로 잡힌다.
set -euo pipefail

error() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::error::$*" >&2
  else
    echo "오류: $*" >&2
  fi
}

fail() {
  error "$@"
  exit 1
}

[ $# -eq 2 ] || { echo "사용: bash .github/scripts/verify-api-isolation.sh <APK> <mapping.txt>" >&2; exit 2; }
apk=$1
mapping=$2
rules=${API_ISOLATION_RULES:-$(dirname "$0")/../api-isolation-rules}
sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}

[ -f "$apk" ] || fail "APK가 없다: $apk"
[ -s "$mapping" ] || fail "mapping.txt가 없거나 비었다: $mapping — 릴리스 빌드에서 R8(minify)이 돌았는지 확인할 것"
[ -f "$rules" ] || fail "규칙 파일이 없다: $rules"
[ -n "$sdk" ] && [ -d "$sdk" ] || fail "ANDROID_HOME(또는 ANDROID_SDK_ROOT)의 Android SDK를 찾지 못했다"

# ── 규칙 읽기 ───────────────────────────────────────────────────────────────
guard=""
allows=()
lineno=0
while IFS= read -r line || [ -n "$line" ]; do
  lineno=$((lineno + 1))
  line=${line%$'\r'}
  line=${line%%#*}
  read -r key value rest <<<"$line" || true
  [ -n "${key:-}" ] || continue
  [ -n "${value:-}" ] && [ -z "${rest:-}" ] || fail "$rules:$lineno: 형식이 틀렸다 — '$line' (지시어와 값 하나)"
  case $key in
    guard-api)
      [ -z "$guard" ] || fail "$rules:$lineno: guard-api가 두 번 있다"
      [[ $value =~ ^[0-9]+$ ]] || fail "$rules:$lineno: guard-api는 정수 API 수준이다 — '$value'"
      guard=$value
      ;;
    allow) allows+=("$value") ;;
    *) fail "$rules:$lineno: 모르는 지시어 '$key' (guard-api·allow만 쓴다)" ;;
  esac
done <"$rules"
[ -n "$guard" ] || fail "$rules: guard-api가 없다"
[ ${#allows[@]} -gt 0 ] || fail "$rules: allow가 하나도 없다"

# ── SDK 도구 찾기: dexdump·aapt2가 모두 있는 가장 높은 build-tools ──────────────
find_tool() { # <디렉터리> <이름> — Windows SDK는 .exe가 붙는다
  if [ -f "$1/$2" ]; then echo "$1/$2"; elif [ -f "$1/$2.exe" ]; then echo "$1/$2.exe"; fi
}
dexdump=""
aapt2=""
while IFS= read -r dir; do
  d=$(find_tool "$dir" dexdump)
  a=$(find_tool "$dir" aapt2)
  if [ -n "$d" ] && [ -n "$a" ]; then
    dexdump=$d
    aapt2=$a
    break
  fi
done < <(find "$sdk/build-tools" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -rV)
[ -n "$dexdump" ] || fail "$sdk/build-tools에서 dexdump·aapt2가 함께 있는 버전을 찾지 못했다"
echo "도구: $dexdump"

# ── APK의 minSdk·compileSdk → api-versions.xml ─────────────────────────────
badging=$("$aapt2" dump badging "$apk") || fail "aapt2 dump badging 실패: $apk"
min_sdk=$(printf '%s\n' "$badging" | sed -n "s/^minSdkVersion:'\([0-9]*\)'.*/\1/p" | head -1)
compile_sdk=$(printf '%s\n' "$badging" | sed -n "s/^package:.* compileSdkVersion='\([0-9]*\)'.*/\1/p" | head -1)
[ -n "$min_sdk" ] && [ -n "$compile_sdk" ] || fail "APK에서 minSdk·compileSdk를 읽지 못했다 (aapt2 dump badging 형식 확인)"
echo "APK: minSdk $min_sdk, compileSdk $compile_sdk / 검사 대상: API $guard 이상에 추가된 API"
[ "$min_sdk" -lt "$guard" ] ||
  fail "minSdk($min_sdk)가 guard-api($guard) 이상이라 격리할 대상이 없다 — $rules의 guard-api와 격리 클래스를 다시 정할 것"
api_versions="$sdk/platforms/android-$compile_sdk/data/api-versions.xml"
[ -f "$api_versions" ] || fail "compileSdk $compile_sdk 플랫폼의 api-versions.xml이 없다: $api_versions"

# ── dex 꺼내 dexdump ───────────────────────────────────────────────────────
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
unzip -q -o "$apk" 'classes*.dex' -d "$work" 2>/dev/null || true
shopt -s nullglob
dexes=("$work"/classes*.dex)
[ ${#dexes[@]} -gt 0 ] || fail "APK에 classes*.dex가 없다: $apk"
: >"$work/dump.txt"
for dex in "${dexes[@]}"; do
  "$dexdump" -d "$dex" >>"$work/dump.txt" || fail "dexdump 실패: $(basename "$dex")"
done
echo "dex ${#dexes[@]}개 검사"

# ── 대조 ──────────────────────────────────────────────────────────────────
# 입력: api-versions.xml → mapping.txt → dexdump 출력. 결과 표(종류<TAB>원래 이름<TAB>dex 이름<TAB>참조)를 내고
# 종료 코드로 상태를 알린다: 0 통과, 1 허용 밖 참조, 3 검사 대상 참조 0개, 4 api-versions에 대상 항목 0개, 5 dex 클래스 0개.
ALLOW=$(printf '%s\n' "${allows[@]}") GUARD=$guard awk '
  function attr(line, name,    m) {
    if (match(line, " " name "=\"[^\"]*\"")) {
      m = substr(line, RSTART + length(name) + 3, RLENGTH - length(name) - 4)
      return m
    }
    return ""
  }
  # glob(*만 특수) → 앵커가 있는 정규식
  function glob_re(g,    out, i, ch) {
    out = "^"
    for (i = 1; i <= length(g); i++) {
      ch = substr(g, i, 1)
      if (ch == "*") out = out ".*"
      else if (index("\\^$.[]|()+?{}", ch)) out = out "\\" ch
      else out = out ch
    }
    return out "$"
  }
  function descriptor_name(d) { d = substr(d, 2, length(d) - 2); gsub("/", ".", d); return d }
  function hit(ref) {
    if (!((cls SUBSEP ref) in seen)) { seen[cls SUBSEP ref] = 1; refs[cls] = refs[cls] "\t" ref; total++ }
  }
  BEGIN {
    guard = ENVIRON["GUARD"] + 0
    n_allow = split(ENVIRON["ALLOW"], allow_glob, "\n")
    for (i = 1; i <= n_allow; i++) allow_re[i] = glob_re(allow_glob[i])
  }
  { sub(/\r$/, "") }
  # 1) api-versions.xml: 검사 대상 타입·메서드·필드
  FILENAME == ARGV[1] {
    if ($0 ~ /^[ \t]*<class name="/) {
      klass = "L" attr($0, "name") ";"
      framework[descriptor_name(klass)] = 1
      since = attr($0, "since"); if (since == "") since = 1
      klass_new = (since + 0 >= guard)
      if (klass_new) { types[klass] = 1; guarded++ }
    } else if ($0 ~ /^[ \t]*<\/class>/) {
      klass = ""
    } else if (klass != "" && !klass_new && $0 ~ /^[ \t]*<(method|field) name="/) {
      since = attr($0, "since")
      if (since != "" && since + 0 >= guard) {
        name = attr($0, "name")
        if ($0 ~ /<method/) { p = index(name, "("); members[klass "." substr(name, 1, p - 1) ":" substr(name, p)] = 1 }
        else fields[klass "." name ":"] = 1
        guarded++
      }
    }
    next
  }
  # 2) mapping.txt: dex 이름 → 원래 이름 (클래스 줄만: "원래 -> dex:")
  FILENAME == ARGV[2] {
    if ($0 ~ /^[^ #][^ ]* -> [^ ]+:$/) { obf = $3; sub(/:$/, "", obf); original[obf] = $1; last_class = obf }
    else if ($0 ~ /^# \{"id":"com\.android\.tools\.r8\.synthesized"\}$/ && last_class != "") synthesized[last_class] = 1
    else if ($0 !~ /^#/) last_class = ""
    next
  }
  # 3) dexdump: 클래스마다 나오는 모든 타입·멤버 참조를 본다
  /^  Class descriptor  *: '\''L/ {
    match($0, /'\''L[^'\'']*;'\''/)
    cls = descriptor_name(substr($0, RSTART + 1, RLENGTH - 2))
    classes++
    next
  }
  cls != "" {
    line = $0
    while (match(line, /L[^;[:space:]'\''"(){},]+;(\.[^:[:space:]]+:[^[:space:]]+)?/)) {
      token = substr(line, RSTART, RLENGTH)
      line = substr(line, RSTART + RLENGTH)
      p = index(token, ";")
      type = substr(token, 1, p)
      if (type in types) hit(type)
      if (length(token) > p) {
        if (token in members) hit(token)
        q = index(substr(token, p + 2), ":")
        if (substr(token, 1, p + 1 + q) in fields) hit(substr(token, 1, p + 1 + q))
      }
      # 멤버 참조의 시그니처 안 타입도 본다 (예: 메서드 인자·반환 타입)
      rest_types = substr(token, p + 1)
      while (match(rest_types, /L[^;]+;/)) {
        type = substr(rest_types, RSTART, RLENGTH)
        rest_types = substr(rest_types, RSTART + RLENGTH)
        if (type in types) hit(type)
      }
    }
  }
  END {
    if (guarded == 0) exit 4
    if (classes == 0) exit 5
    if (total == 0) exit 3
    bad = 0
    for (c in refs) {
      name = (c in original) ? original[c] : c
      # 프레임워크 클래스 이름 그대로 dex에 있는 클래스는 R8이 새 API 클래스를 대신해 넣는 스텁이다
      # (그 클래스를 상속한 앱 클래스가 낮은 API에서도 검증되게 한다 — 기기에 진짜 클래스가 있으면 그쪽을 쓴다)
      if ((name in framework) && (!(c in original) || (c in synthesized))) kind = "허용(R8 스텁)"
      else {
        kind = "위반"
        for (i = 1; i <= n_allow; i++) if (name ~ allow_re[i]) { kind = "허용"; break }
      }
      if (kind == "위반") bad = 1
      n = split(substr(refs[c], 2), list, "\t")
      for (i = 1; i <= n; i++) print kind "\t" name "\t" c "\t" list[i]
    }
    exit bad
  }
' "$api_versions" "$mapping" "$work/dump.txt" >"$work/report.tsv" && status=0 || status=$?

case $status in
  0 | 1) ;;
  3) fail "dex 전체에서 API $guard 이상 전용 참조를 하나도 찾지 못했다 — dexdump 출력 형식이 바뀌었거나, API $guard 코드를 없앴다면 $rules와 이 검사를 다시 정할 것" ;;
  4) fail "api-versions.xml에 API $guard 이상 항목이 없다: $api_versions (플랫폼 버전·파일 형식 확인)" ;;
  5) fail "dexdump 출력에서 클래스를 하나도 읽지 못했다 (출력 형식 확인)" ;;
  *) fail "대조 중 오류 (awk 종료 코드 $status)" ;;
esac

# 클래스별로 묶어 보여 준다 (허용 → 위반 순)
sort -t$'\t' -k1,1 -k2,2 -k4,4 "$work/report.tsv" | awk -F'\t' '
  { key = $1 "\t" $2 "\t" $3 }
  key != last { printf "%s %s (dex %s)\n", $1, $2, $3; last = key }
  { printf "    %s\n", $4 }
'
if [ $status -eq 1 ]; then
  fail "API $guard 이상 전용 참조가 허용된 격리 클래스($rules의 allow) 밖에 있다 — 위 \"위반\" 클래스. API $((guard - 1)) 이하 기기에서 클래스 검증·로딩이 실패할 수 있다. 참조를 @RequiresApi 격리 object(@DoNotInline 메서드)로 옮길 것 (#95, #109)"
fi
echo "통과: API $guard 이상 전용 참조가 모두 허용된 격리 클래스 안에 있다"

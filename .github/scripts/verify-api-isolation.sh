#!/usr/bin/env bash
# CI: 릴리스 APK(R8 축소)에서 새 API 수준 전용 참조가 정해진 격리 클래스 밖으로 새지 않았는지 검사한다 (#109).
#
# 사용: bash .github/scripts/verify-api-isolation.sh <APK> <mapping.txt>
#   APK         — `flutter build apk --release`가 만든 APK (R8로 축소·난독화된 dex가 들어 있다)
#   mapping.txt — 같은 빌드의 R8 이름 대응표 (build/app/outputs/mapping/release/mapping.txt)
#   ANDROID_HOME(또는 ANDROID_SDK_ROOT)의 Android SDK가 있어야 한다:
#     build-tools의 dexdump·aapt2(둘 다 있는 가장 높은 버전), compileSdk 이상 플랫폼의 data/api-versions.xml
#     (설치된 것 중 가장 높은 숫자 플랫폼 — 상위집합이라 마이너 API 항목까지 담는다).
#
# 왜: R8은 늘 실행되는 메서드에 API 36 전용 타입 참조를 인라인할 수 있다. 그러면 API 35 이하 기기에서
#   클래스 검증·로딩이 실패할 수 있다(Flutter 엔진이 같은 이유로 Api34Impl에 가두는 NoClassDefFoundError, flutter#192231).
#   소스의 @RequiresApi 중첩 object + @DoNotInline 격리(#95)가 R8 뒤에도 유지되는지는 dex를 열어 봐야 안다.
#
# 규칙(.github/api-isolation-rules, 바꾸려면 API_ISOLATION_RULES):
#   guard-api <N> — api-versions.xml에서 API N 이상에 추가된 클래스·메서드(생성자 포함)·필드를 "검사 대상 참조"로 삼는다.
#                   그 클래스를 (전이적으로) 상속·구현한 dex 클래스(예: 새 리스너를 구현한 람다)도 검사 대상 타입이 된다.
#   allow <glob>  — 원래(난독화 전) 클래스 이름 glob. 검사 대상 참조는 이 클래스들 안에만 있어야 한다.
#   dex의 클래스 이름은 mapping.txt로 원래 이름으로 되돌려 맞춘다(대응표에 없으면 dex 이름 그대로).
#   대응표가 이 APK의 빌드 것인지 R8 빌드 id(대응표의 pg_map_id = dex 표식의 pg-map-id)로 먼저 확인한다.
#   프레임워크 클래스 이름 그대로 dex에 든 클래스(api-versions.xml에 있는 이름이고, 대응표에 R8 합성 표시가 있거나 대응표에 없음)는
#   R8 API 스텁이라 늘 허용한다.
#
# 출력: 검사 대상 참조가 있는 클래스마다 "허용|허용(R8 스텁)|위반 <원래 이름> (dex <dex 이름>)"과 그 참조 목록.
#
# 검사가 헛돌지 않게 다음 경우에도 실패한다:
#   - mapping.txt가 비었거나 없음(R8이 돌지 않은 빌드), APK에 dex가 없음, dex와 mapping.txt의 R8 빌드 id가 다르거나 없음
#   - api-versions.xml에 guard-api 이상 항목이 하나도 없음(플랫폼이 낮거나 형식이 바뀜)
#   - APK의 minSdk가 guard-api 이상(격리할 대상이 없어 규칙을 다시 정해야 함)
#   - dex 전체에서 검사 대상 참조를 하나도 찾지 못함(앱에 API 36 코드가 있으므로, 0개면 dexdump 출력 형식 변화를 의심한다)
#
# 한계: 참조는 dex에 적힌 그대로(그 참조에 적힌 클래스 기준) 맞추고, 프레임워크 클래스 계층은 따라가지 않는다.
#   - 하위 클래스 타입으로 부른 새 메서드(예: API N에 View에 추가된 메서드를 TextView로 호출)
#   - 오래된 클래스가 API N에 새로 구현하게 된 인터페이스의 메서드(예: API 36에 AutoCloseable을 구현하게 된
#     ExecutorService의 close()를 ExecutorService로 호출 — api-versions.xml에는 <implements since="36">으로만 적힌다)
#   는 메서드로는 못 잡는다. 그 경우에도 R8은 보통 호출을 API 아웃라인으로 옮기고, 새 타입이 들어간 시그니처·캐스트는
#   타입으로 잡힌다. 아웃라인 클래스 안은 들여다보지 않는다(R8이 API 수준별로 나눠 만드는 합성 클래스라 R8의 책임으로 본다).
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
# compileSdk 이상으로 설치된 가장 높은 플랫폼의 목록을 쓴다 — 새 플랫폼의 목록은 옛 항목의 since가 같은 상위집합이고,
# 마이너 API(예: since="36.1", 폴더 이름 android-37.0 같은 형식) 항목도 담는다. 숫자 이름이 아닌 폴더(미리보기 등)는 건너뛴다.
api_versions=""
while IFS= read -r dir; do
  [[ ${dir##*/} =~ ^android-([0-9]+)(\.[0-9]+)?$ ]] || continue
  [ "${BASH_REMATCH[1]}" -ge "$compile_sdk" ] && [ -f "$dir/data/api-versions.xml" ] || continue
  api_versions="$dir/data/api-versions.xml"
  break
done < <(find "$sdk/platforms" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -rV)
[ -n "$api_versions" ] ||
  fail "compileSdk $compile_sdk 이상 플랫폼의 api-versions.xml이 없다 ($sdk/platforms/android-<N>/data/api-versions.xml, N ≥ $compile_sdk)"
echo "API 목록: $api_versions"

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

# mapping.txt가 이 APK를 만든 R8 빌드의 것인지 확인한다 — 다른 빌드의 대응표면 클래스 이름을 조용히 잘못 붙인다.
# R8은 대응표 머리(# pg_map_id: <id>)와 각 dex의 표식 문자열(~~R8{..."pg-map-id":"<id>"...})에 같은 id를 적는다.
map_id=$(sed -n 's/^# pg_map_id: \([0-9a-f]*\)[[:space:]]*$/\1/p' "$mapping" | head -1)
[ -n "$map_id" ] || fail "mapping.txt 머리에 pg_map_id가 없다: $mapping — R8이 만든 대응표인지 확인할 것"
for dex in "${dexes[@]}"; do
  ids=$( { grep -a -o '"pg-map-id":"[0-9a-f]*"' "$dex" || true; } | sed 's/.*:"\([0-9a-f]*\)"/\1/' | sort -u)
  [ -n "$ids" ] || fail "$(basename "$dex")에 R8 표식(pg-map-id)이 없다 — R8(minify)로 만든 릴리스 APK인지 확인할 것"
  [ "$ids" = "$map_id" ] ||
    fail "$(basename "$dex")의 pg-map-id($(echo $ids))가 mapping.txt($map_id)와 다르다 — 같은 빌드의 APK와 mapping.txt를 줄 것"
done

# ── 대조 ──────────────────────────────────────────────────────────────────
# 입력: api-versions.xml → mapping.txt → dexdump 출력(두 번). 결과 표(종류<TAB>원래 이름<TAB>dex 이름<TAB>참조)를 내고
# 종료 코드로 상태를 알린다: 0 통과, 1 허용 밖 참조, 3 검사 대상 참조 0개, 4 api-versions에 대상 항목 0개, 5 dex 클래스 0개.
# dexdump 출력의 1차 읽기는 dex 클래스의 상위 클래스·인터페이스만 모은다. 검사 대상 타입을 (전이적으로) 상속·구현한
# dex 클래스(예: 새 리스너 인터페이스를 구현한 합성 람다)도 검사 대상 타입으로 삼는다 — 그 클래스를 낮은 API에서
# 로드하는 것은 새 타입을 직접 쓰는 것과 같다. 2차 읽기가 모든 참조를 대조한다.
ALLOW=$(printf '%s\n' "${allows[@]}") GUARD=$guard awk '
  # XML 속성 값 (엔티티를 푼다 — 생성자는 name="&lt;init>(Z)V"로 적힌다)
  function attr(line, name,    m) {
    if (match(line, " " name "=\"[^\"]*\"")) {
      m = substr(line, RSTART + length(name) + 3, RLENGTH - length(name) - 4)
      gsub(/&lt;/, "<", m); gsub(/&gt;/, ">", m); gsub(/&quot;/, "\"", m); gsub(/&amp;/, "\\&", m)
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
  # 줄에서 작은따옴표로 감싼 첫 클래스 서술자 (예: Superclass        : '\''Ljava/lang/Object;'\'')
  function quoted_descriptor(line) {
    if (!match(line, /'\''L[^'\'']*;'\''/)) return ""
    return substr(line, RSTART + 1, RLENGTH - 2)
  }
  function hit(ref) {
    if (!((cls SUBSEP ref) in seen)) { seen[cls SUBSEP ref] = 1; refs[cls] = refs[cls] "\t" ref; total++ }
  }
  BEGIN {
    guard = ENVIRON["GUARD"] + 0
    n_allow = split(ENVIRON["ALLOW"], allow_glob, "\n")
    for (i = 1; i <= n_allow; i++) allow_re[i] = glob_re(allow_glob[i])
  }
  FNR == 1 { file_no++ }
  { sub(/\r$/, "") }
  # 1) api-versions.xml: 검사 대상 타입·메서드·필드
  file_no == 1 {
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
  # 2) mapping.txt: dex 이름 → 원래 이름 (클래스 줄만: "원래 -> dex:"), 클래스 머리 주석의 R8 합성 표시
  file_no == 2 {
    if ($0 ~ /^[^ #][^ ]* -> [^ ]+:$/) { obf = $3; sub(/:$/, "", obf); original[obf] = $1; last_class = obf }
    else if ($0 ~ /^# \{"id":"com\.android\.tools\.r8\.synthesized"\}$/ && last_class != "") synthesized[last_class] = 1
    else if ($0 !~ /^#/) last_class = ""
    next
  }
  # 3) dexdump 1차: 클래스마다 상위 클래스·인터페이스
  file_no == 3 {
    if ($0 ~ /^  Class descriptor  *: '\''L/) { cls = quoted_descriptor($0); in_ifaces = 0; classes++ }
    else if ($0 ~ /^  Superclass  *: '\''L/) supers[cls] = supers[cls] " " quoted_descriptor($0)
    else if ($0 ~ /^  Interfaces  *-/) in_ifaces = 1
    else if (in_ifaces && $0 ~ /^    #[0-9]+  *: '\''L/) supers[cls] = supers[cls] " " quoted_descriptor($0)
    else if ($0 ~ /^  [A-Z]/) in_ifaces = 0
    next
  }
  # 1차와 2차 사이: 검사 대상 타입을 상속·구현한 dex 클래스를 검사 대상 타입에 더한다 (전이적으로)
  file_no == 4 && FNR == 1 {
    cls = ""
    do {
      changed = 0
      for (c in supers) {
        if (c in types) continue
        n = split(supers[c], list, " ")
        for (i = 1; i <= n; i++) if (list[i] in types) { types[c] = 1; derived[c] = list[i]; changed = 1; break }
      }
    } while (changed)
  }
  # 4) dexdump 2차: 클래스마다 나오는 모든 타입·멤버 참조를 본다
  /^  Class descriptor  *: '\''L/ { cls = descriptor_name(quoted_descriptor($0)); next }
  cls != "" {
    line = $0
    # 문자열 상수(로그 문구·리플렉션 이름)는 참조가 아니다
    if (line ~ /: const-string(\/jumbo)? /) sub(/".*"/, "\"\"", line)
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
      for (i = 1; i <= n; i++) {
        ref = list[i]
        # 상속·구현으로 검사 대상이 된 dex 클래스는 원래 이름과 이유를 붙인다
        if (ref in derived) {
          d = descriptor_name(ref)
          ref = ref " (= " ((d in original) ? original[d] : d) ", " derived[ref] " 상속·구현)"
        }
        print kind "\t" name "\t" c "\t" ref
      }
    }
    exit bad
  }
' "$api_versions" "$mapping" "$work/dump.txt" "$work/dump.txt" >"$work/report.tsv" && status=0 || status=$?

case $status in
  0 | 1) ;;
  3) fail "dex 전체에서 API $guard 이상 전용 참조를 하나도 찾지 못했다 — dexdump 출력 형식이 바뀌었거나, API $guard 코드를 없앴다면 $rules와 이 검사를 다시 정할 것" ;;
  4) fail "api-versions.xml에 API $guard 이상 항목이 없다: $api_versions (플랫폼 버전·파일 형식 확인)" ;;
  5) fail "dexdump 출력에서 클래스를 하나도 읽지 못했다 (출력 형식 확인)" ;;
  *) fail "대조 중 오류 (awk 종료 코드 $status)" ;;
esac

# 클래스별로 묶어 보여 준다 (종류 이름순: 위반 → 허용 → 허용(R8 스텁))
sort -t$'\t' -k1,1 -k2,2 -k4,4 "$work/report.tsv" | awk -F'\t' '
  { key = $1 "\t" $2 "\t" $3 }
  key != last { printf "%s %s (dex %s)\n", $1, $2, $3; last = key }
  { printf "    %s\n", $4 }
'
if [ $status -eq 1 ]; then
  fail "API $guard 이상 전용 참조가 허용된 격리 클래스($rules의 allow) 밖에 있다 — 위 \"위반\" 클래스. API $((guard - 1)) 이하 기기에서 클래스 검증·로딩이 실패할 수 있다. 참조를 @RequiresApi 격리 object(@DoNotInline 메서드)로 옮길 것 (#95, #109)"
fi
echo "통과: API $guard 이상 전용 참조가 모두 허용된 격리 클래스 안에 있다"

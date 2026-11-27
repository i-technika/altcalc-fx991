# 번들 글꼴 (#16)

LCD·키캡 라벨의 수학 기호(`◼`, `◻`, `⇔`, `∑`, `∫`, `≈`, `⁻¹`, `ˣ` 등)가 모든 플랫폼에서
같은 모양·같은 폭으로 그려지도록 글꼴을 앱에 넣는다. 합계 약 1.08MB.
키캡 각인은 #156부터 실물처럼 비례폭 글꼴(Saira)과 변수 이탤릭(Noto Serif Bold Italic)으로 그린다 — 아래 "키캡 각인 글꼴".

| 파일 | 패밀리 | 원본 | 라이선스 |
|---|---|---|---|
| `NotoSansMono-{Regular,Medium,SemiBold,Bold}.ttf` | `NotoSansMono` (기본) | Noto Sans Mono 2.014 (hinted TTF) | SIL OFL 1.1 — `NotoSansMono-OFL.txt` |
| `NotoSansMath-Regular.ttf` | `NotoSansMath` (대체) | Noto Sans Math 3.000 (hinted TTF) | SIL OFL 1.1 — `NotoSansMath-OFL.txt` |
| `Saira-{Medium,SemiBold}.ttf` | `Saira` (키캡 각인, #156) | Saira 가변 글꼴(`wdth`·`wght`)의 고정 인스턴스 | SIL OFL 1.1 — `Saira-OFL.txt` |
| `NotoSerif-BoldItalic.ttf` | `NotoSerifItalic` (키캡 변수 이탤릭, #156) | Noto Serif 2.015 Bold Italic (hinted TTF) | SIL OFL 1.1 — `NotoSerif-OFL.txt` |

- 네 글꼴 모두 예약 글꼴 이름(Reserved Font Name)이 없어 서브셋(수정본)을 같은 이름으로 배포할 수 있다
  (각 OFL 전문 첫 줄의 저작권 표시에 "with Reserved Font Name"이 없다).
- 라이선스 전문은 이 폴더의 txt로 앱 번들에 들어가고, 앱 시작 시 `LicenseRegistry`에 등록된다
  (`lib/core/theme/font_licenses.dart`). 앱에는 아직 라이선스 화면 진입점이 없다(#46에서 연결).

## 원본

Noto 글꼴은 저장소 <https://github.com/notofonts/notofonts.github.io> 의 `fonts/<패밀리>/hinted/ttf/<파일>`.
Saira는 저장소 <https://github.com/google/fonts> 의 `ofl/saira/<파일>`(OFL 전문은 같은 폴더의 `OFL.txt`).
Noto Serif의 OFL 전문은 <https://github.com/notofonts/latin-greek-cyrillic> 의 `OFL.txt`다.

| 원본 파일 | 해당 경로의 마지막 커밋 | SHA-256 |
|---|---|---|
| `NotoSansMono-Regular.ttf` | `8b36ddb234b06c091320e28985a3c96b48ce2596` | `65b5e2b2c4a1fba9ae8be1f026cb35b03dcb8886d9b2a4147054fde12f7e767d` |
| `NotoSansMono-Medium.ttf` | 〃 | `53e262499b3e6b4e7274dcc4840e9374c8d9c4a4fad48227a38d8cedd2e34c40` |
| `NotoSansMono-SemiBold.ttf` | 〃 | `82e49094ec3a1a3c8fa0d730016f5f890384f6e164dd2cc84f39b30639bb6e8f` |
| `NotoSansMono-Bold.ttf` | 〃 | `a21ea0ba6ea49fda7b34ca39a504b487f1130885d36e1a4f9f4255b3ba6994bc` |
| `NotoSansMath-Regular.ttf` | `55773c3eb233b5a0eaa07de6226da189b136b4f0` | `d51afd5739c7ba6c44fcab35a88160e25dfb69a2d4ad0bd99533f8d894af1f96` |
| `NotoSerif-BoldItalic.ttf` | `28b15b4b43b7bed62b5cf6e6b0b5ff5846270535` | `c710c5b9cf354ae46e7a10472a08019b28220fafeb5887a482a76856f8f6fc0b` |
| `Saira[wdth,wght].ttf` (google/fonts) | `3cfea32a77637ada0e209f10d9f91e7ff9d2a32f` | `9d050fc5a01c85f74c4257c207d50b55d1e40c37308c642f974a2c5003231dde` |

## 왜 LCD는 두 글꼴인가

- **Noto Sans Mono**: 모든 글자 폭이 0.6em(600/1000)인 고정폭 글꼴이다. LCD 줄 칸 수 계산
  (`CalcTheme.lcdLineCharWidthRatio`)이 이 가정에 기대고 있다. #156 전에는 키캡 각인도 이 글꼴이었다 — 지금은 각인 글꼴
  (Saira)에 없는 기호를 여기서 찾고, 각인 줄 상자(strut)를 이 글꼴로 고정한다.
  굵기는 테마가 쓰는 400/500/600/700을 모두 넣었다(Flutter는 가변 글꼴의 굵기 축을
  `fontWeight`로 자동 조절하지 않으므로 정적 글꼴을 쓴다).
- **Noto Sans Math**: Noto Sans Mono에 없는 `∑`(U+2211), `∫`(U+222B)를 채운다.
  `∛`(U+221B)도 여기에 있다. #155부터 키캡의 근호·분수·위첨자는 그림(2차원 각인)으로 그리지만,
  M1 LCD 임시 표시(마지막 입력 기능의 한 줄 표기)는 아직 `∛◼`·`x²`·`×10ˣ` 같은 글자로 그린다(M2에서 수식 렌더링으로 대체).
  고정폭이 아니고 Regular 한 굵기뿐이라, 굵은 라벨 옆에서는 조금 가늘게 보인다.
  Line 표시(LineI/LineO)의 분수 구분 기호 `⌟`(U+231F)도 Noto Sans Mono에 없어 여기에만 있다 —
  LCD 줄에서 고정폭이 아니므로 Line 표시 렌더링(M2)에서 폭 처리를 정한다(#2).
  LCD 줄에 들어갈 글자(숫자·`−`·`×`·위첨자 등)는 반드시 Noto Sans Mono에 있어야 한다.

## 키캡 각인 글꼴 (#156)

- **Saira** (`CalcTheme.keyFontFamily`): 실물 각인은 모서리가 둥근 각진 비례폭 산세리프다(실물 키패드 근접 사진). 고정폭
  Noto Sans Mono로 그리면 `x²`·`sin⁻¹`·`S⇔D`가 띄엄띄엄 보여 코드 편집기처럼 보였다. SIL OFL 비례폭 글꼴 Saira·Exo 2·Oxanium·
  Chakra Petch·Titillium Web·Rajdhani를 같은 글자(`SHIFT OPTN CALC sin cos tan log ln … 7890`)로 그려 사진과 견주고, 각진
  `C`·`S`·`n`과 둥근 모서리가 가장 가까운 Saira를 골랐다. 가변 글꼴이라 각인이 쓰는 굵기(메인 600, SHIFT·ALPHA·본체 인쇄 500)를
  폭 100에서 고정 인스턴스로 만든다(Flutter는 가변 글꼴의 굵기 축을 `fontWeight`로 자동 조절하지 않는다).
- 서브셋은 ASCII에서 `+`·`=`를 뺀 글자뿐이다. 연산 기호(`+`·`=`·`−`·`×`·`÷`)·입력 칸(`◼`·`◻`)·방향 화살표(`▲` 등)·`°`는 대체
  글꼴 Noto Sans Mono에서 찾는다(`CalcTheme.keyFontFallback`) — Saira의 연산 기호는 x높이 안의 작은 기호라 Mono가 실물에 더
  가깝다(Mono의 `×`도 실물보다 숫자 대비 조금 작다). `∑`·`∫`는 지금처럼 Noto Sans Math다. `⇔`도 Noto Sans Math로 그린다
  (`CalcTheme.isKeyMathSymbol`, #156 R2) — Mono의 `⇔`는 x높이보다 낮은 작은 화살표에 좌우 여백이 커서 `S ⇔ D`처럼 벌어졌다.
- 줄 상자(strut)는 Noto Sans Mono의 것을 그대로 쓴다(`CalcTheme.keyStrutFontFamily`). Saira는 위아래 여백(ascent 1.135·
  descent 0.439em)이 커서 그대로 쓰면 2차원 각인 배치·키패드 글자 크기 계산(#155·#169·#186)이 모두 달라진다.
- **Noto Serif Bold Italic** (`CalcTheme.keyVariableFontFamily`): 실물은 변수 `x`·`y`·`e`를 교과서처럼 세리프 이탤릭으로
  인쇄한다(근접 사진의 `x²`·`x!`·`×10ˣ`·ALPHA `y`·`e`, SHIFT `π`). 어느 글자를 이탤릭으로 그리는지는
  `CalcTheme.isKeyVariableLetter`가 정한다. 서브셋은 그 네 글자와 공백뿐이다.
- 글자의 세로 잉크 범위 표(`KeyLegendView.glyphInk`·`variableGlyphInk`)는 그 글자를 실제로 그리는 글꼴의 값이다 —
  글꼴을 바꾸면 `test/widget/key_legend_view_test.dart`가 어긋난 값을 알려 준다.

## 글리프 선택 규칙 (실측 #16)

Noto Sans Mono에도 **두 칸 폭(1200)** 글자가 있다. 라벨·LCD에는 한 칸 폭 글자를 쓴다.

| 쓰지 않는 글자 | 이유 | 대신 쓰는 글자 |
|---|---|---|
| `▭` U+25AD | 두 칸 폭 | 입력 칸 `◼` U+25FC · `◻` U+25FB |
| `■` U+25A0 · `□` U+25A1 | 한 칸 폭이지만 두 글리프의 크기·기준선이 달라(484 vs 600) 짝이 맞지 않음 | `◼` · `◻` (둘 다 482×483, 기준선 위) |
| `◀` U+25C0 · `▶` U+25B6 | 두 칸 폭 (보이는 모양은 한 칸이라 `FittedBox`가 75%로 줄임) | `◄` U+25C4 · `►` U+25BA (`▲`·`▼`와 같은 디자인) |
| `℃` U+2103 | 두 칸 폭 | `°C` |

`⇔`(U+21D4, S⇔D 키)도 두 칸 폭이지만 대체 글자가 없어 키 라벨에서만 예외로 허용한다. #156부터 키 라벨의 `⇔`는 Noto Sans
Math로 그린다(위 "키캡 각인 글꼴").

## 서브셋 재현 방법

[fontTools](https://github.com/fonttools/fonttools) **4.68.0**의 `pyftsubset`으로 아래 범위만 남겼다
(이 버전으로 위 원본에서 다시 만들면 커밋된 파일과 비트 단위로 같다 — #16 리뷰 R2에서 확인).
Latin 확장(ħ, ȳ, ŷ 등)·위첨자 수식 문자(ᵍ 등)·블록 요소(█)·기술 기호(⌟ 등)는 M2 이후 LCD 표시를 위해 미리 넣었다.

```bash
# 원본은 src/, 결과는 out/ (같은 이름으로 덮어쓰지 않는다)
MONO="U+0020-007E,U+00A0-00FF,U+0100-024F,U+02B0-02FF,U+0300-036F,U+0370-03FF,U+1D2C-1D6A,U+2000-206F,U+2070-209F,U+2100-214F,U+2190-21FF,U+2200-22FF,U+2300-23FF,U+2580-259F,U+25A0-25FF"
MATH="U+0020,U+2190-23FF"
for w in Regular Medium SemiBold Bold; do
  pyftsubset src/NotoSansMono-$w.ttf --unicodes="$MONO" --output-file=out/NotoSansMono-$w.ttf \
    --name-IDs='*' --name-languages='*' --notdef-outline
done
pyftsubset src/NotoSansMath-Regular.ttf --unicodes="$MATH" --output-file=out/NotoSansMath-Regular.ttf \
  --name-IDs='*' --name-languages='*' --notdef-outline
```

키캡 각인 글꼴(#156)은 같은 fontTools 4.68.0으로 아래처럼 만든다(이 명령으로 위 원본에서 다시 만들면 커밋된 파일과 비트 단위로
같다 — 인스턴스의 `head` 시각을 원본 그대로 두려고 `--no-recalc-timestamp`를 준다).

```bash
SAIRA="U+0020-002A,U+002C-003C,U+003E-007E"   # ASCII에서 + = 를 뺀 범위
for pair in "500 Medium" "600 SemiBold"; do
  set -- $pair
  fonttools varLib.instancer "src/Saira[wdth,wght].ttf" wght=$1 wdth=100 --no-recalc-timestamp -q -o tmp/Saira-$2.ttf
  pyftsubset tmp/Saira-$2.ttf --unicodes="$SAIRA" --output-file=out/Saira-$2.ttf \
    --name-IDs='*' --name-languages='*' --notdef-outline
done
pyftsubset src/NotoSerif-BoldItalic.ttf --unicodes="U+0020,U+0065,U+0078,U+0079,U+03C0" \
  --output-file=out/NotoSerif-BoldItalic.ttf --name-IDs='*' --name-languages='*' --notdef-outline
```

| 결과 파일 | SHA-256 |
|---|---|
| `Saira-Medium.ttf` | `a6a10b46effe616602f11b71744515b95cf3c692aa2e94e0bd6c38d63f19858f` |
| `Saira-SemiBold.ttf` | `f10b3687657a4e7038e7c2b56ec2730966e21c00dcc1f6a02840a874d8daecf2` |
| `NotoSerif-BoldItalic.ttf` | `67412450895043ab5fdda51ccdb31975973e63079fba1854e7880331e4cee166` |

범위를 바꾸거나 새 기호를 라벨·LCD에 쓰면 `test/widget/font_glyph_coverage_test.dart`(글리프 유무·글자마다 그리는 글꼴)와
`test/widget/bundled_font_test.dart`(실제 폭 — 키캡 각인은 글자마다 그리는 글꼴의 진행폭)가 빠진 글리프·두 칸 폭 글자를
알려 준다.

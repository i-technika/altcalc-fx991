# 번들 글꼴 (#16)

LCD·키캡 라벨의 수학 기호(`◼`, `◻`, `∛`, `⇔`, `∑`, `∫`, `≈`, `⁻¹`, `ˣ` 등)가 모든 플랫폼에서
같은 모양·같은 폭으로 그려지도록 글꼴을 앱에 넣는다. 합계 약 1.04MB.

| 파일 | 패밀리 | 원본 | 라이선스 |
|---|---|---|---|
| `NotoSansMono-{Regular,Medium,SemiBold,Bold}.ttf` | `NotoSansMono` (기본) | Noto Sans Mono 2.014 (hinted TTF) | SIL OFL 1.1 — `NotoSansMono-OFL.txt` |
| `NotoSansMath-Regular.ttf` | `NotoSansMath` (대체) | Noto Sans Math 3.000 (hinted TTF) | SIL OFL 1.1 — `NotoSansMath-OFL.txt` |

- 두 글꼴 모두 예약 글꼴 이름(Reserved Font Name)이 없어 서브셋(수정본)을 같은 이름으로 배포할 수 있다.
- 라이선스 전문은 이 폴더의 txt로 앱 번들에 들어가고, 앱 시작 시 `LicenseRegistry`에 등록된다
  (`lib/core/theme/font_licenses.dart`). 앱에는 아직 라이선스 화면 진입점이 없다(#46에서 연결).

## 원본

저장소 <https://github.com/notofonts/notofonts.github.io> 의 `fonts/<패밀리>/hinted/ttf/<파일>`.

| 원본 파일 | 해당 경로의 마지막 커밋 | SHA-256 |
|---|---|---|
| `NotoSansMono-Regular.ttf` | `8b36ddb234b06c091320e28985a3c96b48ce2596` | `65b5e2b2c4a1fba9ae8be1f026cb35b03dcb8886d9b2a4147054fde12f7e767d` |
| `NotoSansMono-Medium.ttf` | 〃 | `53e262499b3e6b4e7274dcc4840e9374c8d9c4a4fad48227a38d8cedd2e34c40` |
| `NotoSansMono-SemiBold.ttf` | 〃 | `82e49094ec3a1a3c8fa0d730016f5f890384f6e164dd2cc84f39b30639bb6e8f` |
| `NotoSansMono-Bold.ttf` | 〃 | `a21ea0ba6ea49fda7b34ca39a504b487f1130885d36e1a4f9f4255b3ba6994bc` |
| `NotoSansMath-Regular.ttf` | `55773c3eb233b5a0eaa07de6226da189b136b4f0` | `d51afd5739c7ba6c44fcab35a88160e25dfb69a2d4ad0bd99533f8d894af1f96` |

## 왜 두 글꼴인가

- **Noto Sans Mono**: 모든 글자 폭이 0.6em(600/1000)인 고정폭 글꼴이다. LCD 줄 칸 수 계산
  (`CalcTheme.lcdLineCharWidthRatio`)과 키 라벨 폭 측정이 이 가정에 기대고 있다.
  굵기는 테마가 쓰는 400/500/600/700을 모두 넣었다(Flutter는 가변 글꼴의 굵기 축을
  `fontWeight`로 자동 조절하지 않으므로 정적 글꼴을 쓴다).
- **Noto Sans Math**: Noto Sans Mono에 없는 `∑`(U+2211), `∛`(U+221B), `∫`(U+222B)를 채운다.
  고정폭이 아니고 Regular 한 굵기뿐이라, 굵은 라벨 옆에서는 조금 가늘게 보인다.
  Line 표시(LineI/LineO)의 분수 구분 기호 `⌟`(U+231F)도 Noto Sans Mono에 없어 여기에만 있다 —
  LCD 줄에서 고정폭이 아니므로 Line 표시 렌더링(M2)에서 폭 처리를 정한다(#2).
  LCD 줄에 들어갈 글자(숫자·`−`·`×`·위첨자 등)는 반드시 Noto Sans Mono에 있어야 한다.

## 글리프 선택 규칙 (실측 #16)

Noto Sans Mono에도 **두 칸 폭(1200)** 글자가 있다. 라벨·LCD에는 한 칸 폭 글자를 쓴다.

| 쓰지 않는 글자 | 이유 | 대신 쓰는 글자 |
|---|---|---|
| `▭` U+25AD | 두 칸 폭 | 입력 칸 `◼` U+25FC · `◻` U+25FB |
| `■` U+25A0 · `□` U+25A1 | 한 칸 폭이지만 두 글리프의 크기·기준선이 달라(484 vs 600) 짝이 맞지 않음 | `◼` · `◻` (둘 다 482×483, 기준선 위) |
| `◀` U+25C0 · `▶` U+25B6 | 두 칸 폭 (보이는 모양은 한 칸이라 `FittedBox`가 75%로 줄임) | `◄` U+25C4 · `►` U+25BA (`▲`·`▼`와 같은 디자인) |
| `℃` U+2103 | 두 칸 폭 | `°C` |

`⇔`(U+21D4, S⇔D 키)도 두 칸 폭이지만 대체 글자가 없어 키 라벨에서만 예외로 허용한다(테스트로 고정).

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

범위를 바꾸거나 새 기호를 라벨·LCD에 쓰면 `test/unit/font_glyph_coverage_test.dart`(글리프 유무)와
`test/widget/bundled_font_test.dart`(실제 폭)가 빠진 글리프·두 칸 폭 글자를 알려 준다.

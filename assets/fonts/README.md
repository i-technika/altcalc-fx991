# 번들 글꼴 (#16)

LCD·키캡 라벨의 수학 기호(`■`, `□`, `∛`, `⇔`, `∑`, `∫`, `≈`, `⁻¹`, `ˣ` 등)가 모든 플랫폼에서
같은 모양·같은 폭으로 그려지도록 글꼴을 앱에 넣는다.

| 파일 | 패밀리 | 원본 | 라이선스 |
|---|---|---|---|
| `NotoSansMono-{Regular,Medium,SemiBold,Bold}.ttf` | `NotoSansMono` (기본) | Noto Sans Mono 2.014 (hinted TTF) | SIL OFL 1.1 — `NotoSansMono-OFL.txt` |
| `NotoSansMath-Regular.ttf` | `NotoSansMath` (대체) | Noto Sans Math 3.000 (hinted TTF) | SIL OFL 1.1 — `NotoSansMath-OFL.txt` |

- 원본: <https://github.com/notofonts/notofonts.github.io> 의 `fonts/<패밀리>/hinted/ttf/`
- 두 글꼴 모두 예약 글꼴 이름(Reserved Font Name)이 없어 서브셋(수정본)을 같은 이름으로 배포할 수 있다.
- 라이선스 전문은 앱 시작 시 `LicenseRegistry`에 등록되어 라이선스 화면에 표시된다
  (`lib/core/theme/font_licenses.dart`).

## 왜 두 글꼴인가
- **Noto Sans Mono**: 모든 글자 폭이 0.6em(600/1000)인 고정폭 글꼴이다. LCD 줄 칸 수 계산
  (`CalcTheme.lcdLineCharWidthRatio`)과 키 라벨 폭 측정이 이 가정에 기대고 있다.
  굵기는 테마가 쓰는 400/500/600/700을 모두 넣었다(Flutter는 가변 글꼴의 굵기 축을
  `fontWeight`로 자동 조절하지 않으므로 정적 글꼴을 쓴다).
- **Noto Sans Math**: Noto Sans Mono에 없는 `∑`(U+2211), `∛`(U+221B), `∫`(U+222B)를 채운다.
  고정폭이 아니므로 LCD 줄에 들어갈 글자(숫자·`−`·`×`·위첨자 등)는 반드시 Noto Sans Mono에 있어야 한다.
- `▭`(U+25AD)는 Noto Sans Mono에서 **두 칸 폭(1200)** 이다. 그래서 키 라벨의 입력 칸 표기는
  한 칸 폭인 `■`(U+25A0)·`□`(U+25A1)를 쓴다.

## 서브셋 재현 방법
[fontTools](https://github.com/fonttools/fonttools)의 `pyftsubset`으로 아래 범위만 남겼다(원본 대비 약 1/3 크기).

```bash
MONO="U+0020-007E,U+00A0-00FF,U+0131,U+02B0-02FF,U+0300-036F,U+0370-03FF,U+2000-206F,U+2070-209F,U+2100-214F,U+2190-21FF,U+2200-22FF,U+2300-23FF,U+25A0-25FF"
MATH="U+0020,U+2070-209F,U+2100-214F,U+2190-21FF,U+2200-22FF,U+2300-23FF,U+25A0-25FF,U+27C0-27EF,U+2980-29FF,U+2A00-2AFF"
for w in Regular Medium SemiBold Bold; do
  pyftsubset NotoSansMono-$w.ttf --unicodes="$MONO" --output-file=NotoSansMono-$w.ttf \
    --name-IDs='*' --name-languages='*' --notdef-outline
done
pyftsubset NotoSansMath-Regular.ttf --unicodes="$MATH" --output-file=NotoSansMath-Regular.ttf \
  --name-IDs='*' --name-languages='*' --notdef-outline
```

범위를 바꾸거나 새 기호를 라벨에 쓰면 `test/unit/font_glyph_coverage_test.dart`가 빠진 글리프를 알려 준다.

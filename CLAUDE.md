# 프로젝트: 카시오 fx-991 공학용 계산기 시뮬레이터 (Flutter)

> 이 프로젝트는 초기에 Antigravity(Gemini)로 시작되어 #7까지 진행된 뒤 Claude Code로 이관되었다.
> 이 문서가 프로젝트 규칙의 단일 기준(Single Source of Truth)이다. (구 `gemini.md` 대체)

## 0. 응답 및 작업 언어
- 모든 설명, 계획 수립, 코드 주석, 커밋 메시지 본문, PR/이슈 본문은 **한국어**로 작성한다.
- 현재 진행 단계와 완료 기준은 항상 [milestone.md](milestone.md)와 GitHub 이슈를 기준으로 삼는다.

## 1. 핵심 아키텍처 및 기술 스택
- **프레임워크:** Flutter 3.50.0 (Dart 3.14.0) — Android / iOS 크로스 플랫폼
  - SDK 버전은 `pubspec.yaml`의 `environment.flutter` 하나로 고정하고 CI도 그 값을 읽는다 (#78). 올릴 때는 README "Flutter SDK 버전 올리기" 절차대로 로컬 SDK·`pubspec.lock`과 함께 바꾼다.
  - Flutter 3.50부터 Material 위젯은 분리 패키지 `material_ui`로 제공된다.
    **`import 'package:material_ui/material_ui.dart';`** 를 사용한다 (`package:flutter/material.dart` 아님).
- **상태 관리:** `flutter_riverpod` (현재 2.x)
- **수학 연산 엔진:** 커스텀 AST(추상 구문 트리) + `decimal` 패키지. **정밀도는 실물 fx-991EX와 동일하게** 맞춘다 (출처: User's Guide "Calculation Range and Precision").
  - 내부 연산: 유효숫자 **15자리** / LCD 표시: 유효숫자 **10자리** 반올림 (단일 계산 정밀도는 10번째 자리 ±1)
  - 계산 범위: ±1×10⁻⁹⁹ ~ ±9.999999999×10⁹⁹ 또는 0 — 범위를 벗어나면 Math ERROR
  - 상수: π = 3.14159265358980, e = 2.71828182845904 (가이드 기재값)
  - 연산 단계별 반올림 방식·언더플로 처리 등 세부 규칙은 #30에서 실물 대조로 확정한다.
- **2D 자연어 수식 렌더링 (Natural Textbook Display):** `IntrinsicWidth`, `Row`, `Column` 등을 활용한 재귀 위젯 트리(`MathNodeWidget`)로 분수, 루트, 지수, 정적분, 시그마 기호를 렌더링한다.
- **수익화 및 서버리스 인앱결제:**
  - 하단 적응형 배너 광고(`google_mobile_ads`): 최하단 키패드 행 아래 `8dp~12dp` 오터치 방지 안전 여백 확보
  - 비소모성 인앱결제(`in_app_purchase`, 상품 ID: `remove_ads`) + `shared_preferences` 로컬 캐싱 + 앱 시작 시 백그라운드 `restorePurchases()` 동기화 (백엔드 서버 없음)

## 2. 디렉토리 구조 (`lib/`)
- `core/constants/key_definitions.dart`: 50개 버튼 레이아웃 및 SHIFT/ALPHA 키 매핑 정의
- `core/theme/calc_theme.dart`: 카시오 fx-991EX/CW 색상 팔레트 및 LCD 폰트 스타일
- `core/theme/font_licenses.dart`: 번들 글꼴 OFL 라이선스를 `LicenseRegistry`에 등록
- `core/layout/form_factor.dart`: 기기 종류(폰·폴더블·태블릿) 판정·방향 고정 규칙, 창 크기·접힘선 기준 배치 판정
- `domain/models/`: `math_node.dart` (수식 AST 노드), `calc_state.dart` (계산기 전체 상태), `lcd_status.dart` (LCD 상태 표시기 스냅샷), `handedness.dart` (손잡이 설정 — 좌우 분할 시 키패드 위치)
- `domain/engine/`: `cursor_navigator.dart` (방향키 커서 이동), `ast_evaluator.dart` (수식 계산기), `numerical_methods.dart` (수치해석)
- `presentation/providers/`: `calc_provider.dart`, `settings_provider.dart` (`shared_preferences` 앱 설정 — `main()`이 불러와 override), `device_provider.dart` (폴더블 기기 여부 — `main()`이 힌지 센서로 판정해 override), `iap_provider.dart`
- `presentation/l10n/`: `calc_semantic_strings.dart` (스크린리더 음성 문구 — 키 기능 이름·LCD 표시기 의미, 한국어·영어), `device_locale_scope.dart` (기기 로캘 전달·언어 변경 시 재빌드), `settings_strings.dart` (설정 UI 문구, 한국어·영어)
- `presentation/screens/`: `calculator_screen.dart`
- `presentation/widgets/`: `lcd_display.dart`, `lcd_status_icon.dart` (글자 대신 직접 그리는 LCD 상태 아이콘 →x·√▭✎·‖), `math_node_widget.dart`, `calc_key_button.dart`, `calc_keypad.dart` (50키 배치·글자 크기 통일), `banner_ad_slot.dart`, `text_fit.dart` (글자 배율 반영 높이 맞춤), `settings_button.dart`·`handedness_dialog.dart` (설정 진입·키패드 위치 선택), `screen_coordinate_root.dart` (화면을 흉내 내는 곳에 MediaQuery와 좌표 원점을 함께 제공 — 위젯 배치는 미리보기 기기 틀 전용, 키 버튼이 좌표 변환에 사용)
- 테스트: `test/unit/` (순수 Dart 로직, Flutter 바인딩 없이 저장소 설정 파일을 읽는 구성 검사 포함 — 줄바꿈 속성 검사는 `git` 명령으로 속성을 조회한다), `test/widget/` (위젯 테스트 — 바인딩·`rootBundle`·실제 글꼴을 쓰는 테스트 포함), `test/support/` (테스트 공용 도구: 번들 글꼴 로더, cmap 파서, LCD 글자 목록, 키 터치 치수 측정)
- 개발 도구: `preview/key_preview_main.dart` (실제 `CalculatorScreen`을 기기 크기 프리셋·글자 배율·입력 로그와 함께 띄우는 미리보기 — 실행 방법은 README. `lib/`에서 import 금지, 앱 빌드 제외, CI가 웹 빌드로 확인)
- VS Code: `.vscode/` (실행 구성 `launch.json`·추천 확장 `extensions.json` — 준비 단계·SDK 탐지는 README "VS Code에서 실행". 기기마다 다른 절대경로는 넣지 않으며, 구성과 README 표의 일치와 함께 `test/unit/vscode_config_test.dart`가 검사한다)
- 줄바꿈: `.gitattributes` (Flutter가 다시 쓰는 생성 플러그인 파일을 LF로 고정 — `test/unit/gitattributes_test.dart`가 대상 누락을, CI가 빌드 뒤 작업 트리가 깨끗한지 검사한다. 아래 "로컬 개발 환경 메모" 참조)
- 에셋: `assets/fonts/` (번들 글꼴 Noto Sans Mono/Math 서브셋과 OFL 전문 — 출처·서브셋 재현·글리프 선택 규칙은 `assets/fonts/README.md`)

## 3. 코딩 원칙
- 일반 스마트폰, 폴더블, 태블릿 등 다양한 화면비에서도 키패드 비율이 깨지지 않도록 반응형으로 설계한다.
- M1 단계부터 하단 배너 광고 슬롯 높이(`50dp~60dp`)를 미리 확보하여 추후 광고 연동 시 키패드 레이아웃이 찌그러지지 않게 한다.
- 기본 연산 시 부동소수점 오차(`0.1 + 0.2`) 방지를 위해 일반 `double` 대신 `Decimal`을 사용한다.
- 키 명세·테마 등 상수 데이터에는 반드시 불변식 테스트(키 개수, ID 중복 금지 등)를 함께 둔다.
- 커밋 전 항상 `flutter analyze`(이슈 0건)와 `flutter test`(전부 통과)를 확인한다.

## 4. 로컬 개발 환경 메모
- Flutter SDK가 시스템 PATH에 없을 수 있다. `flutter`를 찾지 못하면 Bash에서
  `export PATH="/c/Users/fmthead/develop/flutter/bin:$PATH"` 후 실행한다.
- 생성 플러그인 파일(`linux/flutter/generated_plugin*`, `windows/flutter/generated_plugin*`,
  `macos/Flutter/GeneratedPluginRegistrant.swift`)은 `.gitattributes`로 LF 고정이라, `flutter pub get`·`test` 뒤에도
  수정됨으로 보이지 않는다 (#67). 그래도 이 파일들이 `M`이면 실제 변경인지 먼저 `git diff`로 본다(줄바꿈만 다르면 비어 있다).
  - 속성이 생기기 전에 체크아웃한 작업 트리는 CRLF로 남아 있어 Flutter가 다시 쓰면 내용 차이 없이 `M`이 된다.
    #67이 들어온 브랜치로 전환·머지한 **뒤** Git Bash에서 `bash .claude/scripts/normalize-generated-eol.sh`로 한 번 정리한다
    (대상은 `.gitattributes`가 정하고, 내용이 실제로 바뀐 파일이 있으면 아무것도 하지 않고 중단한다).
  - #67 이전 브랜치에 있어서 `M` 때문에 전환·머지가 막히면(스크립트가 아직 없다): 위 생성 파일 7개에 대해
    `git diff --stat -- <7개>`가 비어 있음을 확인한 뒤 그 7개만 `git checkout -- <7개>`로 되돌린다.
  - `git checkout -- linux macos windows`처럼 플랫폼 폴더 전체를 되돌리지 않는다 — 진짜 변경까지 지워진다.
- GitHub CLI(`gh`)로 이슈/PR/프로젝트를 관리한다. 저장소: `i-technika/altcalc-fx991`
- `gh`에 여러 줄 본문을 넘길 때는 셸 이스케이프 깨짐(과거 이슈 본문의 `\경로\` 깨짐 현상)을 막기 위해
  **반드시 임시 파일 + `--body-file`** 을 사용한다.

## 5. 개발 워크플로우 (스킬)
마일스톤 에픽 → 서브이슈 구조로 진행하며, 아래 프로젝트 스킬을 사용한다 (`.claude/skills/`).

| 명령 | 용도 |
|---|---|
| `/open-ms <에픽번호>` | `main`에서 `milestone/m<N>` 분기 + 마일스톤 Draft PR 생성 |
| `/fix-issue <서브이슈번호>` | 서브이슈 구현 → PR → 적대적 리뷰 2라운드 → 마일스톤 브랜치 머지 → 이슈 Close |
| `/close-ms <에픽번호>` | 마일스톤 PR Ready 전환 → 멀티플랫폼 CI → `main` 머지 |

### 브랜치/PR 규칙
- 마일스톤 브랜치: `milestone/m<N>` (base: `main`, Draft PR로 유지 → Draft 동안 CI 미실행)
- 서브이슈 브랜치: `issue/<번호>-<영문-키워드>` (base: `milestone/m<N>`)
- 서브이슈 PR 제목: `[M<N>-<순번>] <이슈 제목> (#<번호>)` — 이슈 제목의 `[M1-2]` 접두사를 그대로 사용
- 라벨: 에픽 `milestone`, 서브이슈 `sub-issue` / 프로젝트: `AltCalc FX-991` (#7)
- 서브이슈 PR은 기본 브랜치가 아닌 마일스톤 브랜치로 머지되므로 `Closes #N`으로 **이슈가 자동 Close되지 않는다.** 머지 후 직접 `gh issue close`한다.
- CI: 마일스톤 브랜치 대상 PR → `Sub-issue Linux CI`, `main` 대상 PR(Ready) → `Milestone Full Multi-Platform CI`

### GitHub Project #7 (AltCalc FX-991) 식별자
- Project ID: `PVT_kwHOBMwL0c4BsMze` / Owner: `i-technika`
- Status 필드 ID: `PVTSSF_lAHOBMwL0c4BsMzezhqcBOI`
  - Todo `f75ad846` / In Progress `47fc9ee4` / Done `98236657`

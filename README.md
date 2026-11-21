# AltCalc fx-991

카시오 fx-991EX 공학용 계산기 시뮬레이터 (Flutter, Android / iOS).

- 프로젝트 규칙: [CLAUDE.md](CLAUDE.md)
- 진행 단계: [milestone.md](milestone.md)

## 개발 환경

- Flutter 3.50 이상 (Dart 3.14 이상)
- 의존성 설치: `flutter pub get`

## 앱 실행

```bash
flutter run            # 연결된 기기·에뮬레이터
```

## 개발용 미리보기 (`preview/`)

실제 계산기 화면(`CalculatorScreen`)을 데스크톱 브라우저 창에 띄워, 휴대폰·에뮬레이터 없이
키패드와 키 입력 동작을 확인하는 개발 도구다.

- **기기 크기**: 일반·소형·대형 폰, 폴더블 커버·내부, 태블릿 세로·가로, 분할 화면 위쪽 창 프리셋으로 반응형 배치를 확인한다.
  프리셋마다 상태 표시줄·내비게이션 바 인셋이 들어간다. 창보다 큰 화면은 비율을 유지해 축소하며, 표시 배율은 화면 위에 나온다.
- **시스템 글자 배율**: 85% / 100% / 130% / 200% (키패드·LCD는 130%에서 배율을 자르므로 200%는 그 잘림 확인용)
- **입력 로그**: 눌린 기능을 번호와 함께 최근 순으로 기록한다. SHIFT·ALPHA 기능은 각인 색과 `SOLVE  ← SHIFT + CALC` 형식으로,
  길게 눌러 반복된 입력은 `(반복)`으로, 입력 없는 대기 변화는 `[SHIFT 대기]`·`[SHIFT 해제]`로 표시한다.
  `초기화`는 계산기 상태와 로그를 함께 지운다.

```bash
flutter run -d chrome -t preview/key_preview_main.dart
```

- **VS Code**: 추천 확장(Dart·Flutter, [.vscode/extensions.json](.vscode/extensions.json))을 설치한 뒤
  실행 및 디버그(Ctrl+Shift+D)에서 `Key Preview (Chrome)`을 고른다 ([.vscode/launch.json](.vscode/launch.json)).
  확장은 Flutter SDK를 `dart.flutterSdkPath` 설정 → `FLUTTER_ROOT` → VS Code 프로세스의 PATH → 잘 알려진 설치 위치 순으로
  찾는다. 터미널 세션에서만 추가한 PATH(예: Git Bash의 `export PATH=...`)는 보지 않으므로, SDK를 찾지 못한다는 안내가
  뜨면 `Locate SDK`로 SDK 폴더를 고르거나 **사용자** 설정에 `"dart.flutterSdkPath": "<Flutter SDK 폴더>"`를 한 번 지정한다.
  SDK 경로는 기기마다 다르므로 저장소(워크스페이스 설정)에는 넣지 않는다.
- **Windows 데스크톱** (`-d windows`, `Key Preview (Windows)`): 플러그인 빌드에 심볼릭 링크가 필요해
  Windows **개발자 모드**를 켜야 한다 (`start ms-settings:developers`).
- 미리보기는 `lib/` 밖에 있고, 앱 진입점(`lib/main.dart`)에서 도달할 수 없으므로 앱 빌드에 포함되지 않는다.
  `test/widget/key_preview_test.dart`가 `lib/`의 preview import와 pubspec 에셋의 preview 경로를 금지하고,
  Sub-issue CI와 Milestone Full CI가 미리보기를 웹으로 빌드해 깨지지 않았는지 확인한다.
- 미리보기로 확인할 수 없는 것 — 실기기·에뮬레이터에서 확인한다:
  터치감·햅틱, 화면 방향 고정, 시스템 제스처 영역(미리보기에서는 0으로 둔다), 기기 픽셀 밀도(DPR),
  폴더블 힌지, Android 스크린리더 알림 경로(웹은 플랫폼이 다르다), Android 14 이상의 비선형 글자 배율.

## 검증

```bash
flutter analyze   # preview/ 포함, 이슈 0건이어야 한다
flutter test      # 미리보기 실행·입력 기록 테스트 포함
flutter build web -t preview/key_preview_main.dart --no-wasm-dry-run   # 미리보기 웹 빌드 (CI와 같음)
```

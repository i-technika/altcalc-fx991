# AltCalc fx-991

카시오 fx-991EX 공학용 계산기 시뮬레이터 (Flutter, Android / iOS).

- 프로젝트 규칙: [CLAUDE.md](CLAUDE.md)
- 진행 단계: [milestone.md](milestone.md)

## 개발 환경

- Flutter 3.50 이상 (Dart 3.14 이상)
- 의존성 설치: `flutter pub get`
- 생성 플러그인 파일(`linux/flutter/generated_plugin*` 등)은 `.gitattributes`로 LF 고정이다. 이 설정 이전에 받은 Windows 작업 트리에서
  이 파일들이 내용 차이 없이 수정됨으로 보이면 Git Bash에서 `bash .claude/scripts/normalize-generated-eol.sh`를 한 번 실행한다.

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
- **고대비**: 기기의 고대비 설정(iOS "대비 증가", Android "고대비 텍스트" — `MediaQuery.highContrast`)을 켠 화면.
  키 테두리·각인·LCD 꺼진 표시기가 진해지고, 흰 라벨 키는 누르면 반전된다(#54).
- **입력 로그**: 눌린 기능을 번호와 함께 최근 순으로 기록한다. SHIFT·ALPHA 기능은 각인 색과 `SOLVE  ← SHIFT + CALC` 형식으로,
  길게 눌러 반복된 입력은 `(반복)`으로, 입력 없는 대기 변화는 `[SHIFT 대기]`·`[SHIFT 해제]`로 표시한다.
  `초기화`는 계산기 상태와 로그를 함께 지운다.

```bash
flutter run -d chrome -t preview/key_preview_main.dart
```

- **VS Code**: 실행 및 디버그에서 `Key Preview (Chrome)`을 고른다 — 준비 단계는 아래 [VS Code에서 실행](#vs-code에서-실행).
- **Windows 데스크톱** (`-d windows`, `Key Preview (Windows)`): 플러그인 빌드에 심볼릭 링크가 필요해
  Windows **개발자 모드**를 켜야 한다 (`start ms-settings:developers`). Chrome 실행에는 필요 없다.
- 미리보기는 `lib/` 밖에 있고, 앱 진입점(`lib/main.dart`)에서 도달할 수 없으므로 앱 빌드에 포함되지 않는다.
  `test/widget/key_preview_test.dart`가 `lib/`의 preview import와 pubspec 에셋의 preview 경로를 금지하고,
  Sub-issue CI와 Milestone Full CI가 미리보기를 웹으로 빌드해 깨지지 않았는지 확인한다.
- 미리보기로 확인할 수 없는 것 — 실기기·에뮬레이터에서 확인한다:
  터치감·햅틱, 화면 방향 고정, 시스템 제스처의 실제 가로채기(미리보기는 Android 프리셋에 시스템 제스처 영역을
  근사해 넣는다 — 위·아래는 시스템 바와 같게, 제스처 내비게이션은 좌우에 약 24dp. 가장자리 키가 손을 뗄 때
  입력되는 것이 보이는 프리셋은 폴더블 커버다), 기기 픽셀 밀도(DPR),
  폴더블 힌지, Android 스크린리더 알림 경로(웹은 플랫폼이 다르다), Android 14 이상의 비선형 글자 배율.

## VS Code에서 실행

[.vscode/launch.json](.vscode/launch.json)에 실행 구성 세 개가 있다.
아래 단축키는 Windows·Linux 기준이며, macOS는 Ctrl 대신 Cmd를 쓴다.

| 구성 | 진입점 | 기기 | 비고 |
| --- | --- | --- | --- |
| `AltCalc (앱)` | `lib/main.dart` | 상태 표시줄에서 고른 기기 | 기기를 지정하지 않아 VS Code 하단 상태 표시줄의 기기 선택을 따른다 (Windows 데스크톱을 고르면 개발자 모드 필요) |
| `Key Preview (Chrome)` | `preview/key_preview_main.dart` | Chrome | Windows 개발자 모드 불필요 |
| `Key Preview (Windows)` | `preview/key_preview_main.dart` | Windows 데스크톱 | Windows 개발자 모드 필요 |

### 처음 한 번 준비

1. **터미널에서 `flutter pub get`** — SDK를 PATH에 넣은 셸에서, VS Code로 폴더를 열기 **전에** 실행한다.
   이때 생기는 `.dart_tool/package_config.json`의 `flutterRoot`로 확장이 SDK를 찾으므로,
   Flutter가 VS Code의 PATH에 없는 PC도 따로 설정하지 않아도 된다.
   확장은 SDK를 켜질 때 한 번만 찾으므로, 폴더를 먼저 열어 SDK를 못 찾는다는 알림을 봤다면 `pub get` 뒤
   명령 팔레트(Ctrl+Shift+P)에서 `Developer: Reload Window`를 실행한다.
   개발자 모드가 꺼진 Windows에서는 이 명령이 종료 코드 1로 끝나도 Chrome 실행에는 지장이 없다 ([알아 둘 점](#알아-둘-점)).
2. **작업 영역 신뢰** — 폴더를 열 때 묻는 "작성자를 신뢰합니까?"에 **신뢰**를 고른다.
   Dart 확장은 제한 모드(Restricted Mode)를 지원하지 않는다. 신뢰하지 않으면 확장이 아예 켜지지 않고
   `"type": "dart"` 실행 구성도 쓸 수 없다. 나중에 바꾸려면 명령 팔레트의 `Workspaces: Manage Workspace Trust`를 쓴다.
3. **추천 확장 설치** — 확장 보기(Ctrl+Shift+X)의 "권장" 목록([.vscode/extensions.json](.vscode/extensions.json))에서
   Dart·Flutter를 설치하거나, 터미널에서 다음을 실행한다. macOS에서 `code` 명령을 쓰려면 먼저 명령 팔레트의
   `Shell Command: Install 'code' command in PATH`를 실행해야 한다.

   ```bash
   code --install-extension dart-code.dart-code --install-extension dart-code.flutter
   ```

4. 실행 및 디버그(Ctrl+Shift+D)에서 구성을 고르고 F5를 누른다.

### Flutter SDK를 찾는 순서

확장(Dart-Code 3.146 소스 기준)은 위에서부터 처음 찾은 SDK를 쓴다.

1. 설정 `dart.flutterSdkPath`, 그다음 `dart.getFlutterSdkCommand`(SDK 경로를 출력하는 명령)
2. 프로젝트 안에 둔 SDK (`.flutter`, `vendor/flutter` 폴더 등)
3. 환경 변수 `DART_PATH_OVERRIDE`, 그다음 그 창의 확장이 물려받은 `PATH`
4. `.dart_tool/package_config.json`의 `flutterRoot` (위 준비 1단계)
5. 환경 변수 `FLUTTER_ROOT`
6. 고정 위치: `~/snap/flutter/common/flutter`(Linux만), `~/flutter-sdk`, `/google/flutter`, `/opt/flutter` 순서
   (Windows에서 `/`로 시작하는 경로는 현재 드라이브의 루트 기준이다)

3번의 `PATH`가 무엇인지는 확장이 아니라 VS Code가 창을 연 방식에 따라 다르다. 아래는 VS Code 본체 소스로 확인한 내용이며
실측하지는 않았다.

- 터미널에서 `code .`로 새 창을 열면 그 터미널의 환경을 쓴다. VS Code가 이미 실행 중이어도 같다.
- 시작 메뉴·Dock·메뉴(파일 > 폴더 열기)로 연 창, 또는 이미 열린 폴더에 `code .`를 해서 기존 창으로 옮겨 간 경우에는
  VS Code를 처음 켰을 때의 환경을 쓴다. macOS·Linux는 이때 로그인 셸의 환경(예: `~/.zshrc`의 PATH)을 가져온다.
- 터미널 세션에서만 `export PATH=...`를 한 뒤 시작 메뉴로 연 창은 그 PATH를 보지 못한다.

`~/develop/flutter`처럼 고정 위치 목록에 없는 곳에 SDK가 있고 PATH에도 없으면, `flutter pub get` 전의 새 클론이나
`.dart_tool`을 지운 뒤에는 확장이 SDK를 찾지 못한다(확장 소스 기준이다. 이 알림은 실제로 띄워 보지 않았다).
그때는 알림의 `Locate SDK`로 SDK 폴더를 고르거나, **사용자** 설정에 한 번 지정한다.
사용자 설정은 명령 팔레트의 `Preferences: Open User Settings (JSON)`에서 연다. `~/`는 홈 폴더로 풀린다(Windows에서도 `~\`가 아니라 `~/`로 쓴다).

```jsonc
{ "dart.flutterSdkPath": "~/develop/flutter" }
```

SDK 경로는 기기마다 다르므로 저장소의 워크스페이스 설정(`.vscode/`)에는 넣지 않는다.

### 알아 둘 점

- **개발자 모드가 꺼진 Windows**에서는 `flutter pub get` 자체가 종료 코드 1로 끝난다.
  - 의존성 해석을 마친 뒤 `Building with plugins requires symlink support` 오류가 난다.
  - 확장이 패키지가 없는 프로젝트에 자동으로 돌리는 pub get도 같은 이유로 실패하며, 출력 패널의
    `flutter (package:...)` 채널에 기록된다(작업 영역 안의 다른 체크아웃에서 실측).
  - 이때도 `package_config.json`은 이미 기록되어 있으므로 SDK 탐지와 Chrome 실행(`Key Preview (Chrome)`, Chrome에서 실행하는 `AltCalc (앱)`)에는 지장이 없다.
  - 실패하는 것은 Windows 데스크톱 실행뿐이다.

## 검증

```bash
flutter analyze   # preview/ 포함, 이슈 0건이어야 한다
flutter test      # 미리보기 실행·입력 기록 테스트 포함
flutter build web -t preview/key_preview_main.dart --no-wasm-dry-run   # 미리보기 웹 빌드 (CI와 같음)
```

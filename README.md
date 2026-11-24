# AltCalc fx-991

카시오 fx-991EX 공학용 계산기 시뮬레이터 (Flutter, Android / iOS).

- 프로젝트 규칙: [CLAUDE.md](CLAUDE.md)
- 진행 단계: [milestone.md](milestone.md)

## 개발 환경

- Flutter 3.50.0 — `pubspec.yaml`의 `environment.flutter`로 고정한다. CI도 같은 값을 읽고(#78),
  다른 버전의 SDK로는 `flutter pub get`이 `requires Flutter SDK version ...`으로 실패한다.
  - CI는 `.github/scripts/read-flutter-version.sh`로 이 값을 읽어 설치 액션에 넘긴다(#90, 러너의 yq·Chocolatey에 기대지 않는다).
    `flutter test`가 이 스크립트를 bash로 실행해 검사하므로, Windows에서는 Git for Windows(bash 포함)가 있어야 한다.
- 의존성 설치: `flutter pub get`
- 생성 플러그인 파일(`linux/flutter/generated_plugin*` 등)은 `.gitattributes`로 LF 고정이다. 이 설정 이전에 받은 Windows 작업 트리에서
  이 파일들이 내용 차이 없이 수정됨으로 보이면 Git Bash에서 `bash .claude/scripts/normalize-generated-eol.sh`를 한 번 실행한다.

### Flutter SDK 버전 올리기

로컬 SDK·`pubspec.yaml`·`pubspec.lock`·README를 **한 커밋**에서 함께 바꾼다. CI는 `pubspec.yaml`을 읽으므로 워크플로는 고치지 않는다.

**먼저 알아 둘 점:** 고정값은 정확한 버전이라, SDK를 바꾸는 순간 옛 고정값을 가진 **같은 PC의 다른 브랜치·worktree**에서
`flutter pub get`·`test`·`analyze`·VS Code 실행이 모두 실패한다(SDK 폴더는 하나를 공유한다).
같은 이유로 버전 올리기 절차 밖에서는 `flutter upgrade`를 실행하지 않는다(새 버전 알림이 떠도 무시한다).

- 버전 올리기는 진행 중인 서브이슈 브랜치가 없는 마일스톤 경계에서 한다.
  SDK를 바꾸기 전에 다른 세션의 `flutter` 명령과 VS Code 창을 닫는다(Windows에서 SDK 파일이 잠겨 있으면 전환이 실패할 수 있다).
- 그럴 수 없으면 새 버전을 별도 폴더에 받아(`git clone -b X.Y.Z https://github.com/flutter/flutter.git ~/develop/flutter-X.Y.Z`)
  그 작업에 쓰는 셸의 PATH 앞에만 넣는다. 기존 SDK는 나머지 브랜치가 고정값을 올릴 때까지 그대로 둔다.
  - PATH는 브랜치가 아니라 셸마다 적용된다. 그 셸에서 실행한 명령만 새 SDK를 쓴다.
  - VS Code는 사용자 설정 `dart.flutterSdkPath`가 PATH보다 앞선다(아래 "Flutter SDK를 찾는 순서").
    그 설정이 없으면 새 SDK를 PATH에 넣은 셸에서 `code <worktree 폴더>`로 **새 창**을 연다.
    설정이 있으면 그 창에서 명령 팔레트의 `Flutter: Change SDK`로 새 폴더를 고른다.

1. 올릴 stable 버전 `X.Y.Z`를 정한다 ([릴리스 목록](https://docs.flutter.dev/install/archive)).
2. 로컬 SDK를 그 버전으로 바꾼다.
   - 최신 stable이 `X.Y.Z`면 `flutter upgrade`로 충분하다.
   - 아니면 SDK 폴더에서 `git fetch --tags && git checkout X.Y.Z`를 실행하고 `flutter --version`으로 확인한다.
     태그를 체크아웃하면 SDK가 브랜치 밖에 있게 되어 `flutter upgrade`가 거부된다.
     나중에 최신으로 돌아갈 때는 `git checkout stable` 뒤 `flutter upgrade`를 실행한다.
3. `pubspec.yaml`의 `environment.flutter`를 `X.Y.Z`로 바꾼다. Dart 버전이 바뀌었으면 `environment.sdk`도 검토한다.
4. `flutter pub get`을 실행한다. `pubspec.lock`의 `sdks.flutter`가 바뀌고, SDK가 고정하는 의존성(`meta`·`characters` 등)도 바뀔 수 있다.
5. 위 "개발 환경"의 버전 표기를 고친다. `test/unit/flutter_sdk_pin_test.dart`가 고정값과 대조한다.
6. `flutter analyze`·`flutter test`와 Android 단위 테스트(아래 "Android 단위 테스트")를 통과시킨 뒤 위 파일을 함께 커밋한다.
   - Flutter가 minSdk·targetSdk 기본값을 바꾸면 `AndroidTestSetupTest`가 실패한다. `TestSupport.kt`의 `MIN_SDK` 등을 함께 고친다.
   - `pubspec.lock`을 빠뜨리면 CI의 작업 트리 검사(`.github/scripts/verify-clean-tree.sh`)가 실패한다.
   - 로컬 테스트는 이를 잡지 못한다. `flutter test`가 먼저 pub get으로 lock을 다시 쓰기 때문이다.

다른 개발 PC는 이 커밋을 받은 뒤 2번처럼 SDK를 맞춘다.

### CI 액션 고정 버전 올리기

워크플로(`.github/workflows/`)의 모든 `uses:`는 커밋 SHA로 고정하고, 같은 줄 끝에 그 SHA의 릴리스 태그를 적는다 (#88).
태그(`@v2`)는 움직여서, 가리키는 커밋이 바뀌면 CI 동작도 조용히 바뀐다.

```yaml
uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2.23.0
```

- 같은 액션은 두 워크플로에서 같은 SHA로 고정한다. 올릴 때도 한꺼번에 올린다.
- 검사는 두 곳에서 한다.
  - `test/unit/ci_actions_test.dart`(오프라인): 모든 `uses:`가 SHA 40자리 + `# vX.Y.Z`인지, 워크플로끼리 같은지,
    주석의 버전이 Node 24 최소 버전(`_minVersions`, #79) 이상인지 본다.
  - CI의 `Verify Action Pins` 잡(`bash .github/scripts/action-pins.sh verify`, Sub-issue CI·Milestone CI 모두): GitHub API로
    SHA가 정말 그 태그의 커밋인지, 그 버전에 해당하는 보안 권고(GitHub Advisory Database의 검토된 GHSA, 철회된 것 제외)가 없는지 확인한다.
    - 외부 API에 기대는 검사라 테스트 잡과 따로 둔다. 이 잡만 빨간색이면 고정·권고 문제거나 API 장애다.
      일시 장애는 세 번까지 시도하고, HTTP 404(태그·저장소 없음)는 바로 실패한다. 로그의 오류 줄이 원인을 적는다.
    - 권고가 새로 나오면 워크플로를 고치지 않은 PR에서도 이 잡이 실패한다(아래 "보안 권고가 나왔을 때").
- 한계: composite 액션이 안에서 쓰는 액션은 고정되지 않는다. 예를 들어 flutter-action v2.23.0은 내부에서 `actions/cache@v5`를 쓴다.
  바깥 SHA를 고정해도 그 내부 참조는 `actions/cache`의 v5 태그를 따라 움직인다.

**보안 권고가 나왔을 때.** 마일스톤 점검을 기다리지 않고 바로 이번 마일스톤의 서브이슈를 만든다.

- 고친 릴리스가 있으면 아래 절차로 올린다. 그 PR이 머지되기 전까지 다른 서브이슈 PR의 `Verify Action Pins`는 실패한 채로 둔다
  (머지된 뒤 각 PR에 마일스톤 브랜치를 머지하면 통과한다).
- 고친 릴리스가 아직 없거나, 이 저장소가 쓰지 않는 입력·기능에만 해당하면 `.github/action-advisories-ignore`에
  `GHSA-xxxx-xxxx-xxxx YYYY-MM-DD 사유` 한 줄을 적는다(사유에 판단 근거와 추적 이슈 번호). 그 기한까지는 경고만 나온다.
  - 기한이 지나면 다시 실패한다. 다시 검토해 기한을 늘리거나, 고친 릴리스로 올리고 줄을 지운다.
  - 형식이 틀린 줄은 `verify`와 `test/unit/ci_actions_test.dart`가 잡는다.
**갱신 방법: 수동 절차, 마일스톤 착수 때 점검.** `/open-ms`가 새 마일스톤 브랜치에서 `action-pins.sh outdated`를 돌린다.
새 릴리스가 있으면 그 마일스톤의 서브이슈(`CI 액션 고정 버전 올리기 (M<N>)`)로 등록해 아래 절차로 올린다.
보안 권고는 기다리지 않는다(위 "보안 권고가 나왔을 때").

Dependabot(`github-actions` 생태계)은 쓰지 않는다.

- Dependabot PR은 기본 브랜치(`main`)로 바로 간다. 서브이슈 → 마일스톤 흐름(이슈·라벨·마일스톤·`Sub-issue Linux CI`)을 건너뛰고,
  캐시가 없는 멀티플랫폼 CI가 돈다.
- `target-branch`는 고정된 이름이라 마일스톤마다 바뀌는 `milestone/m<N>`을 따라가지 못한다.
- 주 버전이 바뀌면 어차피 사람이 `runs.using`을 확인하고 `_minVersions`를 고쳐야 한다(아래 2번).
- Dependabot 경고(alerts)도 대신하지 못한다. GitHub 문서("About Dependabot alerts"의 제한 사항)에 따르면
  Actions 경고는 버전 태그로 참조한 액션에만 나오고, SHA로 고정한 액션에는 나오지 않는다.
  그래서 권고 확인은 위 `verify`·`outdated`가 Advisory Database API(`advisories?ecosystem=actions`)로 직접 한다.

1. `bash .github/scripts/action-pins.sh outdated`로 액션마다 고정 버전과 새 릴리스를 본다(`gh` 로그인 필요).
   - 같은 주 버전의 새 릴리스와 더 높은 주 버전을 따로, 커밋 SHA와 함께 보여 준다. 고정한 버전에 권고가 있으면 `!` 줄로 보인다
     (예외 목록에 있는 권고는 기한과 함께 따로 표시한다).
   - 새 릴리스나 권고가 있어도 실패하지 않는다. 조회에 실패할 때만 실패한다.
2. 주 버전이 바뀌면 그 버전의 `action.yml`(`action.yaml`)과 릴리스 노트를 확인한다.
   - `runs.using`이 `node24`여야 한다. `composite`면 내부에서 쓰는 액션들이 node24여야 한다.
   - 입력·기본값 변경(예: 캐시 키 형식)이 워크플로에 영향을 주는지 본다.
   - `test/unit/ci_actions_test.dart`의 `_minVersions` 주석과 최소 버전을 갱신한다.
3. 두 워크플로의 해당 `uses:` 줄을 모두 `@<새 SHA> # <새 태그>`로 바꾼다.
   - SHA는 1번 출력을 쓰거나 `gh api repos/<owner>/<repo>/commits/refs/tags/<태그> --jq .sha`로 얻는다.
   - `gh api …/git/ref/tags/<태그>`는 쓰지 않는다. 주석 달린 태그에서 커밋이 아니라 태그 객체의 SHA를 낸다.
4. `bash .github/scripts/action-pins.sh verify`, `flutter analyze`, `flutter test`를 통과시킨 뒤 커밋한다.
5. 서브이슈 PR의 CI에서 새 액션으로 잡이 돌고, 실행 주석(annotation)에 Node 런타임 경고가 없는지 확인한다.
   Milestone CI에만 있는 잡(Windows·macOS·웹 빌드)은 마일스톤 PR을 Ready로 바꿀 때 확인된다.

## 앱 실행

```bash
flutter run            # 연결된 기기·에뮬레이터
```

## 개발용 미리보기 (`preview/`)

실제 계산기 화면(`CalculatorScreen`)을 데스크톱 브라우저 창에 띄워, 휴대폰·에뮬레이터 없이
키패드와 키 입력 동작을 확인하는 개발 도구다.

- **기기 크기**: 일반·소형·대형 폰, 폴더블 커버·내부·가로형 내부·플립형 내부, 태블릿 세로·가로·가로 (제스처), 분할 화면 위쪽 창, 작은 팝업 창 프리셋으로 반응형 배치를 확인한다.
  분할 화면 위쪽 창은 짧은 창이라 좌우 분할로, 작은 팝업 창은 창을 키워 달라는 안내로 그려진다(`CalcTheme` "짧은 창" 절, #38).
  프리셋마다 상태 표시줄·내비게이션 바 인셋이 들어간다. 창보다 큰 화면은 비율을 유지해 축소하며, 표시 배율은 화면 위에 나온다.
  폴더블 내부(Galaxy Z Fold 근사, 세로가 기본 방향)·가로형 폴더블 내부(Pixel Fold 근사, 가로가 기본 방향)·플립형 폴더블 내부
  (Galaxy Z Flip 근사, 세로) 프리셋에는 화면 가운데의 접힘선이 `MediaQuery.displayFeatures`로 들어간다. 이 프리셋들에서는
  **자세**(펼침/반 접힘)를, 앞의 두 프리셋에서는 **방향**(세로/가로)도 고를 수 있고(다른 기기로 바꾸면 기본 방향으로 펼친 상태로
  돌아간다), 조합마다 배치가 다음과 같다. 플립형은 짧은 변이 600dp 미만이라 실제 앱이 세로로 고정하므로(`FormFactor.orientationPolicyOf`)
  방향 선택 대신 `세로 고정` 안내가 나온다 — 기기를 돌려도 앱 화면은 돌지 않는다.

  | 접힘선 방향 | 펼침 | 반 접힘 |
  | --- | --- | --- |
  | 세로 (Fold 세로, Pixel Fold 가로) | 접힘선 기준 좌우 배치 | 접힘선 기준 좌우 배치 (책 자세) |
  | 가로 (Fold 가로, Pixel Fold 세로, Flip 세로) | 위아래 배치 — 접힘선은 `(배치에 안 씀)` | 위 LCD·아래 키패드 (테이블톱 자세, Flip은 Flex 모드). Fold·Pixel Fold는 숫자부를 함수부 오른쪽에 둔 넓은 키패드(#80) |

  접힘선 위치는 기기 화면 위 점선과 캡션으로 표시된다 — 앱이 화면을 나누는 데
  쓰는 접힘선은 주황, 배치에 쓰지 않는 접힘선은 회색 점선과 캡션 `(배치에 안 씀)`이고, 폭이 있는 힌지는 영역을 반투명하게 칠한다.
  반 접힌 접힘선은 캡션에 `반 접힘`이 붙는다. 돌린 화면의 인셋은 근사로 화면 기준 그대로 둔다(상태 표시줄 위, 내비게이션 아래, 뒤로가기 영역 좌우).
  점선 색·캡션은 앱의 배치 규칙(`FormFactor.arrangementOf`)을 따르며, 키가 터치 하한보다 작아 화면이 위아래 배치로
  되돌아가는 경우는 반영하지 않는다 — 지금 프리셋 조합에서는 일어나지 않는다(테스트가 확인 — 테이블톱 조합도 넓은 키패드(#80)로 일반 하한을 넘는다).
- **시스템 글자 배율**: 85% / 100% / 130% / 200% (키패드·LCD는 130%에서 배율을 자르므로 200%는 그 잘림 확인용)
- **고대비**: 기기의 고대비 설정(`MediaQuery.highContrast` — iOS "대비 증가", Android 14 이상 "색상 대비" 중간·높음)을 켠 화면.
  호스트(브라우저·OS)의 고대비 설정과 무관하게 이 스위치가 정한다. 실제 앱은 Android 접근성 "고대비 텍스트"를 켜도 같은
  고대비 팔레트를 쓴다(#95) — 미리보기는 그 설정을 따로 흉내 내지 않고, 이 스위치로 같은 화면을 본다.
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
  입력되는 것이 보이는 프리셋은 폴더블 커버·플립형 폴더블 내부(펼침)이고, 좌우 분할 배치에서 화면 끝에 붙은 키패드의 바깥쪽 열(그 키의
  화면 가장자리 쪽 일부)은 태블릿 가로 (제스처)·폴더블 내부·가로형 폴더블 내부에서 본다 — 같은 화면의 태블릿 가로는
  3버튼 작업 표시줄이라 좌우 영역이 없다), 기기 픽셀 밀도(DPR),
  폴더블 힌지 상태 변화의 시점(접힘 정보가 늦게 오는 시작 구간, 회전 직후 접힘 정보가 몇 프레임 늦게 오는 구간 — 자세·방향별 배치 자체는 미리보기로 본다), Android 스크린리더 알림 경로(웹은 플랫폼이 다르다), Android 14 이상의 비선형 글자 배율.

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
  - 확장이 돌리는 pub get도 같은 이유로 실패하며, 출력 패널의 `flutter (package:...)` 채널에 기록된다
    (#52에서 작업 영역 안 `.claude/worktrees/`의 다른 체크아웃에 돈 것을 실측했다. 루트 체크아웃이 #66이 들어간 브랜치이면
    그곳은 확장의 프로젝트 목록에서 빠진다 — [작업 영역 안의 git 워크트리](#작업-영역-안의-git-워크트리) 참고).
  - 이때도 `package_config.json`은 이미 기록되어 있으므로 SDK 탐지와 Chrome 실행(`Key Preview (Chrome)`, Chrome에서 실행하는 `AltCalc (앱)`)에는 지장이 없다.
  - 실패하는 것은 Windows 데스크톱 실행뿐이다.

### 작업 영역 안의 git 워크트리

병렬 작업용 git 워크트리는 **`.claude/worktrees/` 아래**(Claude Code의 기본 위치, `.gitignore` 대상)나 **저장소 밖**
(`../altcalc-wt<번호>`)에 만든다. 저장소 폴더 안의 점으로 시작하지 않는 폴더(예: `worktrees/`)에는 만들지 않는다.
확장이 다른 세션의 워크트리에 pub get을 돌리면 그 세션의 `pubspec.lock`이 다시 쓰일 수 있다. 그 세션의 test·pub과
`.dart_tool`을 동시에 쓰게 되고, 개발자 모드가 꺼진 Windows에서는 실패 로그가 남는다.
#67 이전에 체크아웃한 작업 트리에서는 생성 플러그인 파일도 `M`이 된다.

[analysis_options.yaml](analysis_options.yaml)의 `analyzer.exclude`에 `.claude/worktrees/**`를 두어 확장이 워크트리를
프로젝트로 보지 않게 한다(#66). 아래에서 **(소스)** 는 확장(Dart-Code 3.146) 소스로 확인한 것이다. **(실측)** 은
사용자 설정과 분리한 VS Code(`--user-data-dir`·`--extensions-dir`)를 저장소 루트로 띄우고 확장 로그(`dart.extensionLogFile`)로 본 것이다.

- **프로젝트 목록** (소스)
  - 연 폴더를 포함해 5단계(루트 아래 4단계, `dart.projectSearchDepth`)까지 `pubspec.yaml`이 있는 폴더를 모두 프로젝트로 본다.
    점 폴더도 들어간다(analyzer가 점 폴더를 분석하지 않는 것과 다르다).
  - 목록을 쓰는 모든 곳(시작 알림, pubspec 변경 처리, `Pub: Get Packages for All Projects`, 프로젝트 선택 목록, 작업·테스트 실행 등)에
    `analyzer.exclude`가 적용된다.
  - `analyzer.exclude`는 끝의 `/**`를 뗀 뒤 `*`가 남지 않는 항목만 폴더 제외로 쓰인다. 저장소 쪽 표기는
    [test/unit/analysis_options_test.dart](test/unit/analysis_options_test.dart)가 지킨다. 확장 쪽 규칙이 바뀌는 것은 테스트가 잡지 못한다.
  - analyzer는 원래 점 폴더를 건너뛰므로 `flutter analyze` 결과는 달라지지 않는다.
  - 목록은 5분 동안 캐시된다. 작업 영역 안 어디서든 `.dart_tool/package_config.json`이 바뀌면(pub get) 캐시가 바로 비워진다.
- **켜질 때**
  - (소스) 패키지가 없거나 오래된 프로젝트를 모아 "Some packages are missing or out of sync…" 알림으로 pub get을 묻는다.
    마지막 pub get 때보다 Dart SDK 메이저·마이너가 올라간 프로젝트가 하나라도 있으면, 그 알림 대신 upgrade 알림 하나로
    대상 전부에 `pub upgrade`를 묻는다. 버튼을 누르면 알림에 든 프로젝트 **모두**에 돌린다.
    이 단계에는 묻지 않고 돌리는 경로가 없다.
  - (실측) 새 워크트리를 `.claude/worktrees/`에 만들고 창을 열면, 수정 전에는 그 워크트리가 `package_config.json` 없음으로
    알림 대상이 된다. 수정 후에는 프로젝트 목록에서 빠져 알림이 없다.
- **켜져 있는 동안 `pubspec.yaml`·`pubspec_overrides.yaml`이 생기거나 바뀌면** (소스, `dart.runPubGetOnPubspecChanges` 기본값 `always`)
  - 바뀐 파일의 절대경로에 점으로 시작하는 폴더가 있으면 아무것도 하지 않는다. 이 동작은 브랜치와 무관하다.
    - 그래서 `.claude/worktrees/`에서 워크트리를 만들거나 브랜치를 바꿔도 돌지 않는다(실측. 대조군이라 수정 전에도 같다).
    - 반대로 워크트리 자체를 VS Code로 열면 그 창에서는 이 자동 실행이 늘 꺼진다. pubspec을 바꾼 뒤 직접 `flutter pub get`을 한다.
  - 그 밖에는 걸러진 목록에서 오래된 프로젝트를 센다.
    - 0개이면 바뀐 폴더에, **1개이면 그 프로젝트에** 묻지 않고 돌린다. 2개 이상이면 알림을 띄운다.
    - 루트 `pubspec.yaml`을 저장하면 루트 자신도 오래됨이 되어 보통 알림으로 간다.
    - 그러나 루트가 이미 최신이면 오래된 것이 워크트리 하나뿐일 때 그 워크트리에 돈다. 예를 들어
      루트의 `pubspec_overrides.yaml`만 바꿨을 때(오래됨 판정에 쓰이지 않는다), 또는 터미널 `flutter pub add`가
      `package_config.json`까지 먼저 다시 썼을 때다. `analyzer.exclude`가 워크트리를 이 셈에서 빼서 막는다.
  - 바뀐 폴더 자체는 거르지 않는다. 그래서 점으로 시작하지 않는 폴더에 워크트리를 만들면, 만드는 즉시 그 워크트리에
    pub get이 돈다(실측. 저장소 안 `wt-visible-66/`). 워크트리 위치 규칙은 이것 때문이다.
- **루트 체크아웃의 브랜치에 달려 있다** (소스)
  - 확장은 **연 폴더에 체크아웃된 브랜치**의 `analysis_options.yaml`을 읽는다.
  - 이 항목이 없는 브랜치로 바꾸면, 창을 다시 불러오거나 목록 캐시가 비워진 뒤 워크트리가 다시 목록에 들어간다.
    그런 브랜치는 #66 머지 전에 분기해 아직 마일스톤 브랜치를 머지하지 않은 브랜치, M1 종료 전의 `main` 등이다.
  - 그러면 시작 알림에 나오고, 위의 "1개" 경로로 묻지 않고 pub get될 수 있다.
    그런 브랜치에서 작업할 때는 먼저 마일스톤 브랜치를 머지한다.
  - 보조로 **사용자** 설정에 `"dart.analysisExcludedFolders": [".claude/worktrees"]`를 둘 수 있다
    (상대경로는 연 폴더 기준으로 풀린다. 선택 사항이며 저장소에는 넣지 않는다).
    다만 이 설정에는 빈틈이 있다. 기기 연결 때 도는 플랫폼 조회가 이 설정 없이 목록을 만든다. 목록 캐시가 제외 설정과
    무관하게 공유되므로, 그 뒤 최대 5분 동안은 다른 호출도 워크트리가 든 목록을 받을 수 있다.

방법 비교
- 사용자 설정: 브랜치와 무관하다. 그러나 기기마다 따로 해야 하고, 저장소가 지키거나 테스트할 수 없다. 위의 빈틈도 있다.
- 워크스페이스 설정 `.vscode/settings.json`의 `dart.analysisExcludedFolders`: #52에서 도구 종속이라 넣지 않았다.
  사용자 설정과 같은 빈틈도 있다.
- 위치 규칙만 두기: Claude Code가 워크트리를 저장소 안 `.claude/worktrees/`에 만들므로, 그곳의 워크트리가 시작 알림과
  "1개" 경로에 계속 잡힌다.
- 그래서 저장소가 지키고 테스트할 수 있는 Dart 도구 공통 설정인 `analysis_options.yaml`을 쓰고, 위치 규칙을 보조로 둔다.

## 검증

```bash
flutter analyze   # preview/ 포함, 이슈 0건이어야 한다
flutter test      # 미리보기 실행·입력 기록 테스트 포함
flutter build web -t preview/key_preview_main.dart --no-wasm-dry-run   # 미리보기 웹 빌드 (CI와 같음)
```

### Android 단위 테스트 (Kotlin)

`android/app/src/main/kotlin`의 플랫폼 코드(플랫폼 채널, 고대비 텍스트 수신)는 JVM 단위 테스트로 검사한다 (#108).
테스트는 `android/app/src/test/kotlin`에 있고, Robolectric이 API 수준별 Android 프레임워크를 JVM에서 돌리므로
기기·에뮬레이터는 필요 없다(Android SDK는 앱 빌드와 같이 필요하다). Kotlin 코드나 `android/` Gradle 설정을 바꿨으면 커밋 전에 돌린다.

```bash
flutter build apk --debug --config-only   # gradlew·android/local.properties를 만들고 지금 셸의 Flutter SDK 경로로 맞춘다 (몇 초)
cd android
./gradlew :app:testDebugUnitTest          # PowerShell: .\gradlew.bat :app:testDebugUnitTest
```

- 첫 줄은 래퍼가 이미 있어도 돌린다. `gradlew`는 `android/local.properties`의 `flutter.sdk`를 쓰므로,
  다른 SDK 폴더로 버전을 올리는 중(위 "Flutter SDK 버전 올리기")이면 옛 SDK로 돌 수 있다.
- **Java 21 이상**이 필요하다. Gradle은 `JAVA_HOME`(없으면 PATH의 `java`)을 쓴다 — Android Studio의 JBR
  (`<Android Studio>/jbr`)이면 된다. 낮은 버전이면 테스트를 시작하기 전에 안내 문구와 함께 멈춘다
  (`android/app/build.gradle.kts`의 `minTestJavaVersion` — Robolectric이 API 36 프레임워크에 Java 21을 요구한다).
- 처음 실행할 때 내려받는 것이 많다:
  - Robolectric이 테스트 대상 API 수준(24·29·30·35·36)의 프레임워크 jar를 Maven Central에서
    `~/.m2/repository/org/robolectric`으로 받는다(합쳐 약 700MB).
  - Gradle 구성 단계에서 Flutter 기본 NDK가 없으면 Android SDK에 설치한다(`jni` 플러그인이 NDK 버전을 지정한다 — 테스트에는 쓰지 않는다).
- 콘솔 마지막에 `Android 단위 테스트: SUCCESS — 실행 N, 성공 N, 실패 0, 건너뜀 0` 한 줄이 나온다.
  실패·건너뛴 테스트는 이름과 단언 문구·스택이 콘솔에 나오고, 결과 보고서는 `build/app/reports/tests/testDebugUnitTest/index.html`이다.
- 테스트 구성:
  - `HighTextContrastStreamHandlerTest` — 고대비 텍스트 처리기의 구독·전송 규칙과 API 35 이하/36 이상 분기
  - `MainActivityChannelsTest` — 채널 등록 부분을 가짜 메신저로 부른다(채널·메서드 이름, `hasHingeSensor`, 정리)
  - `MainActivityLifecycleTest` — `FlutterJNI`를 Mockito 대역으로 바꾼 캐시 엔진으로 액티비티를 생명주기대로 돌려
    `configureFlutterEngine`·`cleanUpFlutterEngine`·`onResume`의 연결을 본다(Flutter 자체 `FlutterActivityTest`와 같은 방식)
  - `AndroidTestSetupTest` — 테스트 대상 API 수준(`TestSupport.kt`의 `MIN_SDK` 등)을 앱 minSdk·targetSdk와 대조한다.
    Flutter를 올려 minSdk가 바뀌면 이 테스트가 실패하므로 상수를 함께 고친다.
  - Dart 쪽 `test/unit/main_activity_source_test.dart`가 `MainActivity.kt` 소스를 읽어 채널 이름을 Dart 쪽과 대조하고,
    생명주기 테스트가 구조상 못 보는 `super.configureFlutterEngine`(플러그인 등록) 호출을 확인한다.
  - Mockito 인라인 모크 에이전트는 Gradle이 테스트 JVM에 `-javaagent`로 붙인다(`android/app/build.gradle.kts`의 `mockitoAgent`).
- CI: Sub-issue CI와 Milestone CI의 `Android Unit Tests (JVM)` 잡(두 잡의 일치는 `test/unit/ci_android_unit_test_test.dart`가 지킨다).
  - 캐시는 다섯 가지이고 한 벌이 약 4.5GiB다: Flutter SDK·pub(flutter-action), Gradle·Gradle 래퍼(`setup-java`의 `cache: gradle`),
    NDK·Robolectric jar(`actions/cache`).
  - 걸리는 시간 (실측 기록: #121):
    - 캐시가 모두 맞으면 약 2~3분이다(1분 57초~2분 48초, 14회).
    - 캐시가 없으면 3분 51초~11분 35초다(4회, Flutter SDK만 복원한 경우 포함). 내려받기 속도 편차가 커서 같은 NDK 설치가 14초~3분 25초로 갈렸다.
    - Gradle 캐시만 없는 경우는 재지 않았다. 이 둘 사이로 추정한다.
  - 캐시 범위 (GitHub 규칙):
    - PR 실행은 자기 범위(`refs/pull/<번호>/merge`)와 베이스 브랜치, 기본 브랜치(`main`) 범위만 읽는다.
    - push·`workflow_dispatch` 실행은 자기 브랜치와 `main` 범위만 읽는다.
    - 저장은 늘 자기 범위에 하고, 키가 정확히 맞으면 다시 저장하지 않는다.
    - 그래서 Sub-issue CI는 마일스톤 브랜치 push(서브이슈 머지)에서도 돌아 그 범위에 캐시를 예열한다.
      다음 서브이슈 PR들은 첫 실행부터 다섯 가지를 모두 복원하고, PR 범위에는 키가 바뀐 캐시만 저장한다.
    - Milestone CI(마일스톤 PR → `main`)는 마일스톤 범위를 읽지 못한다. `main` 범위도 비어 있다(`main` push에서 도는 워크플로가 없다).
      그래서 Ready로 바꾼 뒤의 첫 실행은 캐시 없이 돈다.
  - Gradle 캐시 키는 Gradle 설정 파일(`*.gradle*`·`gradle.properties`·`gradle-wrapper.properties`) 해시라, 그 파일을 고친 PR은
    Gradle 캐시 없이 돈다. NDK·Robolectric 캐시는 앞부분이 같은 키에서 부분 복원한다.
  - `Linux Analyze, Test & Build`(약 3분)와 나란히 돈다. 캐시가 맞으면 이 잡이 먼저 끝나므로 서브이슈 PR의 CI 대기는 Linux 잡이 정한다.
    캐시가 없으면 이 잡이 정한다.
  - 캐시 용량: 저장소 한도는 10GB다. 넘으면 마지막으로 쓴 지 오래된 캐시부터 지워지고, 7일 동안 쓰지 않은 캐시도 지워진다(GitHub 문서 기준).
    - 머지된 PR, 끝난 마일스톤, 지운 브랜치 범위의 캐시는 더는 읽히지 않는다. 그래서 스킬이 머지 직후에 지운다.
      `/fix-issue` 11단계가 그 PR 범위를, `/close-ms` 5단계가 마일스톤 PR 범위와 마일스톤 브랜치 범위를 지운다.
      정리 워크플로는 따로 두지 않는다.
    - 범위가 하나 더 커지는 주요 경우는 아래와 같다. 이때 머지 push는 같은 크기를 마일스톤 범위에 새 키로 또 저장하고, 옛 키는 7일 뒤 만료된다.
      - Gradle 설정을 고친 PR: Gradle 1.2GiB를 저장한다. `android/app/build.gradle.kts`를 고쳤으면 NDK/Robolectric 1.3GiB, 래퍼 설정을 고쳤으면 래퍼 0.4GiB가 더해진다.
      - Flutter SDK를 올린 PR: Flutter SDK·pub 1.6GiB를 저장한다.
      - 마일스톤 범위가 7일 동안 쓰이지 않아 만료된 뒤의 PR: 한 벌을 통째로 저장한다.
      - Milestone CI의 Ready 실행: 한 벌에 Windows·macOS 캐시까지 저장한다.
      - 마일스톤이 아닌 브랜치에서 `workflow_dispatch`로 돌린 실행: 한 벌을 통째로 저장한다.
    - 직접 지울 때는 `gh cache delete --all --ref refs/heads/<브랜치>`나 `--ref refs/pull/<번호>/merge`를 쓴다.
      사용량은 `gh api repos/i-technika/altcalc-fx991/actions/cache/usage`로, 목록은 `gh cache list`로 본다.
- 다루지 않는 것: 실제 기기의 시스템 동작(설정 앱에서 바꿨을 때 알림이 오는지 등 — 에뮬레이터·실기기로 확인한다),
  릴리스 빌드(R8)의 API 36 참조 격리(아래 "릴리스 APK의 새 API 격리 검사"), 실제 Flutter 엔진(Dart 실행·플러그인 자동 등록).

### 릴리스 APK의 새 API 격리 검사 (R8)

API 36 전용 타입·메서드(고대비 텍스트 리스너 등)는 `@RequiresApi` 중첩 object(`Api36`)의 `@DoNotInline` 메서드 안에서만 참조한다 (#95).
바깥 클래스에 쓰면 R8이 늘 실행되는 메서드에 그 타입을 인라인해, API 35 이하 기기에서 클래스 검증·로딩이 실패할 수 있다
(Flutter 엔진이 같은 이유로 `Api34Impl`에 가둔다 — flutter#192231). 이 격리가 R8 뒤에도 유지되는지는 단위 테스트로 볼 수 없어
릴리스 APK의 dex를 열어 검사한다 (#109).

```bash
flutter build apk --release --target-platform android-arm64   # dex는 ABI와 무관하다 (로컬 약 2분)
export ANDROID_HOME="$LOCALAPPDATA/Android/Sdk"                 # Windows Git Bash의 기본 SDK 위치 (macOS·Linux는 각자의 SDK 경로)
bash .github/scripts/verify-api-isolation.sh \
  build/app/outputs/flutter-apk/app-release.apk build/app/outputs/mapping/release/mapping.txt
```

- 검사 방법:
  - build-tools의 `dexdump`로 dex 전체를 푼다.
  - compileSdk 이상으로 설치된 가장 높은 플랫폼의 `api-versions.xml`에서 API 36 이상에 추가된 클래스·메서드(생성자 포함)·필드를 모두 찾는다.
    새 플랫폼의 목록은 상위집합이라 `since="36.1"` 같은 마이너 API 항목까지 담는다.
  - 그 새 클래스를 (전이적으로) 상속·구현한 dex 클래스(예: 새 리스너 인터페이스를 구현한 람다)도 검사 대상 타입으로 삼는다.
  - 이 참조들이 어느 dex 클래스에 있는지 본다. 클래스 이름은 R8의 `mapping.txt`로 원래 이름으로 되돌린다.
    `mapping.txt`가 이 APK의 빌드 것인지는 R8 빌드 id(`# pg_map_id`와 dex 표식의 `pg-map-id`)로 먼저 확인한다.
  - 검사할 API 목록을 손으로 적지 않으므로 새 API 36 코드를 더해도 자동으로 검사 대상이 된다.
- 허용 위치(`.github/api-isolation-rules`의 `allow`):
  - 격리 object와 그 안의 클래스(`$*` — 리스너를 구현한 합성 람다, 익명 object, 중첩 클래스). 그 클래스들을 격리 object 밖에서
    만들거나 쓰면 새 타입을 구현·상속한 클래스로서 따로 잡힌다.
  - R8 API 모델링이 새 API 호출을 옮겨 담는 아웃라인 클래스(`*$$ExternalSyntheticApiModelOutline*` — Flutter 엔진 것과 합쳐지기도 한다).
  - R8이 새 프레임워크 클래스를 대신해 dex에 넣는 API 스텁(프레임워크 이름 그대로이고 대응표에 R8 합성 표시가 있다)은
    낮은 API에서도 해석·로드되므로(스텁의 목적), 그 타입은 검사 대상에서 빼고 그 스텁을 상속·구현한 클래스도 검사하지 않는다.
  - 출력에 클래스별 참조 목록이 `위반`·`허용`으로 나온다.
- 새 API 수준 전용 코드를 더할 때: 같은 방식의 `object Api<N>`으로 가두고 규칙 파일에 그 object와 `<object>$*`를 더한다.
  - `test/unit/ci_api_isolation_test.dart`가 소스의 격리 object(`Api<N>`·`Api<N>Impl`, N ≥ guard-api)와 규칙의 allow가 맞는지,
    allow가 그 모양(격리 object, 그 `$*`, 아웃라인 glob)만 쓰는지 확인한다. `allow *` 같은 넓은 glob은 막는다.
  - guard-api보다 낮은 수준 전용 코드를 가뒀으면 guard-api를 낮춘다. 낮추면 Flutter 엔진·androidx의 참조도 검사 대상이 된다.
    실측(#109, Flutter 3.50): guard-api 35는 허용 밖 클래스 0개, 34는 4개(Flutter 엔진의 `AccessibilityBridge$Api34Impl`과 그 람다,
    뒤로 가기 제스처의 `FlutterActivity$1`·`BackGestureChannel`), 25는 45개였다.
- 실패 메시지가 "위반 <클래스>"이면 그 클래스가 새 API를 직접 참조한다. 흔한 원인은 `@DoNotInline` 빠짐(격리 object 메서드가 바깥 클래스로
  인라인됨)과 바깥 클래스에서 새 타입의 람다·캐스트를 쓴 경우다. 둘 다 #109에서 일부러 만들어 이 검사가 실패하는 것을 확인했다.
- 검사가 헛돌지 않게 다음 경우에도 실패한다:
  - 검사 대상 참조를 하나도 찾지 못함(dexdump 형식 변화 의심)
  - `mapping.txt`가 없거나 R8 빌드 id가 dex와 다름
  - minSdk가 guard-api 이상
- 한계: 프레임워크 클래스 계층은 따라가지 않는다. 하위 클래스 타입으로 부른 새 메서드나, 오래된 클래스가 새로 구현하게 된 인터페이스의 메서드
  (예: API 36에 `AutoCloseable`을 구현하게 된 `ExecutorService.close()`)는 메서드로는 못 잡는다.
  보통은 R8이 그런 호출을 API 아웃라인으로 옮기고, 새 타입이 들어간 시그니처·캐스트는 타입으로 잡힌다.
  아웃라인 클래스 안은 들여다보지 않는다(R8이 API 수준별로 나눠 만드는 합성 클래스다).
- API 목록은 설치된 가장 높은 플랫폼의 것이라 환경마다 다를 수 있다(#109 때 로컬 `android-37.0`, CI 러너 `android-37.2`).
  guard-api 이상 항목을 넓게 잡는 쪽이다. 러너 이미지가 바뀌어 새 마이너 API 항목이 들어와도 보통은 결과가 같다.
  CI만 결과가 다르면, 출력 첫머리의 `API 목록:` 줄로 어느 플랫폼을 썼는지 본다.
- CI: Sub-issue CI와 Milestone CI의 `Android Release API Isolation` 잡(두 잡의 일치는 `test/unit/ci_api_isolation_test.dart`가 지킨다).
  - 스크립트 동작은 `test/unit/api_isolation_script_test.dart`가 가짜 SDK(build-tools·플랫폼)와 실제 빌드에서 옮긴 dexdump·mapping 표본으로 검사한다.
  - 첫 실행(#109)은 3분 36초 걸렸다. 그중 릴리스 빌드가 3분이고, 빌드 안에서 NDK·CMake 내려받기가 약 1분 30초다.
    같이 도는 `Linux Analyze, Test & Build`(3분 18초)와 거의 같아, NDK 캐시(약 1GB를 범위마다 더 저장)는 두지 않았다.

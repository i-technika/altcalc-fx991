# 프로젝트: 카시오 fx-991 공학용 계산기 시뮬레이터 (Flutter)

## 1. 핵심 아키텍처 및 기술 스택
- **응답 및 주석 언어:** 모든 설명, 계획 수립, 코드 주석은 한국어로 작성한다.
- **프레임워크:** Flutter (Dart) - Android / iOS 크로스 플랫폼
- **상태 관리:** `flutter_riverpod`
- **수학 연산 엔진:** 커스텀 AST(추상 구문 트리) + `decimal` 패키지 (내부 유효숫자 20자리 고정밀도 연산, LCD 출력 시 유효숫자 10자리 반올림 포맷팅)
- **2D 자연어 수식 렌더링 (Natural Textbook Display):** `IntrinsicWidth`, `Row`, `Column` 등을 활용한 재귀 위젯 트리(`MathNodeWidget`)로 분수, 루트, 지수, 정적분, 시그마 기호를 렌더링한다.
- **수익화 및 서버리스 인앱결제:**
  - 하단 적응형 배너 광고(`google_mobile_ads`): 최하단 키패드 행 아래 `8dp~12dp` 오터치 방지 안전 여백 확보
  - 비소모성 인앱결제(`in_app_purchase`, 상품 ID: `remove_ads`) + `shared_preferences` 로컬 캐싱 + 앱 시작 시 백그라운드 `restorePurchases()` 동기화 (백엔드 서버 없음)

## 2. 디렉토리 구조 (`lib/`)
- `core/constants/key_definitions.dart`: 50개 버튼 레이아웃 및 SHIFT/ALPHA 키 매핑 정의
- `core/theme/calc_theme.dart`: 카시오 fx-991EX/CW 색상 팔레트 및 LCD 폰트 스타일
- `domain/models/`: `math_node.dart` (수식 AST 노드), `calc_state.dart` (계산기 전체 상태)
- `domain/engine/`: `cursor_navigator.dart` (방향키 커서 이동), `ast_evaluator.dart` (수식 계산기), `numerical_methods.dart` (수치해석)
- `presentation/providers/`: `calc_provider.dart`, `iap_provider.dart`
- `presentation/screens/`: `calculator_screen.dart`
- `presentation/widgets/`: `lcd_display.dart`, `math_node_widget.dart`, `calc_key_button.dart`, `banner_ad_slot.dart`

## 3. 코딩 원칙
- 현재 진행 단계와 완료 기준은 항상 `MILESTONE.md`를 기준으로 삼는다.
- 일반 스마트폰, 폴더블, 태블릿 등 다양한 화면비에서도 키패드 비율이 깨지지 않도록 반응형으로 설계한다.
- M1 단계부터 하단 배너 광고 슬롯 높이(`50dp~60dp`)를 미리 확보하여 추후 광고 연동 시 키패드 레이아웃이 찌그러지지 않게 한다.
- 기본 연산 시 부동소수점 오차(`0.1 + 0.2`) 방지를 위해 일반 `double` 대신 `Decimal`을 사용한다.
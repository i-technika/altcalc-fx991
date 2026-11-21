# 개발 마일스톤 (Development Milestones)

## [ ] M1: UI 셸, 50개 키패드 및 광고 슬롯 레이아웃 구축
- [ ] `pubspec.yaml`에 `flutter_riverpod`, `decimal`, `shared_preferences` 패키지 추가
- [ ] `CalcKeyButton` 커스텀 버튼 위젯 구현 (메인 라벨 + 금색 SHIFT 라벨 + 빨간색 ALPHA 라벨 + 햅틱 진동 피드백)
- [ ] fx-991EX/CW 비율에 맞춘 50개 키패드 그리드 레이아웃(`CalculatorScreen`) 구성
- [ ] 상단 LCD 화면 프레임 및 상태 표시줄(`S`, `A`, `DEG/RAD/GRAD`, `MATH`) 구현
- [ ] 최하단 배너 광고 슬롯(`50dp~60dp`) 및 상단 안전 여백(`8dp~12dp`) 예약 배치
- [ ] 1회성 `SHIFT` / `ALPHA` 모디파이어 상태 머신 구현

## [ ] M2: 2D 수식 AST 및 커서 내비게이션 엔진
- [ ] 수식 AST 모델 정의 (`NumberNode`, `OperatorNode`, `FractionNode`, `SqrtNode`, `PowerNode`, `ParenNode`, `CursorNode`)
- [ ] 트리 깊이(depth)에 따라 폰트 크기가 자동 축소되는 재귀 위젯 렌더러(`MathNodeWidget`) 구현
- [ ] 방향키(`◀`, `▶`, `▲`, `▼`) 및 삭제(`DEL`, `AC`) 커서 탐색 로직(`CursorNavigator`) 구현

## [ ] M3: 코어 공학 연산 엔진 (`COMP` 모드)
- [ ] `Decimal` 기반 실물 동일 정밀도(내부 15자리, 표시 10자리) `AstEvaluator` 구현
- [ ] `DEG`/`RAD`/`GRAD` 각도 단위와 연동되는 삼각함수, 역삼각함수, 쌍곡선함수, 로그함수 구현
- [ ] 메모리 변수(`A~F`, `X`, `Y`, `M`, `Ans`) 저장/호출 및 `S⇔D`(분수/소수 변환) 토글 구현

## [ ] M4: 수치해석 모듈 (`SOLVE` 및 미적분)
- [ ] 정적분($\int_a^b$), 미분($\frac{d}{dx}$), 시그마($\sum$) 전용 2D 수식 템플릿 노드 추가
- [ ] 가우스-크론로드 구적법(정적분), 중심차분법(수치미분), 뉴턴-랩슨법(`SOLVE`) 알고리즘 구현

## [ ] M5: 특수 연산 모드 확장 (`MODE` 메뉴)
- [ ] 계산 모드 선택 오버레이 화면 구현 (`COMP`, `CMPLX`, `EQN`, `MATRIX`, `VECTOR`, `BASE-N`)
- [ ] 복소수 연산/극좌표 변환, 2~4원 연립·다항방정식 풀이, 행렬/벡터 연산, 진법 변환 구현

## [ ] M6: AdMob 배너, 서버리스 인앱결제 및 출시 QA
- [ ] `google_mobile_ads` 하단 적응형 배너 광고 연동
- [ ] `in_app_purchase` 비소모성 상품(`remove_ads`) 결제 + 로컬 캐싱 + 앱 실행 시 자동 구매 복원 + 명시적 '구매 복원' 버튼 구현
- [ ] 실물 fx-991EX/CW 계산기와 주요 수식 테스트 케이스 100종 대조 검증 및 스토어 빌드 생성
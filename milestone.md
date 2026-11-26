# 개발 마일스톤 (Development Milestones)

## [ ] M1: UI 셸, 50개 키패드 및 광고 슬롯 레이아웃 구축
- [ ] `pubspec.yaml`에 `flutter_riverpod`, `decimal`, `shared_preferences` 패키지 추가
- [ ] `CalcKeyButton` 커스텀 버튼 위젯 구현 (메인 라벨 + 금색 SHIFT 라벨 + 빨간색 ALPHA 라벨 + 햅틱 진동 피드백)
- [ ] fx-991EX/CW 비율에 맞춘 50개 키패드 그리드 레이아웃(`CalculatorScreen`) 구성
- [ ] 상단 LCD 화면 프레임 및 상태 표시줄(`S`, `A`, `D/R/G`, `√◻` 등 — #44) 구현
- [ ] 광고 없는(과금 기준) 화면 배치 — 맨 아래 광고 슬롯 없이 화면을 다 채움(#141), 가로형·접힘선 배치(#142~#144)
- [ ] 1회성 `SHIFT` / `ALPHA` 모디파이어 상태 머신 구현

## [ ] M2: 2D 수식 AST 및 커서 내비게이션 엔진
- [ ] 수식 AST 모델 정의 (`NumberNode`, `OperatorNode`, `FractionNode`, `SqrtNode`, `PowerNode`, `ParenNode`, `CursorNode`)
- [ ] 트리 깊이(depth)에 따라 폰트 크기가 자동 축소되는 재귀 위젯 렌더러(`MathNodeWidget`) 구현
- [ ] 방향키(`◄`, `►`, `▲`, `▼`) 및 삭제(`DEL`, `AC`) 커서 탐색 로직(`CursorNavigator`) 구현

## [ ] M3: 코어 공학 연산 엔진 (`COMP` 모드)
- [ ] `Decimal` 기반 실물 동일 정밀도(내부 15자리, 표시 10자리) `AstEvaluator` 구현
- [ ] `DEG`/`RAD`/`GRAD` 각도 단위와 연동되는 삼각함수, 역삼각함수, 쌍곡선함수, 로그함수 구현
- [ ] 메모리 변수(`A~F`, `x`, `y`, `M`, `Ans`) 저장/호출 및 `S⇔D`(분수/소수 변환) 토글 구현

## [ ] M4: 수치해석 모듈 (`SOLVE` 및 미적분)
- [ ] 정적분($\int_a^b$), 미분($\frac{d}{dx}$), 시그마($\sum$) 전용 2D 수식 템플릿 노드 추가
- [ ] 가우스-크론로드 구적법(정적분), 중심차분법(수치미분), 뉴턴-랩슨법(`SOLVE`) 알고리즘 구현

## [ ] M5: 특수 연산 모드 확장 (`MODE` 메뉴)
- [ ] MENU 아이콘 메뉴 구현 — v1.0 앱 9개: `Calculate`, `Complex`, `Base-N`, `Matrix`, `Vector`, `Equation/Func`, `Table`, `Inequality`, `Ratio`
- [ ] 복소수 연산/극좌표 변환, 2~4원 연립·다항방정식 풀이, 행렬/벡터 연산, 진법 변환 구현
- [ ] 함수 값 표(`Table`, f(x)·g(x)), 4차까지 다항 부등식(`Inequality`), 비례식(`Ratio`) 구현

## [ ] M6: AdMob 배너, 서버리스 인앱결제 및 출시 QA (v1.0)
- [ ] `google_mobile_ads` 배너 광고 연동 — 무과금 배치에서 LCD 쪽(화면 맨 위·기록 영역)에 넣는다 (#18)
- [ ] `in_app_purchase` 비소모성 상품(`remove_ads`) 결제 + 로컬 캐싱 + 앱 실행 시 자동 구매 복원 + 명시적 '구매 복원' 버튼 구현
- [ ] 실물 fx-991EX/CW 계산기와 주요 수식 테스트 케이스 100종 대조 검증 및 스토어 빌드 생성
- [ ] M1~M5에서 넘긴 Android·iOS(iPhone·iPad) 실기기 점검 — 에픽 #6 "실기기 점검" 절과 그 서브이슈. 에뮬레이터·CI로 되는 확인은 그 과제가 속한 마일스톤에서 한다 (결정: #185)

## [ ] M7: 데이터 분석 앱 (`Statistics` · `Distribution` · `Spreadsheet`) — v1.1 업데이트
> v1.0(M6) 출시 후 업데이트로 제공한다. 이 마일스톤 완료로 실물과 같은 MENU 앱 12개 구성이 완성된다. (결정: #32)
- [ ] 표 형태 데이터 편집기 공용 컴포넌트 (Statistics 데이터 편집기·Spreadsheet 공용)
- [ ] `Statistics`: 1변수 통계 13종, 회귀 분석(선형·2차·로그·지수·거듭제곱 등)
- [ ] `Distribution`: 정규·역정규·이항·푸아송 확률/누적 분포 (특수함수 10자리 정확도)
- [ ] `Spreadsheet`: 5열×45행, 수식·상대/절대 셀 참조·채우기·잘라내기/복사/붙여넣기·자동 재계산
- [ ] MENU에 데이터 앱 3종 추가 및 실물 대조 검증

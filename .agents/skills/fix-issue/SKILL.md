---
name: fix-issue
description: >-
  이슈 번호를 받아 마일스톤 이슈와 서브이슈를 구분하여 자동 처리합니다.
  마일스톤 이슈는 main에서 브랜치 및 PR을 생성하며,
  서브이슈는 코딩, 브랜치 생성, PR 작성, 2단계 적대적 코드리뷰, 수정, 후속 이슈 문의, 커밋까지 일괄 처리합니다.
  사용자가 `/fix-issue <번호>` 또는 `fix-issue <번호>`를 입력하거나 특정 이슈 해결을 요청할 때 사용합니다.
---

# 이슈 처리 및 적대적 코드리뷰 자동화 워크플로우 (`/fix-issue <번호>`)

이 스킬은 GitHub 이슈를 처리할 때 엄격한 품질 보증 및 표준 프로세스를 준수하기 위한 절차를 정의합니다.
명령어 형태: `/fix-issue <번호>` (예: `/fix-issue 1`, `/fix-issue 7`)

---

## 🔀 분기 기준: 마일스톤 이슈 vs 서브이슈

이슈 번호 조회 시 라벨(`labels`)과 제목을 확인하여 두 가지 모드 중 하나로 자동 분기합니다:

- **모드 A: 마일스톤 이슈 (`milestone` 라벨 보유 시)**
  - `main`에서 마일스톤 통합 브랜치 생성 ➡️ 빈 커밋 추가 ➡️ 원격 푸시 ➡️ `main` 대상 PR 생성 ➡️ **코딩/리뷰 없이 즉시 종료**
- **모드 B: 일반 서브이슈 (`sub-issue` 라벨 또는 Parent 이슈 보유 시)**
  - 코딩 ➡️ 브랜치 생성 ➡️ PR 작성 ➡️ 적대적 코드리뷰 1R ➡️ 수정 ➡️ 적대적 코드리뷰 2R ➡️ 수정 ➡️ 후속 이슈 문의 ➡️ 커밋/푸시

---

## 🅰️ 모드 A: 마일스톤 이슈 처리 절차 (코딩/리뷰 불필요)

1. **이슈 정보 조회**:
   ```bash
   gh issue view <번호> --json number,title,body,labels,milestone
   ```
2. **마일스톤 브랜치 이름 결정**:
   - 예: M1 이슈(#1)인 경우 `milestone/m1`, M2(#2)인 경우 `milestone/m2`
3. **`main`에서 마일스톤 브랜치 생성 및 초기 커밋**:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b milestone/m<번호>
   git commit --allow-empty -m "chore: Initialize milestone M<번호> integration branch (#<번호>)"
   git push -u origin milestone/m<번호>
   ```
4. **마일스톤 PR 생성**:
   - **Target (Base)**: `main`
   - **Head**: `milestone/m<번호>`
   - **Title**: `<이슈 제목> (#<번호>)`
   - **Body**: 마일스톤 목표 요약 및 `Closes #<번호>` 포함
   - **Label**: `milestone`
   - **Milestone**: 해당 마일스톤 설정
   - **Project**: `AltCalc FX-991` 등록
   ```bash
   gh pr create --base main --head milestone/m<번호> --title "<이슈 제목> (#<번호>)" --body "## 마일스톤 통합 PR%0A%0ACloses #<번호>" --label "milestone" --milestone "<마일스톤 이름>" --project "AltCalc FX-991"
   ```
5. **완료 보고**: 마일스톤 PR 생성 결과(URL 및 전체 플랫폼 CI 연동 상황)를 사용자에게 보고하고 종료합니다.

---

## 🅱️ 모드 B: 서브이슈 처리 절차 (코딩 & 2단계 적대적 리뷰)

```
[1. 이슈 정보 분석]
       │
       ▼
[2. 베이스 브랜치 확인 & 작업 브랜치 생성]
       │
       ▼
[3. 코딩 & 로컬 검증 (Analyze/Test)]
       │
       ▼
[4. 1차 커밋 & 푸시]
       │
       ▼
[5. PR 생성 및 메타데이터 설정 (Label, Milestone, Project, Closes #)]
       │
       ▼
[6. 적대적 코드리뷰 1라운드] ───▶ [7. 수정 및 보완]
                                       │
       ┌───────────────────────────────┘
       ▼
[8. 적대적 코드리뷰 2라운드] ───▶ [9. 수정 및 보완]
                                       │
       ┌───────────────────────────────┘
       ▼
[10. 후속 이슈 도출 여부 점검 & 사용자 문의]
       │
       ▼
[11. 최종 커밋, 푸시 및 CI 확인]
```

---

## 1단계: 이슈 정보 분석
1. GitHub CLI로 이슈 상세 정보를 조회합니다:
   ```bash
   gh issue view <번호> --json number,title,body,labels,milestone,parent,issueType
   ```
2. 이슈의 목표, 세부 체크리스트, 상위(Parent) 에픽 이슈 및 소속 마일스톤을 파악합니다.

## 2단계: 베이스 브랜치 확인 및 작업 브랜치 생성
1. 베이스 브랜치를 결정합니다:
   - 서브이슈인 경우: 해당 마일스톤 브랜치 (예: Parent가 M1 에픽이면 `milestone/m1`)
   - 마일스톤 브랜치가 원격/로컬에 없으면 `main`에서 생성하여 원격에 푸시해 둡니다.
2. 최신 베이스 브랜치로부터 작업 브랜치를 분기합니다:
   ```bash
   git checkout <base_branch>
   git pull origin <base_branch>
   git checkout -b issue/<번호>-<간략키워드>
   ```

## 3단계: 코딩 및 로컬 검증
1. `GEMINI.md` 및 프로젝트 규칙을 엄격히 준수하여 코드를 구현합니다:
   - 한국어 주석 및 명확한 도메인 모델링
   - 고정밀도 연산 시 `Decimal` 사용 (`double` 지양)
   - 반응형 위젯 및 안전 여백 확보
2. 로컬 정적 분석 및 테스트를 수행하여 무결성을 검증합니다:
   ```bash
   flutter analyze
   flutter test
   ```

## 4단계: 1차 커밋 및 원격 푸시
1. 구현한 변경 사항을 의미 있는 커밋 메시지로 작성합니다:
   ```bash
   git add .
   git commit -m "feat/fix: <이슈 제목> (#<번호>)"
   git push -u origin issue/<번호>-<간략키워드>
   ```

## 5단계: PR 생성 및 메타데이터 연동
1. 상위 마일스톤 브랜치(`milestone/m1` 등)를 대상으로 PR을 생성합니다:
   - **제목**: `feat/fix: <이슈 제목> (#<번호>)`
   - **본문**: `Closes #<번호>` 또는 `Fixes #<번호>`를 반드시 포함하여 Development 링크 자동 연결
   - **라벨(`--label`)**: 이슈의 라벨(예: `sub-issue`) 부여
   - **마일스톤(`--milestone`)**: 해당 마일스톤 설정
   - **프로젝트(`--project`)**: `AltCalc FX-991` 프로젝트에 자동 등록
2. 명령어 예시:
   ```bash
   gh pr create --base <base_branch> --title "feat: <제목> (#<번호>)" --body "## 작업 요약%0A...%0A%0ACloses #<번호>" --label "sub-issue" --milestone "<마일스톤 이름>" --project "AltCalc FX-991"
   ```

## 6단계 & 7단계: 적대적 코드리뷰 1라운드 및 수정
1. **적대적 코드리뷰 1라운드 (Adversarial Review Round 1)**:
   - 변경 사항(`git diff <base_branch>...HEAD`)을 매우 까다롭고 회의적인 시각의 시니어 리뷰어 관점에서 심층 검토합니다.
   - **점검 항목**:
     - 잠재적 런타임 예외 (Null Safety, Range Error, 형 변환 에러)
     - 부동소수점 오차 누출 여부 (`Decimal` 미사용 지점)
     - 불필요한 위젯 리빌드 및 성능 저하
     - 기기 해상도/화면비 대응 누락 (Overflow 가능성)
     - 햅틱 피드백, UI 패딩 오차
   - 발견된 취약점, 리팩토링 필요점, 엣지 케이스를 목록화하여 보고합니다.
2. **1차 수정**:
   - 지적된 사항들을 빠짐없이 코드로 보완하고 수정합니다.
   - `flutter analyze` 및 `flutter test`로 검증합니다.

## 8단계 & 9단계: 적대적 코드리뷰 2라운드 및 수정
1. **적대적 코드리뷰 2라운드 (Adversarial Review Round 2)**:
   - 1차 수정으로 인해 발생할 수 있는 부작용(Regression) 및 미처 발견하지 못한 숨은 엣지 케이스를 재검토합니다.
   - 테스트 코드가 충분한 케이스를 검증하는지 확인합니다.
2. **2차 수정**:
   - 2차 리뷰에서 발견된 잔여 이슈를 최종 수정하고 정적 분석/테스트를 완벽히 통과시킵니다.

## 10단계: 후속 이슈 도출 여부 점검 및 사용자 문의
1. 코딩 및 2차례의 적대적 리뷰 과정에서 **현재 이슈 범위를 넘어서는 추가 개선점, 리팩토링 과제, 신규 요구사항**이 발견되었는지 점검합니다.
2. 발견된 사항이 있을 경우 **사용자에게 이슈 생성 여부를 구체적으로 문의**합니다:
   > "작업 및 리뷰 과정에서 다음과 같은 후속 작업이 식별되었습니다:
   > 1. [제안 내용 1]
   > 해당 내용을 후속 이슈로 등록할까요?"
3. 사용자가 승인하면 아래 표준 메타데이터를 갖춘 신규 이슈를 자동 생성합니다:
   - `Label`: `sub-issue`
   - `Type`: `Task` / `Bug` / `Feature`
   - `Project`: `AltCalc FX-991`
   - `Milestone`: 현재 마일스톤
   - `Parent`: 현재 마일스톤 에픽 이슈

## 11단계: 최종 커밋, 푸시 및 CI 확인
1. 1차/2차 수정 내용을 모두 커밋하고 푸시합니다:
   ```bash
   git add .
   git commit -m "refactor: Address adversarial code review feedback (R1 & R2) for #<번호>"
   git push
   ```
2. 서브이슈 PR의 **Linux CI** 동작 상태를 점검하고 최종 완료 보고를 수행합니다.

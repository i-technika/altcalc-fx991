---
name: open-ms
description: >-
  마일스톤 에픽 번호를 받아 main 브랜치를 베이스로 마일스톤 브랜치를 분기하고, 마일스톤 PR(Draft)을 생성하여 라벨, 프로젝트, 마일스톤, Development를 연결합니다.
  사용자가 `/open-ms <번호>` 또는 `open-ms <번호>`를 입력할 때 사용합니다.
---

# 마일스톤 착수 및 PR 생성 스킬 (`/open-ms <번호>`)

이 스킬은 새로운 마일스톤을 시작할 때 `main` 브랜치로부터 마일스톤 전용 통합 브랜치를 분기하고, 마일스톤 통합 PR(Draft)을 생성하여 이슈 및 프로젝트 메타데이터를 연결하는 역할을 담당합니다.

명령어 형태: `/open-ms <번호>` (예: `/open-ms 1`)

---

## 🔄 처리 순서

```
[1. 마일스톤 이슈 정보 확인]
       │
       ▼
[2. main 최신화 및 마일스톤 브랜치 생성 (milestone/m<번호>)]
       │
       ▼
[3. 초기 빈 커밋 생성 & 원격 푸시]
       │
       ▼
[4. 마일스톤 PR(Draft) 생성 및 메타데이터 연결]
    - Base: main / Head: milestone/m<번호>
    - Label: milestone
    - Milestone: 해당 마일스톤
    - Project: AltCalc FX-991
    - Development 연결: Closes #<번호>
    - Draft 모드 (마일스톤 CI 미수행)
       │
       ▼
[5. 프로젝트 보드 상태를 In Progress로 갱신]
       │
       ▼
[6. 완료 보고 및 서브이슈 안내]
```

---

## 세부 단계별 지침

### 1단계: 마일스톤 이슈 확인
1. GitHub CLI로 이슈 정보를 확인합니다:
   ```bash
   gh issue view <번호> --json number,title,labels,milestone
   ```
2. 라벨에 `milestone`이 포함되어 있는지 확인합니다. 만약 일반 서브이슈 번호인 경우:
   > ⚠️ "이슈 #<번호>는 마일스톤 에픽 이슈가 아닙니다. `/open-ms`는 마일스톤 에픽 이슈 번호(예: #1)를 지정해야 합니다."
   메시지를 출력하고 중단합니다.

### 2단계: main 베이스로 마일스톤 브랜치 생성
1. 로컬의 변경사항이 없는지(`git status`) 확인합니다.
2. `main` 브랜치를 최신으로 갱신하고 새 마일스톤 브랜치를 분기합니다:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b milestone/m<번호>
   ```

### 3단계: 초기 커밋 생성 및 원격 푸시
1. 마일스톤 PR 생성을 위한 초기 빈 커밋을 생성하고 원격에 푸시합니다:
   ```bash
   git commit --allow-empty -m "chore: Open milestone M<번호> (#<번호>)"
   git push -u origin milestone/m<번호>
   ```

### 4단계: 마일스톤 PR(Draft) 생성 및 메타데이터 연결
1. `main` 브랜치를 타겟으로 마일스톤 PR을 생성합니다:
   - **Base**: `main`
   - **Head**: `milestone/m<번호>`
   - **Draft**: `--draft` (서브이슈 개발 단계 중 불필요한 마일스톤 전체 CI 실행 방지)
   - **Title**: `[M<번호>] <이슈 제목> (#<번호>)`
   - **Body**: 마일스톤 목표 및 `Closes #<번호>` 포함 (GitHub Development 섹션 자동 연결)
   - **Label**: `milestone`
   - **Milestone**: 해당 마일스톤 지정
   - **Project**: `AltCalc FX-991` 지정
   ```bash
   gh pr create --base main --head milestone/m<번호> \
     --title "[M<번호>] <이슈 제목> (#<번호>)" \
     --body "## 마일스톤 통합 PR%0A%0AM<번호> 마일스톤의 세부 서브이슈들을 통합하는 PR입니다.%0A%0ACloses #<번호>" \
     --label "milestone" \
     --milestone "<마일스톤 이름>" \
     --project "AltCalc FX-991" \
     --draft
   ```

### 5단계: 프로젝트 보드 상태 업데이트
1. GitHub Project #7(AltCalc FX-991)에서 해당 마일스톤 이슈의 Status를 `In Progress`로 설정합니다:
   ```bash
   gh project item-edit 7 --owner i-technika --url "https://github.com/i-technika/altcalc-fx991/issues/<번호>" --field "Status" --value "In Progress"
   ```

### 6단계: 완료 보고
1. 마일스톤 브랜치 및 연결된 PR URL을 사용자에게 보고하고, 서브이슈 개발(`/fix-issue`) 착수 가능 상태임을 안내합니다.

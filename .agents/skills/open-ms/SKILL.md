---
name: open-ms
description: >-
  마일스톤 에픽 번호를 받아 main 브랜치를 베이스로 마일스톤 브랜치를 분기하고 원격에 푸시합니다.
  별도의 CI는 수행하지 않으며 프로젝트 보드 상태를 갱신합니다.
  사용자가 `/open-ms <번호>` 또는 `open-ms <번호>`를 입력할 때 사용합니다.
---

# 마일스톤 착수 및 브랜치 생성 스킬 (`/open-ms <번호>`)

이 스킬은 새로운 마일스톤을 시작할 때 `main` 브랜치로부터 마일스톤 전용 통합 브랜치를 분기하고 원격에 설정하는 역할을 담당합니다.

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
[3. 초기 빈 커밋 생성 & 원격 푸시 (CI 미수행)]
       │
       ▼
[4. 프로젝트 보드 상태를 In Progress로 갱신]
       │
       ▼
[5. 완료 보고 및 서브이슈 안내]
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
1. 브랜치 존재를 명확히 하기 위해 초기 빈 커밋을 생성하고 원격에 푸시합니다:
   ```bash
   git commit --allow-empty -m "chore: Open milestone M<번호> (#<번호>)"
   git push -u origin milestone/m<번호>
   ```
   > 💡 마일스톤 브랜치 자체 푸시 시에는 CI가 트리거되지 않습니다.

### 4단계: 프로젝트 보드 상태 업데이트
1. GitHub Project #7(AltCalc FX-991)에서 해당 마일스톤 이슈의 Status를 `In Progress`로 설정합니다:
   ```bash
   gh project item-edit 7 --owner i-technika --url "https://github.com/i-technika/altcalc-fx991/issues/<번호>" --field "Status" --value "In Progress"
   ```

### 5단계: 완료 보고
1. 마일스톤 브랜치 생성 완료 및 서브이슈 개발 착수 가능 상태임을 사용자에게 보고합니다.

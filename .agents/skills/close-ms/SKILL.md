---
name: close-ms
description: >-
  마일스톤 번호를 받아 기존 마일스톤 PR을 Ready 상태로 전환하고, 플러터 멀티플랫폼 전체 CI를 수행/검증한 뒤 main에 머지하고 마일스톤을 닫습니다.
  사용자가 `/close-ms <번호>` 또는 `close-ms <번호>`를 입력할 때 사용합니다.
---

# 마일스톤 완료 및 main 머지 스킬 (`/close-ms <번호>`)

이 스킬은 마일스톤 하위의 모든 서브이슈가 완료된 후, `/open-ms`로 열어두었던 마일스톤 PR을 Ready for review 상태로 전환하여 전체 멀티플랫폼 CI를 수행하고, 성공 검증 후 `main`에 최종 머지하는 절차를 수행합니다.

명령어 형태: `/close-ms <번호>` (예: `/close-ms 1`)

---

## 🔄 처리 순서

```
[1. 마일스톤 및 서브이슈 완료 상태 확인]
       │
       ▼
[2. 기존 마일스톤 PR 조회 및 Ready 상태 전환 (gh pr ready)]
       │
       ▼
[3. 마일스톤 전체 플랫폼 CI 수행 및 통과 대기 (gh pr checks)]
       │
       ▼
[4. main 브랜치로 머지 (Merge/Squash)]
       │
       ▼
[5. 마일스톤 이슈 Close 및 프로젝트 보드 Done 갱신]
       │
       ▼
[6. 로컬 main 최신화 및 완료 보고]
```

---

## 세부 단계별 지침

### 1단계: 마일스톤 완료 상태 점검
1. GitHub CLI로 마일스톤 이슈 및 하위 서브이슈들의 상태를 확인합니다:
   ```bash
   gh issue view <번호> --json number,title,labels,subIssues,milestone
   ```
2. 모든 하위 서브이슈가 `CLOSED` 상태인지 검증합니다. 아직 열려 있는 서브이슈가 있다면 사용자에게 알리고 진행 여부를 확인합니다.

### 2단계: 기존 마일스톤 PR 조회 및 Ready 상태 전환
1. `milestone/m<번호>` 브랜치에 대응하는 마일스톤 PR을 조회합니다:
   ```bash
   gh pr list --head milestone/m<번호> --json number,url,isDraft
   ```
2. Draft 상태인 마일스톤 PR을 Ready 상태로 전환하여 전체 멀티플랫폼 CI를 트리거합니다:
   ```bash
   gh pr ready <PR번호>
   ```

### 3단계: 마일스톤 전체 플랫폼 CI 수행 및 검증
1. `.github/workflows/milestone-full-ci.yml` 파이프라인이 구동됩니다.
2. `gh pr checks <PR번호>` 명령어로 멀티플랫폼 빌드 결과들을 모니터링합니다:
   - `Code Quality & Linux Build`
   - `Android Build`
   - `Web Build`
   - `Windows Build`
   - `macOS & iOS Build`
3. 모든 CI Job이 성공(Pass)으로 완료되었음을 확인합니다.

### 4단계: main 브랜치로 머지
1. CI가 모두 통과하면 PR을 `main`에 머지합니다:
   ```bash
   gh pr merge <PR번호> --merge --delete-branch
   ```

### 5단계: 이슈 Close 및 프로젝트 보드 Done 갱신
1. PR 머지와 함께 마일스톤 에픽 이슈가 자동으로 Closed 되었는지 확인합니다.
2. GitHub Project #7(AltCalc FX-991)에서 해당 마일스톤 이슈의 Status를 `Done`으로 갱신합니다:
   ```bash
   gh project item-edit 7 --owner i-technika --url "https://github.com/i-technika/altcalc-fx991/issues/<번호>" --field "Status" --value "Done"
   ```

### 6단계: 로컬 환경 동기화 및 완료 보고
1. 로컬 `main` 브랜치를 최신으로 갱신합니다:
   ```bash
   git checkout main
   git pull origin main
   ```
2. 마일스톤이 성공적으로 완료되었음을 사용자에게 보고하고 다음 마일스톤 착수 준비를 안내합니다.

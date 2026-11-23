---
name: open-ms
description: >-
  마일스톤 에픽 이슈 번호를 받아 main에서 milestone/m<N> 브랜치를 분기하고, 마일스톤 통합 Draft PR을 생성해
  라벨·마일스톤·프로젝트·Development(Closes)를 연결한 뒤 프로젝트 보드를 In Progress로 갱신한다.
  사용자가 `/open-ms <번호>`를 입력하거나 "마일스톤 M2 시작해줘"처럼 새 마일스톤 착수를 요청할 때 사용한다.
argument-hint: <마일스톤 에픽 이슈 번호>
---

# 마일스톤 착수 (`/open-ms <번호>`)

입력: `$ARGUMENTS` = 마일스톤 에픽 이슈 번호 (예: `1` → M1)

> 규칙의 기준은 [CLAUDE.md](../../../CLAUDE.md)이다. 명령은 Bash 도구로 실행한다.
> `gh`에 여러 줄 본문을 넘길 때는 스크래치패드에 파일을 만들고 `--body-file`을 사용한다.

## 1. 에픽 이슈 검증
```bash
gh issue view <번호> --json number,title,body,labels,milestone,state,subIssues
```
- `labels`에 `milestone`이 없으면 중단하고 안내한다:
  > ⚠️ 이슈 #<번호>는 마일스톤 에픽 이슈가 아닙니다. `/open-ms`에는 에픽 번호(예: #1)를 지정해 주세요. 서브이슈는 `/fix-issue`를 사용합니다.
- 이미 `milestone/m<번호>` 브랜치나 열린 마일스톤 PR이 있으면(`gh pr list --head milestone/m<번호>`) 새로 만들지 말고 현황만 보고한다.
  이때도 담당자는 맞춰 둔다: `gh issue edit <번호> --add-assignee i-technika`, `gh pr edit <PR번호> --add-assignee i-technika`
- 이전 마일스톤이 아직 `main`에 머지되지 않았다면 단일 선택으로 묻는다 (마일스톤은 순차 진행이 원칙):
  "이전 마일스톤을 먼저 마무리 (Recommended)" / "그래도 새 마일스톤 착수".

## 2. 브랜치 생성
1. `git status --porcelain`으로 작업 트리가 깨끗한지 확인한다. 변경 사항이 있으면 단일 선택으로 묻는다 (CLAUDE.md "질의 규칙"):
   "변경 내용을 보여 주고 중단 (Recommended)" / "stash 후 진행" / "그대로 둔 채 진행".
   생성 플러그인 파일만 `M`이고 `git diff`가 비어 있다면 줄바꿈 차이일 뿐이므로 CLAUDE.md "로컬 개발 환경 메모"의 절차로 정리한다 (#67).
2. ```bash
   git checkout main && git pull --ff-only origin main
   git checkout -b milestone/m<번호>
   git commit --allow-empty -m "chore: Open milestone M<번호> (#<번호>)"
   git push -u origin milestone/m<번호>
   ```

## 3. CI 액션 새 릴리스 점검 (#88)
CI 워크플로의 액션은 커밋 SHA로 고정돼 있어 저절로 올라가지 않는다. 마일스톤을 시작할 때마다 새 마일스톤 브랜치에서
새 릴리스와 보안 권고를 본다 (README "CI 액션 고정 버전 올리기"). 갱신 이슈를 4단계 PR 본문의 서브이슈 체크리스트에
처음부터 넣으려고 PR 생성보다 먼저 한다.
```bash
bash .github/scripts/action-pins.sh outdated
```
- 모두 최신이고 권고가 없으면 보고에 그렇다고만 적는다.
- 새 릴리스나 권고가 있으면 먼저 열린 서브이슈 목록(`gh issue list --label sub-issue --state open -L 300 --json number,title,milestone`)에서
  제목이 `CI 액션 고정 버전 올리기`로 시작하는 이슈를 찾는다.
  - 있으면(이전 마일스톤에서 남은 것) 새로 만들지 않는다. 그 이슈에 이번 출력을 코멘트로 남기고 이번 마일스톤으로 옮긴다:
    제목의 마일스톤 표시를 바꾸고(`gh issue edit <번호> --title "CI 액션 고정 버전 올리기 (M<번호>)" --milestone "<마일스톤 이름>"`),
    상위 에픽을 이번 에픽으로 바꾼다(GraphQL `removeSubIssue`로 옛 에픽에서 뗀 뒤 `/fix-issue` 9단계 B 블록을 다시 실행).
  - 없으면 이 마일스톤의 서브이슈 하나로 등록한다(`/fix-issue` 9단계의 A·B 블록, 타입 Task).
    제목은 `CI 액션 고정 버전 올리기 (M<번호>)`로 한다 — 버전은 넣지 않고 마일스톤을 넣는다.
    A 블록은 닫힌 이슈까지 같은 제목을 찾아 막으므로, 마일스톤마다 제목이 달라야 다음 마일스톤에서도 만들 수 있다.
    본문에 스크립트 출력과 README 절차의 링크를 넣고, 주 버전이 바뀌는 액션은 `runs.using`·릴리스 노트 확인이 필요하다고 적는다.
  - 어느 쪽이든 그 이슈를 4단계 PR 본문의 서브이슈 체크리스트에 넣는다.
- 권고가 있으면 이 마일스톤의 첫 서브이슈로 착수하라고 보고에 적는다.
- 조회가 실패하면(gh 인증·네트워크) 착수는 그대로 마치고, 보고에 실패와 함께 "첫 `/fix-issue` 전에 이 단계를 다시 돌릴 것"을 적는다.
  그때 갱신 이슈가 생기면 마일스톤 PR 본문의 체크리스트에 추가한다(`gh pr edit <PR번호> --body-file ...`).

## 4. 마일스톤 Draft PR 생성
본문 파일 예시 (`<scratchpad>/ms-pr-body.md`):
```markdown
## 마일스톤 M<번호> 통합 PR

M<번호> 마일스톤(<에픽 제목에서 [M<번호>] 제외>)의 세부 서브이슈들을 통합하는 PR입니다.

### 서브이슈
- [ ] #<서브이슈1> <제목>
- [ ] ...

Closes #<번호>
```
```bash
gh pr create --base main --head milestone/m<번호> --draft \
  --title "<에픽 제목> (#<번호>)" \
  --body-file "<scratchpad>/ms-pr-body.md" \
  --label milestone --milestone "<마일스톤 이름>" --project "AltCalc FX-991" \
  --assignee i-technika
```
- Draft로 유지해야 서브이슈 개발 중 `Milestone Full Multi-Platform CI`가 돌지 않는다.

## 5. 담당자·프로젝트 보드 갱신
```bash
gh issue edit <번호> --add-assignee i-technika   # 착수한 에픽의 담당자 (서브이슈는 /fix-issue 착수 시 지정)
bash .claude/scripts/set-project-status.sh <번호> "In Progress"
bash .claude/scripts/set-project-status.sh <PR번호> "In Progress"
```

## 6. 완료 보고
- 브랜치명, PR URL, 서브이슈 목록(번호·제목·상태), 3단계 점검 결과를 보고하고 첫 서브이슈를 `/fix-issue <번호>`로 착수할 수 있음을 안내한다.

---
name: fix-issue
description: >-
  서브이슈 번호를 받아 브랜치 생성, 구현, 로컬 검증, PR 작성, 독립 서브에이전트를 통한 2라운드 적대적 코드리뷰와 수정,
  후속 이슈 등록, Linux CI 확인, 마일스톤 브랜치 머지, 이슈 Close 및 프로젝트 보드 Done 처리까지 일괄 수행한다.
  마일스톤 에픽 이슈 번호가 들어오면 거절한다. 사용자가 `/fix-issue <번호>`를 입력하거나 "8번 이슈 진행해줘"처럼
  특정 서브이슈 작업을 요청할 때 사용한다.
argument-hint: <서브이슈 번호>
---

# 서브이슈 처리 + 2라운드 적대적 코드리뷰 (`/fix-issue <번호>`)

입력: `$ARGUMENTS` = 서브이슈 번호 (예: `8`)

> 규칙의 기준은 [CLAUDE.md](../../../CLAUDE.md)이다. 명령은 Bash 도구로 실행하고,
> `flutter`가 없으면 `export PATH="/c/Users/fmthead/develop/flutter/bin:$PATH"`를 앞에 붙인다.
> `gh`에 여러 줄 본문을 넘길 때는 스크래치패드 파일 + `--body-file`을 사용한다.

## 🚫 거절 규칙
- 이슈에 `milestone` 라벨이 있으면 즉시 중단:
  > ⚠️ 이슈 #<번호>는 마일스톤 에픽 이슈이므로 `/fix-issue`로 수행할 수 없습니다. 마일스톤 착수는 `/open-ms <번호>`, 개발은 서브이슈 번호를 지정해 주세요.
- 이슈가 이미 `CLOSED`면 현황만 보고하고 재작업 여부를 묻는다 (단일 선택 질의, CLAUDE.md "질의 규칙").

## 진행 순서
```
1 이슈 분석 → 2 브랜치 → 3 구현·검증 → 4 커밋·PR → 5 리뷰 R1 → 6 수정 → 7 리뷰 R2 → 8 수정
→ 9 후속 이슈 등록 → 10 CI 확인 → 11 머지·Close·보드 Done → 12 보고
```
TodoWrite 등으로 단계를 추적하고, 각 단계 완료 시 짧게 진행 상황을 알린다.

### 1. 이슈 분석
```bash
gh issue view <번호> --json number,title,body,labels,milestone,parent,state,issueType
```
- 마일스톤의 M 번호 N은 `milestone.title`의 `M<N>:`(또는 상위 에픽 제목의 `[M<N>]`)에서 읽고 베이스 브랜치 `milestone/m<N>`을 확인한다.
  에픽 번호(`parent.number`)나 `milestone.number`는 M 번호와 다르다(CLAUDE.md "마일스톤 대응 표" — 예: 에픽 #6 = M8, 브랜치 `milestone/m8`).
- 같은 마일스톤의 다른 서브이슈 본문도 훑어 **이번 이슈의 범위 경계**를 파악한다(다음 이슈의 일을 미리 하지 않는다).
- 원격/로컬에 이미 `issue/<번호>-*` 브랜치나 미커밋 작업물(이전 에이전트의 WIP 등)이 있으면 내용을 검토해 재사용 여부를 판단한다.
- **M1~M7 이슈 본문에 실기기 확인 항목이 있으면**(예: "실기기 태블릿에서 잰다", "iPhone에서 확인") 이 이슈에서 하지 않는다 (#185).
  M 구분은 위의 N(마일스톤 제목)으로 한다. M8 이슈(출시 QA 마일스톤 전체)와 M9~ 이슈의 실기기 항목은 그 이슈에서 한다.
  - "실기기"가 휴대폰·태블릿 기기를 뜻하는지 문맥으로 가린다 — 옛 주석·이슈에는 실물 fx-991EX 계산기를 "실기기"라고 쓴 곳이 있다(실물 대조는 실기기 확인이 아니다).
  - "실기기나 에뮬레이터에서"처럼 둘 중 하나로 되는 항목은 에뮬레이터로 하고, 실기기로만 남는 부분이 있을 때만 나눈다.
  - 먼저 겹치는 M8 이슈를 찾는다: 에픽 #6 서브이슈(`gh issue view 6 --json subIssues --jq '.subIssues.nodes[] | "\(.number)\t\(.state)\t\(.title)"'`)와
    이 이슈의 코멘트·본문에 적힌 분기 번호. 있으면 새로 만들지 않고 그 이슈에 코멘트로 보탠다. 없을 때만 9단계 규칙대로 A·B 블록으로 만든다.
  - 원래 이슈 본문의 그 항목은 체크박스를 없애고 `- ~~원래 항목~~ → 실기기 분기: #N (M8)`으로 바꾼다
    (`gh issue view <번호> --json body -q .body` → 파일 수정 → `gh issue edit <번호> --body-file ...`). 12단계 보고에 적는다.
- 담당자 지정: `gh issue edit <번호> --add-assignee i-technika` (이미 지정돼 있으면 그대로 둔다)
- 프로젝트 보드: `bash .claude/scripts/set-project-status.sh <번호> "In Progress"`

### 2. 브랜치 생성
```bash
git checkout milestone/m<N> && git pull --ff-only origin milestone/m<N>
git checkout -b issue/<번호>-<영문-키워드>
```
- 미커밋 WIP 파일이 있으면 브랜치 전환 시 그대로 따라오는지 확인한다(추적되지 않은 파일은 따라온다).
- 생성 플러그인 파일이 `M`이라 전환이 막히면, `git diff`가 비어 있는지(줄바꿈 차이뿐인지) 보고 CLAUDE.md "로컬 개발 환경 메모"의 절차로 정리한다 (#67).
  `git checkout -- linux macos windows`처럼 플랫폼 폴더 전체를 되돌리지 않는다.

### 3. 구현 및 로컬 검증
- CLAUDE.md 규칙 준수: 한국어 주석, `material_ui` import, `Decimal` 사용, 반응형, 광고 배치 규칙(광고 없는 배치가 기준 — #141·#18).
- 이슈 체크리스트의 산출물을 모두 만든다. 상수/명세 데이터에는 불변식 테스트를 추가한다.
- ```bash
  flutter analyze   # No issues found! 이어야 함
  flutter test      # All tests passed! 이어야 함
  ```
- `android/`의 Kotlin·Gradle 설정을 바꿨으면 Android 단위 테스트도 통과시킨다 (Java 21 이상 — README "Android 단위 테스트"):
  ```bash
  flutter build apk --debug --config-only          # 래퍼(저장소에 없다)를 만들고 local.properties를 지금 SDK로 맞춘다
  (cd android && ./gradlew :app:testDebugUnitTest) # "Android 단위 테스트: SUCCESS" 이어야 함
  ```

### 4. 커밋·푸시·PR
```bash
git add <변경 파일들>   # git add . 대신 명시적으로
git commit -m "feat: <이슈 제목 요약> (#<번호>)"
git push -u origin issue/<번호>-<키워드>
```
PR 본문 파일(`<scratchpad>/pr-<번호>.md`):
```markdown
## 작업 요약
- ...

## 변경 파일
- `path` — 설명

## 검증
- `flutter analyze`: No issues found
- `flutter test`: N개 통과

## 적대적 코드리뷰
- R1: (리뷰 후 갱신)
- R2: (리뷰 후 갱신)

Closes #<번호>
```
```bash
gh pr create --base milestone/m<N> --head issue/<번호>-<키워드> \
  --title "<이슈 제목 그대로> (#<번호>)" \
  --body-file "<scratchpad>/pr-<번호>.md" \
  --label sub-issue --milestone "<마일스톤 이름>" --project "AltCalc FX-991" \
  --assignee i-technika
```
- 이 브랜치의 PR이 이미 있으면(이전 작업 재사용) 새로 만들지 않고 담당자만 붙인다: `gh pr edit <PR> --add-assignee i-technika`

### 5. 적대적 코드리뷰 R1 (독립 서브에이전트)
- 구현자의 편향을 피하기 위해 **새 컨텍스트의 `general-purpose` 서브에이전트**에게 리뷰를 맡긴다. 프롬프트에 포함할 것:
  - 이슈 번호·목표·체크리스트, 베이스 브랜치, `git diff milestone/m<N>...HEAD`로 diff를 직접 보라는 지시
  - 역할: "이 변경을 머지시키지 않으려는 회의적인 시니어 리뷰어. 칭찬 없이 결함만, 심각도(Critical/Major/Minor)와 파일:라인, 근거, 수정안 제시"
  - 점검 항목: 이슈 요구사항 충족 여부, 도메인 정확성(실제 fx-991EX 동작/배열), Null Safety, 예외 처리, `Decimal` 준수,
    반응형 오버플로우, 불필요한 리빌드, 햅틱 누락, 테스트 누락·허술한 테스트, 다음 서브이슈와의 인터페이스 적합성, CLAUDE.md 위반
  - "코드를 수정하지 말고 보고만 할 것"
- 결과를 검토해 타당한 지적과 기각할 지적(근거 포함)을 구분한다. 리뷰 결과를 PR 코멘트로 남긴다:
  `gh pr comment <PR> --body-file <scratchpad>/review-r1.md`

### 6. R1 수정
- 타당한 지적을 모두 반영하고 `flutter analyze && flutter test` 통과 후 커밋:
  `refactor: Address adversarial review R1 for #<번호>`

### 7. 적대적 코드리뷰 R2 (새 서브에이전트)
- R1과 **다른 새 서브에이전트**에게 R1 지적 목록과 수정 커밋을 알려주고, 회귀·미반영·새 엣지 케이스를 검토시킨다.
- 결과를 PR 코멘트로 남긴다 (`review-r2.md`).

### 8. R2 수정
- 반영 후 검증·커밋: `refactor: Address adversarial review R2 for #<번호>` → `git push`
- PR 본문의 "적대적 코드리뷰" 섹션을 실제 결과로 갱신한다 (`gh pr edit <PR> --body-file ...`).

### 9. 후속 이슈 등록 (사용자에게 묻지 않고 직접 판단)
- 구현·리뷰 중 이번 범위 밖으로 미룬 개선점/리팩토링/검증 과제를 정리하고, **등록할 항목을 Claude가 직접 고른다**
  (CLAUDE.md "질의 규칙" — 여러 개를 고르는 체크박스 질의는 하지 않는다).
  - 먼저 경계: **이번 이슈 범위 안의 결함은 미루지 않고 이번 PR에서 고친다.** 후속 이슈는 범위 밖의 일만 대상이다.
  - 등록: 범위 밖의 실제 결함, 누락된 검증, 실기기·실물 확인처럼 나중에 누군가 해야 하는 일.
    리팩토링·개선은 **구체적인 재현 근거나 측정 근거**(깨지는 입력, 수치, 중복 코드 위치 등)가 있을 때만 등록한다.
  - 등록하지 않음: 이번 PR에서 이미 고친 것, 근거가 약한 취향 수준 지적, 기존 이슈와 겹치는 것(기존 이슈에 코멘트로 보탬).
    겹침 확인은 검색이 아니라 열린 서브이슈 전체 목록으로 한다(다른 마일스톤 포함 — 한국어 제목은 검색 색인으로 잘 찾아지지 않는다):
    `gh issue list --label sub-issue --state open -L 300 --json number,title,milestone`
  - 12단계 보고에 등록한 것·등록하지 않은 것과 각각의 이유를 적는다.
- 제목에는 순번 접두사(`[M<N>-<순번>]`)를 붙이지 않는다 — 이슈 번호·마일스톤·상위 에픽으로 식별한다.
- **마일스톤 기준**: `<마일스톤 이름>`·`<에픽번호>`는 지금 작업 중인 마일스톤이 아니라 **그 후속 이슈가 속할 마일스톤** 기준이다
  (실물 대조 등 다른 마일스톤 과제는 그 마일스톤과 에픽으로 만든다 — 에픽·마일스톤 번호는 CLAUDE.md "마일스톤 대응 표"에서 찾는다.
  예: M3 과제면 M3 마일스톤·에픽 #3, M6 앱 설정 과제면 M6 마일스톤(GitHub 번호 8)·에픽 #191 — 에픽 #6이 아니다).
  - **실기기 확인은 M8**(CLAUDE.md "브랜치/PR 규칙", #185): M1~M7 과제에서 Android·iOS(iPhone·iPad) 실기기가 있어야 하는
    확인은 M8 출시 QA 마일스톤·에픽 #6으로 만든다. M8 이후 마일스톤(M9~)의 실기기 확인은 그 마일스톤에 둔다.
    (2026-11-27 마일스톤 재구성 전에는 이 마일스톤이 M6였다. 그 무렵의 이슈·코멘트에 적힌 "M6 실기기"는 지금의 M8이다.)
    M1~M7로 정한 근거: 재구성 전에는 광고·결제(지금의 M7)까지 포함한 모든 앞 마일스톤의 실기기 확인을 출시 직전 마일스톤에서 했다.
    재구성은 그 마일스톤을 M8로 옮기고 앞에 M6·M7을 끼워 넣은 것이므로 M6·M7의 실기기 확인도 M8로 간다(추론 — #185 코멘트).
    - 마일스톤 이름은 번호로 조회해 `--milestone`에 그대로 쓴다: `gh api repos/i-technika/altcalc-fx991/milestones/6 --jq .title`
      (GitHub 마일스톤 번호 6 = M8 출시 QA. 번호와 제목의 M 번호가 다르다)
    - 제목은 "… 실기기 확인 (…)" 꼴로 한다. B 블록의 `EPIC=6`이 에픽 #6 서브이슈로 연결하므로, 에픽 #6 본문에 번호 목록을 따로 쓰지 않는다
      (에픽 #6 "실기기 점검" 절이 서브이슈 목록을 가리킨다).
    - 한 과제에 에뮬레이터·CI로 되는 부분과 실기기가 있어야 하는 부분이 섞이면, 앞부분은 그 과제가 속한 마일스톤에 두고
      실기기 부분만 따로 M8 이슈로 만든다. 두 이슈 본문에 서로를 적는다 — 원래 이슈 "실기기 분기: #N (M8)", M8 이슈 "분기 원본: #M".
    - 원격 테스트 기기(Samsung Remote Test Lab 등)도 실기기다.
    - iOS 화면·동작 확인(VoiceOver·Metal 렌더링 포함)은 실기기로 본다 — 개발 PC에 Mac이 없어 iOS 시뮬레이터를 쓸 수 없다.
      CI macOS 러너로 되는 iOS 빌드 확인(`flutter build ios --no-codesign`)은 그 과제의 마일스톤에 둔다.
    - 실물 fx-991EX 계산기·사진과의 대조는 실기기 확인이 아니다. 그 과제가 속한 마일스톤에 둔다.
- 항목마다 **A 블록(생성) → B 블록(연결)** 을 각각 한 번의 Bash 호출로 실행한다 (셸 변수는 호출 사이에 남지 않으므로
  A가 출력한 번호를 B의 `NUM=`에 적는다).
  - **A는 같은 항목에 대해 "만들어지지 않았다"고 출력했을 때만 다시 실행한다.** 그 밖의 중단(생성 여부 불명 등)에서는 다시 만들지 않는다.
  - **B는 몇 번을 다시 실행해도 안전하다**(이미 된 단계는 건너뛴다). 어디서 멈췄든 B만 다시 실행해 마무리한다.

  **A 블록 — 생성**
  ```bash
  set -e
  TITLE='<제목>'   # 제목에 작은따옴표가 있으면 '\'' 로 바꿔 쓴다
  TITLE=$(printf '%s' "$TITLE" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')   # GitHub이 앞뒤 공백을 다듬어 저장하므로 미리 맞춘다
  # 이슈 목록("번호<TAB>제목"). 검색(--search)은 한국어·특수문자 제목과 색인 지연 때문에 못 찾으므로 목록에서 정확히 비교한다.
  # 조회 실패와 "목록에 없음"을 구별해야 하므로 파이프로 바로 잇지 않고 변수로 받아 상태를 확인한다(파이프는 gh 실패를 삼킨다).
  rows() { gh issue list --state all -L "$1" --json number,title --jq '.[] | "\(.number)\t\(.title)"'; }
  match() { printf '%s\n' "$1" | T="$TITLE" awk -F'\t' 'substr($0, length($1) + 2) == ENVIRON["T"] { print $1; exit }'; }
  # 1) 같은 제목이 이미 있으면 만들지 않는다 — 그래야 실패 뒤 "같은 제목 = 이번에 만든 이슈"로 판정할 수 있다
  ALL=$(rows 1000) || { echo "목록 조회 실패 — 아무것도 만들지 않았다. 다시 실행해도 된다"; exit 1; }
  DUP=$(match "$ALL")
  [ -z "$DUP" ] || { echo "같은 제목의 이슈 #$DUP 이 이미 있다 — 만들지 않음(그 이슈와 겹치는지 판단해 제목을 바꾸거나 그 이슈에 코멘트)"; exit 1; }
  # 2) 생성. gh는 이슈를 만든 뒤 프로젝트 추가 단계에서 실패할 수 있다 → 실패해도 다시 만들지 않고 생겼는지 확인한다
  if URL=$(gh issue create --title "$TITLE" --body-file <파일> \
      --label sub-issue --milestone "<마일스톤 이름>" --project "AltCalc FX-991"); then
    NUM=${URL##*/}
  else
    NUM=""
    for i in 1 2 3; do
      sleep 3
      RECENT=$(rows 30) || { echo "생성 여부 불명(목록 조회도 실패) — 다시 만들지 말 것. 나중에 gh issue list로 이 제목을 확인한 뒤 B 블록"; exit 1; }
      NUM=$(match "$RECENT")
      [ -z "$NUM" ] || break
    done
    [ -n "$NUM" ] || { echo "목록에 없음 — 이슈가 만들어지지 않았다. 원인을 고친 뒤 A 블록을 다시 실행해도 된다"; exit 1; }
    echo "생성은 됐고 뒤 단계(프로젝트 추가 등)가 실패함 — B 블록이 마무리한다"
  fi
  [[ $NUM =~ ^[0-9]+$ ]] || { echo "이슈 번호를 읽지 못했다: $URL — 다시 만들지 말고 gh issue list로 확인"; exit 1; }
  echo "생성: #$NUM → B 블록에 NUM=$NUM"
  ```

  **B 블록 — 프로젝트·에픽·타입 (다시 실행해도 안전)**
  ```bash
  set -e
  NUM=<A가 출력한 번호>; EPIC=<에픽번호>; TYPE=<타입 id>
  # 프로젝트 추가 — 이미 들어 있으면 그대로다(A의 실패 원인일 수 있어 항상 한 번 더 한다)
  gh issue edit "$NUM" --add-project "AltCalc FX-991" >/dev/null
  # 상위 에픽 연결 — 이미 연결돼 있으면 건너뛴다(addSubIssue는 중복 연결 시 오류)
  PARENT=$(gh issue view "$NUM" --json parent --jq '.parent.number // empty')
  ISSUE_ID=$(gh issue view "$NUM" --json id --jq .id)   # ID는 변수로 먼저 받는다 — 인자 안의 $(...) 실패는 set -e가 잡지 못한다
  if [ -z "$PARENT" ]; then
    EPIC_ID=$(gh issue view "$EPIC" --json id --jq .id)
    gh api graphql -f query='mutation($p:ID!,$c:ID!){addSubIssue(input:{issueId:$p,subIssueId:$c}){issue{number}}}' \
      -f p="$EPIC_ID" -f c="$ISSUE_ID" >/dev/null
  elif [ "$PARENT" != "$EPIC" ]; then
    echo "#$NUM 은 이미 다른 에픽 #$PARENT 에 연결돼 있다 — 확인 필요"; exit 1
  fi
  # 에픽과 마일스톤이 같은 M인지 확인 — 에픽 번호는 M 번호와 다르다(CLAUDE.md "마일스톤 대응 표")
  EPIC_M=$(gh issue view "$EPIC" --json title --jq '.title' | sed -nE 's/^\[(M[0-9]+)\].*/\1/p')
  ISSUE_M=$(gh issue view "$NUM" --json milestone --jq '.milestone.title // ""' | sed -nE 's/^(M[0-9]+):.*/\1/p')
  [ -n "$EPIC_M" ] && [ "$EPIC_M" = "$ISSUE_M" ] || { echo "에픽 #$EPIC($EPIC_M)과 마일스톤($ISSUE_M)이 다르다 — 에픽·마일스톤을 확인"; exit 1; }
  # 이슈 타입(Task/Bug/Feature) 지정 — 같은 값으로 다시 지정해도 무방
  gh api graphql -f query='mutation($i:ID!,$t:ID!){updateIssueIssueType(input:{issueId:$i,issueTypeId:$t}){issue{number}}}' \
    -f i="$ISSUE_ID" -f t="$TYPE" >/dev/null
  echo "완료: #$NUM (프로젝트·에픽 #$EPIC·타입)"
  ```
  타입 ID: Task `IT_kwDOBMwL0c4PCk6t`, Feature `IT_kwDOBMwL0c4PCk6v` (Bug는 `gh api graphql`로 `repository.issueTypes` 조회)
- 후속 이슈는 아직 착수 전이므로 담당자를 지정하지 않는다 (착수할 때 1단계에서 지정).

### 10. Linux CI 확인
```bash
gh pr checks <PR> --watch
```
- `Linux Analyze, Test & Build`, `Android Unit Tests (JVM)`, `Verify Action Pins`가 통과해야 한다. `Verify Action Pins`만 실패하면 고정 SHA·보안 권고 문제거나 GitHub API 장애다(README "CI 액션 고정 버전 올리기"). 실패 시 로그(`gh run view --log-failed`)로 원인을 고친다.

### 11. 머지·이슈 Close·보드 갱신
```bash
gh pr merge <PR> --squash --delete-branch \
  --subject "<PR 제목> (#<PR번호>)"
```
- 마일스톤 브랜치로의 머지에는 `Milestone Full CI`가 돌지 않는다(정상).
- 서브이슈 PR은 기본 브랜치가 아닌 곳으로 머지되므로 **이슈가 자동 Close되지 않는다** → 직접 처리:
  1. 이슈 본문 체크리스트를 `[x]`로 갱신 (`gh issue edit <번호> --body-file ...`). 본문은 지금 상태를 다시 읽어(`gh issue view <번호> --json body -q .body`) 고친다 —
     1단계에서 바꾼 실기기 분기 줄이 덮이지 않게. 분기 줄은 체크하지 않는다. 작업 중 사실과 다르다고 확인된 항목은 문구를 실측대로 고친 뒤 체크한다.
  2. `gh issue close <번호> --reason completed --comment "PR #<PR번호>로 milestone/m<N>에 머지 완료"`
  3. `bash .claude/scripts/set-project-status.sh <번호> Done` / `... <PR번호> Done`
  4. 마일스톤 PR 본문의 서브이슈 체크리스트가 있으면 해당 항목을 `[x]`로 갱신
  5. 머지된 PR 범위의 Actions 캐시를 지운다 — 머지 뒤에는 어떤 실행도 읽지 못한다(README "Android 단위 테스트" 캐시 용량, #121):
     `gh cache delete --all --ref refs/pull/<PR번호>/merge --succeed-on-no-caches`
- 로컬 정리: `git checkout milestone/m<N> && git pull --ff-only origin milestone/m<N>`

### 12. 보고
- PR/머지 커밋 링크, 변경 요약, 리뷰 R1/R2에서 고친 것, 기각한 지적(이유), 1단계에서 M8로 분기한 실기기 항목, 후속 이슈(등록한 것·등록하지 않은 것과 이유), 다음 서브이슈 번호를 짧게 보고한다.

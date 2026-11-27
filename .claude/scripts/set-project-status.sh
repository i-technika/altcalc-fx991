#!/usr/bin/env bash
# GitHub Project #7(AltCalc FX-991)에서 이슈/PR의 Status를 변경한다.
# 사용법: bash .claude/scripts/set-project-status.sh <이슈|PR 번호> <Todo|"In Progress"|Done>
# 항목이 프로젝트에 없으면 먼저 추가한 뒤 상태를 설정한다.
#
# 프로젝트 항목 전체(`gh project item-list`)를 읽지 않는다 (#250) — 항목이 수백 개라 그 조회 한 번이
# GraphQL 시간당 한도(5,000점)의 상당 부분을 써서, 여러 세션이 함께 돌면 한도가 바닥났다.
# 대신 그 이슈·PR 쪽에서 자기가 들어 있는 프로젝트 항목을 찾는다(조회 1번 + 변경 1~2번).
# 테스트용 환경 변수: SET_PROJECT_STATUS_GH(가짜 gh 경로) — test/unit/set_project_status_script_test.dart
set -euo pipefail

gh=${SET_PROJECT_STATUS_GH:-gh}

NUMBER="${1:?이슈/PR 번호를 입력하세요}"
STATUS="${2:?상태(Todo | In Progress | Done)를 입력하세요}"

OWNER="i-technika"
REPO_NAME="altcalc-fx991"
PROJECT_ID="PVT_kwHOBMwL0c4BsMze"
STATUS_FIELD_ID="PVTSSF_lAHOBMwL0c4BsMzezhqcBOI"

[[ $NUMBER =~ ^[1-9][0-9]*$ ]] || { echo "이슈/PR 번호가 아니다: $NUMBER" >&2; exit 1; }

case "$STATUS" in
  "Todo")        OPTION_ID="f75ad846" ;;
  "In Progress") OPTION_ID="47fc9ee4" ;;
  "Done")        OPTION_ID="98236657" ;;
  *) echo "알 수 없는 상태: $STATUS (Todo | In Progress | Done)" >&2; exit 1 ;;
esac

# 이슈·PR의 노드 ID와 그것이 들어 있는 프로젝트 항목들 (이슈와 PR 번호 공간은 공유되므로 번호만으로 유일).
# 출력: 첫 줄 = 노드 ID, 다음 줄부터 항목마다 "프로젝트 ID<TAB>항목 ID".
# projectItems는 보관(archived)된 항목도 돌려준다(includeArchived 기본값 true) — 보관된 항목을 다시 추가하지 않는다.
# 한 이슈가 들어 있는 프로젝트는 몇 개뿐이라 first:20이면 다 온다.
LOOKUP=$("$gh" api graphql \
  -f query='query($owner:String!,$name:String!,$number:Int!){
  repository(owner:$owner,name:$name){
    issueOrPullRequest(number:$number){
      ... on Issue{id projectItems(first:20){nodes{id project{id}}}}
      ... on PullRequest{id projectItems(first:20){nodes{id project{id}}}}
    }
  }
}' \
  -f owner="$OWNER" -f name="$REPO_NAME" -F number="$NUMBER" \
  --jq '.data.repository.issueOrPullRequest | .id, (.projectItems.nodes[] | "\(.project.id)\t\(.id)")') \
  || { echo "#${NUMBER} 조회 실패(번호가 없거나 API 오류 — 위 gh 메시지 참고) — 상태를 바꾸지 않았다" >&2; exit 1; }

# 없는 번호는 gh가 GraphQL 오류("Could not resolve to an issue or pull request")로 1을 내 위에서 멈춘다.
# 아래 null·빈 값 검사는 응답이 예상과 다를 때를 위한 방어다.
CONTENT_ID=$(printf '%s\n' "$LOOKUP" | sed -n 1p)
[ -n "$CONTENT_ID" ] && [ "$CONTENT_ID" != "null" ] \
  || { echo "#${NUMBER} 이슈/PR을 찾지 못했다 — 상태를 바꾸지 않았다" >&2; exit 1; }

ITEM_ID=$(printf '%s\n' "$LOOKUP" | sed 1d \
  | awk -F'\t' -v p="$PROJECT_ID" '$1 == p { print $2; exit }')

if [ -z "$ITEM_ID" ]; then
  # 프로젝트에 없으면 추가한다(이미 들어 있으면 기존 항목을 돌려주는 mutation이라 다시 실행해도 안전하다)
  ITEM_ID=$("$gh" api graphql \
    -f query='mutation($project:ID!,$content:ID!){
  addProjectV2ItemById(input:{projectId:$project,contentId:$content}){item{id}}
}' \
    -f project="$PROJECT_ID" -f content="$CONTENT_ID" \
    --jq '.data.addProjectV2ItemById.item.id') \
    || { echo "#${NUMBER} 프로젝트 추가 실패 — 상태를 바꾸지 않았다" >&2; exit 1; }
  [ -n "$ITEM_ID" ] && [ "$ITEM_ID" != "null" ] \
    || { echo "#${NUMBER} 프로젝트 추가 결과에 항목 ID가 없다 — 상태를 바꾸지 않았다" >&2; exit 1; }
fi

"$gh" api graphql \
  -f query='mutation($project:ID!,$item:ID!,$field:ID!,$option:String!){
  updateProjectV2ItemFieldValue(input:{projectId:$project,itemId:$item,fieldId:$field,value:{singleSelectOptionId:$option}}){projectV2Item{id}}
}' \
  -f project="$PROJECT_ID" -f item="$ITEM_ID" -f field="$STATUS_FIELD_ID" -f option="$OPTION_ID" \
  >/dev/null \
  || { echo "#${NUMBER} 상태 변경 실패 (item: ${ITEM_ID})" >&2; exit 1; }

echo "#${NUMBER} → ${STATUS} (item: ${ITEM_ID})"

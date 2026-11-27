import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:material_ui/material_ui.dart';

import '../../core/layout/form_factor.dart';
import 'handedness_dialog.dart';

/// 설정 키(ON, #190)로 설정을 연다 — 키패드 위치(손잡이) 선택 대화상자([HandednessDialog], #24)를 띄운다. 앱 설정
/// 화면은 M6에서 만든다.
///
/// 이 위젯은 그리지 않는다. 계산기 화면(`CalculatorScreen`)이 본체 전체를 이 위젯으로 감싸고, 키패드의 설정 키가
/// [openFrom]에 자기 context를 넘겨 연다. 대화상자는 그 키(이하 "ON 키")의 위치를 기준으로 띄운다. 예전에는 LCD 위
/// 상단 띠·LCD 옆의 설정 버튼(`SettingsButton`, #24·#41)이 열었다 — ON 키는 키패드 안에 있어 모든 배치에서 주로 쓰는
/// 손 쪽에 있다(세로 접힘선 기준 배치에서는 키패드 쪽 절반).
///
/// ON 키는 다른 키처럼 **누르는 순간** 연다(`CalcKeyButton` 입력 계약 — 시스템 제스처 영역에서 시작한 터치만 손을 뗄 때).
/// 예전 설정 버튼(IconButton)은 손을 뗄 때 열었다. 실물 키처럼 모든 키의 반응을 같게 두고, 모달이라 연 뒤의 손가락
/// 움직임은 대화상자 뒤의 키에 닿지 않는다.
///
/// ## 접힘선이 있을 때 대화상자 위치 (#25)
/// 대화상자는 ON 키가 있는 쪽 절반에 뜬다(대화상자 경로의 `anchorPoint` → `DisplayFeatureSubScreen`, 좁은 절반
/// 예외는 아래 "좁은 하위 화면").
/// Flutter는 반 접힘·물리 힌지만 화면을 나누는 것으로 보지만, 앱은 펼친 폭 0 세로 접힘선에서도 화면을 나눈다
/// (`FormFactor.arrangementOf`). 그 경우 대화상자가 주름을 가로지르지 않도록 같은 기준으로 한 번 더 나눈다.
/// 어디에 띄울지는 다음 순서로 정한다 (#41 R1·R2, #129).
/// 1. 실제로 그린 배치([arrangement])가 세로 접힘선 기준 배치가 아니면 화면 전체다. 키가 터치 하한보다 낮아 위아래
///    배치로 그렸다면 앱도 화면을 나누지 않았으므로 대화상자를 한쪽 절반에 가두지 않는다.
/// 2. 손잡이를 바꾸면 그린 배치가 위아래 배치로 바뀌는 화면([handednessKeepsArrangement]가 `false` — 키패드가 반대쪽
///    절반에 들어가지 못한다)도 화면 전체다. 열린 채 손잡이를 바꾸면 1에 따라 대화상자가 화면 전체로 옮겨 가야 하므로,
///    처음부터 화면 전체에 띄워 그대로 남게 한다(아래 "대화상자가 열린 채 손잡이를 바꾸면", #94).
/// 3. 절반은 아래 "좁은 하위 화면"과 같은 규칙으로 고른다. ON 키 쪽 절반이 인셋을 빼고 대화상자 최소 크기
///    ([dialogMinRegionOf], 폭 360dp)에 못 미치면 카드가 Material 최소 폭(280dp)보다 좁게 나뉘므로, 최소 크기를
///    넘는 반대쪽 절반을 고른다. 넘는 곳이 없으면 ON 키 쪽 절반이다.
/// 4. ON 키 쪽 절반을 골랐으면, 그 절반이 인셋을 빼고 [FormFactor.hingeMinPanelExtent] 이상일 때만 그 절반이고
///    아니면 화면 전체다(카드가 200dp 아래로 줄어 읽기 어렵다 — 주름을 가로지르더라도 화면 전체에 띄운다).
///    세로 접힘선 기준 배치에서 ON 키는 키패드 쪽 절반에 있고 그 절반은 키패드가 들어갈 만큼 넓지만, 키패드는 인셋을
///    빼고 약 264dp까지 들어가므로 옆 인셋이 있는 좁은 절반(인셋 제외 280dp 미만)에서는 이 하한(#129 R2)에 걸린다.
///    (#190 전에는 2가 반대쪽 절반을 고를 때만의 조건이었다 — 설정 버튼은 LCD 쪽 절반이라 손잡이를 바꾸면 그 절반에
///    키패드가 들어갈 수 있는지가 문제였다. ON 키는 키패드 쪽에 있어, 같은 화면을 반대 손잡이로 바꾸면 ON 키 쪽
///    절반에 연 대화상자도 위아래 배치로 바뀌는 화면이 되므로 두 경우를 함께 막는다.)
///
/// 그래서 양쪽 절반이 모두 최소 크기에 못 미치면 카드가 280dp보다 좁게 남는다 — ON 키 쪽 절반 280~360dp에 맞춰
/// 200~280dp다. 조금 더 넓을 뿐인 곳으로 ON 키와 멀어지지 않는 #125의 규칙을 따른 것이고, 대칭인 Galaxy Z Fold 내부
/// 세로 화면(절반 336.5dp, 카드 256dp)도 주름을 피하는 쪽을 택했다 (#25).
///
/// 앱이 나눌 때는 대화상자 경로의 SafeArea를 끄고, 나눈 절반 안쪽에서 SafeArea를 씌운다. 경로의 SafeArea 안에서
/// 나누면 화면 크기 기준으로 잰 절반이 인셋만큼 줄어든 상자 안에 놓여, 반대쪽 가장자리 인셋만큼 밀리고 좁아진다
/// (#129 R1 — Flutter 경로도 `DisplayFeatureSubScreen` 안쪽에 SafeArea를 둔다).
///
/// ### 좁은 하위 화면 (#125)
/// Flutter가 나누는 접힘선(반 접힘, 폭이 있는 물리 힌지 — `DisplayFeatureSubScreen.avoidBounds`)에서는 대화상자
/// 경로가 앱의 배치와 무관하게 늘 화면을 나누고(접힘선이 2개 이상인 화면은 예외 — 아래 절), `anchorPoint`에 가장
/// 가까운 하위 화면(나뉜 절반)에 대화상자를 가둔다. 접힘선이 한쪽에 치우친 창에서는 ON 키가 좁은 절반에 있을 수
/// 있다 — 위아래 배치에서 세로 접힘선이 키패드 오른쪽을 지나면 오른쪽 위 ON 키가 좁은 절반에 들고, 테이블톱(가로
/// 접힘선)의 ON 키는 키패드가 있는 아래 절반이라 그 절반이 낮을 수 있다.
/// ON 키 쪽 하위 화면이 그 인셋을 빼고 대화상자 최소 크기([dialogMinRegionOf] — 카드 최소 폭·높이와 바깥 여백)에
/// 못 미치면, 최소 크기를 넘는 하위 화면 중 ON 키에 가장 가까운 곳에 띄운다([dialogAnchorPointOf]). 넘는 곳이 없으면
/// ON 키 쪽 그대로다(조금 더 넓을 뿐인 곳으로 ON 키와 멀어지지 않는다).
/// 화면 전체에 띄우지 않는 이유: 물리 힌지는 가로지르면 내용이 힌지 틈에 가려지고, 반 접힘의 주름도 피한다(#25).
/// 배치는 한쪽 패널이 좁으면 위아래 배치로 주름을 가로지르지만(키패드가 절반에 들어가지 못한다), 대화상자는 작아
/// 한쪽 절반에 들어가므로 주름을 피하는 쪽을 택한 설계다. ON 키와 다른 절반이지만 모달이라 대화상자만 다루면 된다.
/// 그 결과 이런 화면에서는 손잡이와 무관하게 대화상자가 넓은 절반에 뜬다.
/// 펼친 폭 0 세로 접힘선은 Flutter가 나누지 않아, 앱이 나눌 때 바로 위 절의 순서 안에서 이 규칙을 쓴다 (#129).
///
/// ### 접힘선이 2개 이상인 화면 (#198)
/// 창을 가로지르는 접힘선이 2개 이상인 화면(펼친 트라이폴드, `FormFactor.crossesMultipleHinges`)은 배치가 접힘선을 모두
/// 무시하므로(#144) 대화상자도 **화면 전체 가운데**에 뜬다 — 자세(펼침·반 접힘)와 힌지 폭에 상관없다. 한 칸에 가두지
/// 않는 이유: Galaxy Z TriFold 공개 해상도 근사 823×603dp는 칸 폭이 약 274dp로 최소 크기(360dp)에 못 미쳐 카드가 약
/// 194dp로 줄어든다. `showDialog` 경로는 반 접힘·폭 있는 힌지면 화면을 나누고, 접힘선이 둘 이상이면 Flutter
/// `DisplayFeatureSubScreen.subScreensInBounds`가 다른 접힘선이 걸친 칸도 만든다(x=274.5·548.5: 0~548.5 칸 — 고치기 전
/// 카드가 x=55~493으로 접힘선 하나를 가로질렀다, #190 R2 실측). 그래서 경로를 직접 띄워(`_SettingsDialogRoute`) 이런
/// 화면에서는 경로 안의 접힘 정보를 지운다([dialogRouteMediaOf] — 다른 화면에서도 경로가 나누는 접힘선을 배치가 쓰는
/// 접힘선 하나로 맞춘다).
///
/// 폭 있는 물리 힌지 2개도 화면 전체다. 그 틈의 내용은 보이지 않는다 — 823×603에 폭 20dp 힌지 2개
/// (x=264.5~284.5·538.5~558.5)를 두고 재면 카드는 x=192.5~630.5(438dp), 선택지 글은 x=264.5~606.5라 두 글의 앞 20dp가
/// 왼쪽 틈에 가리고 오른쪽 틈도 글 위를 지난다. 다른 자리로 옮겨도 낫지 않다: 틈으로 나눈 칸(264.5·254·264.5dp)은 모두
/// 카드 최소 폭(280dp)보다 좁고, 선택지 글 폭(약 342dp)이 가운데 칸보다 넓어 카드를 어디로 옮겨도 글이 틈에 걸친다.
/// 배치의 키도 같은 틈에 걸친다(#144). 틈으로 나눈 칸이 넉넉한 화면이면 그 칸에 가둘 수 있지만, 폭 있는 힌지 2개를
/// 보고하는 기기가 알려져 있지 않아 따로 두지 않는다(#198 R1 — 추측 분기는 폭 0 주름이 섞인 화면에서 주름을 가로지른다).
///
/// ## 대화상자가 열린 동안 배치가 바뀌면
/// 회전·접기·창 크기 변경으로 [arrangement]·[handednessApplies]·[handednessKeepsArrangement]가 바뀌면 다음 프레임에
/// 열린 대화상자에도 반영된다(나뉨 여부와 그 기준 위치, 적용 안내 글). 대화상자는 다른 경로라 이 위젯이 다시
/// 빌드되는 중에는 바꿀 수 없어 한 프레임 늦다. 나뉨 여부가 바뀌어 대화상자를 감싸는 위젯이 달라져도 대화상자는 같은
/// [GlobalKey]로 옮겨 가므로 키보드 포커스·스크롤 위치가 유지된다.
/// 다시 잰 기준 위치(ON 키 중심)는 앱만 나누는 펼친 폭 0 세로 접힘선에만 쓰인다. Flutter도 나누는 반 접힘·물리 힌지는
/// 경로가 연 시점의 `anchorPoint`로 절반을 고르고, 그 값은 경로가 열린 동안 바뀌지 않는다. 접힘선이 2개 이상인 화면에서
/// 연 `anchorPoint`는 연 시점의 ON 키 중심 그대로다([dialogAnchorPointOf]). 접힘 정보가 바뀌어 접힘선 2개 이상인 화면이
/// 되거나 그 반대가 되면 경로는 나뉨 여부를 같은 프레임에 바꾼다(경로의 MediaQuery를 직접 본다, 앱만 나누는 절반은 위처럼
/// 한 프레임 늦다). 연 시점의 값이라, 가로형 배치(접힘선 2개)로 연 채 접힘선 1개 화면이 되면 대화상자는 연 시점의 ON 키
/// 쪽 절반에 뜬다 — 접힘선 기준 배치에서는 ON 키가 반대쪽 절반으로 옮겨 가 있을 수 있다(회전 등 다른 전환과 같은 한계,
/// 기준점을 따라가게 하는 일은 후속 이슈).
///
/// ## 대화상자가 열린 채 손잡이를 바꾸면 (#94)
/// 세로 접힘선 기준 배치는 그대로이고 손잡이만 바뀌어 키패드(와 ON 키)가 반대쪽 절반으로 옮겨 가도, 대화상자는 연
/// 자리(연 시점의 ON 키 쪽 절반)에 남는다. 고른 뒤에는 ON 키와 대화상자가 서로 다른 절반에 있고 옮겨 온 LCD를
/// 대화상자가 가리지만, 고르는 순간 반대쪽 절반으로 키패드가 옮겨 가는 것은 대화상자 바깥에서 보인다(미리 보기).
/// 닫았다가 다시 열면 지금 ON 키가 있는 절반에 뜬다(좁은 절반 예외는 위 "좁은 하위 화면" — 그 경우 연 자리가 처음부터
/// 반대쪽 넓은 절반이고, 거기 그대로 남는다). 다른 두 방식을 쓰지 않는 이유:
/// - ON 키 쪽으로 따라가기: 키보드 화살표로 선택지를 옮기면 선택도 바뀌므로([HandednessDialog]) 화살표를 누를
///   때마다 대화상자가 접힘선 건너로 뛴다. 손가락·스크린리더 터치 탐색 위치에서도 대화상자가 사라진다.
///   (반 접힘·물리 힌지까지 따라가게 하려면 경로의 `anchorPoint`를 열린 동안 바꿀 수 있어야 한다 — 지금 경로는
///   연 시점의 값을 쓴다.)
/// - 고르면 바로 닫기: 화살표 한 번에 설정이 바뀌고 대화상자가 닫힌다([HandednessDialog]).
///
/// 다른 화면에서도 대화상자는 연 자리에 남는다.
/// - 손잡이를 바꾸면 배치까지 바뀌는 비대칭 세로 접힘선(키패드가 들어갈 절반 폭이 손잡이마다 다르다): 반 접힘·물리
///   힌지는 연 시점의 `anchorPoint`가 고정이라 ON 키가 옮겨 가도 대화상자는 그 자리다. 펼친 폭 0 접힘선은
///   [handednessKeepsArrangement]가 `false`라 처음부터 화면 전체에 떠 있다(위 2).
/// - 가로 접힘선 기준 배치(테이블톱): ON 키는 늘 아래 절반(키패드)에 있고 손잡이를 바꾸면 같은 절반 안에서 좌우로만
///   옮겨 간다.
/// - 가로형 배치(접힘선 없음, #142): 대화상자가 화면 가운데 한 자리다.
/// - 접힘선이 2개 이상인 화면(펼친 트라이폴드, #144·#198): 대화상자가 화면 가운데 한 자리다.
class SettingsLauncher extends StatefulWidget {
  /// 화면의 실제 배치 (`CalculatorScreen`이 그린 배치 — 접힘선 기준 배치를 쓸 수 없어 위아래 배치로 그렸으면
  /// [ScreenArrangement.stacked])
  final ScreenArrangement arrangement;

  /// 손잡이 설정을 바꾸면 이 화면의 키패드 위치가 달라지는지. 아니면 대화상자에 그 안내 글을 보인다.
  /// 접힘선 기준 배치라도 반대 손잡이의 키패드 자리가 같으면(키패드가 아래 절반 폭을 다 쓰는 테이블톱 — Fold 가로의
  /// 넓은 키패드 배열, Flip 내부, #80 R1) 키패드는 옮겨 가지 않는다 — 폭 상한에 걸려 좁게 남는 LCD만 좌우로
  /// 옮겨 간다. 블록 폭 상한에 걸린 넓은 배열처럼 몇 dp만 옮겨 가는 것도 옮겨 가지 않는 것으로 본다
  /// (`CalculatorScreen`, `CalcTheme.screenPanelGap` 미만).
  ///
  /// 그린 배치만으로는 정할 수 없다 — 세로 접힘선 기준 배치는 키패드가 들어갈 절반의 폭이 손잡이마다 달라,
  /// 지금 손잡이로는 위아래 배치로 대체했어도 반대 손잡이로는 접힘선 기준 배치가 될 수 있다(#41 R2).
  /// `CalculatorScreen`이 두 손잡이로 모두 판정해 넘긴다.
  final bool handednessApplies;

  /// 어느 손잡이로 그려도 [arrangement]가 같은지 — 손잡이를 바꿔도 접힘선 기준 배치가 위아래 배치로 바뀌지 않는지.
  /// 앱이 나누는 펼친 폭 0 세로 접힘선에서 대화상자를 ON 키 반대쪽 절반에 띄워도 되는지 고를 때 쓴다
  /// ("접힘선이 있을 때 대화상자 위치", #129). `CalculatorScreen`이 두 손잡이로 모두 판정해 넘긴다.
  final bool handednessKeepsArrangement;

  /// 설정 키(ON)가 든 화면 (키패드를 품은 계산기 본체)
  final Widget child;

  const SettingsLauncher({
    super.key,
    required this.arrangement,
    required this.handednessApplies,
    required this.handednessKeepsArrangement,
    required this.child,
  });

  /// 설정 키 버튼의 context [keyContext]를 기준 위치로 설정을 연다 (`CalcKeypad.onSettingsPressed`).
  /// [keyContext] 위에 [SettingsLauncher]가 있어야 한다 — 없으면 아무것도 하지 않는다(디버그 빌드는 assert로 알린다).
  static void openFrom(BuildContext keyContext) {
    final state = keyContext.findAncestorStateOfType<_SettingsLauncherState>();
    assert(state != null, '설정 키 위에 SettingsLauncher가 없다');
    state?._open(keyContext);
  }

  /// 대화상자 카드 최소 높이를 테마가 정하지 않을 때 쓰는 값 (dp). Material은 최소 높이를 두지 않는다.
  /// 최소 폭과 같은 값으로 정한 기준이다. 이 높이의 카드는 글자 배율 2.0에서도 넘치지 않고 닫기 버튼이 보인다
  /// (#125 테스트가 확인). 영어 2.0에서는 제목이 높이 대부분을 차지해 선택지는 스크롤해야 보인다. 이 값은 제목을
  /// 스크롤 밖에 고정하던 때(영어 2.0에서 넘치지 않는 최소 카드 높이 약 270dp)에 정했다 — #38부터 제목도 선택지와
  /// 함께 스크롤하므로(닫기 버튼만 고정) 넘침까지의 여유는 그보다 크다.
  static const double dialogFallbackMinCardHeight = 280;

  /// 대화상자 카드가 최소 크기를 지키려면 대화상자가 뜨는 하위 화면이 시스템 인셋을 빼고 가져야 하는 크기 (dp).
  /// 카드 최소 크기에 대화상자 바깥 여백을 더한 값이다. 폭·여백은 Material `Dialog`처럼 테마 값이 있으면 그 값,
  /// 없으면 `Dialog` 기본값(최소 폭 280dp, 여백 좌우 40·위아래 24dp — 기본값 상수는 공개돼 있지 않다)이다.
  /// 높이는 테마 최소 높이와 [dialogFallbackMinCardHeight] 중 큰 값이다.
  @visibleForTesting
  static Size dialogMinRegionOf(DialogThemeData theme) {
    final constraints = theme.constraints;
    final inset =
        theme.insetPadding ??
        const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
    return Size(
      (constraints?.minWidth ?? 280) + inset.horizontal,
      math.max(constraints?.minHeight ?? 0, dialogFallbackMinCardHeight) +
          inset.vertical,
    );
  }

  /// 대화상자 경로(`DialogRoute`)에 줄 `anchorPoint` ([SettingsLauncher] "좁은 하위 화면", #125).
  ///
  /// [screen]은 대화상자 경로가 그려지는 Navigator의 MediaQuery다 — 경로 좌표, 접힘 정보, 시스템 인셋이 모두 그
  /// 기준이다. [anchor]는 ON 키 중심(경로 좌표)이다. Flutter와 같은 방법(`DisplayFeatureSubScreen`의 공개 함수)으로
  /// 하위 화면을 나누고, ON 키에 가장 가까운 하위 화면이 인셋을 빼고 [minRegion] 이상이면 [anchor]를 그대로,
  /// 아니면 [minRegion] 이상인 하위 화면 중 ON 키에 가장 가까운 곳의 가운데를 돌려준다. 그런 곳이 없거나 화면이
  /// 나뉘지 않으면 [anchor] 그대로다.
  ///
  /// 하위 화면은 경로와 같은 접힘 정보([dialogRouteMediaOf] — 배치가 쓰는 접힘선만)로 나눈다. 그래서 창을
  /// 가로지르는 접힘선이 2개 이상인 화면은 나뉘지 않아 [anchor] 그대로다 — Flutter가 그런 화면에서 만드는 겹치는 하위
  /// 화면(#198)으로 고르지 않는다(#198 R1·R2).
  @visibleForTesting
  static Offset? dialogAnchorPointOf(
    MediaQueryData? screen,
    Offset? anchor,
    Size minRegion,
  ) {
    if (screen == null || anchor == null) return anchor;
    screen = dialogRouteMediaOf(screen);
    final whole = Offset.zero & screen.size;
    final subScreens = DisplayFeatureSubScreen.subScreensInBounds(
      whole,
      DisplayFeatureSubScreen.avoidBounds(screen),
    ).toList();
    if (subScreens.length < 2) return anchor;
    // 인셋은 `MediaQueryData.removeDisplayFeatures`처럼 화면 가장자리에 닿은 쪽에만 남는다 = 안전 영역과의 교집합.
    // 시스템 인셋(SafeArea)과 함께 Material `Dialog`가 바깥 여백에 더하는 키보드 인셋도 뺀다(키보드가 뜨면
    // padding 아래쪽은 0이 되므로 합이 실제 남는 영역이다).
    final safe = (screen.padding + screen.viewInsets).deflateRect(whole);
    bool fits(Rect sub) {
      final usable = sub.intersect(safe);
      return usable.width >= minRegion.width &&
          usable.height >= minRegion.height;
    }

    // Flutter `DisplayFeatureSubScreen`처럼 기준점과의 거리가 가장 짧은 곳 (같으면 앞의 것)
    Rect? closest(Iterable<Rect> rects) {
      Rect? best;
      var bestDistance = double.infinity;
      for (final r in rects) {
        final nearest = Offset(
          anchor.dx.clamp(r.left, r.right),
          anchor.dy.clamp(r.top, r.bottom),
        );
        final d = (anchor - nearest).distance;
        if (d < bestDistance) {
          best = r;
          bestDistance = d;
        }
      }
      return best;
    }

    if (fits(closest(subScreens)!)) return anchor;
    return closest(subScreens.where(fits))?.center ?? anchor;
  }

  /// 대화상자 경로 안에 줄 MediaQuery — 접히는 부분(fold·hinge)을 배치가 쓰는 접힘선만 남긴다 ([SettingsLauncher]
  /// "접힘선이 2개 이상인 화면", #198).
  ///
  /// [route]는 경로가 그려지는 Navigator의 MediaQuery다. Flutter `DisplayFeatureSubScreen.subScreensInBounds`는 접히는
  /// 부분이 둘 이상이면 다른 접힘선이 걸친 칸을 만들어(823×603, x=274.5·548.5: 0~548.5 칸) 대화상자가 접힘선을
  /// 가로지르거나 보고 순서에 따라 다른 칸에 뜬다. 그래서 경로가 나누는 접힘선을 배치([FormFactor.hingeOf])와 맞춘다.
  /// - 창을 가로지르는 접힘선이 2개 이상([FormFactor.crossesMultipleHinges] — 펼친 트라이폴드, 십자 힌지): 모두 지운다.
  ///   배치도 접힘선을 모두 무시한다(#144). 경로가 화면을 나누지 않아 대화상자가 화면 전체 가운데에 뜬다.
  /// - 1개: 그 접힘선 하나만 남긴다. 같은 접힘선이 두 번 보고되면(폭 있는 힌지와 그 안의 폭 0 접힘선) 폭이 가장 넓고,
  ///   같으면 반 접힌 것 — Flutter가 나누는 쪽이다. 창 가장자리·창 밖·창보다 긴 접힘 정보는 지운다 — 트라이폴드에서 두
  ///   장에 걸친 분할 창(548.5×603, 반 접힘 x=274.5와 창 끝 x=548.5)도 가운데 접힘선 하나로 나눈다(#198 R2).
  /// - 0개: 모두 지운다(위와 같은 이유 — 배치도 접힘선이 없는 것으로 본다).
  ///
  /// 화면 구멍(cutout)은 남긴다. 바꿀 것이 없으면 [route] 그대로다.
  @visibleForTesting
  static MediaQueryData dialogRouteMediaOf(MediaQueryData route) {
    bool foldOrHinge(DisplayFeature f) =>
        f.type == DisplayFeatureType.fold || f.type == DisplayFeatureType.hinge;
    final crossing = FormFactor.crossingHingesOf(
      route.size,
      route.displayFeatures,
    );
    DisplayFeature? kept;
    if (crossing.length == 1) {
      // 창을 가로지르는 접힘 정보는 모두 같은 접힘선이다(다르면 2개로 센다)
      for (final f in route.displayFeatures) {
        if (FormFactor.crossingHingesOf(route.size, [f]).isEmpty) continue;
        final current = kept;
        if (current == null ||
            f.bounds.shortestSide > current.bounds.shortestSide ||
            (f.bounds.shortestSide == current.bounds.shortestSide &&
                f.state == DisplayFeatureState.postureHalfOpened &&
                current.state != DisplayFeatureState.postureHalfOpened)) {
          kept = f;
        }
      }
    }
    final features = [
      for (final f in route.displayFeatures)
        if (!foldOrHinge(f) || identical(f, kept)) f,
    ];
    if (features.length == route.displayFeatures.length) return route;
    return route.copyWith(displayFeatures: features);
  }

  @override
  State<SettingsLauncher> createState() => _SettingsLauncherState();
}

/// 열린 대화상자가 보는 화면 상태 — 배치, 손잡이 적용 여부, 손잡이를 바꿔도 배치가 같은지, ON 키 중심(Navigator
/// 좌표, 나눌 절반을 고르는 기준)
typedef _DialogLayout = ({
  ScreenArrangement arrangement,
  bool handednessApplies,
  bool handednessKeepsArrangement,
  Offset? anchor,
});

class _SettingsLauncherState extends State<SettingsLauncher> {
  /// 열린 대화상자가 보는 화면 상태 ([SettingsLauncher]의 값을 한 프레임 늦게 따른다)
  late final ValueNotifier<_DialogLayout> _layout = ValueNotifier(
    _layoutOf(null),
  );

  /// 마지막으로 설정을 연 ON 키의 context — 배치가 바뀐 뒤 ON 키 중심을 다시 잴 때 쓴다. 키패드 element는 배치가
  /// 바뀌어도 유지되므로(`CalculatorScreen`) 같은 context가 새 자리를 가리킨다.
  BuildContext? _anchorContext;

  /// 지금 [widget] 값과 [anchor]로 만든 대화상자 화면 상태
  _DialogLayout _layoutOf(Offset? anchor) => (
    arrangement: widget.arrangement,
    handednessApplies: widget.handednessApplies,
    handednessKeepsArrangement: widget.handednessKeepsArrangement,
    anchor: anchor,
  );

  @override
  void didUpdateWidget(SettingsLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.arrangement != oldWidget.arrangement ||
        widget.handednessApplies != oldWidget.handednessApplies ||
        widget.handednessKeepsArrangement !=
            oldWidget.handednessKeepsArrangement) {
      // 대화상자 경로는 이 위젯의 자손이 아니라 빌드 중에 다시 빌드하라고 표시할 수 없다 — 프레임이 끝난 뒤
      // (ON 키가 새 자리에 놓인 뒤) 알린다. ON 키 중심도 그때 다시 잰다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final key = _anchorContext;
        final navigator = Navigator.maybeOf(context, rootNavigator: true);
        _layout.value = _layoutOf(
          key == null || !key.mounted || navigator == null
              ? _layout.value.anchor
              : _anchorIn(key, navigator) ?? _layout.value.anchor,
        );
      });
    }
  }

  @override
  void dispose() {
    _layout.dispose();
    super.dispose();
  }

  /// [key](ON 키) 중심을 [navigator] 좌표로 바꾼 값 (배치 전이면 `null`).
  ///
  /// 대화상자 경로는 그 Navigator 안에서 그려지고, `DisplayFeatureSubScreen`은 그 위치의 MediaQuery
  /// (접힘 정보 포함)와 경로 좌표로 절반을 고른다. 실제 앱에서는 Navigator가 화면 전체를 채워 경로 좌표가
  /// 곧 화면 좌표다.
  static Offset? _anchorIn(BuildContext key, NavigatorState navigator) {
    final box = key.findRenderObject();
    final navigatorBox = navigator.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || navigatorBox is! RenderBox) {
      return null;
    }
    return navigatorBox.globalToLocal(
      box.localToGlobal(box.size.center(Offset.zero)),
    );
  }

  /// 앱이 화면을 나누는데 Flutter는 나누지 않는 접힘선(펼친 폭 0 세로 접힘선)을, 대화상자 배치에서는
  /// 나누는 접힘선(반 접힘)으로 바꾼 접힘 정보와, 대화상자를 둘 절반을 고르는 기준점을 돌려준다.
  /// 화면 전체에 띄우면 `null`이다 ([SettingsLauncher] "접힘선이 있을 때 대화상자 위치", #41·#129).
  /// - 앱이 실제로 세로 접힘선 기준 배치로 그렸어야 한다([_DialogLayout.arrangement]). ON 키 위치를 모르면
  ///   ([_DialogLayout.anchor]가 `null` — 배치 전에는 열 수 없어 실제로는 생기지 않는다) 화면 전체다.
  /// - 손잡이를 바꿔도 배치가 그대로일 때([_DialogLayout.handednessKeepsArrangement])만 나눈다.
  /// - 기준점은 [SettingsLauncher.dialogAnchorPointOf]로 고른다. ON 키 쪽 절반이면 그 절반이 인셋을 빼고
  ///   [FormFactor.hingeMinPanelExtent] 이상일 때만 나눈다.
  ///
  /// [media]는 대화상자 경로의 MediaQuery다(경로의 SafeArea를 껐으므로 시스템·키보드 인셋이 그대로 있다).
  static ({List<DisplayFeature> features, Offset anchorPoint})? _splitLikeApp(
    MediaQueryData media,
    _DialogLayout layout,
    Size minRegion,
  ) {
    final anchor = layout.anchor;
    if (layout.arrangement != ScreenArrangement.hingeSplit ||
        !layout.handednessKeepsArrangement ||
        anchor == null) {
      return null;
    }
    bool splitByAppOnly(DisplayFeature f) =>
        !FormFactor.separates(f) &&
        FormFactor.hingeOf(media.size, [f]) != null &&
        FormFactor.isVerticalHinge(f.bounds);
    final hinge = media.displayFeatures.where(splitByAppOnly).firstOrNull;
    if (hinge == null) return null;
    final features = [
      for (final f in media.displayFeatures)
        splitByAppOnly(f)
            ? DisplayFeature(
                bounds: f.bounds,
                type: f.type,
                state: DisplayFeatureState.postureHalfOpened,
              )
            : f,
    ];
    // 나눈 접힘 정보로 Flutter가 나누는 접힘선과 같은 규칙(#125)을 적용한다.
    final anchorPoint = SettingsLauncher.dialogAnchorPointOf(
      media.copyWith(displayFeatures: features),
      anchor,
      minRegion,
    )!;
    // 반대쪽(최소 크기를 넘는) 절반
    if (anchorPoint != anchor) {
      return (features: features, anchorPoint: anchorPoint);
    }
    // ON 키 쪽 절반의 폭 (그쪽 인셋 제외 — `dialogAnchorPointOf`처럼 시스템·키보드 인셋을 함께 뺀다). 하한보다
    // 좁으면 카드가 읽기 어려워 화면 전체에 띄운다.
    final inset = media.padding + media.viewInsets;
    final half = anchor.dx < hinge.bounds.center.dx
        ? hinge.bounds.left - inset.left
        : media.size.width - hinge.bounds.right - inset.right;
    if (half < FormFactor.hingeMinPanelExtent) return null;
    return (features: features, anchorPoint: anchor);
  }

  void _open(BuildContext key) {
    final navigator = Navigator.of(context, rootNavigator: true);
    _anchorContext = key;
    final anchor = _anchorIn(key, navigator);
    _layout.value = _layoutOf(anchor);
    // 나뉨 여부가 바뀌어 감싸는 위젯이 달라져도 대화상자 element(포커스·스크롤)를 옮겨 유지한다.
    final dialogKey = GlobalKey(debugLabel: 'handedness-dialog');
    final minRegion = SettingsLauncher.dialogMinRegionOf(
      DialogTheme.of(context),
    );
    // `showDialog`와 같은 경로(테마 전달, 장벽 색, 포커스 순환)를 직접 띄운다 — 접힘선이 2개 이상인 화면에서 경로의
    // 하위 화면 나눔을 바꾸려면 경로를 직접 만들어야 한다([_SettingsDialogRoute], #198).
    assert(debugCheckHasMaterialLocalizations(context));
    navigator.push(
      _SettingsDialogRoute(
        context: context,
        themes: InheritedTheme.capture(from: context, to: navigator.context),
        barrierColor:
            DialogTheme.of(context).barrierColor ??
            Theme.of(context).dialogTheme.barrierColor ??
            Colors.black54,
        traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
        // ON 키 중심([_layout]의 anchor)은 앱만 나누는 펼친 폭 0 접힘선용으로 그대로 두고, Flutter가 나누는
        // 접힘선의 하위 화면 선택에만 좁은 하위 화면을 피한 기준점을 쓴다.
        anchorPoint: SettingsLauncher.dialogAnchorPointOf(
          // 의존을 등록하지 않고 읽는다 — `MediaQuery.of`로 읽으면 Navigator가 MediaQuery의 모든 속성에 영구히
          // 의존해, 한 번 연 뒤로 어떤 변경에도 모든 경로를 다시 빌드한다.
          navigator.context.getInheritedWidgetOfExactType<MediaQuery>()?.data,
          anchor,
          minRegion,
        ),
        // SafeArea는 아래에서 직접 씌운다 — 앱이 나눌 때는 나눈 절반 안쪽에 있어야 한다([SettingsLauncher]
        // "접힘선이 있을 때 대화상자 위치"). 나누지 않으면 기본값(경로가 씌우는 SafeArea)과 같은 자리다.
        useSafeArea: false,
        builder: (dialogContext) => ValueListenableBuilder<_DialogLayout>(
          valueListenable: _layout,
          builder: (dialogContext, layout, _) {
            final dialog = SafeArea(
              child: HandednessDialog(
                key: dialogKey,
                showLayoutNote: !layout.handednessApplies,
              ),
            );
            final media = MediaQuery.of(dialogContext);
            final split = _splitLikeApp(
              media,
              layout,
              SettingsLauncher.dialogMinRegionOf(DialogTheme.of(dialogContext)),
            );
            if (split == null) return dialog;
            // 바깥 `DisplayFeatureSubScreen`이 나누지 않아 화면 전체(경로 좌표 = 이 좌표)를 받았으므로,
            // 고른 기준점(ON 키 중심, ON 키 쪽이 좁으면 넓은 반대쪽 절반 가운데)으로 앱 기준 절반을 고른다.
            return MediaQuery(
              data: media.copyWith(displayFeatures: split.features),
              child: DisplayFeatureSubScreen(
                anchorPoint: split.anchorPoint,
                child: dialog,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 설정 대화상자 경로 — `showDialog`가 만드는 [DialogRoute]이고, 경로가 나누는 접힘선을 배치와 맞춘다(창을 가로지르는
/// 접힘선이 2개 이상인 화면은 나누지 않는다, [SettingsLauncher] "접힘선이 2개 이상인 화면", #198).
class _SettingsDialogRoute extends DialogRoute<void> {
  _SettingsDialogRoute({
    required super.context,
    required super.builder,
    super.themes,
    super.barrierColor,
    super.useSafeArea,
    super.anchorPoint,
    super.traversalEdgeBehavior,
  });

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _LayoutHingesOnly(
    child: super.buildPage(context, animation, secondaryAnimation),
  );
}

/// 경로 페이지([child] — Flutter `DisplayFeatureSubScreen`을 품는다)에 [SettingsLauncher.dialogRouteMediaOf]의
/// MediaQuery를 준다 — 페이지는 배치가 쓰는 접힘선으로만 나누고, 접힘선이 2개 이상인 화면은 나누지 않는다.
///
/// 페이지의 빌더가 아니라 이 위젯이 MediaQuery에 의존한다 — 접힘 정보가 바뀌면(열린 채 펴거나 접음) 같은 프레임에 이
/// 위젯만 다시 그린다. 이 위젯은 어느 화면이든 같은 구조다(대화상자 element는 안쪽 나눔이 바뀌어도 [GlobalKey]로 옮겨
/// 가 유지된다 — `_open`).
class _LayoutHingesOnly extends StatelessWidget {
  final Widget child;

  const _LayoutHingesOnly({required this.child});

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: SettingsLauncher.dialogRouteMediaOf(MediaQuery.of(context)),
    child: child,
  );
}

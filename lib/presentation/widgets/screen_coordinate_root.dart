import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [MediaQuery]가 정의하는 화면 영역의 좌표 원점을 표시한다 (#50).
///
/// `MediaQuery.size`·`systemGestureInsets`는 그 MediaQuery가 가리키는 화면 영역의 좌표로 주어진다.
/// 실제 앱에서는 MediaQuery가 View(기기 창)에서 오므로 전역 좌표가 곧 화면 좌표지만, 화면을 흉내 내는
/// 곳(개발용 미리보기의 기기 틀 등)에서는 화면이 원점이 아닌 곳에 있거나 축소되어 두 좌표가 어긋난다.
/// 그런 곳에서 MediaQuery를 덮어쓸 때 그 바로 아래에 이 위젯을 두면, 하위 위젯이 전역 좌표를
/// [ScreenCoordinateRoot.globalToScreen]으로 화면 좌표로 바꿀 수 있다(이동·축소·회전 모두 반영).
///
/// ## 배치 계약
/// - 덮어쓴 `MediaQuery.size`와 **같은 크기·위치**의 영역을 덮도록 둔다(보통 MediaQuery의 바로 아래).
///   SafeArea·Padding 안쪽처럼 더 작은 영역에 두면 가장자리 판정이 틀어진다(디버그 모드에서 assert).
/// - 실제 앱의 화면 루트에는 두지 않는다 — 전역 좌표가 이미 화면 좌표이고, 화면 전환 애니메이션 중
///   밀려나는 라우트 기준이 아니라 기기 가장자리 기준으로 판정해야 하기 때문이다.
/// - 여러 겹이면 가장 가까운 조상이 기준이다.
///
/// 레이아웃·그리기·히트 테스트에는 영향을 주지 않는다(투명한 프록시).
class ScreenCoordinateRoot extends SingleChildRenderObjectWidget {
  const ScreenCoordinateRoot({super.key, super.child});

  /// [context]가 속한 화면 영역의 좌표로 [globalPosition]을 바꾼다.
  ///
  /// 조상에 [ScreenCoordinateRoot]가 없거나 아직 배치되지 않았으면 전역 좌표를 그대로 돌려준다
  /// (실제 앱: View 좌표 = 화면 좌표).
  static Offset globalToScreen(BuildContext context, Offset globalPosition) {
    final root = context
        .findAncestorRenderObjectOfType<RenderScreenCoordinateRoot>();
    if (root == null || !root.attached || !root.hasSize) return globalPosition;
    assert(
      _sizeMatches(root.size, MediaQuery.sizeOf(context)),
      'ScreenCoordinateRoot 크기(${root.size})가 MediaQuery.size'
      '(${MediaQuery.sizeOf(context)})와 다르다. 덮어쓴 MediaQuery의 영역 전체를 덮도록 배치한다.',
    );
    return root.globalToLocal(globalPosition);
  }

  /// 레이아웃 반올림 오차를 허용해 두 크기가 같은지 본다.
  static bool _sizeMatches(Size a, Size b) =>
      (a.width - b.width).abs() < 0.5 && (a.height - b.height).abs() < 0.5;

  @override
  RenderScreenCoordinateRoot createRenderObject(BuildContext context) =>
      RenderScreenCoordinateRoot();
}

/// [ScreenCoordinateRoot]의 렌더 객체 — 자식을 그대로 감싸는 표식이다.
class RenderScreenCoordinateRoot extends RenderProxyBox {
  RenderScreenCoordinateRoot([super.child]);
}

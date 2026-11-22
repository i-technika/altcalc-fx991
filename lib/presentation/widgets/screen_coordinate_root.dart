import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 화면을 흉내 내는 영역에 [MediaQuery]와 그 화면의 좌표 원점을 함께 제공한다 (#50).
///
/// `MediaQuery.size`·`systemGestureInsets`는 그 MediaQuery가 가리키는 화면 영역의 좌표로 주어진다.
/// 실제 앱에서는 MediaQuery가 View(기기 창)에서 오므로 전역 좌표가 곧 화면 좌표지만, 화면을 흉내 내는
/// 곳(개발용 미리보기의 기기 틀 등)에서는 화면이 원점이 아닌 곳에 있거나 축소되어 두 좌표가 어긋난다.
/// 이 위젯은 [data]로 MediaQuery를 덮어쓰면서 같은 영역을 좌표 원점으로 표시해, 하위 위젯이 전역 좌표를
/// [ScreenCoordinateRoot.globalToScreen]으로 그 화면의 좌표로 바꿀 수 있게 한다(이동·축소 반영).
///
/// ## 배치 계약
/// - 이 위젯이 받는 크기는 `data.size`와 같아야 한다(예: `SizedBox.fromSize(size: data.size)` 안).
///   다르면 가장자리 판정이 틀어지므로 디버그 모드에서 첫 레이아웃 때 assert로 알린다.
/// - 이 아래에서 `size`·`systemGestureInsets`를 바꾸는 MediaQuery 덮어쓰기를 하지 않는다.
///   (SafeArea·Scaffold의 `removePadding` 등 padding만 바꾸는 덮어쓰기는 괜찮다.)
/// - **실제 앱에서는 쓰지 않는다** — 개발용 미리보기·테스트처럼 화면을 흉내 내는 곳 전용이다.
///   실제 앱은 전역 좌표가 이미 화면 좌표이고, 화면 전환 애니메이션 중에도 밀려나는 라우트가 아니라
///   기기 가장자리 기준으로 판정해야 하기 때문이다. 같은 이유로 앱 안의 분할 배치(#24·#25)에서도
///   영역마다 `size`·`systemGestureInsets`를 덮어쓰지 말고 View의 MediaQuery를 그대로 물려준다.
/// - 여러 겹이면 가장 가까운 조상이 기준이다.
class ScreenCoordinateRoot extends StatelessWidget {
  /// 흉내 낼 화면의 MediaQuery (크기·인셋·시스템 제스처 영역·글자 배율 등)
  final MediaQueryData data;

  final Widget child;

  const ScreenCoordinateRoot({
    super.key,
    required this.data,
    required this.child,
  });

  /// [context]가 속한 화면의 좌표로 [globalPosition]을 바꾼다.
  ///
  /// 조상에 [ScreenCoordinateRoot]가 없거나 아직 배치되지 않았으면 전역 좌표를 그대로 돌려준다
  /// (실제 앱: View 좌표 = 화면 좌표). 의존성을 등록하지 않으므로 이벤트 처리 중에 불러도 된다.
  static Offset globalToScreen(BuildContext context, Offset globalPosition) {
    final scope = context
        .getElementForInheritedWidgetOfExactType<_ScreenCoordinateScope>();
    final root = scope?.findRenderObject();
    if (root is! RenderBox || !root.attached || !root.hasSize) {
      return globalPosition;
    }
    return root.globalToLocal(globalPosition);
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: data,
      child: _ScreenCoordinateScope(
        child: _ScreenCoordinateMarker(expectedSize: data.size, child: child),
      ),
    );
  }
}

/// 루트 조회용 스코프 — 바로 아래 렌더 객체([_RenderScreenCoordinateMarker])가 좌표 원점이다.
class _ScreenCoordinateScope extends InheritedWidget {
  const _ScreenCoordinateScope({required super.child});

  @override
  bool updateShouldNotify(_ScreenCoordinateScope oldWidget) => false;
}

/// 좌표 원점 렌더 객체를 만들고, 받은 크기가 MediaQuery 크기와 같은지 디버그 모드에서 확인한다.
class _ScreenCoordinateMarker extends SingleChildRenderObjectWidget {
  final Size expectedSize;

  const _ScreenCoordinateMarker({required this.expectedSize, super.child});

  @override
  _RenderScreenCoordinateMarker createRenderObject(BuildContext context) =>
      _RenderScreenCoordinateMarker(expectedSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderScreenCoordinateMarker renderObject,
  ) {
    renderObject.expectedSize = expectedSize;
  }
}

/// 자식을 그대로 감싸는 표식 렌더 객체 (레이아웃·그리기·히트 테스트에 영향 없음)
class _RenderScreenCoordinateMarker extends RenderProxyBox {
  _RenderScreenCoordinateMarker(this._expectedSize);

  Size _expectedSize;
  set expectedSize(Size value) {
    if (value == _expectedSize) return;
    _expectedSize = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    assert(() {
      // 레이아웃 반올림 오차는 허용한다.
      final matches =
          (size.width - _expectedSize.width).abs() < 0.5 &&
          (size.height - _expectedSize.height).abs() < 0.5;
      if (!matches) {
        throw FlutterError(
          'ScreenCoordinateRoot 크기($size)가 MediaQuery.size($_expectedSize)와 다르다.\n'
          '흉내 내는 화면 크기와 같은 영역(예: SizedBox.fromSize(size: data.size)) 안에 둔다.',
        );
      }
      return true;
    }());
  }
}

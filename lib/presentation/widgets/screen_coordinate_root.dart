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
///   다르면 가장자리 판정이 틀어지므로 디버그 모드에서 레이아웃할 때마다 확인해 assert로 알린다.
/// - 이 아래에서 `size`·`systemGestureInsets`를 바꾸는 MediaQuery 덮어쓰기를 하지 않는다.
///   (SafeArea·Scaffold의 `removePadding` 등 padding만 바꾸는 덮어쓰기는 괜찮다.)
///   디버그 모드에서 [globalToScreen]이 불릴 때 확인해 오류로 보고한다(입력 처리는 계속한다).
/// - 위젯 배치는 **실제 앱에서 하지 않는다** — 개발용 미리보기·테스트처럼 화면을 흉내 내는 곳 전용이다.
///   실제 앱은 전역 좌표가 이미 화면 좌표이고, 화면 전환 애니메이션 중에도 밀려나는 라우트가 아니라
///   기기 가장자리 기준으로 판정해야 하기 때문이다. 같은 이유로 앱 안의 분할 배치(#24·#25)에서도
///   영역마다 `size`·`systemGestureInsets`를 덮어쓰지 말고 View의 MediaQuery를 그대로 물려준다.
/// - 여러 겹이면 가장 가까운 조상이 기준이다.
/// - 전역 좌표를 이 화면의 MediaQuery 기하 값(`systemGestureInsets`, `displayFeatures`의 힌지 영역 등)과
///   비교하는 코드는 모두 [globalToScreen]을 거쳐야 미리보기에서도 맞는다.
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
  ///
  /// 디버그 모드에서는 [context]의 `MediaQuery.size`가 기준 화면(루트가 있으면 루트, 없으면 View)의
  /// 크기와 같은지 확인해, 다르면 배치 계약 위반으로 보고한다. 이벤트 처리를 끊지 않도록 예외를
  /// 던지지 않고 [FlutterError.reportError]로 알린다.
  static Offset globalToScreen(BuildContext context, Offset globalPosition) {
    final scope = context
        .getElementForInheritedWidgetOfExactType<_ScreenCoordinateScope>();
    final marker = scope?.findRenderObject();
    final root = marker is RenderBox && marker.attached && marker.hasSize
        ? marker
        : null;
    assert(_debugCheckScreenSize(context, root));
    return root == null ? globalPosition : root.globalToLocal(globalPosition);
  }

  /// `MediaQuery.size`가 기준 화면 크기와 다르면 오류를 보고한다 (디버그 전용, 항상 `true`).
  static bool _debugCheckScreenSize(BuildContext context, RenderBox? root) {
    final actual = MediaQuery.maybeSizeOf(context);
    final view = View.maybeOf(context);
    if (actual == null || (root == null && view == null)) return true;
    final Size expected;
    final String basis;
    if (root != null) {
      expected = root.size;
      basis = 'ScreenCoordinateRoot';
    } else {
      expected = view!.physicalSize / view.devicePixelRatio;
      basis = 'View(루트 없음)';
    }
    if (!_sameSize(actual, expected, _viewSizeTolerance)) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError(
            'MediaQuery.size($actual)가 기준 화면 $basis의 크기($expected)와 다르다.\n'
            '키 위쪽에서 size·systemGestureInsets를 영역 기준으로 덮어쓰면 시스템 제스처 영역 판정이 '
            '틀어진다. 분할 배치에서는 View의 MediaQuery를 그대로 물려주고, 화면을 흉내 내는 곳은 '
            'ScreenCoordinateRoot를 쓴다.',
          ),
          library: 'altcalc screen coordinates',
          context: ErrorDescription('시스템 제스처 영역 판정 중'),
        ),
      );
    }
    return true;
  }

  /// 레이아웃 크기와 MediaQuery 크기를 비교할 때의 부동소수 오차 허용치 (dp)
  static const double _layoutSizeTolerance = 1e-10;

  /// View 크기(물리 픽셀 ÷ 배율)와 비교할 때의 부동소수 오차 허용치 (dp)
  static const double _viewSizeTolerance = 1e-6;

  static bool _sameSize(Size a, Size b, double tolerance) =>
      (a.width - b.width).abs() <= tolerance &&
      (a.height - b.height).abs() <= tolerance;

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
      // Flutter 레이아웃은 크기를 반올림하지 않으므로(tight 제약이면 그대로) 부동소수 오차만 허용한다.
      final matches = ScreenCoordinateRoot._sameSize(
        size,
        _expectedSize,
        ScreenCoordinateRoot._layoutSizeTolerance,
      );
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

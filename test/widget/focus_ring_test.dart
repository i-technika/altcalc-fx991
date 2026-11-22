import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/focus_ring.dart';
import 'package:material_ui/material_ui.dart';

// FocusRing 단독 위젯 테스트 (#106 R2) — 앱 화면에서의 대비·배치는 material_theme_test.dart가 본다.

const _ringColor = CalcTheme.materialFocusRingStandard;
const _width = CalcTheme.materialFocusRingWidth;

/// 포커스 표시를 키보드 조작 중으로 둔다.
void _keyboardMode() {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: CalcTheme.materialTheme,
    home: Scaffold(body: Center(child: child)),
  ),
);

RenderFocusRing _ring(WidgetTester tester) =>
    tester.renderObject<RenderFocusRing>(find.byKey(FocusRing.ringKey));

/// 테두리 영역 (화면 좌표, 그리지 않으면 `null`)
Rect? _ringRect(WidgetTester tester) {
  final ring = _ring(tester);
  final rect = ring.ringRect;
  return rect == null
      ? null
      : MatrixUtils.transformRect(ring.getTransformTo(null), rect);
}

/// [finder] 위젯 안 InkWell에 포커스를 준다.
Future<void> _focus(WidgetTester tester, Finder finder) async {
  Focus.of(
    tester.element(
      find.descendant(of: finder, matching: find.byType(Text)).first,
    ),
  ).requestFocus();
  await tester.pumpAndSettle();
}

/// [rect](화면 좌표)에 StadiumBorder 테두리를 실제로 그리는지 — StadiumBorder.paint와 같은 계산
/// (안쪽 정렬 선: 선 중심이 가장자리에서 굵기의 절반 안쪽)
PaintPattern _paintsStadiumAt(WidgetTester tester, Rect rect) {
  final local = rect.shift(-_ring(tester).localToGlobal(Offset.zero));
  return paints..rrect(
    rrect: RRect.fromRectAndRadius(
      local,
      Radius.circular(local.shortestSide / 2),
    ).deflate(_width / 2),
    color: _ringColor,
    style: PaintingStyle.stroke,
  );
}

Finder _materialOf(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(Material)).first;

void main() {
  const a = ValueKey('a');
  const b = ValueKey('b');

  testWidgets('터치 여백이 있는 버튼은 보이는 면(Material)에 맞춰 그 자리에 실제로 그린다', (
    tester,
  ) async {
    _keyboardMode();
    await _pump(
      tester,
      FocusRing(
        shape: const StadiumBorder(),
        child: TextButton(key: a, onPressed: () {}, child: const Text('a')),
      ),
    );
    await _focus(tester, find.byKey(a));
    final visible = tester.getRect(_materialOf(a));
    // 터치 영역(위젯)이 보이는 면보다 커야 이 검사가 의미 있다
    expect(visible.height, lessThan(tester.getSize(find.byKey(a)).height));
    expect(_ringRect(tester), visible);
    // 영역 계산뿐 아니라 실제 그리기 호출도 그 자리다 (자식 전체에 그리면 실패한다)
    expect(find.byKey(FocusRing.ringKey), _paintsStadiumAt(tester, visible));
  });

  testWidgets('포커스를 가진 자식이 다른 위젯으로 바뀌는 프레임에도 예외 없이 그린다', (tester) async {
    _keyboardMode();
    Widget build(bool first) => FocusRing(
      shape: const StadiumBorder(),
      child: first
          ? TextButton(key: a, onPressed: () {}, child: const Text('a'))
          : OutlinedButton(key: b, onPressed: () {}, child: const Text('b')),
    );
    await _pump(tester, build(true));
    await _focus(tester, find.byKey(a));
    expect(_ringRect(tester), isNotNull);
    await _pump(tester, build(false));
    expect(tester.takeException(), isNull);
    // 옛 노드의 포커스는 사라졌고 새 버튼은 포커스가 없다
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_ringRect(tester), isNull);
  });

  testWidgets('자식 안에서 포커스가 다른 노드로 옮겨 가면 테두리도 따라간다', (tester) async {
    _keyboardMode();
    await _pump(
      tester,
      FocusRing(
        shape: const StadiumBorder(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(key: a, onPressed: () {}, child: const Text('a')),
            TextButton(key: b, onPressed: () {}, child: const Text('b')),
          ],
        ),
      ),
    );
    await _focus(tester, find.byKey(a));
    expect(_ringRect(tester), tester.getRect(_materialOf(a)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final second = tester.getRect(_materialOf(b));
    expect(_ringRect(tester), second);
    expect(find.byKey(FocusRing.ringKey), _paintsStadiumAt(tester, second));
  });

  testWidgets('포커스 노드가 자식 렌더 트리 밖(Overlay)에 그려지면 테두리를 그리지 않는다', (tester) async {
    _keyboardMode();
    final controller = OverlayPortalController()..show();
    await _pump(
      tester,
      FocusRing(
        child: SizedBox(
          width: 200,
          height: 60,
          child: OverlayPortal(
            controller: controller,
            overlayChildBuilder: (_) => Positioned(
              left: 0,
              top: 0,
              child: TextButton(
                key: a,
                onPressed: () {},
                child: const Text('a'),
              ),
            ),
          ),
        ),
      ),
    );
    await _focus(tester, find.byKey(a));
    // 포커스는 FocusRing 안(포커스 트리)에 있지만 렌더 박스는 Overlay에 있다
    expect(
      Focus.of(tester.element(find.byKey(FocusRing.ringKey))).hasFocus,
      isTrue,
    );
    expect(_ringRect(tester), isNull);
    expect(
      find.byKey(FocusRing.ringKey),
      isNot(paints..drrect(color: _ringColor)),
    );
  });

  testWidgets('포커스 노드와 FocusRing 사이에 RepaintBoundary가 있으면 디버그 빌드에서 알린다', (
    tester,
  ) async {
    _keyboardMode();
    await _pump(
      tester,
      FocusRing(
        child: RepaintBoundary(
          child: TextButton(key: a, onPressed: () {}, child: const Text('a')),
        ),
      ),
    );
    await _focus(tester, find.byKey(a));
    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect('$error', contains('RepaintBoundary'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/screen_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// `showScreenDialog`는 가장 가까운 Navigator에 대화상자를 띄운다 (#72).
void main() {
  const innerKey = ValueKey('inner-screen');
  const dialogKey = ValueKey('dialog');

  /// 루트 Navigator 안 오른쪽 절반에 중첩 Navigator(흉내 낸 화면)를 둔다.
  Widget host() => MaterialApp(
    home: Row(
      children: [
        const Expanded(child: ColoredBox(color: Colors.black)),
        Expanded(
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 600),
              textScaler: TextScaler.linear(1.5),
            ),
            child: SizedBox(
              key: innerKey,
              child: Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute<void>(
                  builder: (context) => Center(
                    child: ElevatedButton(
                      onPressed: () => showScreenDialog<void>(
                        context: context,
                        builder: (_) =>
                            const AlertDialog(key: dialogKey, title: Text('t')),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  testWidgets('중첩 Navigator 안에 뜨고 그 영역의 MediaQuery를 물려받는다', (tester) async {
    tester.view.physicalSize =
        const Size(800, 600) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final inner = tester.getRect(find.byKey(innerKey));
    final card = tester.getRect(
      find
          .descendant(
            of: find.byKey(dialogKey),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(inner.left, 400);
    expect(card.left, greaterThanOrEqualTo(inner.left));
    expect(card.center.dx, moreOrLessEquals(inner.center.dx, epsilon: 0.5));
    expect(
      MediaQuery.textScalerOf(tester.element(find.byKey(dialogKey))),
      const TextScaler.linear(1.5),
    );

    // 장벽은 중첩 화면만 덮는다 — 왼쪽 절반을 눌러도 닫히지 않고, 오른쪽 장벽을 누르면 닫힌다.
    await tester.tapAt(const Offset(100, 300));
    await tester.pumpAndSettle();
    expect(find.byKey(dialogKey), findsOneWidget);
    await tester.tapAt(Offset(inner.left + 5, inner.top + 5));
    await tester.pumpAndSettle();
    expect(find.byKey(dialogKey), findsNothing);
  });
}

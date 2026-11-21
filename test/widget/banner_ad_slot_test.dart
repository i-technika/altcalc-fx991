import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/banner_ad_slot.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(
  WidgetTester tester,
  BannerAdSlot slot, {
  Size screen = const Size(400, 800),
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: screen, padding: padding),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(width: 400, child: slot),
        ),
      ),
    ),
  );
}

final _slot = find.byKey(const ValueKey('banner-ad-slot'));
final _background = find.byKey(const ValueKey('banner-ad-slot-background'));

void main() {
  group('높이', () {
    testWidgets('폰 화면 기본값: 슬롯 adSlotHeight + 안전 여백', (tester) async {
      await _pump(tester, const BannerAdSlot());
      expect(tester.getSize(_slot).height, CalcTheme.adSlotHeight);
      expect(
        tester.getSize(find.byType(BannerAdSlot)).height,
        CalcTheme.adSlotHeight + CalcTheme.adSlotSafetyMargin,
      );
    });

    testWidgets('대형 화면 기본값: adSlotMaxHeight', (tester) async {
      await _pump(tester, const BannerAdSlot(), screen: const Size(800, 1280));
      expect(tester.getSize(_slot).height, CalcTheme.adSlotMaxHeight);
    });

    testWidgets('주입한 높이는 기본값 범위(50~60dp)를 넘어도 그대로 쓴다 (적응형 배너, #18)', (
      tester,
    ) async {
      await _pump(tester, const BannerAdSlot(height: 90));
      expect(tester.getSize(_slot).height, 90);
    });

    test('defaultHeightFor는 짧은 변 기준으로 판정한다', () {
      expect(
        BannerAdSlot.defaultHeightFor(const Size(400, 900)),
        CalcTheme.adSlotHeight,
      );
      // 가로 폰: 긴 변이 600 이상이어도 짧은 변이 작으면 폰이다.
      expect(
        BannerAdSlot.defaultHeightFor(const Size(900, 400)),
        CalcTheme.adSlotHeight,
      );
      expect(
        BannerAdSlot.defaultHeightFor(
          const Size.square(CalcTheme.adSlotLargeScreenShortestSide),
        ),
        CalcTheme.adSlotMaxHeight,
      );
    });

    testWidgets('광고가 없어도(child null) 같은 높이를 유지한다', (tester) async {
      await _pump(tester, const BannerAdSlot());
      final empty = tester.getSize(find.byType(BannerAdSlot));
      await _pump(
        tester,
        const BannerAdSlot(child: SizedBox(width: 320, height: 50)),
      );
      expect(tester.getSize(find.byType(BannerAdSlot)), empty);
    });
  });

  group('안전 여백', () {
    testWidgets('슬롯 위에 safetyMargin만큼 비어 있다', (tester) async {
      await _pump(tester, const BannerAdSlot(safetyMargin: 12));
      final whole = tester.getRect(find.byType(BannerAdSlot));
      final bg = tester.getRect(_background);
      expect(bg.top - whole.top, 12);
    });

    test('안전 여백이 하한보다 작으면 assert로 막는다', () {
      expect(
        () => BannerAdSlot(safetyMargin: CalcTheme.adSlotMinSafetyMargin - 1),
        throwsAssertionError,
      );
    });

    test('높이가 0 이하면 assert로 막는다', () {
      expect(() => BannerAdSlot(height: 0), throwsAssertionError);
    });
  });

  group('배치', () {
    testWidgets('하단 시스템 인셋만큼 배경을 늘리고 슬롯은 그 위에 둔다', (tester) async {
      await _pump(
        tester,
        const BannerAdSlot(),
        padding: const EdgeInsets.only(bottom: 34),
      );
      expect(tester.getSize(_background).height, CalcTheme.adSlotHeight + 34);
      expect(
        tester.getRect(_background).bottom - tester.getRect(_slot).bottom,
        34,
      );
    });

    testWidgets('가로 모드 좌우 시스템 인셋만큼 광고를 안쪽으로 들인다', (tester) async {
      await _pump(
        tester,
        const BannerAdSlot(),
        padding: const EdgeInsets.only(left: 24, right: 48),
      );
      final bg = tester.getRect(_background);
      final slot = tester.getRect(_slot);
      expect(slot.left - bg.left, 24);
      expect(bg.right - slot.right, 48);
    });

    testWidgets('광고는 슬롯 가운데에 놓이고 슬롯 크기를 넘지 않으며 잘리지 않는다', (tester) async {
      const adKey = ValueKey('ad');
      await _pump(
        tester,
        const BannerAdSlot(
          child: SizedBox(key: adKey, width: 320, height: 200),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getCenter(find.byKey(adKey)), tester.getCenter(_slot));
      // 큰 광고는 자르지 않고 슬롯 크기로 제약한다 (AdMob 정책: 광고를 잘라 가리지 않는다).
      expect(tester.getSize(find.byKey(adKey)).height, CalcTheme.adSlotHeight);
      expect(
        find.ancestor(of: find.byKey(adKey), matching: find.byType(ClipRect)),
        findsNothing,
      );
    });

    testWidgets('안전 여백을 누른 터치는 뒤쪽 위젯이나 광고로 전달되지 않는다', (tester) async {
      var behindTaps = 0;
      var adTaps = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => behindTaps++,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: BannerAdSlot(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => adTaps++,
                      child: const SizedBox(width: 320, height: 50),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final margin = find.byKey(const ValueKey('banner-ad-slot-safety-margin'));
      await tester.tapAt(tester.getCenter(margin));
      await tester.pump();
      expect(behindTaps, 0);
      expect(adTaps, 0);
      // 대조: 여백 밖(위쪽)은 뒤쪽 위젯이 받는다.
      await tester.tapAt(const Offset(200, 100));
      await tester.pump();
      expect(behindTaps, 1);
    });

    testWidgets('부모 너비를 가득 채운다', (tester) async {
      await _pump(tester, const BannerAdSlot());
      expect(tester.getSize(_slot).width, 400);
    });
  });
}

import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/handedness_dialog.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/lcd_display.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/settings_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/top_strip.dart';
import 'package:material_ui/material_ui.dart';

import '../support/korean_locale.dart';
import '../support/screen_arrangement.dart';

/// LCD 위 상단 띠 (#41): 설정 버튼·워드마크·태양전지 장식의 배치 규칙과 화면비별 표시/숨김.

final _lcd = find.byType(LcdDisplay);
final _keypad = find.byKey(const ValueKey('calc-keypad'));
final _button = find.byKey(SettingsButton.buttonKey);
final _touch = find.byKey(SettingsButton.touchExtensionKey);
final _wordmark = find.byKey(TopStripDecoration.wordmarkKey);
final _solar = find.byKey(TopStripDecoration.solarPanelKey);
final _dialog = find.byType(HandednessDialog);

const _tolerance = 0.01;

/// [size] 창·[padding] 인셋으로 [CalculatorScreen]을 띄운다. 같은 테스트에서 [container]를 넘겨 다시 부르면
/// 창만 바꿔 다시 그린다.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Size size,
  EdgeInsets padding = EdgeInsets.zero,
  double textScale = 1.0,
  bool highContrast = false,
  List<DisplayFeature> displayFeatures = const [],
  ProviderContainer? container,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  tester.view.displayFeatures = displayFeatures;
  addTearDown(tester.view.resetDisplayFeatures);
  if (container == null) {
    container = ProviderContainer();
    addTearDown(container.dispose);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: padding,
            viewPadding: padding,
            textScaler: TextScaler.linear(textScale),
            highContrast: highContrast,
            displayFeatures: displayFeatures,
          ),
          child: const CalculatorScreen(),
        ),
      ),
    ),
  );
  return container;
}

/// 본체 크기 [body]의 위아래 배치에서 LCD 영역 (본체 좌표)
Rect _stackedLcd(Size body) {
  final l = CalcScreenLayout.of(body);
  return Rect.fromLTWH(l.lcdLeft, l.top, l.lcdWidth, l.lcdHeight);
}

/// 창 [size]·인셋(위 [top], 아래 [bottom])의 본체 크기 — 좌우 화면 여백, 위 화면 여백, 광고 슬롯·안전 여백 제외
Size _bodyOf(Size size, {double top = 0, double bottom = 0}) => Size(
  size.width - 2 * CalcTheme.screenPadding,
  size.height -
      top -
      bottom -
      CalcTheme.screenPadding -
      CalcTheme.adSlotHeight -
      CalcTheme.adSlotSafetyMargin,
);

void main() {
  group('띠 배치 계산 (CalcTopStripLayout)', () {
    const button = CalcTheme.settingsButtonSize;
    const pad = CalcTheme.screenPadding;

    test(
      '최소 띠(줄 20dp): 아이콘이 줄어들고, 터치 영역은 줄 윗변에서 48dp로 LCD 위에 겹치며, 워드마크만 그린다',
      () {
        // iPhone 390×844 (인셋 47/34): 남는 높이가 없어 띠는 최소 높이 12dp
        final body = _bodyOf(const Size(390, 844), top: 47, bottom: 34);
        final lcd = _stackedLcd(body);
        expect(lcd.top, CalcTheme.screenTopStripMinHeight);
        final s = CalcTopStripLayout.of(body, lcd);

        expect(s.row, Rect.fromLTRB(0, -pad, body.width, lcd.top));
        expect(s.row.height, 20);
        expect(
          s.settingsButton,
          Rect.fromLTWH(body.width - button, -pad, button, button),
        );
        expect(s.settingsButton!.bottom, greaterThan(lcd.top)); // LCD 위에 겹친다
        expect(s.settingsVisualHeight, 20);
        expect(s.settingsIconSize, CalcTheme.settingsIconMinSize);
        expect(s.wordmark, Rect.fromLTWH(4, -pad, body.width * 0.4, 20));
        expect(s.wordmarkFontSize, 10);
        expect(s.solarPanel, isNull);
      },
    );

    test('줄이 태양전지 최소 높이보다 낮으면 워드마크만 그리고, 아이콘은 기본 크기다', () {
      // 360×800 (인셋 24/24): 남는 높이 약 20.8dp → 줄 약 28.8dp
      final body = _bodyOf(const Size(360, 800), top: 24, bottom: 24);
      final lcd = _stackedLcd(body);
      final s = CalcTopStripLayout.of(body, lcd);
      expect(s.row.height, moreOrLessEquals(lcd.top + pad));
      expect(
        s.row.height,
        inExclusiveRange(26, CalcTheme.topStripSolarMinHeight),
      );
      expect(s.settingsIconSize, CalcTheme.settingsIconSize);
      expect(s.wordmark, isNotNull);
      expect(s.wordmarkFontSize, moreOrLessEquals(s.row.height * 0.5));
      expect(s.solarPanel, isNull);
    });

    test('줄이 태양전지 최소 높이 이상이면 설정 버튼 왼쪽에 태양전지를 그린다', () {
      // 412×915 (인셋 24/24): 남는 높이 약 36.7dp → 줄 약 44.7dp (버튼보다 낮다)
      final body = _bodyOf(const Size(412, 915), top: 24, bottom: 24);
      final lcd = _stackedLcd(body);
      final s = CalcTopStripLayout.of(body, lcd);
      final row = s.row;
      expect(
        row.height,
        inInclusiveRange(CalcTheme.topStripSolarMinHeight, 48),
      );
      final solar = s.solarPanel!;
      expect(solar.height, moreOrLessEquals(row.height * 0.5));
      expect(solar.width, moreOrLessEquals(solar.height * 3));
      expect(solar.center.dy, moreOrLessEquals(row.center.dy));
      expect(
        solar.right,
        moreOrLessEquals(s.settingsButton!.left - CalcTheme.topStripGap),
      );
      expect(
        solar.left,
        greaterThanOrEqualTo(s.wordmark!.right + CalcTheme.topStripGap),
      );
      expect(s.wordmarkFontSize, CalcTheme.topStripWordmarkMaxFontSize);
      // 줄이 버튼보다 낮아 터치 영역은 아직 LCD 위에 겹친다.
      expect(s.settingsButton!.height, button);
      expect(s.settingsButton!.bottom, greaterThan(lcd.top));
    });

    test('높은 띠: 내용 줄은 48dp로 LCD 바로 위에 붙고, 설정 버튼은 줄 안에 있다', () {
      // 10인치 태블릿 세로 800×1280 (인셋 24/48): 남는 높이 약 218dp, LCD는 폭 480으로 가운데
      final body = _bodyOf(const Size(800, 1280), top: 24, bottom: 48);
      final lcd = _stackedLcd(body);
      expect(lcd.top, greaterThan(200));
      final s = CalcTopStripLayout.of(body, lcd);
      expect(
        s.row,
        Rect.fromLTWH(lcd.left, lcd.top - button, lcd.width, button),
      );
      expect(
        s.settingsButton,
        Rect.fromLTWH(lcd.right - button, lcd.top - button, button, button),
      );
      expect(s.settingsVisualHeight, button);
      expect(s.settingsIconSize, CalcTheme.settingsIconSize);
      expect(s.wordmark!.left, lcd.left + CalcTheme.topStripInset);
      expect(s.solarPanel, isNotNull);
    });

    test('LCD가 좁으면 워드마크·태양전지를 숨기고, 설정 버튼은 LCD 폭을 넘지 않는다', () {
      const body = Size(1000, 600);
      // 워드마크 자리 = min(100 × 0.4, 100 − 48 − 8 − 4) = 40 < 최소 48
      final narrow = CalcTopStripLayout.of(
        body,
        const Rect.fromLTWH(0, 100, 100, 200),
      );
      expect(narrow.wordmark, isNull);
      expect(narrow.solarPanel, isNull);
      expect(narrow.settingsButton!.width, button);

      final tiny = CalcTopStripLayout.of(
        body,
        const Rect.fromLTWH(0, 100, 30, 200),
      );
      expect(tiny.settingsButton!.width, 30);
      expect(tiny.wordmark, isNull);

      // 워드마크 자리는 있지만 태양전지가 워드마크와 간격 없이 붙으면 태양전지만 숨긴다.
      // 폭 200: 워드마크 4~84, 태양전지 폭 72 → 왼쪽 끝 200 − 48 − 8 − 72 = 72 < 84 + 8
      final crowded = CalcTopStripLayout.of(
        body,
        const Rect.fromLTWH(0, 100, 200, 200),
      );
      expect(crowded.wordmark, isNotNull);
      expect(crowded.solarPanel, isNull);
    });

    test('설정 버튼이 다른 곳에 있는 배치: 띠에 버튼을 두지 않고 태양전지를 줄 오른쪽 끝에 둔다', () {
      const body = Size(1000, 900);
      const lcd = Rect.fromLTWH(20, 260, 480, 274);
      const elsewhere = Rect.fromLTWH(20, 542, 48, 48); // LCD 아래 (좌우 분할)
      final s = CalcTopStripLayout.of(body, lcd, settingsButton: elsewhere);
      expect(s.settingsButton, isNull);
      expect(s.row, const Rect.fromLTWH(20, 212, 480, 48));
      expect(s.wordmark, isNotNull);
      expect(
        s.solarPanel!.right,
        moreOrLessEquals(lcd.right - CalcTheme.topStripInset),
      );
    });

    test('다른 곳의 설정 버튼과 장식 줄이 겹치면(간격 포함) 장식을 모두 숨긴다', () {
      const body = Size(400, 400);
      // 테이블톱 위 절반 모서리의 버튼(0,0,48,48)과 그 아래로 줄어든 LCD(윗변 56)
      const corner = Rect.fromLTWH(0, 0, 48, 48);
      final overlapping = CalcTopStripLayout.of(
        body,
        const Rect.fromLTWH(0, 56, 400, 200),
        settingsButton: corner,
      );
      expect(overlapping.wordmark, isNull);
      expect(overlapping.solarPanel, isNull);

      // 줄이 버튼에서 간격 이상 떨어지면 그린다 (LCD 윗변 48 + 간격 8 + 줄 48 = 104).
      final clear = CalcTopStripLayout.of(
        body,
        const Rect.fromLTWH(0, 104, 400, 200),
        settingsButton: corner,
      );
      expect(clear.wordmark, isNotNull);
      expect(clear.solarPanel, isNotNull);
    });

    test('불변식: 어떤 본체 크기에서도 띠 안의 것들이 줄 안에 있고 서로 겹치지 않는다', () {
      for (var width = 0.0; width <= 1100; width += 37) {
        for (var height = 0.0; height <= 1400; height += 41) {
          final body = Size(width, height);
          final lcd = _stackedLcd(body);
          final s = CalcTopStripLayout.of(body, lcd);
          final reason = '$body $s';
          final row = s.row;

          expect(row.bottom, moreOrLessEquals(lcd.top), reason: reason);
          expect(row.left, lcd.left, reason: reason);
          expect(row.width, lcd.width, reason: reason);
          expect(row.height, greaterThanOrEqualTo(pad), reason: reason);
          expect(row.height, lessThanOrEqualTo(button), reason: reason);
          expect(row.top, greaterThanOrEqualTo(-pad), reason: reason);
          expect(
            s.settingsIconSize,
            inInclusiveRange(
              CalcTheme.settingsIconMinSize,
              CalcTheme.settingsIconSize,
            ),
            reason: reason,
          );

          final b = s.settingsButton!;
          expect(b.top, row.top, reason: reason);
          expect(b.right, row.right, reason: reason);
          expect(b.left, greaterThanOrEqualTo(row.left), reason: reason);
          expect(b.height, lessThanOrEqualTo(button + 1e-9), reason: reason);
          // 터치 영역은 줄 아래로 넓어져도 본체 아래(광고 슬롯 쪽)로는 나가지 않는다.
          expect(
            b.bottom,
            lessThanOrEqualTo(
              (row.bottom > height ? row.bottom : height) + 1e-9,
            ),
            reason: reason,
          );

          final wordmark = s.wordmark;
          final solar = s.solarPanel;
          if (solar != null) expect(wordmark, isNotNull, reason: reason);
          for (final r in [wordmark, solar]) {
            if (r == null) continue;
            expect(r.left, greaterThanOrEqualTo(row.left), reason: reason);
            expect(r.top, greaterThanOrEqualTo(row.top - 1e-9), reason: reason);
            expect(
              r.bottom,
              lessThanOrEqualTo(row.bottom + 1e-9),
              reason: reason,
            );
            expect(
              r.right,
              lessThanOrEqualTo(b.left - CalcTheme.topStripGap + 1e-9),
              reason: reason,
            );
          }
          if (wordmark != null && solar != null) {
            expect(
              solar.left,
              greaterThanOrEqualTo(wordmark.right + CalcTheme.topStripGap),
              reason: reason,
            );
          }
        }
      }
    });

    test('불변식: 테이블톱 배치에서 장식은 다른 곳에 놓인 설정 버튼과 겹치지 않는다', () {
      var hidden = 0;
      var shown = 0;
      for (final width in const [320.0, 395.0, 480.0, 685.0, 825.0, 1000.0]) {
        for (var height = 300.0; height <= 1000; height += 50) {
          for (final ratio in const [0.25, 0.4, 0.5, 0.6]) {
            for (final handedness in Handedness.values) {
              final body = Size(width, height);
              final hinge = Rect.fromLTWH(0, height * ratio, width, 0);
              final l = CalcTabletopLayout.of(body, hinge, handedness);
              final s = CalcTopStripLayout.of(
                body,
                l.lcd,
                settingsButton: l.settingsButton,
              );
              final reason = '$body $hinge ${handedness.name} $l $s';
              expect(s.settingsButton, isNull, reason: reason);
              for (final r in [s.wordmark, s.solarPanel]) {
                if (r == null) continue;
                expect(r.overlaps(l.settingsButton), isFalse, reason: reason);
                expect(r.bottom, lessThanOrEqualTo(l.lcd.top), reason: reason);
              }
              s.wordmark == null ? hidden++ : shown++;
            }
          }
        }
      }
      // 두 경우를 모두 지나갔는지 (조합이 한쪽으로 쏠리면 위 검사가 의미를 잃는다)
      expect(hidden, greaterThan(0));
      expect(shown, greaterThan(0));
    });

    test('무한·NaN·음수 크기에서도 유한한 영역을 돌려준다', () {
      for (final (body, lcd) in [
        (Size.infinite, Rect.largest),
        (const Size(double.nan, double.nan), Rect.zero),
        (const Size(-10, -10), const Rect.fromLTWH(-5, -5, -10, -10)),
        (Size.zero, Rect.zero),
      ]) {
        final s = CalcTopStripLayout.of(body, lcd);
        for (final r in [s.row, s.settingsButton!]) {
          for (final v in [r.left, r.top, r.right, r.bottom]) {
            expect(v.isFinite, isTrue, reason: '$body $lcd $s');
          }
          expect(r.width, greaterThanOrEqualTo(0), reason: '$s');
          expect(r.height, greaterThanOrEqualTo(0), reason: '$s');
        }
        expect(s.wordmark, isNull, reason: '$s');
        expect(s.solarPanel, isNull, reason: '$s');
      }
    });
  });

  group('위아래 배치: 화면비별 띠 내용', () {
    // (이름, 창, 인셋, 워드마크, 태양전지, 터치 영역이 LCD 위에 겹치는지)
    const devices = [
      ('16:9 소형 320×568', Size(320, 568), EdgeInsets.zero, true, false, true),
      (
        'iPhone 390×844',
        Size(390, 844),
        EdgeInsets.only(top: 47, bottom: 34),
        true,
        false,
        true,
      ),
      (
        'iPhone Pro Max 430×932',
        Size(430, 932),
        EdgeInsets.only(top: 59, bottom: 34),
        true,
        false,
        true,
      ),
      (
        '20:9 360×800',
        Size(360, 800),
        EdgeInsets.only(top: 24, bottom: 24),
        true,
        false,
        true,
      ),
      (
        '412×915',
        Size(412, 915),
        EdgeInsets.only(top: 24, bottom: 24),
        true,
        true,
        true,
      ),
      (
        '21:9 411×960',
        Size(411, 960),
        EdgeInsets.only(top: 24, bottom: 24),
        true,
        true,
        false,
      ),
      (
        '폴더블 커버 344×882',
        Size(344, 882),
        EdgeInsets.only(top: 24, bottom: 24),
        true,
        true,
        false,
      ),
      (
        '태블릿 세로 800×1280',
        Size(800, 1280),
        EdgeInsets.only(top: 24, bottom: 48),
        true,
        true,
        false,
      ),
    ];

    for (final (name, size, padding, wordmark, solar, overlapsLcd) in devices) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$name·배율 $scale: 워드마크 ${wordmark ? '표시' : '숨김'}, '
            '태양전지 ${solar ? '표시' : '숨김'}, '
            '설정 버튼은 띠 오른쪽 끝', (tester) async {
          await _pump(tester, size: size, padding: padding, textScale: scale);
          expect(tester.takeException(), isNull);
          expect(isStackedArrangement(tester), isTrue);

          final lcd = tester.getRect(_lcd);
          final bandTop = padding.top; // 띠 윗변 = 상단 시스템 인셋 바로 아래
          final rowHeight = (lcd.top - bandTop).clamp(
            0.0,
            CalcTheme.topStripRowMaxHeight,
          );
          final rowTop = lcd.top - rowHeight;
          // 띠는 최소 높이 이상이다 — 화면 여백 8 + 최소 띠 12
          expect(
            rowHeight,
            greaterThanOrEqualTo(CalcTheme.topStripWordmarkMinHeight - 1e-9),
          );

          // 보이는 버튼: 줄 오른쪽 끝, 줄 높이 안 (LCD를 가리지 않는다)
          final button = tester.getRect(_button);
          expect(button.right, moreOrLessEquals(lcd.right));
          expect(button.width, moreOrLessEquals(CalcTheme.settingsButtonSize));
          expect(button.top, moreOrLessEquals(rowTop, epsilon: _tolerance));
          expect(button.bottom, moreOrLessEquals(lcd.top, epsilon: _tolerance));
          expect(_button.hitTestable(), findsOneWidget);
          final icon = tester.getRect(
            find.descendant(of: _button, matching: find.byType(Icon)),
          );
          expect(icon.top, greaterThanOrEqualTo(rowTop - _tolerance));
          expect(icon.bottom, lessThanOrEqualTo(lcd.top + _tolerance));
          expect(
            icon.center.dy,
            moreOrLessEquals(rowTop + rowHeight / 2, epsilon: _tolerance),
          );

          // 터치 영역: 줄 윗변에서 48dp 정사각형
          final touch = tester.getRect(_touch);
          expect(touch.top, moreOrLessEquals(rowTop, epsilon: _tolerance));
          expect(touch.right, moreOrLessEquals(lcd.right));
          expect(touch.width, moreOrLessEquals(CalcTheme.settingsButtonSize));
          expect(touch.height, moreOrLessEquals(CalcTheme.settingsButtonSize));
          expect(touch.bottom > lcd.top + _tolerance, overlapsLcd);
          // 키패드까지 내려가지는 않는다.
          expect(touch.bottom, lessThan(tester.getRect(_keypad).top));

          // 장식: 줄 안, 설정 버튼 왼쪽
          expect(_wordmark, wordmark ? findsOneWidget : findsNothing);
          expect(_solar, solar ? findsOneWidget : findsNothing);
          for (final finder in [_wordmark, _solar]) {
            if (finder.evaluate().isEmpty) continue;
            final r = tester.getRect(finder);
            expect(r.left, greaterThanOrEqualTo(lcd.left));
            expect(r.right, lessThanOrEqualTo(button.left));
            expect(r.top, greaterThanOrEqualTo(rowTop - _tolerance));
            expect(r.bottom, lessThanOrEqualTo(lcd.top + _tolerance));
          }
          if (wordmark && solar) {
            expect(
              tester.getRect(_wordmark).right,
              lessThanOrEqualTo(tester.getRect(_solar).left),
            );
          }
        });
      }
    }

    testWidgets('태양전지 장식은 칸 4개를 가로로 나란히 그린다', (tester) async {
      await _pump(
        tester,
        size: const Size(411, 960),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
      );
      final panel = tester.getRect(_solar);
      Rect? previous;
      for (var i = 0; i < CalcTheme.topStripSolarCellCount; i++) {
        final cell = tester.getRect(
          find.byKey(TopStripDecoration.solarCellKeyOf(i)),
        );
        expect(cell.width, greaterThan(0));
        expect(cell.height, greaterThan(0));
        expect(panel.contains(cell.topLeft), isTrue);
        expect(
          panel.contains(cell.bottomRight - const Offset(0.01, 0.01)),
          isTrue,
        );
        if (previous != null) expect(cell.left, greaterThan(previous.right));
        previous = cell;
      }
      expect(
        find.byKey(
          TopStripDecoration.solarCellKeyOf(CalcTheme.topStripSolarCellCount),
        ),
        findsNothing,
      );
    });

    testWidgets('워드마크는 앱 이름이고 CASIO 상표·모델명을 쓰지 않는다', (tester) async {
      await _pump(tester, size: const Size(390, 844));
      final text = tester.widget<Text>(_wordmark).data!;
      expect(text, TopStripDecoration.wordmarkText);
      expect(text, 'AltCalc');
      for (final banned in ['casio', 'fx', '991', 'classwiz']) {
        expect(text.toLowerCase(), isNot(contains(banned)));
      }
    });
  });

  group('설정 진입', () {
    const iphone = Size(390, 844);
    const iphoneInsets = EdgeInsets.only(top: 47, bottom: 34);

    testWidgets('낮은 띠: 보이는 아이콘을 눌러 설정을 연다', (tester) async {
      await _pump(tester, size: iphone, padding: iphoneInsets);
      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);
    });

    testWidgets('낮은 띠: LCD 위쪽에 겹친 터치 영역을 눌러도 설정이 열리고, 그 밖의 LCD는 열지 않는다', (
      tester,
    ) async {
      await _pump(tester, size: iphone, padding: iphoneInsets);
      final lcd = tester.getRect(_lcd);
      final touch = tester.getRect(_touch);
      expect(touch.bottom, greaterThan(lcd.top + 20));

      // 터치 영역 밖의 LCD (가운데, 터치 영역 바로 왼쪽·바로 아래)
      for (final point in [
        lcd.center,
        Offset(touch.left - 2, lcd.top + 10),
        Offset(touch.center.dx, touch.bottom + 2),
      ]) {
        await tester.tapAt(point);
        await tester.pumpAndSettle();
        expect(_dialog, findsNothing, reason: '$point');
      }

      // 보이는 버튼 아래, LCD 오른쪽 위에 겹친 곳
      await tester.tapAt(Offset(touch.center.dx, lcd.top + 10));
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);
    });

    testWidgets('높은 띠: 터치 영역이 LCD와 겹치지 않아 LCD 오른쪽 위를 눌러도 열리지 않는다', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(411, 960),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
      );
      final lcd = tester.getRect(_lcd);
      expect(
        tester.getRect(_touch).bottom,
        moreOrLessEquals(lcd.top, epsilon: _tolerance),
      );
      await tester.tapAt(Offset(lcd.right - 24, lcd.top + 10));
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);
      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);
    });

    testWidgets('대화상자는 이 설정이 적용되는 화면을 안내한다 (폰 화면에서는 달라지지 않는다)', (tester) async {
      await _pump(tester, size: iphone, padding: iphoneInsets);
      await tester.tap(_button);
      await tester.pumpAndSettle();
      // 테스트 기본 로캘(en_US)
      expect(
        tester.widget<Text>(find.byKey(HandednessDialog.noteKey)).data,
        'Applies to tablets in landscape and unfolded foldables. '
        'Nothing changes on a phone screen.',
      );
      // 폰의 위아래 배치에서는 손잡이를 바꿔도 배치가 그대로다.
      final lcd = tester.getRect(_lcd);
      final keypad = tester.getRect(_keypad);
      await tester.tap(
        find.byKey(HandednessDialog.optionKeyOf(Handedness.left)),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(_lcd), lcd);
      expect(tester.getRect(_keypad), keypad);
      expect(tester.takeException(), isNull);
    });

    testWidgets('한국어 기기에서는 안내 글이 한국어다', (tester) async {
      useKoreanLocale(tester);
      await _pump(tester, size: iphone, padding: iphoneInsets);
      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(HandednessDialog.noteKey)).data,
        '태블릿 가로 화면과 펼친 폴더블에 적용됩니다. 폰 화면에서는 달라지지 않습니다.',
      );
    });

    testWidgets('스크린리더: 설정 버튼은 하나이고 보이는 부분이 영역이며, 장식·넓힌 터치 영역은 읽히지 않는다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, size: iphone, padding: iphoneInsets);
      expect(
        tester.getSemantics(_button),
        isSemantics(tooltip: 'Settings', isButton: true, hasTapAction: true),
      );
      // 버튼의 시맨틱 영역은 보이는 부분(줄 높이)이라 LCD 상태 표시기의 영역을 가리지 않는다.
      final lcd = tester.getRect(_lcd);
      final node = tester.getSemantics(_button);
      final nodeRect = MatrixUtils.transformRect(
        node.transform ?? Matrix4.identity(),
        node.rect,
      );
      expect(nodeRect.height, lessThanOrEqualTo(lcd.top - 47 + _tolerance));
      // 넓힌 터치 영역은 시맨틱 동작을 만들지 않는다.
      expect(
        find.descendant(of: _touch, matching: find.byType(Semantics)),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel(TopStripDecoration.wordmarkText),
        findsNothing,
      );
      expect(find.byTooltip('Settings'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('장식은 터치를 받지 않는다', (tester) async {
      await _pump(
        tester,
        size: const Size(411, 960),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
      );
      expect(_wordmark, findsOneWidget);
      expect(_solar, findsOneWidget);
      expect(_wordmark.hitTestable(), findsNothing);
      expect(_solar.hitTestable(), findsNothing);
    });

    testWidgets('워드마크·태양전지 테두리·아이콘 색은 기기의 고대비 설정을 따른다', (tester) async {
      for (final palette in [CalcPalette.standard, CalcPalette.highContrast]) {
        await _pump(
          tester,
          size: const Size(411, 960),
          padding: const EdgeInsets.only(top: 24, bottom: 24),
          highContrast: palette.isHighContrast,
        );
        final reason = '고대비=${palette.isHighContrast}';
        expect(
          tester.widget<IconButton>(_button).color,
          palette.settingsIcon,
          reason: reason,
        );
        expect(
          tester.widget<Text>(_wordmark).style!.color,
          palette.settingsIcon,
          reason: reason,
        );
        final decoration =
            tester.widget<DecoratedBox>(_solar).decoration as BoxDecoration;
        expect(
          (decoration.border! as Border).top.color,
          palette.keyBorder,
          reason: reason,
        );
      }
    });

    testWidgets('글자 배율이 커도 워드마크는 줄 높이·자리 폭을 넘지 않는다', (tester) async {
      for (final (size, padding) in const [
        (Size(320, 568), EdgeInsets.zero),
        (Size(390, 844), EdgeInsets.only(top: 47, bottom: 34)),
        (Size(411, 960), EdgeInsets.only(top: 24, bottom: 24)),
      ]) {
        double? unscaledHeight;
        for (final scale in [1.0, 1.3, 3.0]) {
          await _pump(tester, size: size, padding: padding, textScale: scale);
          expect(tester.takeException(), isNull);
          final lcd = tester.getRect(_lcd);
          final text = tester.getRect(_wordmark);
          final reason = '$size 배율 $scale';
          expect(text.top, greaterThanOrEqualTo(padding.top), reason: reason);
          expect(text.bottom, lessThanOrEqualTo(lcd.top), reason: reason);
          expect(
            text.width,
            lessThanOrEqualTo(
              lcd.width * CalcTheme.topStripWordmarkMaxWidthRatio + _tolerance,
            ),
            reason: reason,
          );
          // 배율은 키 각인처럼 상한(1.3)까지만 반영한다 — 3.0이어도 1.3일 때와 같은 크기다.
          if (scale == 1.0) {
            unscaledHeight = text.height;
          } else {
            expect(
              text.height,
              lessThanOrEqualTo(
                unscaledHeight! * CalcTheme.keyMaxTextScaleFactor + 1.0,
              ),
              reason: reason,
            );
          }
        }
      }
    });

    testWidgets('회전으로 배치가 바뀌어도 설정 버튼 element가 유지된다', (tester) async {
      const padding = EdgeInsets.only(top: 24, bottom: 48);
      final container = await _pump(
        tester,
        size: const Size(1280, 800),
        padding: padding,
      );
      expect(isStackedArrangement(tester), isFalse);
      final element = tester.element(_button);

      await _pump(
        tester,
        size: const Size(800, 1280),
        padding: padding,
        container: container,
      );
      expect(isStackedArrangement(tester), isTrue);
      expect(identical(tester.element(_button), element), isTrue);

      await _pump(
        tester,
        size: const Size(1280, 800),
        padding: padding,
        container: container,
      );
      expect(identical(tester.element(_button), element), isTrue);
    });
  });

  group('좌우 분할·접힘선 기준 배치의 띠 장식', () {
    testWidgets('12.9인치 iPad 가로: LCD 위 띠에 장식 줄을 두고, 설정 버튼은 LCD 아래 그대로다', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(1366, 1024),
        padding: const EdgeInsets.only(top: 24, bottom: 20),
      );
      expect(tester.takeException(), isNull);
      expect(isStackedArrangement(tester), isFalse);
      final lcd = tester.getRect(_lcd);
      final button = tester.getRect(_button);
      expect(button.top, greaterThanOrEqualTo(lcd.bottom));
      expect(button.height, moreOrLessEquals(CalcTheme.settingsButtonSize));

      final wordmark = tester.getRect(_wordmark);
      final solar = tester.getRect(_solar);
      for (final r in [wordmark, solar]) {
        expect(r.left, greaterThanOrEqualTo(lcd.left));
        expect(r.right, lessThanOrEqualTo(lcd.right));
        expect(r.bottom, lessThanOrEqualTo(lcd.top + _tolerance));
        expect(
          r.top,
          greaterThanOrEqualTo(
            lcd.top - CalcTheme.topStripRowMaxHeight - _tolerance,
          ),
        );
      }
      // 띠에 버튼이 없으므로 태양전지는 줄 오른쪽 끝(안쪽 여백)에 붙는다.
      expect(
        solar.right,
        moreOrLessEquals(lcd.right - CalcTheme.topStripInset),
      );
    });

    testWidgets('10인치 태블릿 가로: 띠가 낮아 장식을 그리지 않는다', (tester) async {
      await _pump(
        tester,
        size: const Size(1280, 800),
        padding: const EdgeInsets.only(top: 24, bottom: 48),
      );
      expect(isStackedArrangement(tester), isFalse);
      expect(_wordmark, findsNothing);
      expect(_solar, findsNothing);
      expect(_button.hitTestable(), findsOneWidget);
    });

    testWidgets('반 접은 테이블톱: 장식은 LCD 위에 두고 위 절반 모서리의 설정 버튼과 겹치지 않는다', (
      tester,
    ) async {
      // Flip 내부 화면을 반 접음: 키패드가 아래 절반 폭을 다 써서 설정 버튼이 위 절반 모서리로 간다.
      const size = Size(411, 1005);
      await _pump(
        tester,
        size: size,
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        displayFeatures: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 502.5, 411, 0),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      final lcd = tester.getRect(_lcd);
      final keypad = tester.getRect(_keypad);
      expect(lcd.bottom, lessThanOrEqualTo(502.5));
      expect(keypad.top, greaterThanOrEqualTo(502.5));
      final button = tester.getRect(_button);
      expect(button.bottom, lessThanOrEqualTo(lcd.top)); // 위 절반 모서리
      expect(_button.hitTestable(), findsOneWidget);

      for (final finder in [_wordmark, _solar]) {
        expect(finder, findsOneWidget);
        final r = tester.getRect(finder);
        expect(r.overlaps(button), isFalse);
        expect(r.bottom, lessThanOrEqualTo(lcd.top + _tolerance));
      }
    });
  });
}

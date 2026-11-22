import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/settings_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/focus_ring.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/handedness_dialog.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/settings_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WCAG 2.x 명암비 (1.0 ~ 21.0)
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

// 기준값은 리터럴로 둔다 (상수를 낮춰도 테스트가 느슨해지지 않게)
const _aaa = 7.0; // WCAG AAA 일반 텍스트
const _nonText = 3.0; // WCAG 1.4.11 비텍스트 대비

const _strings = EnSettingsStrings(); // 테스트 기본 로캘 en_US

/// 기기 고대비·밝기 설정을 테스트 동안 바꾼다.
void _setDevice(
  WidgetTester tester, {
  required bool highContrast,
  Brightness brightness = Brightness.light,
}) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(highContrast: highContrast);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// 실제 앱 루트([AltCalcApp])로 좌우 분할 배치(설정 버튼이 보이는 태블릿 가로 창)를 띄운다.
Future<void> _pumpApp(
  WidgetTester tester, {
  Widget? home,
  Widget Function(BuildContext, Widget)? frameBuilder,
}) async {
  tester.view.physicalSize =
      const Size(1280, 800) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: home == null
          ? AltCalcApp(frameBuilder: frameBuilder)
          : AltCalcApp(home: home, frameBuilder: frameBuilder),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(SettingsButton.buttonKey));
  await tester.pumpAndSettle();
  expect(find.byType(HandednessDialog), findsOneWidget);
}

/// [text] 글자가 실제로 그려지는 색
Color _textColor(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)).first,
  );
  final span = paragraph.text;
  final color =
      span.style?.color ??
      (span is TextSpan ? span.children?.first.style?.color : null);
  expect(color, isNotNull, reason: '글자색이 없다: $text');
  return color!;
}

/// [actual]이 [expected] 테마인지 — `Theme.of`는 글꼴 지역화를 거친 사본을 돌려주므로 색 구성·대화상자 테마로 비교한다.
void _expectTheme(ThemeData actual, ThemeData expected, {String? reason}) {
  expect(actual.colorScheme, expected.colorScheme, reason: reason);
  expect(actual.dialogTheme, expected.dialogTheme, reason: reason);
  expect(actual.textButtonTheme, expected.textButtonTheme, reason: reason);
  expect(
    actual.scaffoldBackgroundColor,
    expected.scaffoldBackgroundColor,
    reason: reason,
  );
}

/// 대화상자의 보이는 면
Material _dialogSurface(WidgetTester tester) => tester.widget<Material>(
  find
      .descendant(of: find.byType(AlertDialog), matching: find.byType(Material))
      .first,
);

/// 대화상자 뒤의 장벽 색 (본체를 어둡게 덮는다)
Color _barrierColor(WidgetTester tester) =>
    tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).color!;

/// 대화상자 글자·버튼·라디오 색과 대화상자 면 색을 실제 화면에서 잰다.
({Color surface, Map<String, Color> parts}) _measureDialog(
  WidgetTester tester,
) {
  final surface = _dialogSurface(tester).color!;
  final scheme = Theme.of(tester.element(find.byType(HandednessDialog)))
      .colorScheme;
  final parts = <String, Color>{
    '제목': _textColor(tester, find.text(_strings.handednessTitle)),
    for (final h in Handedness.values) ...{
      '선택지 ${h.name}': _textColor(tester, find.text(_strings.handedness(h))),
      '설명 ${h.name}': _textColor(
        tester,
        find.text(_strings.handednessDetail(h)),
      ),
    },
    '닫기 버튼': _textColor(
      tester,
      find.descendant(
        of: find.byKey(HandednessDialog.closeKey),
        matching: find.text(_strings.close),
      ),
    ),
    // 라디오는 그림으로 그려 글자색이 없다 — 아래 테스트가 이 색으로 그려지는지 따로 확인한다.
    '켜진 라디오': scheme.primary,
    '꺼진 라디오': scheme.onSurfaceVariant,
  };
  return (surface: surface, parts: parts);
}

/// [h] 선택지의 라디오
Finder _radioOf(Handedness h) => find.descendant(
  of: find.byKey(HandednessDialog.optionKeyOf(h)),
  matching: find.byWidgetPredicate((w) => w is Radio<Handedness>),
);

/// 라디오가 [ring] 색 고리로 그려지는지. `_RadioPainter`는 배경 채움(평소 투명) → 바깥 고리(선) → 켜지면 안쪽 점
/// 순서로 원을 그린다 (포커스·눌림 중에는 반응 원이 앞에 끼므로 평소 상태에서만 쓴다).
PaintPattern _paintsRing(Color ring) => paints
  ..circle() // 배경 채움
  ..circle(style: PaintingStyle.stroke, color: ring);

/// [target]을 감싼 [FocusRing]의 테두리 그림 (`ringKey` 위젯)
Finder _ringBoxOf(Finder target) => find.descendant(
  of: find.ancestor(of: target, matching: find.byType(FocusRing)).first,
  matching: find.byKey(FocusRing.ringKey),
);

/// [target]을 감싼 [FocusRing]이 그리는 테두리 (안 그리면 `null`)
BorderSide? _ringOf(WidgetTester tester, Finder target) {
  final decoration = tester.widget<DecoratedBox>(_ringBoxOf(target)).decoration;
  return decoration is ShapeDecoration
      ? (decoration.shape as OutlinedBorder).side
      : null;
}

Finder _option(Handedness h) => find.byKey(HandednessDialog.optionKeyOf(h));
final _closeButton = find.byKey(HandednessDialog.closeKey);
final _settingsButton = find.byKey(SettingsButton.buttonKey);

/// 포커스 표시 방식을 테스트 동안 [strategy]로 둔다.
void _setHighlightStrategy(FocusHighlightStrategy strategy) {
  FocusManager.instance.highlightStrategy = strategy;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
}

/// [target] 안 글자·아이콘(RichText)을 감싼 가장 가까운 포커스 노드(버튼·타일의 InkWell)에 포커스를 준다.
Future<FocusNode> _focus(WidgetTester tester, Finder target) async {
  final node = Focus.of(
    tester.element(
      find.descendant(of: target, matching: find.byType(RichText)).first,
    ),
  );
  node.requestFocus();
  await tester.pumpAndSettle();
  expect(node.hasPrimaryFocus, isTrue);
  return node;
}

/// 키보드 조작 중처럼 포커스 표시를 켜고 [target]에 포커스를 준다.
Future<void> _focusByKeyboard(WidgetTester tester, Finder target) async {
  _setHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
  await _focus(tester, target);
}

void main() {
  group('앱이 고르는 Material 테마 (#97)', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        '기기 밝기 ${brightness.name}: 고대비면 고대비 테마, 아니면 일반 테마 (MaterialApp·화면 모두)',
        (tester) async {
          for (final highContrast in [false, true]) {
            _setDevice(
              tester,
              highContrast: highContrast,
              brightness: brightness,
            );
            // MaterialApp이 고른 테마 (builder 문맥 — 화면 위에서 다시 고르기 전)
            ThemeData? appTheme;
            await _pumpApp(
              tester,
              frameBuilder: (context, screen) {
                appTheme = Theme.of(context);
                return screen;
              },
            );
            final expected = highContrast
                ? CalcTheme.materialHighContrastTheme
                : CalcTheme.materialTheme;
            final reason = 'highContrast=$highContrast';
            _expectTheme(appTheme!, expected, reason: reason);
            _expectTheme(
              Theme.of(tester.element(find.byKey(SettingsButton.buttonKey))),
              expected,
              reason: reason,
            );
            await _openDialog(tester);
            _expectTheme(
              Theme.of(tester.element(find.byType(HandednessDialog))),
              expected,
              reason: reason,
            );
            await tester.tap(find.byKey(HandednessDialog.closeKey));
            await tester.pumpAndSettle();
          }
        },
      );
    }

    for (final (host, frame) in [(false, true), (true, false)]) {
      testWidgets(
        '도구용 틀이 고대비를 바꾸면(기기 $host → 틀 $frame) 틀 안의 대화상자는 틀 설정을 따른다 (개발용 미리보기)',
        (tester) async {
          _setDevice(tester, highContrast: host);
          await _pumpApp(
            tester,
            frameBuilder: (context, screen) => MediaQuery(
              data: MediaQuery.of(context).copyWith(highContrast: frame),
              child: screen,
            ),
          );
          await _openDialog(tester);
          final expected = frame
              ? CalcTheme.materialHighContrastTheme
              : CalcTheme.materialTheme;
          _expectTheme(
            Theme.of(tester.element(find.byType(HandednessDialog))),
            expected,
          );
          final side =
              (_dialogSurface(tester).shape! as RoundedRectangleBorder).side;
          expect(side == BorderSide.none, !frame);
        },
      );
    }
  });

  group('고대비 설정에서 설정 대화상자 대비 (#97)', () {
    testWidgets('글자·닫기 버튼·라디오는 대화상자 면과 7:1 이상이고 일반 모드보다 높다', (tester) async {
      _setDevice(tester, highContrast: false);
      await _pumpApp(tester);
      await _openDialog(tester);
      final std = _measureDialog(tester);
      await tester.tap(find.byKey(HandednessDialog.closeKey));
      await tester.pumpAndSettle();

      _setDevice(tester, highContrast: true);
      await _pumpApp(tester);
      await _openDialog(tester);
      final hc = _measureDialog(tester);

      expect(hc.surface.a, 1.0);
      for (final MapEntry(key: name, value: color) in hc.parts.entries) {
        final ratio = _contrast(color, hc.surface);
        expect(ratio, greaterThanOrEqualTo(_aaa), reason: name);
        // 일반 모드도 이미 7:1 이상이므로, 고대비 테마가 실제로 적용됐는지는 "더 높다"로 확인한다.
        expect(
          ratio,
          greaterThan(_contrast(std.parts[name]!, std.surface)),
          reason: name,
        );
      }
    });

    for (final highContrast in [false, true]) {
      testWidgets(
        '라디오는 켜짐 primary·꺼짐 onSurfaceVariant 고리로 그려진다 (대비 측정의 전제, 고대비=$highContrast)',
        (tester) async {
          _setDevice(tester, highContrast: highContrast);
          await _pumpApp(tester);
          await _openDialog(tester);
          final scheme = Theme.of(tester.element(find.byType(HandednessDialog)))
              .colorScheme;
          // 기본값은 오른손잡이
          expect(_radioOf(Handedness.right), _paintsRing(scheme.primary));
          expect(
            _radioOf(Handedness.left),
            _paintsRing(scheme.onSurfaceVariant),
          );
        },
      );
    }

    testWidgets('대화상자 가장자리 선이 대화상자 면·어둡게 덮인 본체와 3:1 이상이다', (tester) async {
      _setDevice(tester, highContrast: true);
      await _pumpApp(tester);
      await _openDialog(tester);
      final dialog = _dialogSurface(tester);
      final shape = dialog.shape! as RoundedRectangleBorder;
      final dimmedBody = Color.alphaBlend(
        _barrierColor(tester),
        CalcTheme.bodyBackground,
      );
      expect(shape.side.style, BorderStyle.solid);
      expect(
        _contrast(shape.side.color, dialog.color!),
        greaterThanOrEqualTo(_nonText),
      );
      expect(
        _contrast(shape.side.color, dimmedBody),
        greaterThanOrEqualTo(_nonText),
      );
    });
  });

  group('대화상자 모양 (#97)', () {
    testWidgets('두 테마의 대화상자 모서리는 M3 기본 대화상자와 같고, 일반 모드는 가장자리 선이 없다', (
      tester,
    ) async {
      // 테마 없이(M3 기본값) 띄운 대화상자
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(title: Text('t')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final m3 = _dialogSurface(tester).shape! as RoundedRectangleBorder;
      expect(m3.side, BorderSide.none);

      for (final highContrast in [false, true]) {
        _setDevice(tester, highContrast: highContrast);
        await _pumpApp(tester);
        await _openDialog(tester);
        final shape = _dialogSurface(tester).shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, m3.borderRadius, reason: '$highContrast');
        expect(shape.side == BorderSide.none, !highContrast);
        await tester.tap(_closeButton);
        await tester.pumpAndSettle();
      }
    });

    for (final from in [false, true]) {
      testWidgets(
        '대화상자를 연 채 고대비를 바꾸면(${from ? '켬→끔' : '끔→켬'}) 전환 중에도 모서리 반경이 그대로다',
        (tester) async {
          _setDevice(tester, highContrast: from);
          await _pumpApp(tester);
          await _openDialog(tester);
          final before =
              (_dialogSurface(tester).shape! as RoundedRectangleBorder)
                  .borderRadius;
          _setDevice(tester, highContrast: !from);
          await tester.pump();
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 50));
            final shape =
                _dialogSurface(tester).shape! as RoundedRectangleBorder;
            expect(shape.borderRadius, before, reason: '${(i + 1) * 50}ms');
          }
          await tester.pumpAndSettle();
          final after = _dialogSurface(tester).shape! as RoundedRectangleBorder;
          expect(after.borderRadius, before);
          expect(after.side == BorderSide.none, from);
        },
      );
    }
  });

  group('고대비 설정에서 키보드 포커스 표시 (#97)', () {
    testWidgets('포커스한 선택지·닫기 버튼에만 대화상자 면과 3:1 이상인 테두리를 그린다', (tester) async {
      _setDevice(tester, highContrast: true);
      await _pumpApp(tester);
      await _openDialog(tester);
      final surface = _dialogSurface(tester).color!;
      final targets = [
        for (final h in Handedness.values) _option(h),
        _closeButton,
      ];
      for (final target in targets) {
        await _focusByKeyboard(tester, target);
        for (final other in targets) {
          final ring = _ringOf(tester, other);
          if (other != target) {
            expect(ring, isNull, reason: '$target 포커스 중 $other');
            continue;
          }
          expect(ring, isNotNull, reason: '$target');
          expect(ring!.width, greaterThanOrEqualTo(2.0));
          expect(ring.strokeAlign, BorderSide.strokeAlignInside);
          expect(
            _contrast(ring.color, surface),
            greaterThanOrEqualTo(_nonText),
          );
        }
      }
    });

    testWidgets('선택지 테두리는 대화상자 가장자리 선에 덮이지 않게 그 굵기만큼 안쪽에 그린다', (tester) async {
      _setDevice(tester, highContrast: true);
      await _pumpApp(tester);
      await _openDialog(tester);
      final dialogShape =
          _dialogSurface(tester).shape! as RoundedRectangleBorder;
      final surface = tester.getRect(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first,
      );
      for (final h in Handedness.values) {
        final ring = tester.getRect(_ringBoxOf(_option(h)));
        expect(
          ring.left,
          greaterThanOrEqualTo(surface.left + dialogShape.side.width),
        );
        expect(
          ring.right,
          lessThanOrEqualTo(surface.right - dialogShape.side.width),
        );
      }
    });

    testWidgets('설정 버튼에도 포커스 테두리를 그리고, 본체와 3:1 이상이며 버튼 크기는 그대로다', (
      tester,
    ) async {
      _setDevice(tester, highContrast: true);
      await _pumpApp(tester);
      final sizeBefore = tester.getSize(_settingsButton);
      expect(_ringOf(tester, _settingsButton), isNull);
      await _focusByKeyboard(tester, _settingsButton);
      final ring = _ringOf(tester, _settingsButton);
      expect(ring, isNotNull);
      expect(ring!.width, greaterThanOrEqualTo(2.0));
      expect(
        _contrast(ring.color, CalcTheme.bodyBackground),
        greaterThanOrEqualTo(_nonText),
      );
      expect(tester.getSize(_settingsButton), sizeBefore);
      expect(
        tester.getSize(_settingsButton),
        const Size.square(CalcTheme.settingsButtonSize),
      );
    });

    testWidgets('키보드 조작 중에 대화상자를 열면(포커스 표시가 이미 켜진 상태) 바로 테두리를 그린다', (
      tester,
    ) async {
      _setDevice(tester, highContrast: true);
      _setHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
      await _pumpApp(tester);
      await _focus(tester, _settingsButton);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(HandednessDialog), findsOneWidget);
      // 대화상자가 열린 뒤 포커스 표시 방식은 바뀌지 않았다 — 테두리 위젯의 초깃값으로 그린다.
      await _focus(tester, _option(Handedness.left));
      expect(_ringOf(tester, _option(Handedness.left)), isNotNull);
    });

    testWidgets('터치 조작 중(포커스 표시 꺼짐)에는 포커스가 있어도 테두리를 그리지 않는다', (tester) async {
      _setDevice(tester, highContrast: true);
      await _pumpApp(tester);
      await _openDialog(tester);
      _setHighlightStrategy(FocusHighlightStrategy.alwaysTouch);
      for (final target in [_option(Handedness.left), _closeButton]) {
        await _focus(tester, target);
        expect(_ringOf(tester, target), isNull, reason: '$target');
        // 키보드를 쓰기 시작하면 바로 보인다
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        await tester.pump();
        expect(_ringOf(tester, target), isNotNull, reason: '$target');
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTouch;
        await tester.pump();
        expect(_ringOf(tester, target), isNull, reason: '$target 터치로 복귀');
      }
      // 설정 버튼도 같다
      await tester.tap(_closeButton);
      await tester.pumpAndSettle();
      await _focus(tester, _settingsButton);
      expect(_ringOf(tester, _settingsButton), isNull);
    });

    testWidgets('일반 모드에서는 포커스 테두리를 그리지 않는다 (Material 기본 포커스 표시 그대로)', (
      tester,
    ) async {
      _setDevice(tester, highContrast: false);
      await _pumpApp(tester);
      await _focusByKeyboard(tester, _settingsButton);
      expect(_ringOf(tester, _settingsButton), isNull);
      await _openDialog(tester);
      for (final target in [_option(Handedness.left), _closeButton]) {
        await _focusByKeyboard(tester, target);
        expect(_ringOf(tester, target), isNull, reason: '$target');
      }
    });

    testWidgets('키보드 화살표로 선택지를 옮기면 테두리도 따라가고 선택도 바로 저장된다', (tester) async {
      _setDevice(tester, highContrast: true);
      await _pumpApp(tester);
      await _openDialog(tester);
      await _focusByKeyboard(tester, _option(Handedness.right));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_ringOf(tester, _option(Handedness.right)), isNull);
      expect(_ringOf(tester, _option(Handedness.left)), isNotNull);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(HandednessNotifier.storageKey),
        Handedness.left.storageValue,
      );
    });
  });

  group('고대비 설정에서 툴팁·SnackBar 대비 (#97)', () {
    testWidgets(
      '설정 버튼 툴팁: M3 기본값이 색 구성과 무관해 테마로 바꾸지 않았고, 고대비에서도 7:1 이상임을 확인한다',
      (tester) async {
        _setDevice(tester, highContrast: true);
        await _pumpApp(tester);
        await tester.longPress(find.byKey(SettingsButton.buttonKey));
        await tester.pumpAndSettle();
        final label = find.descendant(
          of: find.byType(Overlay),
          matching: find.text(_strings.settingsButton),
        );
        expect(label, findsOneWidget);
        final box = tester.widget<Container>(
          find.ancestor(of: label, matching: find.byType(Container)).first,
        );
        final decoration = box.decoration! as BoxDecoration;
        // 툴팁 배경은 반투명이다 — 버튼 둘레의 본체 위에 겹친 색으로 잰다.
        final background = Color.alphaBlend(
          decoration.color!,
          CalcTheme.bodyBackground,
        );
        expect(
          _contrast(_textColor(tester, label), background),
          greaterThanOrEqualTo(_aaa),
        );
      },
    );

    testWidgets('SnackBar 글자·동작 버튼은 SnackBar 면과 7:1 이상이다', (tester) async {
      _setDevice(tester, highContrast: true);
      await _pumpApp(
        tester,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('message'),
                    action: SnackBarAction(label: 'action', onPressed: () {}),
                  ),
                ),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('show'));
      await tester.pumpAndSettle();
      final surface = tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(SnackBar),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      expect(surface.a, 1.0);
      for (final text in ['message', 'action']) {
        expect(
          _contrast(_textColor(tester, find.text(text)), surface),
          greaterThanOrEqualTo(_aaa),
          reason: text,
        );
      }
    });
  });
}

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/settings_strings.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
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

void main() {
  group('앱이 고르는 Material 테마 (#97)', () {
    for (final brightness in Brightness.values) {
      testWidgets('기기 밝기 ${brightness.name}: 고대비면 고대비 테마, 아니면 일반 테마', (
        tester,
      ) async {
        for (final highContrast in [false, true]) {
          _setDevice(
            tester,
            highContrast: highContrast,
            brightness: brightness,
          );
          await _pumpApp(tester);
          final expected = highContrast
              ? CalcTheme.materialHighContrastTheme
              : CalcTheme.materialTheme;
          final element = tester.element(find.byKey(SettingsButton.buttonKey));
          _expectTheme(
            Theme.of(element),
            expected,
            reason: 'highContrast=$highContrast',
          );
          await _openDialog(tester);
          _expectTheme(
            Theme.of(tester.element(find.byType(HandednessDialog))),
            expected,
            reason: 'highContrast=$highContrast',
          );
          await tester.tap(find.byKey(HandednessDialog.closeKey));
          await tester.pumpAndSettle();
        }
      });
    }

    testWidgets('도구용 틀이 그 안에서 고대비를 켜면 틀 안의 대화상자도 고대비 테마를 쓴다 (개발용 미리보기)', (
      tester,
    ) async {
      _setDevice(tester, highContrast: false);
      await _pumpApp(
        tester,
        frameBuilder: (context, screen) => MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: true),
          child: screen,
        ),
      );
      await _openDialog(tester);
      _expectTheme(
        Theme.of(tester.element(find.byType(HandednessDialog))),
        CalcTheme.materialHighContrastTheme,
      );
      expect(
        _dialogSurface(tester).shape,
        CalcTheme.materialHighContrastTheme.dialogTheme.shape,
      );
    });
  });

  group('고대비 설정에서 설정 대화상자 대비 (#97)', () {
    testWidgets('글자·닫기 버튼·라디오는 대화상자 면과 7:1 이상이고 일반 모드 이상이다', (tester) async {
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
        expect(
          ratio,
          greaterThanOrEqualTo(_contrast(std.parts[name]!, std.surface)),
          reason: name,
        );
      }
    });

    testWidgets('라디오는 켜짐 primary·꺼짐 onSurfaceVariant로 그려진다 (위 대비 측정의 전제)', (
      tester,
    ) async {
      _setDevice(tester, highContrast: true);
      await _pumpApp(tester);
      await _openDialog(tester);
      final scheme = CalcTheme.materialHighContrastTheme.colorScheme;
      // 기본값은 오른손잡이
      Finder radioOf(Handedness h) => find.descendant(
        of: find.byKey(HandednessDialog.optionKeyOf(h)),
        matching: find.byWidgetPredicate((w) => w is Radio<Handedness>),
      );
      expect(
        radioOf(Handedness.right),
        paints
          ..circle() // 포커스·눌림 겹침색 (평소 투명)
          ..circle(color: scheme.primary),
      );
      expect(
        radioOf(Handedness.left),
        paints
          ..circle()
          ..circle(color: scheme.onSurfaceVariant),
      );
    });

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

    testWidgets('일반 모드 대화상자는 그동안과 같다 (가장자리 선 없음)', (tester) async {
      _setDevice(tester, highContrast: false);
      await _pumpApp(tester);
      await _openDialog(tester);
      final shape = _dialogSurface(tester).shape! as RoundedRectangleBorder;
      expect(shape.side, BorderSide.none);
    });
  });

  group('고대비 설정에서 툴팁·SnackBar 대비 (#97)', () {
    testWidgets('설정 버튼 툴팁 글자는 툴팁 배경과 7:1 이상이다', (tester) async {
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
      // 툴팁 배경은 반투명일 수 있다 — 버튼 둘레의 본체 위에 겹친 색으로 잰다.
      final background = Color.alphaBlend(
        decoration.color!,
        CalcTheme.bodyBackground,
      );
      expect(
        _contrast(_textColor(tester, label), background),
        greaterThanOrEqualTo(_aaa),
      );
    });

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

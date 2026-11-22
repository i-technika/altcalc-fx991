import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoTheme;
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

/// [target]을 감싼 [FocusRing]의 렌더 객체
RenderFocusRing _ringRenderOf(WidgetTester tester, Finder target) =>
    tester.renderObject<RenderFocusRing>(_ringBoxOf(target));

/// [target]을 감싼 [FocusRing]이 그리는 테두리 (안 그리면 `null`)
BorderSide? _ringOf(WidgetTester tester, Finder target) {
  final ring = _ringRenderOf(tester, target);
  return ring.ringRect == null ? null : ring.side;
}

/// [target]을 감싼 [FocusRing]이 테두리를 그리는 영역 (화면 좌표)
Rect _ringRectOf(WidgetTester tester, Finder target) {
  final ring = _ringRenderOf(tester, target);
  return MatrixUtils.transformRect(ring.getTransformTo(null), ring.ringRect!);
}

/// [target]을 감싼 [FocusRing]이 [color] 테두리를 실제로 그리는지 — [OutlinedBorder.paint]가 모양마다 다른 호출을 쓴다
/// (StadiumBorder: 선 그리기 rrect, RoundedRectangleBorder: 채운 drrect).
/// [at](화면 좌표)을 주면 그 자리에 그리는지도 본다 — 기대 위치를 렌더 객체의 계산(`ringRect`)과 따로 구해야
/// "계산은 맞고 그리기는 다른 곳" 같은 회귀를 잡는다. 기대 도형은 각 모양의 paint와 같은 계산(안쪽 정렬 2dp 선)이다.
PaintPattern _paintsFocusRing(
  WidgetTester tester,
  Finder target,
  Color color, {
  Rect? at,
}) {
  final ring = _ringRenderOf(tester, target);
  // paints 매처는 렌더 객체를 자기 원점(0, 0)에 그린다
  final local = at?.shift(-ring.localToGlobal(Offset.zero));
  const w = CalcTheme.materialFocusRingWidth;
  return switch (ring.shape) {
    StadiumBorder() =>
      paints..rrect(
        rrect: local == null
            ? null
            : RRect.fromRectAndRadius(
                local,
                Radius.circular(local.shortestSide / 2),
              ).deflate(w / 2),
        color: color,
        style: PaintingStyle.stroke,
      ),
    RoundedRectangleBorder(borderRadius: BorderRadius.zero) =>
      paints..drrect(
        outer: local == null ? null : RRect.fromRectAndCorners(local),
        inner: local == null
            ? null
            : RRect.fromRectAndCorners(local.deflate(w)),
        color: color,
      ),
    final other => throw StateError('기대 도형을 모르는 모양: $other'),
  };
}

/// [target] 안의 첫 [InkWell] (버튼·타일이 포커스를 받는 곳이자 보이는 면)
Finder _inkWellOf(Finder target) =>
    find.descendant(of: target, matching: find.byType(InkWell)).first;

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

/// MaterialApp이 자기 테마로 정하는 앱 수준 요소 (#107) — 텍스트 선택·커서 기본 색과 Cupertino 테마의 주요 색.
/// 아이콘 테마는 화면 테마가 Cupertino 테마를 다시 정할 때 바뀌지 않았는지 보려고 함께 본다
/// ([CupertinoTheme]은 아래에 Cupertino 아이콘 테마(primary 색)를 씌운다). 일반·고대비 테마의 아이콘 테마는 같으므로
/// (둘 다 `iconTheme`을 정하지 않아 어두운 테마 기본값) 어느 테마를 따르는지(호스트·틀, 목표·전환 중)는 가려내지 못하고,
/// Cupertino 아이콘 테마로 바뀌지 않았는지만 확인한다.
typedef _AppLevel = ({
  Color? selection,
  Color? cursor,
  Brightness? cupertinoBrightness,
  Color cupertinoPrimary,
  Color cupertinoPrimaryContrasting,
  Color cupertinoScaffold,
  IconThemeData icon,
});

/// [context]에서 보이는 앱 수준 요소
_AppLevel _appLevelOf(BuildContext context) {
  final selection = DefaultSelectionStyle.of(context);
  final cupertino = CupertinoTheme.of(context);
  return (
    selection: selection.selectionColor,
    cursor: selection.cursorColor,
    cupertinoBrightness: cupertino.brightness,
    cupertinoPrimary: cupertino.primaryColor,
    cupertinoPrimaryContrasting: cupertino.primaryContrastingColor,
    cupertinoScaffold: cupertino.scaffoldBackgroundColor,
    icon: IconTheme.of(context),
  );
}

/// 기기 고대비가 [highContrast]일 때 MaterialApp이 정한 앱 수준 요소 — 화면 위에서 다시 정하기 전의
/// `MaterialApp.builder` 문맥에서 읽는다.
Future<_AppLevel> _materialAppLevel(
  WidgetTester tester,
  bool highContrast,
) async {
  _setDevice(tester, highContrast: highContrast);
  _AppLevel? level;
  await _pumpApp(
    tester,
    frameBuilder: (context, screen) {
      level = _appLevelOf(context);
      return screen;
    },
  );
  return level!;
}

/// 계산기 화면(설정 버튼)과 설정 대화상자에서 보이는 앱 수준 요소가 [expected]인지
Future<void> _expectScreenAppLevel(
  WidgetTester tester,
  _AppLevel expected,
) async {
  expect(_appLevelOf(tester.element(_settingsButton)), expected, reason: '화면');
  await _openDialog(tester);
  expect(
    _appLevelOf(tester.element(find.byType(HandednessDialog))),
    expected,
    reason: '대화상자',
  );
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

  group('MaterialApp 수준 요소: 텍스트 선택 색·Cupertino 테마 (#107)', () {
    for (final highContrast in [false, true]) {
      testWidgets(
        '실제 앱(틀 없음, 고대비=$highContrast): 화면·대화상자의 값은 MaterialApp이 정한 값과 같다',
        (tester) async {
          final reference = await _materialAppLevel(tester, highContrast);
          final theme = highContrast
              ? CalcTheme.materialHighContrastTheme
              : CalcTheme.materialTheme;
          // 비교 기준이 MaterialApp의 계산(primary 40%·primary, Material 기반 Cupertino 테마)인지 — 전제 확인.
          // 40%는 MaterialApp(`withOpacity`)과 같은 8비트 알파 식으로 쓴다(0.40에서는 `withValues(alpha: 0.40)`과도 같은 값).
          expect(
            reference.selection,
            theme.colorScheme.primary.withAlpha((255.0 * 0.40).round()),
          );
          expect(reference.cursor, theme.colorScheme.primary);
          expect(reference.cupertinoPrimary, theme.colorScheme.primary);
          expect(reference.cupertinoBrightness, Brightness.dark);
          // 아이콘 테마는 Material 테마의 것 (Cupertino 아이콘 테마의 primary 색이 아니다)
          expect(reference.icon.color, isNot(theme.colorScheme.primary));
          expect(reference.icon.color, theme.iconTheme.color);
          await _expectScreenAppLevel(tester, reference);
        },
      );
    }

    testWidgets('실제 앱에서 고대비 전환 애니메이션 중에도 화면의 값은 MaterialApp이 정한 값과 같다', (
      tester,
    ) async {
      final references = {
        for (final v in [false, true]) v: await _materialAppLevel(tester, v),
      };
      _setDevice(tester, highContrast: false);
      late BuildContext appContext;
      await _pumpApp(
        tester,
        frameBuilder: (context, screen) {
          appContext = context;
          return screen;
        },
      );
      for (final value in [true, false]) {
        _setDevice(tester, highContrast: value);
        await tester.pump();
        await tester.pump(kThemeAnimationDuration ~/ 2);
        final app = _appLevelOf(appContext);
        // 전환 중인지 — Cupertino 테마(전환 중인 테마로 만든다)가 양 끝 값과 다르다
        for (final end in references.values) {
          expect(app.cupertinoPrimary, isNot(end.cupertinoPrimary));
        }
        expect(
          _appLevelOf(tester.element(_settingsButton)),
          app,
          reason: '전환 중 고대비=$value',
        );
        await tester.pumpAndSettle();
        expect(
          _appLevelOf(tester.element(_settingsButton)),
          references[value],
          reason: '전환 뒤 고대비=$value',
        );
      }
    });

    // 아이콘 테마는 두 테마에서 같아 여기서 보지 않는다 ([_AppLevel] 참조)
    testWidgets('두 테마의 값이 서로 달라 아래 틀 테스트가 어느 쪽을 따르는지 가려낸다', (tester) async {
      final standard = await _materialAppLevel(tester, false);
      final high = await _materialAppLevel(tester, true);
      expect(high.selection, isNot(standard.selection));
      expect(high.cursor, isNot(standard.cursor));
      expect(high.cupertinoPrimary, isNot(standard.cupertinoPrimary));
    });

    for (final (host, frame) in [(false, true), (true, false)]) {
      testWidgets(
        '도구용 틀이 고대비를 바꾸면(기기 $host → 틀 $frame) 틀 안 화면·대화상자는 틀 설정의 값을 따른다 (개발용 미리보기)',
        (tester) async {
          final expected = await _materialAppLevel(tester, frame);
          _setDevice(tester, highContrast: host);
          await _pumpApp(
            tester,
            frameBuilder: (context, screen) => MediaQuery(
              data: MediaQuery.of(context).copyWith(highContrast: frame),
              child: screen,
            ),
          );
          await _expectScreenAppLevel(tester, expected);
        },
      );
    }

    testWidgets('틀의 고대비를 실행 중에 켜고 끄면 틀 안 값도 그 설정으로 바뀐다', (tester) async {
      final references = {
        for (final v in [false, true]) v: await _materialAppLevel(tester, v),
      };
      _setDevice(tester, highContrast: false);
      final frame = ValueNotifier(false);
      addTearDown(frame.dispose);
      await _pumpApp(
        tester,
        frameBuilder: (context, screen) => ValueListenableBuilder<bool>(
          valueListenable: frame,
          builder: (context, value, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(highContrast: value),
            child: child!,
          ),
          child: screen,
        ),
      );
      for (final value in [true, false]) {
        frame.value = value;
        await tester.pumpAndSettle();
        expect(
          _appLevelOf(tester.element(_settingsButton)),
          references[value],
          reason: '틀 고대비=$value',
        );
      }
    });
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

  group('키보드 포커스 표시 (고대비 #97, 일반 모드 #106)', () {
    for (final highContrast in [false, true]) {
      final mode = highContrast ? '고대비' : '일반 모드';
      final expectedColor = highContrast
          ? CalcTheme.materialFocusRingHighContrast
          : CalcTheme.materialFocusRingStandard;

      testWidgets(
        '$mode: 포커스한 선택지·닫기 버튼에만 테두리를 그리고, 포커스 전 같은 자리(대화상자 면)와 3:1 이상이다',
        (tester) async {
          _setDevice(tester, highContrast: highContrast);
          await _pumpApp(tester);
          await _openDialog(tester);
          final surface = _dialogSurface(tester).color!;
          final theme = Theme.of(tester.element(find.byType(HandednessDialog)));
          // 테두리 안쪽에 맞닿는 Material 기본 포커스 겹침 — 위젯이 실제로 쓰는 값을 읽는다.
          // 선택지 타일의 InkWell은 색을 받지 않아 테마의 focusColor를 쓴다(그 전제를 먼저 확인).
          final fills = <Finder, Color>{};
          for (final h in Handedness.values) {
            final ink = tester.widget<InkWell>(_inkWellOf(_option(h)));
            expect(ink.focusColor, isNull);
            expect(ink.overlayColor, isNull);
            fills[_option(h)] = Color.alphaBlend(theme.focusColor, surface);
          }
          final closeInk = tester.widget<InkWell>(_inkWellOf(_closeButton));
          fills[_closeButton] = Color.alphaBlend(
            closeInk.overlayColor!.resolve({WidgetState.focused})!,
            surface,
          );
          for (final target in fills.keys) {
            await _focusByKeyboard(tester, target);
            for (final other in fills.keys) {
              final ring = _ringOf(tester, other);
              if (other != target) {
                expect(ring, isNull, reason: '$target 포커스 중 $other');
                continue;
              }
              expect(ring, isNotNull, reason: '$target');
              expect(ring!.color, expectedColor, reason: '$target');
              expect(ring.width, greaterThanOrEqualTo(2.0));
              expect(ring.strokeAlign, BorderSide.strokeAlignInside);
              // 실제로 그 색으로 그린다
              expect(
                _ringBoxOf(target),
                _paintsFocusRing(tester, target, ring.color),
              );
              // WCAG 2.4.13: 포커스 전후 같은 픽셀(테두리 자리 = 대화상자 면)
              expect(
                _contrast(ring.color, surface),
                greaterThanOrEqualTo(_nonText),
                reason: '$target 대화상자 면',
              );
              // 추가 확인: 테두리 안쪽에 맞닿는 포커스 겹침과의 인접 대비
              expect(
                _contrast(ring.color, fills[target]!),
                greaterThanOrEqualTo(_nonText),
                reason: '$target 포커스 겹침',
              );
            }
          }
        },
      );

      testWidgets(
        '$mode: 테두리는 보이는 버튼·타일에 맞춰 그린다 (닫기 버튼은 48dp 터치 여백이 아니라 보이는 면)',
        (tester) async {
          _setDevice(tester, highContrast: highContrast);
          await _pumpApp(tester);
          await _openDialog(tester);
          final dialogShape =
              _dialogSurface(tester).shape! as RoundedRectangleBorder;
          // 고대비 대화상자 가장자리 선은 내용 위에 그려지므로 그 굵기만큼 안쪽, 선이 없는 일반 모드는 타일 전체
          final edge = highContrast ? dialogShape.side.width : 0.0;
          expect(edge, highContrast ? greaterThan(0) : 0);
          for (final h in Handedness.values) {
            await _focusByKeyboard(tester, _option(h));
            final tile = tester.getRect(_inkWellOf(_option(h)));
            final expected = EdgeInsets.symmetric(horizontal: edge)
                .deflateRect(tile);
            expect(_ringRectOf(tester, _option(h)), expected, reason: '$h');
            expect(
              _ringBoxOf(_option(h)),
              _paintsFocusRing(tester, _option(h), expectedColor, at: expected),
              reason: '$h',
            );
          }

          await _focusByKeyboard(tester, _closeButton);
          final visible = find
              .descendant(of: _closeButton, matching: find.byType(Material))
              .first;
          // 닫기 버튼은 터치 영역(위젯)이 보이는 면보다 크다 — 이 검사가 그 차이를 실제로 다루는지 확인
          expect(
            tester.getSize(visible).height,
            lessThan(tester.getSize(_closeButton).height),
          );
          expect(_ringRectOf(tester, _closeButton), tester.getRect(visible));
          expect(
            _ringBoxOf(_closeButton),
            _paintsFocusRing(
              tester,
              _closeButton,
              expectedColor,
              at: tester.getRect(visible),
            ),
          );
          expect(
            tester.widget<Material>(visible).shape,
            _ringRenderOf(tester, _closeButton).shape,
          );
        },
      );

      testWidgets(
        '$mode: 설정 버튼에도 보이는 면에 맞춰 테두리를 그리고, 본체와 3:1 이상이며 버튼 크기는 그대로다',
        (tester) async {
          _setDevice(tester, highContrast: highContrast);
          await _pumpApp(tester);
          final sizeBefore = tester.getSize(_settingsButton);
          expect(_ringOf(tester, _settingsButton), isNull);
          await _focusByKeyboard(tester, _settingsButton);
          final ring = _ringOf(tester, _settingsButton);
          expect(ring, isNotNull);
          expect(ring!.color, expectedColor);
          expect(ring.width, greaterThanOrEqualTo(2.0));
          expect(
            _ringBoxOf(_settingsButton),
            _paintsFocusRing(tester, _settingsButton, ring.color),
          );
          final visible = find
              .descendant(of: _settingsButton, matching: find.byType(Material))
              .first;
          expect(_ringRectOf(tester, _settingsButton), tester.getRect(visible));
          expect(
            _ringBoxOf(_settingsButton),
            _paintsFocusRing(
              tester,
              _settingsButton,
              expectedColor,
              at: tester.getRect(visible),
            ),
          );
          final ink = tester.widget<InkWell>(_inkWellOf(_settingsButton));
          final backgrounds = {
            // WCAG 2.4.13: 포커스 전후 같은 픽셀
            '본체': CalcTheme.bodyBackground,
            // 추가 확인: IconButton 기본 포커스 겹침과의 인접 대비 (위젯이 실제로 쓰는 값)
            '포커스 겹침': Color.alphaBlend(
              ink.overlayColor!.resolve({WidgetState.focused})!,
              CalcTheme.bodyBackground,
            ),
          };
          for (final MapEntry(key: name, value: bg) in backgrounds.entries) {
            expect(
              _contrast(ring.color, bg),
              greaterThanOrEqualTo(_nonText),
              reason: name,
            );
          }
          expect(tester.getSize(_settingsButton), sizeBefore);
          expect(
            tester.getSize(_settingsButton),
            const Size.square(CalcTheme.settingsButtonSize),
          );
        },
      );

      testWidgets('$mode: 터치 조작 중(포커스 표시 꺼짐)에는 포커스가 있어도 테두리를 그리지 않는다', (
        tester,
      ) async {
        _setDevice(tester, highContrast: highContrast);
        await _pumpApp(tester);
        await _openDialog(tester);
        _setHighlightStrategy(FocusHighlightStrategy.alwaysTouch);
        for (final target in [_option(Handedness.left), _closeButton]) {
          await _focus(tester, target);
          expect(_ringOf(tester, target), isNull, reason: '$target');
          expect(
            _ringBoxOf(target),
            isNot(_paintsFocusRing(tester, target, expectedColor)),
            reason: '$target',
          );
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

      testWidgets('$mode: 실제 앱 설정(자동 판정)에서 키를 누르면 테두리가 보이고, 화면을 탭하면 사라진다', (
        tester,
      ) async {
        _setDevice(tester, highContrast: highContrast);
        expect(
          FocusManager.instance.highlightStrategy,
          FocusHighlightStrategy.automatic,
        );
        await _pumpApp(tester);
        await _openDialog(tester); // 탭으로 열었다 — 터치 조작 중
        await _focus(tester, _option(Handedness.right));
        expect(_ringOf(tester, _option(Handedness.right)), isNull);
        // 선택·포커스를 바꾸지 않는 키
        await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(_ringOf(tester, _option(Handedness.right)), isNotNull);
        // 동작이 없는 곳(제목)을 탭하면 터치 조작으로 돌아간다
        await tester.tap(find.text(_strings.handednessTitle));
        await tester.pump();
        expect(_ringOf(tester, _option(Handedness.right)), isNull);
      });

      testWidgets('$mode: 키보드 조작 중에 대화상자를 열면(포커스 표시가 이미 켜진 상태) 바로 테두리를 그린다', (
        tester,
      ) async {
        _setDevice(tester, highContrast: highContrast);
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

      testWidgets('$mode: 키보드 화살표로 선택지를 옮기면 테두리도 따라가고 선택도 바로 저장된다', (
        tester,
      ) async {
        _setDevice(tester, highContrast: highContrast);
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
    }

    testWidgets('키보드 포커스 중 고대비를 켜고 끄면 테두리가 그 모드의 색으로 바로 바뀐다', (tester) async {
      _setDevice(tester, highContrast: false);
      await _pumpApp(tester);
      await _focusByKeyboard(tester, _settingsButton);
      for (final (highContrast, expected) in [
        (false, CalcTheme.materialFocusRingStandard),
        (true, CalcTheme.materialFocusRingHighContrast),
        (false, CalcTheme.materialFocusRingStandard),
      ]) {
        _setDevice(tester, highContrast: highContrast);
        await tester.pump();
        expect(
          _ringOf(tester, _settingsButton)?.color,
          expected,
          reason: 'highContrast=$highContrast',
        );
      }
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

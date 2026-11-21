import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/domain/models/calc_state.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:material_ui/material_ui.dart';

import '../../preview/key_preview_main.dart';

/// 개발용 미리보기 실행기(#21)가 앱 코드 변경에 맞춰 계속 동작하는지 지킨다.
/// (`flutter analyze`가 컴파일을, 이 테스트가 실행·입력 기록을, CI 웹 빌드가 웹 컴파일을 검증한다.)

/// 데스크톱 브라우저 기본 창 크기
const Size _window = Size(1280, 900);

/// 미리보기를 띄운다.
Future<void> _pumpPreview(
  WidgetTester tester, {
  Size window = _window,
  int logCapacity = previewLogCapacity,
}) async {
  tester.view.physicalSize = window * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      child: AltCalcApp(home: KeyPreviewScreen(logCapacity: logCapacity)),
    ),
  );
}

Finder _keycap(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));

Future<void> _press(WidgetTester tester, CalcKeyId id) async {
  await tester.tap(_keycap(id));
  await tester.pump();
}

/// 로그에 표시된 줄 (최근 입력이 먼저). 로그가 비어 있으면 빈 목록.
List<String> _logLines(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('preview-log')),
        matching: find.byType(Text),
      ),
    )
    .map((t) => t.data!)
    .toList();

String _logHeader(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('preview-log-header'))).data!;

final Finder _deviceScreen = find.byKey(
  const ValueKey('preview-device-screen'),
);

void main() {
  group('릴리스 빌드 분리', () {
    test('lib/에서 preview/로 가는 import·export·part 지시문이 없다', () {
      final directive = RegExp(
        r'''^\s*(import|export|part)\s+['"][^'"]*preview/''',
        multiLine: true,
      );
      final offenders = [
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File &&
              f.path.endsWith('.dart') &&
              directive.hasMatch(f.readAsStringSync()))
            f.path,
      ];
      expect(offenders, isEmpty);
    });

    test('pubspec 에셋·글꼴에 preview/ 경로가 없다', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final paths = RegExp(
        r'^\s*-\s*(?:asset:\s*)?(\S+)',
        multiLine: true,
      ).allMatches(pubspec).map((m) => m.group(1)!);
      expect(paths.where((p) => p.contains('preview/')), isEmpty);
    });
  });

  group('프리셋 불변식', () {
    test('기기 프리셋: 이름 중복 없음, 크기는 유한한 양수, 인셋은 음수가 아니고 화면보다 작다', () {
      expect(previewDevices, isNotEmpty);
      final names = previewDevices.map((d) => d.name).toList();
      expect(names.toSet(), hasLength(names.length));
      for (final d in previewDevices) {
        expect(
          d.size.width.isFinite && d.size.width > 0,
          isTrue,
          reason: d.name,
        );
        expect(
          d.size.height.isFinite && d.size.height > 0,
          isTrue,
          reason: d.name,
        );
        expect(d.padding.isNonNegative, isTrue, reason: d.name);
        expect(d.padding.vertical, lessThan(d.size.height), reason: d.name);
        expect(d.padding.horizontal, lessThan(d.size.width), reason: d.name);
      }
    });

    test('글자 배율: 기본값을 포함하고 중복 없이 Android 범위(85~200%) 안', () {
      expect(previewTextScales, contains(previewDefaultTextScale));
      expect(previewTextScales.toSet(), hasLength(previewTextScales.length));
      for (final s in previewTextScales) {
        expect(s, inInclusiveRange(0.85, 2.0));
      }
    });
  });

  group('입력 로그 문구', () {
    test('기능 입력: 층별 표기와 반복 표기', () {
      expect(
        describePreviewInput(KeyInput(CalcKeyId.num7, KeyLayer.main)),
        '7',
      );
      expect(
        describePreviewInput(KeyInput(CalcKeyId.calc, KeyLayer.shift)),
        'SOLVE  ← SHIFT + CALC',
      );
      expect(
        describePreviewInput(KeyInput(CalcKeyId.negative, KeyLayer.alpha)),
        'A  ← ALPHA + (−)',
      );
      expect(
        describePreviewInput(
          KeyInput(CalcKeyId.cursorLeft, KeyLayer.main, isRepeat: true),
        ),
        '◄ (반복)',
      );
    });

    test('모디파이어 대기 변화', () {
      const none = KeyModifier.none;
      const shift = KeyModifier.shift;
      const alpha = KeyModifier.alpha;
      expect(describePreviewModifierChange(none, shift), '[SHIFT 대기]');
      expect(describePreviewModifierChange(shift, alpha), '[ALPHA 대기]');
      expect(describePreviewModifierChange(alpha, none), '[ALPHA 해제]');
      expect(describePreviewModifierChange(shift, none), '[SHIFT 해제]');
      for (final m in KeyModifier.values) {
        expect(describePreviewModifierChange(m, m), isNull);
      }
    });
  });

  group('미리보기 화면', () {
    testWidgets('앱 루트 아래에서 실제 CalculatorScreen을 기본 기기 크기로 띄운다', (tester) async {
      await _pumpPreview(tester);
      expect(find.byType(AltCalcApp), findsOneWidget);
      expect(find.byType(CalculatorScreen), findsOneWidget);
      expect(tester.getSize(_deviceScreen), previewDevices.first.size);
      expect(tester.takeException(), isNull);
    });

    testWidgets('기능 입력은 번호·층 표기로, 모디파이어 대기 변화는 번호 없이 최근 순으로 기록된다', (
      tester,
    ) async {
      await _pumpPreview(tester);
      await _press(tester, CalcKeyId.num7);
      await _press(tester, CalcKeyId.shift);
      await _press(tester, CalcKeyId.calc);
      await _press(tester, CalcKeyId.shift);
      await _press(tester, CalcKeyId.shift);
      await _press(tester, CalcKeyId.alpha);
      await _press(tester, CalcKeyId.shift);

      expect(_logLines(tester), [
        '[SHIFT 대기]',
        '[ALPHA 대기]',
        '[SHIFT 해제]',
        '[SHIFT 대기]',
        '2. SOLVE  ← SHIFT + CALC',
        '[SHIFT 대기]',
        '1. 7',
      ]);
      expect(_logHeader(tester), '입력 로그 · 입력 2회');
    });

    testWidgets('초기화는 상태와 로그를 비우고, 처음으로 돌아가는 알림을 기록하지 않는다', (tester) async {
      await _pumpPreview(tester);
      await _press(tester, CalcKeyId.num7);
      await _press(tester, CalcKeyId.shift); // SHIFT 대기 중에 초기화
      await tester.tap(find.byKey(const ValueKey('preview-reset')));
      await tester.pumpAndSettle();

      expect(_logLines(tester), isEmpty);
      expect(_logHeader(tester), '입력 로그 · 입력 0회');

      // 초기화 후 번호는 1부터, 이미 처음 상태에서 초기화해도 이후 변화가 빠지지 않는다.
      await tester.tap(find.byKey(const ValueKey('preview-reset')));
      await tester.pumpAndSettle();
      await _press(tester, CalcKeyId.shift);
      await _press(tester, CalcKeyId.shift);
      await _press(tester, CalcKeyId.num7);
      expect(_logLines(tester), ['1. 7', '[SHIFT 해제]', '[SHIFT 대기]']);
    });

    testWidgets('상한을 넘으면 오래된 줄부터 버리고, 번호와 총 입력 수는 이어진다', (tester) async {
      await _pumpPreview(tester, logCapacity: 3);
      for (var i = 0; i < 5; i++) {
        await _press(tester, CalcKeyId.num7);
      }
      expect(_logLines(tester), ['5. 7', '4. 7', '3. 7']);
      expect(_logHeader(tester), '입력 로그 · 입력 5회 (최근 3줄만 표시)');
    });

    testWidgets('모든 기기 프리셋 × 글자 배율: 화면에 크기·인셋·배율이 주입되고 창 안에 맞게 축소된다', (
      tester,
    ) async {
      await _pumpPreview(tester);
      for (final (i, device) in previewDevices.indexed) {
        await tester.tap(find.byKey(ValueKey('preview-device-$i')));
        for (final scale in previewTextScales) {
          await tester.tap(find.byKey(ValueKey('preview-text-scale-$scale')));
          await tester.pumpAndSettle();
          final reason = '${device.label} × $scale';
          expect(tester.takeException(), isNull, reason: reason);

          // 화면이 보는 MediaQuery = 프리셋 + 선택한 배율
          final mq = MediaQuery.of(
            tester.element(find.byType(CalculatorScreen)),
          );
          expect(mq.size, device.size, reason: reason);
          expect(mq.padding, device.padding, reason: reason);
          expect(mq.viewPadding, device.padding, reason: reason);
          expect(mq.viewInsets, EdgeInsets.zero, reason: reason);
          expect(mq.systemGestureInsets, EdgeInsets.zero, reason: reason);
          expect(
            mq.textScaler.scale(10),
            closeTo(10 * scale, 1e-9),
            reason: reason,
          );

          // 논리 크기 그대로 배치되고, 표시 영역은 패널·여백(16)·캡션(24)을 뺀 영역 안에 들어간다.
          expect(tester.getSize(_deviceScreen), device.size, reason: reason);
          final shown = tester.getRect(_deviceScreen);
          const frameArea = Rect.fromLTRB(
            KeyPreviewScreen.panelWidth + 16,
            16 + 24,
            1280 - 16,
            900 - 16,
          );
          expect(
            shown.left,
            greaterThanOrEqualTo(frameArea.left - 0.01),
            reason: reason,
          );
          expect(
            shown.top,
            greaterThanOrEqualTo(frameArea.top - 0.01),
            reason: reason,
          );
          expect(
            shown.right,
            lessThanOrEqualTo(frameArea.right + 0.01),
            reason: reason,
          );
          expect(
            shown.bottom,
            lessThanOrEqualTo(frameArea.bottom + 0.01),
            reason: reason,
          );

          // 캡션의 표시 배율 = 실제 표시 비율
          final percent = (shown.width / device.size.width * 100).round();
          expect(
            find.textContaining('표시 배율 $percent%'),
            findsOneWidget,
            reason: reason,
          );
        }
      }
    });

    testWidgets('축소 표시 중에도 키를 누를 수 있다', (tester) async {
      await _pumpPreview(tester, window: const Size(1000, 700));
      final tablet = previewDevices.indexWhere((d) => d.size.height > 1000);
      expect(tablet, isNonNegative);
      await tester.tap(find.byKey(ValueKey('preview-device-$tablet')));
      await tester.pumpAndSettle();
      expect(tester.getRect(_deviceScreen).height, lessThan(700));

      await _press(tester, CalcKeyId.num7);
      expect(_logLines(tester), ['1. 7']);
    });

    for (final window in const [
      Size(1280, 400),
      Size(1280, 300),
      Size(639, 800),
      Size(500, 800),
      Size(300, 600),
      Size(200, 300),
    ]) {
      testWidgets('작은 창 $window에서도 오버플로 없이 그려진다', (tester) async {
        await _pumpPreview(tester, window: window);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(CalculatorScreen), findsOneWidget);
        // 좁은 창은 위아래 배치: 기기 화면이 창 폭 안에 들어간다.
        expect(
          tester.getRect(_deviceScreen).right,
          lessThanOrEqualTo(window.width),
        );
      });
    }

    testWidgets('창이 기기 화면을 그릴 수 없을 만큼 좁으면 안내 문구를 보인다', (tester) async {
      await _pumpPreview(tester, window: const Size(30, 400));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('preview-frame-too-small')),
        findsOneWidget,
      );
      expect(_deviceScreen, findsNothing);
    });
  });
}

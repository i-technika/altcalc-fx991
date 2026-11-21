import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/domain/models/calc_state.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:material_ui/material_ui.dart';

import '../../preview/key_preview_main.dart';

/// 개발용 미리보기 실행기(#21)가 앱 코드 변경에 맞춰 계속 동작하는지 지킨다.
/// (`flutter analyze`가 컴파일을, 이 테스트가 실행·입력 기록을 CI에서 검증한다.)

/// 데스크톱 브라우저 창 크기로 미리보기를 띄운다.
Future<void> _pumpPreview(
  WidgetTester tester, {
  Size window = const Size(1280, 900),
}) async {
  tester.view.physicalSize = window * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const ProviderScope(child: KeyPreviewApp()));
}

Finder _keycap(CalcKeyId id) => find.byKey(CalcKeyButton.keycapKeyOf(id));

/// 로그 목록에 표시된 줄 (최근 입력이 먼저)
List<String> _logLines(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('preview-log')),
        matching: find.byType(Text),
      ),
    )
    .map((t) => t.data!)
    .toList();

void main() {
  group('릴리스 빌드 분리', () {
    test('lib/의 어떤 파일도 preview/를 import하지 않는다', () {
      final offenders = [
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File &&
              f.path.endsWith('.dart') &&
              f.readAsStringSync().contains('preview/'))
            f.path,
      ];
      expect(offenders, isEmpty);
    });
  });

  group('프리셋 불변식', () {
    test('기기 프리셋: 이름 중복 없음, 크기는 유한한 양수, 인셋은 화면보다 작다', () {
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

    test('글자 배율: 기본 100%로 시작하고 중복 없이 100~200% 범위', () {
      expect(previewTextScales.first, 1.0);
      expect(previewTextScales.toSet(), hasLength(previewTextScales.length));
      for (final s in previewTextScales) {
        expect(s, inInclusiveRange(1.0, 2.0));
      }
    });
  });

  group('입력 로그 문구', () {
    test('층별 표기', () {
      expect(
        describePreviewInput(KeyInput(CalcKeyId.num7, KeyLayer.main)),
        '7',
      );
      expect(
        describePreviewInput(KeyInput(CalcKeyId.calc, KeyLayer.shift)),
        'SOLVE  ← SHIFT + CALC',
      );
      final alpha = KeyInput(CalcKeyId.negative, KeyLayer.alpha);
      expect(
        describePreviewInput(alpha),
        '${alpha.label}  ← ALPHA + ${keyDefOf(CalcKeyId.negative).mainLabel}',
      );
      final repeat = KeyInput(
        autoRepeatKeys.first,
        KeyLayer.main,
        isRepeat: true,
      );
      expect(describePreviewInput(repeat), '${repeat.label} (반복)');
    });
  });

  group('미리보기 화면', () {
    testWidgets('실제 CalculatorScreen을 기본 기기 크기로 띄운다', (tester) async {
      await _pumpPreview(tester);
      expect(find.byType(CalculatorScreen), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('preview-device-screen'))),
        previewDevices.first.size,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('키 입력이 번호와 층 표기와 함께 최근 순으로 기록되고, 초기화로 비워진다', (tester) async {
      await _pumpPreview(tester);
      await tester.tap(_keycap(CalcKeyId.num7));
      await tester.pump();
      await tester.tap(_keycap(CalcKeyId.shift));
      await tester.pump();
      await tester.tap(_keycap(CalcKeyId.calc));
      await tester.pump();

      expect(_logLines(tester), ['2. SOLVE  ← SHIFT + CALC', '1. 7']);
      expect(find.text('입력 로그 (2)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('preview-reset')));
      await tester.pump();
      expect(find.byKey(const ValueKey('preview-log')), findsNothing);
      expect(find.text('입력 로그 (0)'), findsOneWidget);

      // 초기화 후에도 기록이 다시 1번부터 이어진다.
      await tester.tap(_keycap(CalcKeyId.num7));
      await tester.pump();
      expect(_logLines(tester), ['1. 7']);
    });

    testWidgets('모든 기기 프리셋 × 글자 배율에서 오류 없이 그려지고 창에 맞게 축소된다', (tester) async {
      await _pumpPreview(tester);
      for (final (i, device) in previewDevices.indexed) {
        await tester.tap(find.byKey(ValueKey('preview-device-$i')));
        for (final scale in previewTextScales) {
          await tester.tap(find.byKey(ValueKey('preview-text-scale-$scale')));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${device.label} $scale',
          );

          // 기기 화면은 논리 크기 그대로 배치되고, 표시 크기는 창 안에 들어간다.
          final screen = find.byKey(const ValueKey('preview-device-screen'));
          expect(tester.getSize(screen), device.size);
          final shown = tester.getRect(screen);
          expect(
            shown.width,
            lessThanOrEqualTo(1280 - KeyPreviewScreen.panelWidth),
            reason: device.label,
          );
          expect(shown.height, lessThanOrEqualTo(900), reason: device.label);
        }
      }
    });

    testWidgets('축소 표시 중에도 키를 누를 수 있다', (tester) async {
      // 태블릿 세로(800×1280)는 이 창에서 반드시 축소된다.
      await _pumpPreview(tester, window: const Size(1000, 700));
      final tablet = previewDevices.indexWhere((d) => d.size.height > 1000);
      expect(tablet, isNonNegative);
      await tester.tap(find.byKey(ValueKey('preview-device-$tablet')));
      await tester.pumpAndSettle();
      expect(find.textContaining('표시 배율 100%'), findsNothing);

      await tester.tap(_keycap(CalcKeyId.num7));
      await tester.pump();
      expect(_logLines(tester), ['1. 7']);
    });
  });
}

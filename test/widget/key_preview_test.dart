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

/// 기기 선택 드롭다운에서 [index]번째 프리셋을 고른다.
Future<void> _selectDevice(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(const ValueKey('preview-device-select')));
  await tester.pumpAndSettle();
  // 드롭다운 버튼 안과 펼친 메뉴에 같은 항목이 있다 — 메뉴(나중에 그려진 쪽)를 누른다.
  await tester.tap(find.byKey(ValueKey('preview-device-$index')).last);
  await tester.pumpAndSettle();
}

Future<void> _selectTextScale(WidgetTester tester, double scale) async {
  await tester.tap(find.byKey(ValueKey('preview-text-scale-$scale')));
  await tester.pumpAndSettle();
}

/// 로그에 표시된 줄 (최근 입력이 먼저). 로그가 비어 있으면 빈 목록.
/// 로그는 지연 생성 목록이라 **화면에 보이는 줄만** 센다 — 화면을 넘는 줄 수를 검사하지 말 것.
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
    test('lib/의 상대 경로 .dart URI 중 preview/ 아래로 풀리는 것이 없다', () {
      // lib/ 밖으로 나가는 길은 상대 경로뿐이다(package: URI는 lib/ 안을 가리킨다).
      // 조건부 import의 두 번째 URI 등도 잡도록, 지시문이 아니라 파일의 모든 .dart 문자열을 실제 경로로 푼다.
      final previewDir = Directory('preview').absolute.uri.path;
      bool underPreview(File from, String uri) =>
          from.absolute.uri.resolve(uri).path.startsWith(previewDir);
      // 경로 풀이 양성 대조
      expect(
        underPreview(File('lib/main.dart'), '../preview/key_preview_main.dart'),
        isTrue,
      );

      final literal = RegExp(r'''['"]([^'"\s]+\.dart)['"]''');
      var checked = 0;
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        for (final m in literal.allMatches(f.readAsStringSync())) {
          final uri = m.group(1)!;
          if (uri.startsWith('package:') || uri.startsWith('dart:')) continue;
          checked++;
          if (underPreview(f, uri)) offenders.add('${f.path} → $uri');
        }
      }
      expect(checked, greaterThan(0), reason: 'lib/의 상대 import를 하나도 읽지 못했다');
      expect(offenders, isEmpty);
    });

    test('pubspec의 주석 아닌 줄에 preview/ 경로가 없다', () {
      final lines = File('pubspec.yaml')
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
      // 같은 방식으로 실제 에셋 경로를 읽는다는 양성 대조
      expect(
        lines.where((l) => l.contains('assets/fonts/NotoSansMono-OFL.txt')),
        isNotEmpty,
      );
      expect(lines.where((l) => l.contains('preview/')), isEmpty);
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
        final gesture = d.systemGestureInsets;
        expect(gesture.isNonNegative, isTrue, reason: d.name);
        expect(gesture.vertical, lessThan(d.size.height), reason: d.name);
        expect(gesture.horizontal, lessThan(d.size.width), reason: d.name);
      }
      // 가장자리 키의 보류 입력을 미리보기로 확인할 수 있도록 제스처 영역이 있는 프리셋이 하나 이상 있다.
      expect(
        previewDevices.where((d) => d.systemGestureInsets != EdgeInsets.zero),
        isNotEmpty,
      );
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

    testWidgets('초기화는 상태와 로그를 비우고 번호를 1부터 다시 센다', (tester) async {
      await _pumpPreview(tester);
      await _press(tester, CalcKeyId.num7);
      await tester.tap(find.byKey(const ValueKey('preview-reset')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preview-log-empty')), findsOneWidget);
      expect(_logHeader(tester), '입력 로그 · 입력 0회');

      await _press(tester, CalcKeyId.num7);
      expect(_logLines(tester), ['1. 7']);
    });

    testWidgets('입력 없이 SHIFT만 대기 중일 때 초기화: 해제 알림을 기록하지 않고, 이후 변화는 빠짐없이 기록한다', (
      tester,
    ) async {
      await _pumpPreview(tester);
      await _press(tester, CalcKeyId.shift);
      await tester.tap(find.byKey(const ValueKey('preview-reset')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preview-log-empty')), findsOneWidget);

      // 처음 상태로 돌아가는 정당한 변화(SHIFT 두 번)도 삼키지 않는다.
      await _press(tester, CalcKeyId.shift);
      await _press(tester, CalcKeyId.shift);
      expect(_logLines(tester), ['[SHIFT 해제]', '[SHIFT 대기]']);
    });

    testWidgets('보관 줄 수를 줄이면 바로 오래된 줄을 버린다', (tester) async {
      await _pumpPreview(tester, logCapacity: 10);
      for (var i = 0; i < 5; i++) {
        await _press(tester, CalcKeyId.num7);
      }
      await tester.pumpWidget(
        const ProviderScope(
          child: AltCalcApp(home: KeyPreviewScreen(logCapacity: 2)),
        ),
      );
      expect(_logLines(tester), ['5. 7', '4. 7']);
      expect(_logHeader(tester), '입력 로그 · 입력 5회 (최근 2줄만 표시)');
    });

    testWidgets('보통 노트북 창(1280×720)에서 입력 로그 헤더와 첫 줄이 창 안에 보인다', (tester) async {
      await _pumpPreview(tester, window: const Size(1280, 720));
      await _press(tester, CalcKeyId.num7);
      final header = tester.getRect(
        find.byKey(const ValueKey('preview-log-header')),
      );
      final line = tester.getRect(find.text('1. 7'));
      expect(header.bottom, lessThanOrEqualTo(720));
      expect(line.bottom, lessThanOrEqualTo(720));
      // 로그에 최소 10줄(줄 높이 약 17dp)이 들어갈 높이가 남는다.
      expect(720 - line.top, greaterThan(170));
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
        await _selectDevice(tester, i);
        for (final scale in previewTextScales) {
          await _selectTextScale(tester, scale);
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
          expect(
            mq.systemGestureInsets,
            device.systemGestureInsets,
            reason: reason,
          );
          expect(
            mq.textScaler.scale(10),
            closeTo(10 * scale, 1e-9),
            reason: reason,
          );

          // 논리 크기 그대로 배치되고, 표시 영역은 패널·여백(16)·캡션(24)을 뺀 영역 안에 들어간다.
          expect(tester.getSize(_deviceScreen), device.size, reason: reason);
          final shown = tester.getRect(_deviceScreen);
          final frameArea = Rect.fromLTRB(
            KeyPreviewScreen.panelWidth + previewFrameMargin,
            previewFrameMargin + previewFrameCaptionHeight,
            _window.width - previewFrameMargin,
            _window.height - previewFrameMargin,
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

    testWidgets('제스처 영역이 있는 프리셋: 화면 가장자리 키는 손을 뗄 때, 안쪽 키는 누르는 순간 입력된다', (
      tester,
    ) async {
      await _pumpPreview(tester);
      final index = previewDevices.indexWhere(
        (d) =>
            d.systemGestureInsets.left > 0 && d.systemGestureInsets.right > 0,
      );
      expect(index, isNonNegative);
      final device = previewDevices[index];
      await _selectDevice(tester, index);

      // 기기 화면이 패널 오른쪽으로 밀리고 축소되어 있어야 이 검사가 의미 있다.
      final screen = tester.getRect(_deviceScreen);
      final scale = screen.width / device.size.width;
      expect(screen.left, greaterThan(KeyPreviewScreen.panelWidth));
      expect(scale, lessThan(1));
      double toScreenX(double globalX) => (globalX - screen.left) / scale;

      /// 전역 좌표 [at]을 누르고, (누른 순간의 로그, 손을 뗀 뒤의 로그)를 ` | `로 이어 돌려준다.
      /// (레코드 안의 List는 `==`로 비교되지 않으므로 문자열로 잇는다.)
      Future<(String, String)> pressAt(Offset at) async {
        final g = await tester.startGesture(at);
        await tester.pump();
        final down = _logLines(tester).join(' | ');
        await g.up();
        await tester.pump();
        return (down, _logLines(tester).join(' | '));
      }

      // 왼쪽 끝 열(7)의 왼쪽 가장자리 — 화면 기준으로 뒤로가기 영역 안
      final left = tester.getRect(_keycap(CalcKeyId.num7));
      final leftX = left.left + 2 * scale;
      expect(toScreenX(leftX), lessThan(device.systemGestureInsets.left));
      expect(await pressAt(Offset(leftX, left.center.dy)), ('', '1. 7'));

      // 오른쪽 끝 열(AC)의 오른쪽 가장자리
      final right = tester.getRect(_keycap(CalcKeyId.ac));
      final rightX = right.right - 2 * scale;
      expect(
        toScreenX(rightX),
        greaterThan(device.size.width - device.systemGestureInsets.right),
      );
      expect(await pressAt(Offset(rightX, right.center.dy)), (
        '1. 7',
        '2. AC | 1. 7',
      ));

      // 가운데 열(8)은 누르는 순간 입력된다.
      expect(await pressAt(tester.getCenter(_keycap(CalcKeyId.num8))), (
        '3. 8 | 2. AC | 1. 7',
        '3. 8 | 2. AC | 1. 7',
      ));
    });

    testWidgets('축소 표시 중에도 키를 누를 수 있다', (tester) async {
      await _pumpPreview(tester, window: const Size(1000, 700));
      final tablet = previewDevices.indexWhere((d) => d.size.height > 1000);
      expect(tablet, isNonNegative);
      await _selectDevice(tester, tablet);
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
        final screen = tester.getRect(_deviceScreen);
        final panel = tester.getRect(
          find.byKey(const ValueKey('preview-panel')),
        );
        expect(screen.right, lessThanOrEqualTo(window.width + 0.01));
        if (window.width < KeyPreviewScreen.narrowWidth) {
          // 좁은 창은 위아래 배치: 기기 화면이 패널 위에 온다.
          expect(screen.bottom, lessThanOrEqualTo(panel.top + 0.01));
          expect(panel.width, window.width);
        } else {
          // 넓은 창은 좌우 배치: 패널이 왼쪽에 고정 폭으로 온다.
          expect(panel.width, KeyPreviewScreen.panelWidth);
          expect(screen.left, greaterThanOrEqualTo(panel.right));
        }
      });
    }

    testWidgets('창이 기기 화면을 그릴 수 없을 만큼 좁으면 안내 문구를 보인다', (tester) async {
      // 넓은 배치에서 창 높이가 여백(16×2)+캡션(24)보다 낮은 경우
      await _pumpPreview(tester, window: const Size(1280, 50));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('preview-frame-too-small')),
        findsOneWidget,
      );
      expect(_deviceScreen, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

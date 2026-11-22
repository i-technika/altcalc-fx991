import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/domain/models/calc_state.dart';
import 'package:itechnika_altcalc_fx991/domain/models/handedness.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/settings_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/handedness_dialog.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/settings_button.dart';
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
      child: AltCalcApp(
        frameBuilder: (context, screen) =>
            KeyPreviewScreen(screen: screen, logCapacity: logCapacity),
      ),
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
        ProviderScope(
          child: AltCalcApp(
            frameBuilder: (context, screen) =>
                KeyPreviewScreen(screen: screen, logCapacity: 2),
          ),
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
      // 키패드 좌우 끝 열이 뒤로가기 영역에 걸리는 프리셋 (폴더블 내부는 화면이 넓어 걸리지 않는다)
      final index = previewDevices.indexWhere((d) => d.name == '폴더블 커버');
      expect(index, isNonNegative);
      final device = previewDevices[index];
      expect(device.systemGestureInsets.left, greaterThan(0));
      expect(device.systemGestureInsets.right, greaterThan(0));
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

  group('기기 틀 안의 대화상자 (#72)', () {
    /// 좌우 분할 배치(설정 버튼이 있는) 태블릿 가로 프리셋
    int tabletLandscape() {
      final i = previewDevices.indexWhere(
        (d) => d.size.shortestSide >= 600 && d.size.width > d.size.height,
      );
      expect(i, isNonNegative);
      return i;
    }

    final dialog = find.byType(HandednessDialog);

    /// 대화상자 카드 (Dialog의 Material)
    Finder card() => find
        .descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first;

    /// 기기 화면 안의 앱 루트 Navigator
    Finder appNavigator() => find
        .descendant(of: _deviceScreen, matching: find.byType(Navigator))
        .first;

    /// 기기 화면 안의 장벽들
    Finder deviceBarriers() =>
        find.descendant(of: _deviceScreen, matching: find.byType(ModalBarrier));

    bool inside(Rect outer, Rect inner) =>
        outer.inflate(0.01).contains(inner.topLeft) &&
        outer.inflate(0.01).contains(inner.bottomRight);

    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.byKey(SettingsButton.buttonKey));
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
    }

    /// 패널의 빈 곳 (기기 틀 밖) — 넓은 창에서 패널은 왼쪽 열
    Offset panelBlank(WidgetTester tester) {
      final panel = tester.getRect(find.byKey(const ValueKey('preview-panel')));
      return Offset(panel.center.dx, panel.bottom - 4);
    }

    testWidgets('축소된 기기 틀의 안전 영역 가운데에 뜨고, 기기 MediaQuery(크기·글자 배율)를 물려받는다', (
      tester,
    ) async {
      await _pumpPreview(tester);
      final index = tabletLandscape();
      final device = previewDevices[index];
      await _selectDevice(tester, index);
      await _selectTextScale(tester, 1.3);
      final screen = tester.getRect(_deviceScreen);
      final scale = screen.width / device.size.width;
      expect(scale, lessThan(1)); // 축소 표시 중

      final barriersBefore = tester.widgetList(deviceBarriers()).length;
      await openSettings(tester);
      // 대화상자의 장벽이 기기 Navigator 안에 하나 더 생긴다(페이지 라우트의 장벽과 별개).
      expect(tester.widgetList(deviceBarriers()).length, barriersBefore + 1);
      final dismissible = tester
          .widgetList<ModalBarrier>(deviceBarriers())
          .where((b) => b.dismissible);
      expect(dismissible, hasLength(1));
      expect(
        inside(screen, tester.getRect(find.byWidget(dismissible.single))),
        isTrue,
      );

      // 카드는 기기 안전 영역(인셋을 뺀 영역)의 가운데에 있다.
      expect(device.padding, isNot(EdgeInsets.zero));
      final safe = Rect.fromLTRB(
        screen.left + device.padding.left * scale,
        screen.top + device.padding.top * scale,
        screen.right - device.padding.right * scale,
        screen.bottom - device.padding.bottom * scale,
      );
      final cardRect = tester.getRect(card());
      expect(inside(safe, cardRect), isTrue);
      expect(cardRect.center.dx, moreOrLessEquals(safe.center.dx, epsilon: 1));
      expect(cardRect.center.dy, moreOrLessEquals(safe.center.dy, epsilon: 1));

      final media = MediaQuery.of(tester.element(dialog));
      expect(media.size, device.size);
      expect(media.textScaler, const TextScaler.linear(1.3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('기기 틀 밖(패널)을 눌러도 닫히지 않고, 기기 화면 장벽을 누르면 닫힌다', (tester) async {
      await _pumpPreview(tester);
      await _selectDevice(tester, tabletLandscape());
      await openSettings(tester);

      await tester.tapAt(panelBlank(tester));
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);

      final screen = tester.getRect(_deviceScreen);
      await tester.tapAt(screen.topLeft + const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
    });

    testWidgets('축소 표시 중에도 선택지·닫기 버튼을 누를 수 있고, 뒤의 키패드가 바로 옮겨진다', (
      tester,
    ) async {
      await _pumpPreview(tester, window: const Size(1000, 700));
      await _selectDevice(tester, tabletLandscape());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CalculatorScreen)),
      );
      final keypad = find.byKey(const ValueKey('calc-keypad'));
      final screen = tester.getRect(_deviceScreen);
      expect(tester.getRect(keypad).center.dx, greaterThan(screen.center.dx));

      await openSettings(tester);
      await tester.tap(
        find.byKey(HandednessDialog.optionKeyOf(Handedness.left)),
      );
      await tester.pumpAndSettle();
      expect(container.read(handednessProvider), Handedness.left);
      expect(tester.getRect(keypad).center.dx, lessThan(screen.center.dx));

      await tester.tap(find.byKey(HandednessDialog.closeKey));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
    });

    testWidgets('열린 채 모든 기기 프리셋 × 글자 배율로 바꿔도 넘치지 않고 그 기기 크기로 다시 그려진다', (
      tester,
    ) async {
      await _pumpPreview(tester);
      await _selectDevice(tester, tabletLandscape());
      await openSettings(tester);

      for (var i = 0; i < previewDevices.length; i++) {
        // 대화상자가 열려 있어도 옆 패널은 쓸 수 있다(장벽은 기기 화면만 덮는다).
        await _selectDevice(tester, i);
        for (final scale in previewTextScales) {
          await _selectTextScale(tester, scale);
          final label = '${previewDevices[i].name} 글자 $scale';
          expect(tester.takeException(), isNull, reason: label);
          expect(dialog, findsOneWidget, reason: label);
          final media = MediaQuery.of(tester.element(dialog));
          expect(media.size, previewDevices[i].size, reason: label);
          expect(media.textScaler, TextScaler.linear(scale), reason: label);
          expect(
            inside(tester.getRect(_deviceScreen), tester.getRect(card())),
            isTrue,
            reason: label,
          );
        }
      }
    });

    testWidgets(
      '창 배치가 좌우 ↔ 위아래로 바뀌거나 창이 잠시 너무 작아져도 앱 Navigator와 열린 대화상자가 유지된다',
      (tester) async {
        await _pumpPreview(tester);
        await _selectDevice(tester, tabletLandscape());
        await openSettings(tester);
        final navigator = tester.state<NavigatorState>(appNavigator());

        for (final window in const [Size(600, 900), _window]) {
          tester.view.physicalSize = window * tester.view.devicePixelRatio;
          await tester.pumpAndSettle();
          expect(dialog, findsOneWidget, reason: '$window');
          expect(
            identical(tester.state<NavigatorState>(appNavigator()), navigator),
            isTrue,
            reason: '$window',
          );
          expect(tester.takeException(), isNull);
        }

        // 기기 화면을 그릴 수 없을 만큼 작은 창(넓은 배치에서 높이가 여백+캡션보다 낮음):
        // 안내 문구만 보이고 앱 화면은 숨겨진 채 남는다.
        tester.view.physicalSize =
            const Size(1280, 50) * tester.view.devicePixelRatio;
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('preview-frame-too-small')),
          findsOneWidget,
        );
        expect(dialog, findsNothing);
        expect(
          find.byType(HandednessDialog, skipOffstage: false),
          findsOneWidget,
        );
        // 숨겨진 쪽에는 기기 화면 키가 없으므로, 살아 있는 Navigator 중에 원래 State가 있는지로 확인한다.
        expect(
          tester
              .stateList<NavigatorState>(
                find.byType(Navigator, skipOffstage: false),
              )
              .any((s) => identical(s, navigator)),
          isTrue,
        );

        tester.view.physicalSize = _window * tester.view.devicePixelRatio;
        await tester.pumpAndSettle();
        expect(dialog, findsOneWidget);
        expect(
          identical(tester.state<NavigatorState>(appNavigator()), navigator),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Esc와 시스템 뒤로가기는 기기 화면의 대화상자를 먼저 닫는다', (tester) async {
      await _pumpPreview(tester);
      await _selectDevice(tester, tabletLandscape());

      await openSettings(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);

      await openSettings(tester);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      // 닫을 것이 없으면 기기 화면(첫 라우트)은 남는다.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CalculatorScreen), findsOneWidget);
    });

    testWidgets('툴팁도 기기 틀 안에 기기 축소 배율로 그려진다', (tester) async {
      await _pumpPreview(tester);
      final index = tabletLandscape();
      await _selectDevice(tester, index);
      final screen = tester.getRect(_deviceScreen);
      final scale = screen.width / previewDevices[index].size.width;
      expect(scale, lessThan(1));

      await tester.longPress(find.byKey(SettingsButton.buttonKey));
      await tester.pump(const Duration(milliseconds: 100));
      final tooltip = find.text('Settings');
      expect(tooltip, findsOneWidget);
      // 요소 트리상 위치(OverlayPortal 자식은 포털 아래)가 아니라 실제로 그려진 곳으로 판정한다:
      // 기기 Overlay에 그려지면 기기 틀의 축소가 함께 적용되고, 기기 화면 안에 있다.
      final drawn = tester.getRect(tooltip);
      final local = tester.getSize(tooltip);
      expect(
        drawn.height / local.height,
        moreOrLessEquals(scale, epsilon: 1e-6),
      );
      expect(inside(screen, drawn), isTrue);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });
  });
}

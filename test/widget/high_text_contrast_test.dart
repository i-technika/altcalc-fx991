import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/core/theme/high_text_contrast.dart';
import 'package:itechnika_altcalc_fx991/main.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/calc_key_button.dart';
import 'package:material_ui/material_ui.dart';

/// Android "고대비 텍스트" 설정 수신([SystemHighTextContrast])과 팔레트 연결([CalcPalette.of]) (#95).

/// 이벤트 채널을 흉내 낸다. 구독되면 [initial]을 보내고(`null`이면 보내지 않음), 이후 [sink]로 값을 보낸다.
class _FakeChannel {
  int listenCount = 0;
  int cancelCount = 0;
  MockStreamHandlerEventSink? sink;

  _FakeChannel(WidgetTester tester, {Object? initial = false}) {
    tester.binding.defaultBinaryMessenger.setMockStreamHandler(
      SystemHighTextContrast.channel,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          listenCount++;
          sink = events;
          if (initial != null) events.success(initial);
        },
        onCancel: (arguments) {
          cancelCount++;
          sink = null;
        },
      ),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockStreamHandler(
        SystemHighTextContrast.channel,
        null,
      ),
    );
  }
}

/// 새 수신기를 만들고 테스트가 끝나면 정리한다.
SystemHighTextContrast _receiver() {
  final receiver = SystemHighTextContrast();
  addTearDown(receiver.dispose);
  return receiver;
}

/// 키캡 배경색
Color? _keycapColor(WidgetTester tester, CalcKeyId id) =>
    (tester
                .widget<AnimatedContainer>(
                  find.byKey(CalcKeyButton.keycapKeyOf(id)),
                )
                .decoration!
            as BoxDecoration)
        .color;

void main() {
  group('SystemHighTextContrast — 설정 수신', () {
    testWidgets('Android: 구독 시작 때 받은 첫 값을 기다렸다가 반영하고, 이후 변경도 따른다', (
      tester,
    ) async {
      final channel = _FakeChannel(tester, initial: true);
      final receiver = _receiver();
      var notified = 0;
      receiver.addListener(() => notified++);

      await receiver.start();
      expect(channel.listenCount, 1);
      expect(receiver.value, isTrue);
      expect(notified, 1);

      channel.sink!.success(false);
      await tester.pump();
      expect(receiver.value, isFalse);
      expect(notified, 2);

      // 같은 값은 알리지 않는다 (불필요한 다시 빌드 방지)
      channel.sink!.success(false);
      await tester.pump();
      expect(notified, 2);
    });

    testWidgets('여러 번 시작해도 구독은 한 번이다', (tester) async {
      final channel = _FakeChannel(tester);
      final receiver = _receiver();
      await receiver.start();
      await receiver.start();
      expect(channel.listenCount, 1);
      expect(receiver.isListening, isTrue);
    });

    testWidgets('첫 호출이 끝나기 전에 다시 불러도 같은 첫 값을 기다린다', (tester) async {
      final channel = _FakeChannel(tester, initial: null);
      final receiver = _receiver();
      var firstDone = false;
      var secondDone = false;
      final first = receiver.start().then((_) => firstDone = true);
      final second = receiver.start().then((_) => secondDone = true);
      await tester.pump();
      expect(channel.listenCount, 1);
      expect([firstDone, secondDone], [false, false]);

      channel.sink!.success(true);
      await Future.wait([first, second]);
      expect([firstDone, secondDone], [true, true]);
      expect(receiver.value, isTrue);
    });

    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      testWidgets('${platform.name}: 구독하지 않고 늘 꺼짐이다', (tester) async {
        final channel = _FakeChannel(tester, initial: true);
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final receiver = _receiver();
        await receiver.start();
        expect(channel.listenCount, 0);
        expect(receiver.isListening, isFalse);
        expect(receiver.value, isFalse);
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testWidgets('오류 이벤트는 꺼짐을 유지하고 시작을 끝낸다', (tester) async {
      final channel = _FakeChannel(tester, initial: null);
      final receiver = _receiver();
      final started = receiver.start();
      await tester.pump();
      channel.sink!.error(code: 'boom', message: '읽기 실패');
      await started;
      expect(receiver.value, isFalse);
      // 오류 뒤에도 구독은 남아 다음 값을 받는다
      channel.sink!.success(true);
      await tester.pump();
      expect(receiver.value, isTrue);
    });

    testWidgets('구독 요청(listen) 자체가 실패하면 제한 시간 뒤 꺼짐으로 시작한다', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockStreamHandler(
        SystemHighTextContrast.channel,
        MockStreamHandler.inline(
          onListen: (arguments, events) =>
              throw PlatformException(code: 'listen-failed'),
        ),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockStreamHandler(
          SystemHighTextContrast.channel,
          null,
        ),
      );
      final receiver = _receiver();
      var done = false;
      final started = receiver.start().then((_) => done = true);
      await tester.pump();
      // Flutter가 FlutterError로만 알리고 스트림에는 오지 않는다
      expect(tester.takeException(), isA<PlatformException>());
      expect(done, isFalse);
      await tester.pump(SystemHighTextContrast.firstValueTimeout);
      await started;
      expect(receiver.value, isFalse);
    });

    testWidgets('첫 값을 기다리는 중에 멈추면 대기가 바로 끝난다', (tester) async {
      _FakeChannel(tester, initial: null);
      final receiver = _receiver();
      var done = false;
      final started = receiver.start().then((_) => done = true);
      await tester.pump();
      receiver.stop();
      await tester.pump();
      await started;
      expect(done, isTrue);
      expect(receiver.isListening, isFalse);
    });

    testWidgets('bool이 아닌 값은 무시한다', (tester) async {
      final channel = _FakeChannel(tester, initial: 1);
      final receiver = _receiver();
      await receiver.start();
      expect(receiver.value, isFalse);
      channel.sink!.success(true);
      await tester.pump();
      expect(receiver.value, isTrue);
      channel.sink!.success('false');
      await tester.pump();
      expect(receiver.value, isTrue);
    });

    testWidgets('첫 값이 오지 않으면 제한 시간 뒤 꺼짐으로 시작하고, 늦게 온 값은 그때 반영한다', (
      tester,
    ) async {
      final channel = _FakeChannel(tester, initial: null);
      final receiver = _receiver();
      var done = false;
      final started = receiver.start().then((_) => done = true);
      await tester.pump(
        SystemHighTextContrast.firstValueTimeout -
            const Duration(milliseconds: 1),
      );
      expect(done, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      await started;
      expect(done, isTrue);
      expect(receiver.value, isFalse);

      channel.sink!.success(true);
      await tester.pump();
      expect(receiver.value, isTrue);
    });

    testWidgets('stop은 구독을 끝내고 꺼짐으로 되돌린다', (tester) async {
      final channel = _FakeChannel(tester, initial: true);
      final receiver = _receiver();
      await receiver.start();
      receiver.stop();
      await tester.pump();
      expect(channel.cancelCount, 1);
      expect(receiver.isListening, isFalse);
      expect(receiver.value, isFalse);
      // 다시 시작할 수 있다
      await receiver.start();
      expect(channel.listenCount, 2);
      expect(receiver.value, isTrue);
    });
  });

  group('CalcPalette.of — MediaQuery.highContrast와 고대비 텍스트 결합', () {
    /// [highContrast](MediaQuery)와 [highText](범위 값)로 팔레트를 고르는 위젯을 띄우고, 고른 팔레트를 기록한다.
    Future<List<CalcPalette>> pumpProbe(
      WidgetTester tester, {
      required ValueListenable<bool>? highText,
      bool highContrast = false,
    }) async {
      final built = <CalcPalette>[];
      final probe = Builder(
        builder: (context) {
          built.add(CalcPalette.of(context));
          return const SizedBox.shrink();
        },
      );
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(highContrast: highContrast),
          child: highText == null
              ? probe
              : HighTextContrastScope(notifier: highText, child: probe),
        ),
      );
      return built;
    }

    testWidgets('범위 밖이면 MediaQuery만 따른다', (tester) async {
      expect(await pumpProbe(tester, highText: null), [CalcPalette.standard]);
      expect(await pumpProbe(tester, highText: null, highContrast: true), [
        CalcPalette.highContrast,
      ]);
    });

    for (final (mediaQuery, highText, expected) in [
      (false, false, CalcPalette.standard),
      (true, false, CalcPalette.highContrast),
      (false, true, CalcPalette.highContrast),
      (true, true, CalcPalette.highContrast),
    ]) {
      testWidgets('MediaQuery $mediaQuery · 고대비 텍스트 $highText → '
          '${expected.isHighContrast ? '고대비' : '일반'}', (tester) async {
        final notifier = ValueNotifier(highText);
        addTearDown(notifier.dispose);
        final built = await pumpProbe(
          tester,
          highText: notifier,
          highContrast: mediaQuery,
        );
        expect(built.single, expected);
      });
    }

    testWidgets('고대비 텍스트가 바뀌면 의존하는 위젯을 다시 빌드한다', (tester) async {
      final highText = ValueNotifier(false);
      addTearDown(highText.dispose);
      final built = await pumpProbe(tester, highText: highText);
      expect(built, [CalcPalette.standard]);

      highText.value = true;
      await tester.pump();
      expect(built.last, CalcPalette.highContrast);

      highText.value = false;
      await tester.pump();
      expect(built.last, CalcPalette.standard);
      expect(built, hasLength(3));
    });
  });

  group('AltCalcApp — 앱 화면 연결', () {
    testWidgets('고대비 텍스트가 켜지면 MediaQuery 고대비 없이도 키캡이 고대비 색이 되고, 꺼지면 돌아온다', (
      tester,
    ) async {
      final highText = ValueNotifier(false);
      addTearDown(highText.dispose);
      await tester.pumpWidget(
        ProviderScope(child: AltCalcApp(highTextContrast: highText)),
      );
      expect(
        MediaQuery.highContrastOf(
          tester.element(find.byType(CalcKeyButton).first),
        ),
        isFalse,
      );
      expect(
        _keycapColor(tester, CalcKeyId.add),
        CalcPalette.standard.keyBackground(KeyCategory.operator),
      );

      highText.value = true;
      await tester.pumpAndSettle();
      expect(
        _keycapColor(tester, CalcKeyId.add),
        CalcPalette.highContrast.keyBackground(KeyCategory.operator),
      );
      expect(tester.takeException(), isNull);

      highText.value = false;
      await tester.pumpAndSettle();
      expect(
        _keycapColor(tester, CalcKeyId.add),
        CalcPalette.standard.keyBackground(KeyCategory.operator),
      );
    });

    testWidgets('값을 넘기지 않으면 앱 전체 수신기(SystemHighTextContrast.instance)를 쓴다', (
      tester,
    ) async {
      _FakeChannel(tester, initial: true);
      addTearDown(SystemHighTextContrast.instance.stop);
      await SystemHighTextContrast.instance.start();
      await tester.pumpWidget(const ProviderScope(child: AltCalcApp()));
      await tester.pump();
      expect(
        _keycapColor(tester, CalcKeyId.add),
        CalcPalette.highContrast.keyBackground(KeyCategory.operator),
      );
    });
  });
}

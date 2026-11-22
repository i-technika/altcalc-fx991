import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/layout/form_factor.dart';

/// 세로 접힘선 (폴더블 내부 화면 펼침)
const _fold = DisplayFeature(
  bounds: Rect.fromLTWH(420, 0, 0, 701),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureFlat,
);

/// 물리 힌지 (Surface Duo 등 두 화면 기기)
const _hinge = DisplayFeature(
  bounds: Rect.fromLTWH(540, 0, 34, 720),
  type: DisplayFeatureType.hinge,
  state: DisplayFeatureState.postureFlat,
);

/// 화면 구멍 (카메라 노치)
const _cutout = DisplayFeature(
  bounds: Rect.fromLTWH(180, 0, 40, 30),
  type: DisplayFeatureType.cutout,
  state: DisplayFeatureState.unknown,
);

/// 좌우 분할 배치인지
bool _split(
  Size window,
  List<DisplayFeature> features, {
  bool foldableDevice = false,
}) =>
    FormFactor.arrangementOf(
      window,
      features,
      foldableDevice: foldableDevice,
    ) ==
    ScreenArrangement.split;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('기기 종류 판정', () {
    test('짧은 변 600dp 미만은 폰이다 (가로·세로 무관)', () {
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(430, 932),
        Size(344, 882), // 폴더블 커버 화면
        Size(844, 390),
        Size(599.9, 1000),
      ]) {
        expect(FormFactor.deviceKindOf(size, const []), DeviceKind.phone);
      }
    });

    test('짧은 변 600dp 이상이고 접히는 부분이 없으면 태블릿이다 (가로·세로 무관)', () {
      for (final size in const [
        Size(600, 960),
        Size(800, 1280),
        Size(1280, 800),
        Size(744, 1133), // iPad mini
        Size(1366, 1024), // iPad Pro 12.9
      ]) {
        expect(FormFactor.deviceKindOf(size, const []), DeviceKind.tablet);
      }
    });

    test('접히는 부분(fold·hinge)이 있으면 크기와 무관하게 폴더블이다', () {
      for (final f in const [_fold, _hinge]) {
        expect(
          FormFactor.deviceKindOf(const Size(841, 701), [f]),
          DeviceKind.foldable,
        );
        expect(
          FormFactor.deviceKindOf(const Size(1280, 800), [f]),
          DeviceKind.foldable,
        );
      }
    });

    test('화면 구멍(cutout)은 접히는 부분이 아니다', () {
      expect(FormFactor.hasFoldOrHinge(const [_cutout]), isFalse);
      expect(
        FormFactor.deviceKindOf(const Size(1280, 800), const [_cutout]),
        DeviceKind.tablet,
      );
      expect(FormFactor.hasFoldOrHinge(const [_cutout, _fold]), isTrue);
    });

    test('힌지 센서가 있으면 접힘 정보가 오기 전에도 폴더블이다 (커버 화면 포함)', () {
      for (final size in const [Size(841, 701), Size(344, 882)]) {
        expect(
          FormFactor.deviceKindOf(size, const [], hasHingeSensor: true),
          DeviceKind.foldable,
        );
      }
    });

    group('힌지 센서 조회', () {
      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(FormFactor.deviceChannel, null);
        debugDefaultTargetPlatformOverride = null;
      });

      void mockChannel(Future<Object?> Function(MethodCall) handler) =>
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(FormFactor.deviceChannel, handler);

      test('Android: 채널 응답을 그대로 쓴다', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final methods = <String>[];
        mockChannel((call) async {
          methods.add(call.method);
          return true;
        });
        expect(await FormFactor.queryHingeSensor(), isTrue);
        expect(methods, ['hasHingeSensor']);
      });

      test('Android: 채널 오류·미등록·null 응답이면 false', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        mockChannel((_) async => throw PlatformException(code: 'x'));
        expect(await FormFactor.queryHingeSensor(), isFalse);
        mockChannel((_) async => null);
        expect(await FormFactor.queryHingeSensor(), isFalse);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(FormFactor.deviceChannel, null);
        expect(await FormFactor.queryHingeSensor(), isFalse); // MissingPlugin
      });

      test('Android: 그 밖의 오류(응답 타입 등)도 false', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        mockChannel((_) async => 'not a bool');
        expect(await FormFactor.queryHingeSensor(), isFalse);
      });

      test('Android: 제한 시간 안에 응답이 없으면 false (앱 시작이 멈추지 않는다)', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final never = Completer<ByteData?>();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(
              FormFactor.deviceChannel.name,
              (_) => never.future,
            );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMessageHandler(FormFactor.deviceChannel.name, null),
        );
        final watch = Stopwatch()..start();
        expect(await FormFactor.queryHingeSensor(), isFalse);
        expect(
          watch.elapsed,
          greaterThanOrEqualTo(FormFactor.hingeQueryTimeout),
        );
      });

      test('iOS: 채널을 부르지 않고 false', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        var called = false;
        mockChannel((_) async {
          called = true;
          return true;
        });
        expect(await FormFactor.queryHingeSensor(), isFalse);
        expect(called, isFalse);
      });
    });
  });

  group('방향 요청', () {
    test('폰·폴더블은 세로, 태블릿은 가로 두 방향', () {
      expect(FormFactor.preferredOrientationsFor(DeviceKind.phone), [
        DeviceOrientation.portraitUp,
      ]);
      expect(FormFactor.preferredOrientationsFor(DeviceKind.foldable), [
        DeviceOrientation.portraitUp,
      ]);
      expect(FormFactor.preferredOrientationsFor(DeviceKind.tablet), [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });

    test('모든 기기 종류가 방향을 하나 이상 요청한다 (빈 목록은 "제한 없음"이 된다)', () {
      for (final kind in DeviceKind.values) {
        expect(FormFactor.preferredOrientationsFor(kind), isNotEmpty);
      }
    });
  });

  group('좌우 분할 배치 판정 (창 크기 기준)', () {
    test('대화면 가로 창은 좌우 분할이다', () {
      for (final size in const [
        Size(1280, 800),
        Size(1024, 768),
        Size(1194, 834),
        Size(1366, 1024),
        Size(960, 600),
      ]) {
        expect(_split(size, const []), isTrue, reason: '$size');
      }
    });

    test('세로 창·정사각형 창·짧은 변 600dp 미만 창은 위아래 배치다', () {
      for (final size in const [
        Size(800, 1280), // 태블릿 세로 (방향 고정 무시)
        Size(768, 768), // 정사각형
        Size(678, 1024), // iPad Split View 절반
        Size(390, 844), // 폰
        Size(844, 390), // 가로 폰 — 짧은 창 대응은 #38
        Size(1280, 599), // 낮고 넓은 팝업 창
      ]) {
        expect(_split(size, const []), isFalse, reason: '$size');
      }
    });

    test('폴더블 기기는 접힘 정보가 없어도 위아래 배치다 (깜빡임 방지, 분할은 #25)', () {
      expect(
        _split(const Size(829, 690), const [], foldableDevice: true),
        isFalse,
      );
      expect(
        _split(const Size(1280, 800), const [], foldableDevice: true),
        isFalse,
      );
    });

    test('접히는 부분이 창을 지나면 위아래 배치다 (힌지 기준 분할은 #25)', () {
      expect(_split(const Size(1280, 800), [_fold]), isFalse);
      expect(_split(const Size(1280, 800), [_hinge]), isFalse);
      expect(_split(const Size(1280, 800), const [_cutout]), isTrue);
    });
  });
}

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
    const phoneDisplay = Size(390, 844);
    const coverDisplay = Size(344, 882); // 폴더블 커버 화면
    const innerDisplay = Size(673, 841); // 폴더블 내부 화면
    const tabletDisplay = Size(1280, 800);

    test('폰·폴더블 커버 화면은 세로, 태블릿은 가로, 폴더블 내부 화면은 네 방향 모두', () {
      expect(
        FormFactor.orientationPolicyOf(DeviceKind.phone, phoneDisplay),
        OrientationPolicy.portrait,
      );
      expect(
        FormFactor.orientationPolicyOf(DeviceKind.foldable, coverDisplay),
        OrientationPolicy.portrait,
      );
      expect(
        FormFactor.orientationPolicyOf(DeviceKind.foldable, innerDisplay),
        OrientationPolicy.any,
      );
      // 내부 화면을 돌려도(가로) 같다
      expect(
        FormFactor.orientationPolicyOf(
          DeviceKind.foldable,
          const Size(841, 673),
        ),
        OrientationPolicy.any,
      );
      expect(
        FormFactor.orientationPolicyOf(DeviceKind.tablet, tabletDisplay),
        OrientationPolicy.landscape,
      );
    });

    test('정책별 방향 목록', () {
      expect(FormFactor.preferredOrientationsOf(OrientationPolicy.portrait), [
        DeviceOrientation.portraitUp,
      ]);
      expect(FormFactor.preferredOrientationsOf(OrientationPolicy.landscape), [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      expect(
        FormFactor.preferredOrientationsOf(OrientationPolicy.any).toSet(),
        DeviceOrientation.values.toSet(),
      );
    });

    test('모든 정책이 방향을 하나 이상 요청한다 (빈 목록은 "제한 없음"이 된다)', () {
      for (final policy in OrientationPolicy.values) {
        expect(FormFactor.preferredOrientationsOf(policy), isNotEmpty);
      }
    });
  });

  group('접힘선 판정 (hingeOf)', () {
    const window = Size(673, 841);

    DisplayFeature feature(Rect bounds, {DisplayFeatureType? type}) =>
        DisplayFeature(
          bounds: bounds,
          type: type ?? DisplayFeatureType.fold,
          state: DisplayFeatureState.postureFlat,
        );

    test('창을 위에서 아래로 가로지르는 세로 접힘선 (폭 0)', () {
      final hinge = FormFactor.hingeOf(window, [
        feature(const Rect.fromLTWH(336, 0, 0, 841)),
      ]);
      expect(hinge?.bounds, const Rect.fromLTWH(336, 0, 0, 841));
      expect(FormFactor.isVerticalHinge(hinge!.bounds), isTrue);
    });

    test('창을 왼쪽에서 오른쪽으로 가로지르는 가로 접힘선', () {
      final hinge = FormFactor.hingeOf(const Size(841, 673), [
        feature(const Rect.fromLTWH(0, 336, 841, 0)),
      ]);
      expect(hinge, isNotNull);
      expect(FormFactor.isVerticalHinge(hinge!.bounds), isFalse);
    });

    test('폭이 있는 물리 힌지도 접힘선이다', () {
      final hinge = FormFactor.hingeOf(const Size(1114, 720), [
        feature(
          const Rect.fromLTWH(540, 0, 34, 720),
          type: DisplayFeatureType.hinge,
        ),
      ]);
      expect(hinge?.bounds, const Rect.fromLTWH(540, 0, 34, 720));
      expect(FormFactor.isVerticalHinge(hinge!.bounds), isTrue);
    });

    test('화면 구멍, 창을 다 가로지르지 않는 접힘 정보, 창 밖 접힘 정보는 접힘선이 아니다', () {
      expect(FormFactor.hingeOf(window, const [_cutout]), isNull);
      // 위아래 일부만 지나는 접힘 정보
      expect(
        FormFactor.hingeOf(window, [
          feature(const Rect.fromLTWH(336, 100, 0, 600)),
        ]),
        isNull,
      );
      // 창 밖 (오른쪽)
      expect(
        FormFactor.hingeOf(window, [
          feature(const Rect.fromLTWH(700, 0, 0, 841)),
        ]),
        isNull,
      );
      // 비유한 좌표
      expect(
        FormFactor.hingeOf(window, [
          feature(const Rect.fromLTWH(double.nan, 0, 0, 841)),
        ]),
        isNull,
      );
      expect(FormFactor.hingeOf(window, const []), isNull);
    });

    test('여러 개면 창을 가로지르는 첫 접힘선을 쓴다', () {
      final hinge = FormFactor.hingeOf(window, [
        _cutout,
        feature(const Rect.fromLTWH(336, 100, 0, 600)),
        feature(const Rect.fromLTWH(336, 0, 0, 841)),
      ]);
      expect(hinge?.bounds, const Rect.fromLTWH(336, 0, 0, 841));
    });

    test('화면을 실제로 나누는 접힘선: 폭이 있는 힌지 또는 반 접힘 (isSeparating과 같은 기준)', () {
      DisplayFeature f(double width, DisplayFeatureState state) =>
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 336, 841, width),
            type: DisplayFeatureType.fold,
            state: state,
          );
      expect(
        FormFactor.separates(f(0, DisplayFeatureState.postureFlat)),
        isFalse,
      );
      expect(FormFactor.separates(f(0, DisplayFeatureState.unknown)), isFalse);
      expect(
        FormFactor.separates(f(0, DisplayFeatureState.postureHalfOpened)),
        isTrue,
      );
      expect(
        FormFactor.separates(f(30, DisplayFeatureState.postureFlat)),
        isTrue,
      );
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

    test('폴더블 기기는 접힘 정보가 오기 전에는 위아래 배치다 (깜빡임 방지)', () {
      for (final size in const [Size(829, 690), Size(1280, 800)]) {
        expect(
          FormFactor.arrangementOf(size, const [], foldableDevice: true),
          ScreenArrangement.stacked,
          reason: '$size',
        );
      }
    });

    test('창을 다 가로지르지 않는 접힘 정보가 있으면 위아래 배치다', () {
      // _fold는 높이 701 — 1280×800 창을 끝까지 가로지르지 않는다.
      expect(_split(const Size(1280, 800), [_fold]), isFalse);
      expect(_split(const Size(1280, 800), [_hinge]), isFalse);
      expect(_split(const Size(1280, 800), const [_cutout]), isTrue);
    });
  });

  group('접힘선 기준 배치 판정 (#25)', () {
    test('세로 접힘선이 창을 가로지르면 접힘선 기준 좌우 배치다 (펼침·반 접힘, 폴더블 여부 무관)', () {
      for (final state in [
        DisplayFeatureState.postureFlat,
        DisplayFeatureState.postureHalfOpened,
        DisplayFeatureState.unknown,
      ]) {
        for (final foldable in [true, false]) {
          expect(
            FormFactor.arrangementOf(const Size(841, 701), [
              DisplayFeature(
                bounds: const Rect.fromLTWH(420, 0, 0, 701),
                type: DisplayFeatureType.fold,
                state: state,
              ),
            ], foldableDevice: foldable),
            ScreenArrangement.hingeSplit,
            reason: '$state foldable=$foldable',
          );
        }
      }
      // 폭이 있는 물리 힌지
      expect(
        FormFactor.arrangementOf(const Size(1114, 720), [
          const DisplayFeature(
            bounds: Rect.fromLTWH(540, 0, 34, 720),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ]),
        ScreenArrangement.hingeSplit,
      );
    });

    DisplayFeature horizontal(
      Size window,
      double y, {
      DisplayFeatureState state = DisplayFeatureState.postureHalfOpened,
      double height = 0,
      DisplayFeatureType type = DisplayFeatureType.fold,
    }) => DisplayFeature(
      bounds: Rect.fromLTWH(0, y, window.width, height),
      type: type,
      state: state,
    );

    test('가로 접힘선은 반 접은 테이블톱 자세·물리 힌지일 때만 위아래로 나눈다', () {
      for (final (window, y) in const [
        (Size(841, 673), 336.5), // Fold 내부를 가로로
        (Size(701, 841), 420.5), // Pixel Fold 내부를 세로로
        (Size(411, 1005), 502.5), // Flip 내부 (Flex 모드)
      ]) {
        expect(
          FormFactor.arrangementOf(window, [
            horizontal(window, y),
          ], foldableDevice: true),
          ScreenArrangement.hingeStacked,
          reason: '$window 반 접힘',
        );
        // 펼친 폭 0 가로 접힘선은 나누지 않는다 (키패드가 아래 절반에 갇혀 터치 하한 아래로 작아진다).
        expect(
          FormFactor.arrangementOf(window, [
            horizontal(window, y, state: DisplayFeatureState.postureFlat),
          ], foldableDevice: true),
          ScreenArrangement.stacked,
          reason: '$window 펼침',
        );
      }
      // 폭이 있는 물리 힌지는 펼쳐도 나눈다.
      const duo = Size(720, 1114);
      expect(
        FormFactor.arrangementOf(duo, [
          horizontal(
            duo,
            540,
            state: DisplayFeatureState.postureFlat,
            height: 34,
            type: DisplayFeatureType.hinge,
          ),
        ]),
        ScreenArrangement.hingeStacked,
      );
    });

    test('접힘선 한쪽이 최소 길이보다 짧으면 접힘선 기준으로 나누지 않는다', () {
      const min = FormFactor.hingeMinPanelExtent;
      const window = Size(841, 701);
      DisplayFeature vertical(double x) => DisplayFeature(
        bounds: Rect.fromLTWH(x, 0, 0, 701),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureFlat,
      );
      for (final x in [20.0, min - 1, window.width - min + 1, 830.0]) {
        expect(
          FormFactor.arrangementOf(window, [vertical(x)], foldableDevice: true),
          ScreenArrangement.stacked,
          reason: 'x=$x',
        );
      }
      for (final x in [min, window.width - min]) {
        expect(
          FormFactor.arrangementOf(window, [vertical(x)], foldableDevice: true),
          ScreenArrangement.hingeSplit,
          reason: 'x=$x',
        );
      }
      // 가로 접힘선도 같다 (위 절반이 짧은 창)
      const tall = Size(701, 841);
      expect(
        FormFactor.arrangementOf(tall, [horizontal(tall, 200)]),
        ScreenArrangement.stacked,
      );
    });

    test('접은 커버 화면(접힘 정보 없음)은 위아래 배치다', () {
      expect(
        FormFactor.arrangementOf(
          const Size(344, 882),
          const [],
          foldableDevice: true,
        ),
        ScreenArrangement.stacked,
      );
    });
  });
}

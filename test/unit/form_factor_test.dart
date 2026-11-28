import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/layout/form_factor.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';

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

/// 가로형 배치인지 (#142 — 창 모양으로 본 답)
bool _landscape(
  Size window,
  List<DisplayFeature> features, {
  bool foldableDevice = false,
}) =>
    FormFactor.arrangementOf(
      window,
      features,
      foldableDevice: foldableDevice,
    ) ==
    ScreenArrangement.landscape;

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

    test('시작 시 폴더블로 판정했으면 접힘 정보가 오기 전에도 폴더블이다 (커버 화면 포함)', () {
      for (final size in const [Size(841, 701), Size(344, 882)]) {
        expect(
          FormFactor.deviceKindOf(size, const [], foldableDevice: true),
          DeviceKind.foldable,
        );
      }
    });

    group('다른 물리 화면으로 바뀜 (#70)', () {
      test('폴더블 커버 ↔ 내부 화면 전환은 다른 화면이다 (양방향)', () {
        const pairs = [
          (Size(344, 882), Size(673, 841)), // Galaxy Z Fold 커버 → 내부
          (Size(344, 882), Size(841, 673)), // 내부를 가로로 든 채 펼침
          (Size(412, 1006), Size(360, 374)), // Galaxy Z Flip 내부 → 커버
          (Size(411, 841), Size(841, 701)), // Pixel Fold 커버 → 내부(가로가 기본)
        ];
        for (final (a, b) in pairs) {
          expect(FormFactor.isOtherScreen(a, b), isTrue, reason: '$a → $b');
          expect(FormFactor.isOtherScreen(b, a), isTrue, reason: '$b → $a');
        }
      });

      test('회전·화면 크기 확대 설정·같은 화면은 다른 화면이 아니다', () {
        const phone = Size(390, 844);
        expect(FormFactor.isOtherScreen(phone, phone), isFalse);
        expect(FormFactor.isOtherScreen(phone, phone.flipped), isFalse);
        expect(FormFactor.isOtherScreen(phone, phone * 0.85), isFalse);
        expect(FormFactor.isOtherScreen(phone, phone * 1.2), isFalse);
        // 태블릿 600dp가 확대 설정으로 짧은 변 600 밑으로 내려가도 비율은 같다
        expect(
          FormFactor.isOtherScreen(const Size(600, 960), const Size(533, 853)),
          isFalse,
        );
      });

      test('허용치 경계: 비율 차이가 허용치 이하면 같은 화면, 넘으면 다른 화면', () {
        const base = Size(400, 800); // 비율 2.0, 폰 크기
        final within = Size(
          400,
          800 * (1 + FormFactor.otherScreenAspectTolerance) - 1,
        );
        final beyond = Size(
          400,
          800 * (1 + FormFactor.otherScreenAspectTolerance) + 1,
        );
        expect(FormFactor.isOtherScreen(base, within), isFalse);
        expect(FormFactor.isOtherScreen(base, beyond), isTrue);
      });

      test('양쪽 모두 대화면인 전환(다른 디스플레이로 옮김)은 다른 화면이 아니다', () {
        const pairs = [
          (Size(1280, 853), Size(1440, 810)), // ChromeOS 3:2 노트북 ↔ 16:9 모니터
          (Size(1024, 1366), Size(1920, 1080)), // iPad ↔ 외부 모니터 (Stage Manager)
          (Size(1470, 956), Size(1920, 1080)), // MacBook ↔ 16:9 모니터
          (Size(1280, 800), Size(2560, 1080)), // 태블릿 ↔ 울트라와이드 모니터
        ];
        for (final (a, b) in pairs) {
          expect(FormFactor.isOtherScreen(a, b), isFalse, reason: '$a → $b');
          expect(FormFactor.isOtherScreen(b, a), isFalse, reason: '$b → $a');
        }
      });

      test('크기를 모르면(빈 크기) 다른 화면으로 보지 않는다', () {
        expect(
          FormFactor.isOtherScreen(Size.zero, const Size(673, 841)),
          isFalse,
        );
        expect(
          FormFactor.isOtherScreen(const Size(344, 882), Size.zero),
          isFalse,
        );
      });
    });

    group('폴더블 판정 조회', () {
      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(FormFactor.deviceChannel, null);
        debugDefaultTargetPlatformOverride = null;
      });

      const none = (foldable: false, fold: null);

      void mockChannel(Future<Object?> Function(MethodCall) handler) =>
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(FormFactor.deviceChannel, handler);

      test(
        'Android: 채널 응답(map)을 그대로 쓴다 (#158 — 폴더블 여부와 창 배치 첫 값 접힘)',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          final methods = <String>[];
          Object? reply;
          mockChannel((call) async {
            methods.add(call.method);
            return reply;
          });
          for (final (foldable, fold) in [
            (true, true),
            (true, false),
            (false, false),
          ]) {
            reply = {
              FormFactor.foldableKey: foldable,
              FormFactor.foldKey: fold,
            };
            expect(await FormFactor.queryFoldableDevice(), (
              foldable: foldable,
              fold: fold,
            ));
          }
          // 첫 값을 받지 못했으면(제한 시간 초과 등) Android는 fold에 null을 보낸다 — 모름(null) 그대로 둔다
          reply = {FormFactor.foldableKey: true, FormFactor.foldKey: null};
          expect(await FormFactor.queryFoldableDevice(), (
            foldable: true,
            fold: null,
          ));
          expect(methods, List.filled(4, FormFactor.foldableDeviceMethod));
          // 키가 없거나 bool이 아닌 값은 폴더블 아님·접힘 모름으로 읽는다
          reply = <String, Object?>{};
          expect(await FormFactor.queryFoldableDevice(), (
            foldable: false,
            fold: null,
          ));
          reply = {FormFactor.foldableKey: 'yes', FormFactor.foldKey: 1};
          expect(await FormFactor.queryFoldableDevice(), (
            foldable: false,
            fold: null,
          ));
        },
      );

      test('Android: 채널 오류·미등록·null 응답이면 둘 다 false', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        mockChannel((_) async => throw PlatformException(code: 'x'));
        expect(await FormFactor.queryFoldableDevice(), none);
        mockChannel((_) async => null);
        expect(await FormFactor.queryFoldableDevice(), none);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(FormFactor.deviceChannel, null);
        expect(await FormFactor.queryFoldableDevice(), none); // MissingPlugin
      });

      test('Android: 그 밖의 오류(응답 타입 등)도 false', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        mockChannel((_) async => 'not a map');
        expect(await FormFactor.queryFoldableDevice(), none);
        // #158 전의 bool 응답도 map이 아니므로 false
        mockChannel((_) async => true);
        expect(await FormFactor.queryFoldableDevice(), none);
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
        expect(await FormFactor.queryFoldableDevice(), none);
        expect(
          watch.elapsed,
          greaterThanOrEqualTo(FormFactor.foldableQueryTimeout),
        );
      });

      test('iOS: 채널을 부르지 않고 false', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        var called = false;
        mockChannel((_) async {
          called = true;
          return true;
        });
        expect(await FormFactor.queryFoldableDevice(), none);
        expect(called, isFalse);
      });
    });

    group('여러 창 모드 조회 (#137)', () {
      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(FormFactor.deviceChannel, null);
        debugDefaultTargetPlatformOverride = null;
      });

      void mockChannel(Future<Object?> Function(MethodCall) handler) =>
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(FormFactor.deviceChannel, handler);

      test('Android: 채널 답(bool)을 그대로 쓴다', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final methods = <String>[];
        Object? reply;
        mockChannel((call) async {
          methods.add(call.method);
          return reply;
        });
        reply = true;
        expect(await FormFactor.queryMultiWindowMode(), isTrue);
        reply = false;
        expect(await FormFactor.queryMultiWindowMode(), isFalse);
        expect(methods, List.filled(2, FormFactor.multiWindowModeMethod));
      });

      test(
        'Android: 오류·null·bool 아닌 답이면 모름(null), 채널 미등록이면 false (#137 R1)',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          mockChannel((_) async => throw PlatformException(code: 'x'));
          expect(await FormFactor.queryMultiWindowMode(), isNull);
          mockChannel((_) async => null);
          expect(await FormFactor.queryMultiWindowMode(), isNull);
          mockChannel((_) async => 'true');
          expect(await FormFactor.queryMultiWindowMode(), isNull);
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(FormFactor.deviceChannel, null);
          expect(
            await FormFactor.queryMultiWindowMode(),
            isFalse,
          ); // MissingPlugin
        },
      );

      test('Android: 제한 시간 안에 답이 없으면 모름(null)', () async {
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
        expect(await FormFactor.queryMultiWindowMode(), isNull);
        expect(
          watch.elapsed,
          greaterThanOrEqualTo(FormFactor.multiWindowQueryTimeout),
        );
      });

      test('Android의 변경 알림을 받아 넘기고, 다른 호출은 모른다고 답한다 (#137 R1)', () async {
        final received = <bool>[];
        FormFactor.onMultiWindowModeChanged(received.add);
        addTearDown(() => FormFactor.onMultiWindowModeChanged(null));
        const codec = StandardMethodCodec();
        Future<ByteData?> send(MethodCall call) {
          final reply = Completer<ByteData?>();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .handlePlatformMessage(
                FormFactor.deviceChannel.name,
                codec.encodeMethodCall(call),
                reply.complete,
              );
          return reply.future;
        }

        await send(
          const MethodCall(FormFactor.multiWindowModeChangedMethod, true),
        );
        await send(
          const MethodCall(FormFactor.multiWindowModeChangedMethod, false),
        );
        // bool이 아닌 인자는 false로 읽는다
        await send(
          const MethodCall(FormFactor.multiWindowModeChangedMethod, 'yes'),
        );
        expect(received, [true, false, false]);
        // 모르는 호출은 notImplemented(빈 응답)
        expect(await send(const MethodCall('noSuchMethod')), isNull);
        expect(received, hasLength(3));

        // 듣지 않으면 아무것도 받지 않는다
        FormFactor.onMultiWindowModeChanged(null);
        await send(
          const MethodCall(FormFactor.multiWindowModeChangedMethod, true),
        );
        expect(received, hasLength(3));
      });

      test('iOS: 채널을 부르지 않고 false', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        var called = false;
        mockChannel((_) async {
          called = true;
          return true;
        });
        expect(await FormFactor.queryMultiWindowMode(), isFalse);
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

    test('여러 창 모드(분할 화면·자유 형식 창)는 기기와 상관없이 방향을 고정하지 않는다 (#137)', () {
      // 고정하면 창 모양이 요청 방향과 다를 때 Android가 레터박스로 줄인다(폰 1/3 분할 창 411×305 → 301.7×304.8dp)
      for (final (kind, display) in const [
        (DeviceKind.phone, phoneDisplay),
        (DeviceKind.foldable, coverDisplay),
        (DeviceKind.foldable, innerDisplay),
        (DeviceKind.tablet, tabletDisplay),
      ]) {
        expect(
          FormFactor.orientationPolicyOf(kind, display, multiWindow: true),
          OrientationPolicy.any,
          reason: '$kind $display',
        );
        expect(
          FormFactor.orientationPolicyOf(
            kind,
            display,
            multipleHinges: true,
            multiWindow: true,
          ),
          OrientationPolicy.any,
        );
      }
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

    test('창보다 긴 접힘 정보(회전 직후 이전 방향 값)는 접힘선이 아니다 (#25 R2)', () {
      // 841×673으로 돌았는데 접힘 정보는 아직 세로(673×841) 기준
      expect(
        FormFactor.hingeOf(const Size(841, 673), [
          feature(const Rect.fromLTWH(336.5, 0, 0, 841)),
        ]),
        isNull,
      );
      expect(
        FormFactor.arrangementOf(const Size(841, 673), [
          feature(const Rect.fromLTWH(336.5, 0, 0, 841)),
        ], foldableDevice: true),
        ScreenArrangement.stacked,
      );
      // 반대 방향도 같다
      expect(
        FormFactor.hingeOf(window, [
          feature(const Rect.fromLTWH(0, 336.5, 841, 0)),
        ]),
        isNull,
      );
    });

    test('여러 개여도 창을 가로지르는 접힘선이 하나뿐이면 그것을 쓴다', () {
      final hinge = FormFactor.hingeOf(window, [
        _cutout,
        feature(const Rect.fromLTWH(336, 100, 0, 600)),
        feature(const Rect.fromLTWH(336, 0, 0, 841)),
      ]);
      expect(hinge?.bounds, const Rect.fromLTWH(336, 0, 0, 841));
    });

    test('창을 가로지르는 접힘선이 둘 이상이면 배치에 쓰는 접힘선이 없다 (#144)', () {
      final left = feature(const Rect.fromLTWH(224, 0, 0, 841));
      final right = feature(const Rect.fromLTWH(448, 0, 0, 841));
      final across = feature(const Rect.fromLTWH(0, 420, 673, 0));
      for (final features in [
        [left, right],
        [_cutout, right, left],
        [left, across], // 세로·가로가 하나씩이어도 둘이다
      ]) {
        expect(
          FormFactor.crossingHingesOf(window, features),
          features.where((f) => f != _cutout).toList(),
        );
        expect(FormFactor.crossesMultipleHinges(window, features), isTrue);
        expect(FormFactor.hingeOf(window, features), isNull);
      }
      expect(FormFactor.crossesMultipleHinges(window, [left]), isFalse);
      expect(FormFactor.crossesMultipleHinges(window, const []), isFalse);
      // 가로지르지 않는 접힘 정보는 세지 않는다
      expect(
        FormFactor.crossesMultipleHinges(window, [
          left,
          feature(const Rect.fromLTWH(448, 100, 0, 600)),
        ]),
        isFalse,
      );
    });

    test('창 가장자리에 놓인 접힘선은 창을 나누지 않으므로 세지 않는다 (#144 — 트라이폴드 두 장에 걸친 분할 창)', () {
      // 펼친 트라이폴드(960×704, 접힘선 x=320·640)의 왼쪽 두 장을 차지한 창 640×704: 둘째 접힘선이 창 오른쪽 끝에 온다.
      const twoPanels = Size(640, 704);
      final middle = feature(const Rect.fromLTWH(320, 0, 0, 704));
      for (final x in [0.0, 0.5, 639.5, 640.0]) {
        final edge = feature(Rect.fromLTWH(x, 0, 0, 704));
        expect(FormFactor.crossingHingesOf(twoPanels, [middle, edge]), [
          middle,
        ], reason: 'x=$x');
        expect(
          FormFactor.hingeOf(twoPanels, [middle, edge]),
          same(middle),
          reason: 'x=$x',
        );
        // 접힘선 1개 규칙: 가운데 접힘선 기준 좌우 배치
        expect(
          FormFactor.arrangementOf(twoPanels, [
            middle,
            edge,
          ], foldableDevice: true),
          ScreenArrangement.hingeSplit,
          reason: 'x=$x',
        );
        // 가장자리 접힘선만 있으면 배치에 쓰는 접힘선이 없다(접힘 정보는 있으므로 위아래 배치)
        expect(FormFactor.hingeOf(twoPanels, [edge]), isNull, reason: 'x=$x');
      }
      // 가로 접힘선도 같다
      const tall = Size(704, 640);
      expect(
        FormFactor.crossingHingesOf(tall, [
          feature(const Rect.fromLTWH(0, 320, 704, 0)),
          feature(const Rect.fromLTWH(0, 640, 704, 0)),
        ]),
        hasLength(1),
      );
      // 공개 사양 근사 823×603의 두 장(약 548.5×603)도 장 폭(274.5)이 [hingeMinPanelExtent](128, #143) 이상이라 가운데
      // 접힘선 기준 좌우 배치(책 자세)다. #143 전(280)에는 나누지 않고 위아래 배치였다.
      const specTwoPanels = Size(548.5, 603);
      final specFolds = [
        feature(const Rect.fromLTWH(274.5, 0, 0, 603)),
        feature(const Rect.fromLTWH(548.5, 0, 0, 603)),
      ];
      expect(FormFactor.crossingHingesOf(specTwoPanels, specFolds), [
        specFolds.first,
      ]);
      expect(
        FormFactor.arrangementOf(
          specTwoPanels,
          specFolds,
          foldableDevice: true,
        ),
        ScreenArrangement.hingeSplit,
      );
    });

    test('같은 접힘선이 두 번 보고되면 하나로 센다 (접힘선 1개 기기가 접힘선을 잃지 않는다)', () {
      final fold = feature(const Rect.fromLTWH(336.5, 0, 0, 841));
      // 같은 상태의 중복: 앞의 것을 남긴다
      for (final again in [
        fold,
        feature(const Rect.fromLTWH(336.5, 0, 0, 841)),
        feature(const Rect.fromLTWH(337, 0, 0, 840.5)), // 허용 오차(1dp) 안
        feature(const Rect.fromLTWH(337.4, 0, 0, 841)), // 1dp 안에 붙음
      ]) {
        expect(FormFactor.crossingHingesOf(window, [fold, again]), [fold]);
        expect(FormFactor.hingeOf(window, [fold, again]), same(fold));
        expect(
          FormFactor.crossesMultipleHinges(window, [fold, again]),
          isFalse,
        );
      }
      // 화면을 나누는 쪽(반 접힘·물리 힌지)을 남긴다 — 순서와 상관없다. 평평한 쪽을 남기면 테이블톱을 놓친다.
      const across = Size(841, 673);
      final flat = feature(const Rect.fromLTWH(0, 336.5, 841, 0));
      final half = DisplayFeature(
        bounds: const Rect.fromLTWH(0, 336.5, 841, 0),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      );
      for (final features in [
        [flat, half],
        [half, flat],
      ]) {
        expect(FormFactor.crossingHingesOf(across, features), [half]);
        expect(
          FormFactor.arrangementOf(across, features, foldableDevice: true),
          ScreenArrangement.hingeStacked,
        );
      }
      // 폭 있는 힌지와 그 안의 폭 0 접힘선(겹침)도 하나 — 힌지를 남긴다
      final hinge = feature(
        const Rect.fromLTWH(326.5, 0, 20, 841),
        type: DisplayFeatureType.hinge,
      );
      for (final features in [
        [fold, hinge],
        [hinge, fold],
      ]) {
        expect(FormFactor.crossingHingesOf(window, features), [hinge]);
        expect(FormFactor.hingeOf(window, features), same(hinge));
      }
      // 1dp보다 떨어지거나 방향이 다르면 다른 접힘선이다
      expect(
        FormFactor.crossesMultipleHinges(window, [
          fold,
          feature(const Rect.fromLTWH(338, 0, 0, 841)),
        ]),
        isTrue,
      );
      expect(
        FormFactor.crossesMultipleHinges(window, [
          fold,
          feature(const Rect.fromLTWH(0, 420, 673, 0)),
        ]),
        isTrue,
      );
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
      // 물리 힌지 종류는 폭·상태와 무관하게 나눈다 (Android isSeparating)
      expect(
        FormFactor.separates(
          const DisplayFeature(
            bounds: Rect.fromLTWH(0, 336, 841, 0),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ),
        isTrue,
      );
    });
  });

  group('가로형 배치 판정 (창 모양 기준, #142)', () {
    test('접힘선 없는 가로 창은 크기와 무관하게 가로형이다 (화면이 본체 크기로 세로형과 다시 비교한다)', () {
      for (final size in const [
        Size(1280, 800),
        Size(1024, 768),
        Size(1194, 834),
        Size(1366, 1024),
        Size(960, 600),
        Size(844, 390), // 가로 폰 — 예전에는 짧은 변 600dp 미만이라 위아래 배치였다
        Size(1280, 599), // 낮고 넓은 팝업 창
        Size(769, 768),
      ]) {
        expect(_landscape(size, const []), isTrue, reason: '$size');
      }
    });

    test('세로 창·정사각형 창은 위아래 배치다', () {
      for (final size in const [
        Size(800, 1280), // 태블릿 세로 (방향 고정 무시)
        Size(768, 768), // 정사각형
        Size(678, 1024), // iPad Split View 절반
        Size(390, 844), // 폰
      ]) {
        expect(_landscape(size, const []), isFalse, reason: '$size');
      }
    });

    test('세로형과 가로형을 키 크기로 고르는 창은 접힘 정보가 없는 폴더블이 아닌 창이다', () {
      const window = Size(841, 701);
      expect(FormFactor.picksFormByKeySize(window, const []), isTrue);
      expect(FormFactor.picksFormByKeySize(window, const [_cutout]), isTrue);
      expect(FormFactor.picksFormByKeySize(window, const [_fold]), isFalse);
      expect(
        FormFactor.picksFormByKeySize(const Size(1114, 720), const [_hinge]),
        isFalse,
      );
      expect(
        FormFactor.picksFormByKeySize(window, const [], foldableDevice: true),
        isFalse,
      );
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
      expect(_landscape(const Size(1280, 800), [_fold]), isFalse);
      expect(_landscape(const Size(1280, 800), [_hinge]), isFalse);
      expect(_landscape(const Size(1280, 800), const [_cutout]), isTrue);
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

    test('가로 접힘선은 자세(펼침·반 접힘)와 무관하게 위아래로 나눈다 (#143)', () {
      for (final (window, y) in const [
        (Size(841, 673), 336.5), // Fold 내부를 가로로
        (Size(701, 841), 420.5), // Pixel Fold 내부를 세로로
        (Size(411, 1006), 503.0), // Flip 내부 (Flex 모드)
        (
          Size(673, 539),
          269.5,
        ), // "화면 크기"를 키운 Fold 가로 (#139 — 280dp 사전 판정에서 떨어졌다)
      ]) {
        for (final state in const [
          DisplayFeatureState.postureHalfOpened,
          DisplayFeatureState.postureFlat,
          DisplayFeatureState.unknown,
        ]) {
          // 살짝 꺾은 각도는 대개 펼침으로 들어온다 — 앱은 반 접힘과 구분할 수 없어 언제나 나눈다.
          expect(
            FormFactor.arrangementOf(window, [
              horizontal(window, y, state: state),
            ], foldableDevice: true),
            ScreenArrangement.hingeStacked,
            reason: '$window $state',
          );
        }
      }
      // 폭이 있는 물리 힌지도 나눈다.
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
        FormFactor.arrangementOf(tall, [horizontal(tall, min - 1)]),
        ScreenArrangement.stacked,
      );
      expect(
        FormFactor.arrangementOf(tall, [horizontal(tall, min)]),
        ScreenArrangement.hingeStacked,
      );
    });

    test('패널 최소 길이는 활성 LCD 최소 높이 + 화면 여백 + 접힘선 여백이다 (#143)', () {
      // 인셋이 없을 때 가로 접힘선 위 패널에 활성 LCD 최소 높이가 들어가는 길이 (form_factor는 테마를 읽지 않는다)
      expect(
        FormFactor.hingeMinPanelExtent,
        CalcTheme.screenLcdMinHeight +
            CalcTheme.screenPadding +
            CalcTheme.screenHingeMargin,
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

  group('트라이폴드 (접힘선 2개, #144)', () {
    // 이슈 #144의 가정: 펼친 화면 960×704dp, 세로 접힘선 x=320·640 (실기기 미확인)
    const landscape = Size(960, 704);
    const portrait = Size(704, 960);
    List<DisplayFeature> vertical(DisplayFeatureState state) => [
      for (final x in [320.0, 640.0])
        DisplayFeature(
          bounds: Rect.fromLTWH(x, 0, 0, 704),
          type: DisplayFeatureType.fold,
          state: state,
        ),
    ];
    List<DisplayFeature> horizontal(DisplayFeatureState state) => [
      for (final y in [640.0, 320.0])
        DisplayFeature(
          bounds: Rect.fromLTWH(0, y, 704, 0),
          type: DisplayFeatureType.fold,
          state: state,
        ),
    ];

    test('펼친 트라이폴드는 접힘선을 무시하고 태블릿처럼 가로면 가로형, 세로면 세로형이다 (자세·폴더블 여부 무관)', () {
      for (final state in DisplayFeatureState.values) {
        for (final foldable in [true, false]) {
          final reason = '$state foldable=$foldable';
          expect(
            FormFactor.arrangementOf(
              landscape,
              vertical(state),
              foldableDevice: foldable,
            ),
            ScreenArrangement.landscape,
            reason: reason,
          );
          expect(
            FormFactor.arrangementOf(
              portrait,
              horizontal(state),
              foldableDevice: foldable,
            ),
            ScreenArrangement.stacked,
            reason: reason,
          );
          // 화면이 본체 크기로 세로형·가로형 중 키가 큰 쪽을 고른다 — 접힘선 없는 창과 같다
          expect(
            FormFactor.picksFormByKeySize(
              landscape,
              vertical(state),
              foldableDevice: foldable,
            ),
            isTrue,
            reason: reason,
          );
          expect(
            FormFactor.picksFormByKeySize(
              portrait,
              horizontal(state),
              foldableDevice: foldable,
            ),
            isTrue,
            reason: reason,
          );
        }
      }
    });

    test('폭이 있는 물리 힌지 2개도 같다', () {
      final hinges = [
        for (final x in [310.0, 630.0])
          DisplayFeature(
            bounds: Rect.fromLTWH(x, 0, 20, 704),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
      ];
      expect(
        FormFactor.arrangementOf(landscape, hinges, foldableDevice: true),
        ScreenArrangement.landscape,
      );
    });

    test('접힘 정보가 오기 전(시작 직후)에는 폴더블 기기 규칙대로 위아래 배치이고, 오면 가로형이 된다', () {
      expect(
        FormFactor.arrangementOf(landscape, const [], foldableDevice: true),
        ScreenArrangement.stacked,
      );
      expect(
        FormFactor.picksFormByKeySize(
          landscape,
          const [],
          foldableDevice: true,
        ),
        isFalse,
      );
      expect(
        FormFactor.arrangementOf(
          landscape,
          vertical(DisplayFeatureState.postureFlat),
          foldableDevice: true,
        ),
        ScreenArrangement.landscape,
      );
    });

    test('회전 직후 이전 방향의 접힘 정보는 창을 가로지르지 않아 위아래 배치다 (폴더블 회전과 같음)', () {
      // 세로로 돌린 직후: 창은 704×960인데 접힘 정보는 가로 화면의 세로 접힘선(높이 704)
      expect(
        FormFactor.crossingHingesOf(
          portrait,
          vertical(DisplayFeatureState.postureFlat),
        ),
        isEmpty,
      );
      expect(
        FormFactor.arrangementOf(
          portrait,
          vertical(DisplayFeatureState.postureFlat),
          foldableDevice: true,
        ),
        ScreenArrangement.stacked,
      );
      // 가로로 돌린 직후: 창은 960×704인데 접힘 정보는 세로 화면의 가로 접힘선(폭 704)
      expect(
        FormFactor.crossingHingesOf(
          landscape,
          horizontal(DisplayFeatureState.postureFlat),
        ),
        isEmpty,
      );
      expect(
        FormFactor.arrangementOf(
          landscape,
          horizontal(DisplayFeatureState.postureFlat),
          foldableDevice: true,
        ),
        ScreenArrangement.stacked,
      );
    });

    test('기기 종류는 폴더블이고 방향 정책은 네 방향 모두다', () {
      final kind = FormFactor.deviceKindOf(
        landscape,
        vertical(DisplayFeatureState.postureFlat),
      );
      expect(kind, DeviceKind.foldable);
      for (final display in [landscape, portrait]) {
        expect(
          FormFactor.orientationPolicyOf(kind, display),
          OrientationPolicy.any,
          reason: '$display',
        );
      }
      // 시작 판정만으로 폴더블인 경우(접힘 정보 오기 전)도 같다
      expect(
        FormFactor.orientationPolicyOf(
          FormFactor.deviceKindOf(landscape, const [], foldableDevice: true),
          landscape,
        ),
        OrientationPolicy.any,
      );
    });

    test('짧은 변이 600dp 미만인 트라이폴드(공개 사양 근사 823×603을 확대)도 접힘선이 2개면 네 방향이다', () {
      // Galaxy Z TriFold 공개 해상도 2160×1584 px를 밀도 2.625로 바꾸면 약 823×603dp — 화면 크기 설정을 키우면
      // 짧은 변이 600 아래로 내려간다.
      for (final display in const [
        Size(823, 603),
        Size(768, 563),
        Size(563, 768),
      ]) {
        final folds = [
          for (final f in [1 / 3, 2 / 3])
            DisplayFeature(
              bounds: display.width > display.height
                  ? Rect.fromLTWH(display.width * f, 0, 0, display.height)
                  : Rect.fromLTWH(0, display.height * f, display.width, 0),
              type: DisplayFeatureType.fold,
              state: DisplayFeatureState.postureFlat,
            ),
        ];
        final multiple = FormFactor.crossesMultipleHinges(display, folds);
        expect(multiple, isTrue, reason: '$display');
        expect(
          FormFactor.orientationPolicyOf(
            DeviceKind.foldable,
            display,
            multipleHinges: multiple,
          ),
          OrientationPolicy.any,
          reason: '$display',
        );
        // 가로면 가로형, 세로면 위아래 배치
        expect(
          FormFactor.arrangementOf(display, folds, foldableDevice: true),
          display.width > display.height
              ? ScreenArrangement.landscape
              : ScreenArrangement.stacked,
          reason: '$display',
        );
      }
      // 접힘선이 2개가 아니면 예전처럼 크기로 정한다(접은 커버 화면·Flip 내부는 세로)
      expect(
        FormFactor.orientationPolicyOf(
          DeviceKind.foldable,
          const Size(768, 563),
        ),
        OrientationPolicy.portrait,
      );
      // 폰·태블릿은 접힘선 개수와 상관없다
      expect(
        FormFactor.orientationPolicyOf(
          DeviceKind.phone,
          const Size(390, 844),
          multipleHinges: true,
        ),
        OrientationPolicy.portrait,
      );
      expect(
        FormFactor.orientationPolicyOf(
          DeviceKind.tablet,
          const Size(1280, 800),
          multipleHinges: true,
        ),
        OrientationPolicy.landscape,
      );
    });
  });
}

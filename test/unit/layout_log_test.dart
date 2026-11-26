import 'dart:ui';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/layout/form_factor.dart';
import 'package:itechnika_altcalc_fx991/core/layout/layout_log.dart';

/// 시작·배치 진단 로그 (#158) — 실기기 logcat에서 읽을 줄의 모양과 "바뀔 때만" 규칙
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> lines;
  // 가짜 시계 (µs). enable 때 1,000,000에서 시작한다.
  late int now;

  void enable({bool frameTimings = false}) {
    now = 1000000;
    LayoutLog.enable(
      sink: lines.add,
      frameTimings: frameTimings,
      clock: () => now,
    );
  }

  setUp(() {
    lines = [];
    enable();
  });
  tearDown(LayoutLog.disable);

  const fold = DisplayFeature(
    bounds: Rect.fromLTRB(420, 0, 420, 701.5),
    type: DisplayFeatureType.fold,
    state: DisplayFeatureState.postureFlat,
  );

  void layout({
    ScreenArrangement chosen = ScreenArrangement.hingeSplit,
    ScreenArrangement drawn = ScreenArrangement.hingeSplit,
    bool tooSmall = false,
    Size window = const Size(841, 701.5),
    List<DisplayFeature> features = const [fold],
    bool foldableDevice = true,
  }) => LayoutLog.layout(
    chosen: chosen,
    drawn: drawn,
    tooSmall: tooSmall,
    window: window,
    features: features,
    foldableDevice: foldableDevice,
  );

  void insets({
    Size window = const Size(841.1, 701),
    EdgeInsets padding = const EdgeInsets.only(top: 28.2, bottom: 32),
    EdgeInsets viewPadding = const EdgeInsets.only(top: 28.2, bottom: 32),
    EdgeInsets gestures = const EdgeInsets.fromLTRB(29.7, 28.2, 29.7, 32),
  }) => LayoutLog.systemInsets(
    window: window,
    padding: padding,
    viewPadding: viewPadding,
    gestures: gestures,
  );

  /// [enable]부터 잰 ms로 빌드 시작·래스터 끝을 준 프레임
  FrameTiming frame(int number, double buildMs, double rasterEndMs) {
    int at(double ms) => 1000000 + (ms * 1000).round();
    return FrameTiming(
      vsyncStart: at(buildMs) - 100,
      buildStart: at(buildMs),
      buildFinish: at(buildMs) + 1000,
      rasterStart: at(buildMs) + 1500,
      rasterFinish: at(rasterEndMs),
      rasterFinishWallTime: at(rasterEndMs),
      frameNumber: number,
    );
  }

  group('enableForBuild — main()이 켜는 조건', () {
    setUp(LayoutLog.disable);

    test('일반 빌드(진단 빌드 플래그 없음)에서는 켜지 않는다', () {
      expect(LayoutLog.buildFlag, isFalse);
      LayoutLog.enableForBuild();
      expect(LayoutLog.enabled, isFalse);
    });

    test('진단 빌드의 Android 앱에서만 켠다 (웹·iOS 제외)', () {
      LayoutLog.enableForBuild(flag: true, platform: TargetPlatform.iOS);
      expect(LayoutLog.enabled, isFalse);
      LayoutLog.enableForBuild(
        flag: true,
        web: true,
        platform: TargetPlatform.android,
      );
      expect(LayoutLog.enabled, isFalse);
      LayoutLog.enableForBuild(flag: false, platform: TargetPlatform.android);
      expect(LayoutLog.enabled, isFalse);
      LayoutLog.enableForBuild(
        flag: true,
        web: false,
        platform: TargetPlatform.android,
      );
      expect(LayoutLog.enabled, isTrue);
    });
  });

  test('켜지 않으면 아무것도 남기지 않는다 (테스트·미리보기)', () {
    LayoutLog.disable();
    expect(LayoutLog.enabled, isFalse);
    LayoutLog.foldableQuery((foldable: true, fold: true));
    LayoutLog.foldFeatureWait(arrived: true, waited: Duration.zero);
    LayoutLog.firstFrame();
    LayoutLog.foldableRemembered('접힘 정보');
    LayoutLog.orientationRequest(
      OrientationPolicy.any,
      kind: DeviceKind.foldable,
      display: const Size(841, 701.5),
    );
    layout();
    LayoutLog.onFrameTimings([frame(1, 0, 10)]);
    insets();
    LayoutLog.keyInput(KeyInputEvent.pressed, key: 'ac');
    expect(lines, isEmpty);
  });

  group('시스템 영역·키 입력 줄 (#118)', () {
    test('시스템 영역 줄은 창·인셋·시스템 바·제스처 영역을 왼/위/오른/아래로 적고, 바뀔 때만 남긴다', () {
      insets();
      insets(); // 같은 값 — 남기지 않는다
      now += 5000;
      insets(
        padding: const EdgeInsets.only(top: 24, bottom: 56),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 56),
        gestures: const EdgeInsets.fromLTRB(30, 24, 30, 56),
      );
      expect(lines, [
        'AltCalc 시스템 영역: 창 841.1x701, 인셋 0/28.2/0/32, 시스템 바 0/28.2/0/32, '
            '제스처 영역 29.7/28.2/29.7/32 @0.0ms',
        'AltCalc 시스템 영역: 창 841.1x701, 인셋 0/24/0/56, 시스템 바 0/24/0/56, '
            '제스처 영역 30/24/30/56 @5.0ms',
      ]);
    });

    test('다시 켜면 같은 시스템 영역도 다시 남긴다', () {
      insets();
      enable();
      insets();
      expect(lines, hasLength(2));
    });

    test('키 입력 줄은 단계·키 이름·화면 좌표를 적고, 매번 남긴다', () {
      for (final event in KeyInputEvent.values) {
        LayoutLog.keyInput(event, key: 'ac', at: const Offset(1262, 517.25));
      }
      LayoutLog.keyInput(KeyInputEvent.pressed, key: 'num7');
      expect(lines, [
        'AltCalc 키 입력(누를 때): ac (1262,517.3) @0.0ms',
        'AltCalc 키 보류(제스처 영역): ac (1262,517.3) @0.0ms',
        'AltCalc 키 입력(뗄 때): ac (1262,517.3) @0.0ms',
        'AltCalc 키 버림(벗어남): ac (1262,517.3) @0.0ms',
        'AltCalc 키 취소: ac (1262,517.3) @0.0ms',
        'AltCalc 키 입력(누를 때): num7 @0.0ms',
      ]);
    });
  });

  test('모든 줄은 머리말로 시작한다 (logcat flutter 태그에서 골라 읽는다)', () {
    LayoutLog.foldableQuery((foldable: false, fold: null));
    LayoutLog.firstFrame();
    LayoutLog.foldableRemembered('접힘 정보');
    LayoutLog.orientationRequest(
      OrientationPolicy.any,
      kind: DeviceKind.foldable,
      display: const Size(841, 701.5),
    );
    layout();
    expect(lines, hasLength(5));
    for (final line in lines) {
      expect(line, startsWith('${LayoutLog.prefix} '));
    }
  });

  test('판정·첫 프레임·기억·방향 요청 줄의 내용', () {
    LayoutLog.foldableQuery((foldable: true, fold: true));
    LayoutLog.foldableQuery((foldable: true, fold: false));
    LayoutLog.foldableQuery((foldable: false, fold: null));
    LayoutLog.foldFeatureWait(
      arrived: true,
      waited: const Duration(microseconds: 1260),
    );
    LayoutLog.foldFeatureWait(
      arrived: false,
      waited: const Duration(milliseconds: 300),
    );
    now += 123456;
    LayoutLog.firstFrame();
    LayoutLog.foldableRemembered(
      '물리 화면 변경',
      from: const Size(360, 860),
      to: const Size(841.4, 701),
    );
    LayoutLog.orientationRequest(
      OrientationPolicy.portrait,
      kind: DeviceKind.phone,
      display: const Size(360, 860),
    );
    LayoutLog.orientationRequest(
      OrientationPolicy.landscape,
      kind: DeviceKind.tablet,
      display: const Size(800, 1280),
      error: 'boom',
    );
    expect(lines, [
      'AltCalc 시작 판정 받음: 폴더블=true, 접힘=있음',
      'AltCalc 시작 판정 받음: 폴더블=true, 접힘=없음',
      'AltCalc 시작 판정 받음: 폴더블=false, 접힘=모름',
      'AltCalc 접힘 정보 기다림: 도착 (1.3ms)',
      'AltCalc 접힘 정보 기다림: 제한 시간 초과 (300.0ms)',
      'AltCalc 첫 프레임 그림 @123.5ms',
      'AltCalc 폴더블 기억: 물리 화면 변경 (360x860 → 841.4x701)',
      'AltCalc 방향 요청: portrait (기기 phone, 화면 360x860)',
      'AltCalc 방향 요청: landscape (기기 tablet, 화면 800x1280) 실패: boom',
    ]);
  });

  test('배치 줄: 그린 배치·고른 배치·안내·창·화면 특징·폴더블·빌드 시각', () {
    layout();
    now += 60000;
    layout(
      chosen: ScreenArrangement.hingeSplit,
      drawn: ScreenArrangement.stacked,
      tooSmall: true,
      features: const [],
      foldableDevice: false,
    );
    expect(lines, [
      'AltCalc 배치: hingeSplit — 창 841x701.5, '
          '화면 특징 [fold postureFlat 420,0-420,701.5], 폴더블=true @0.0ms',
      'AltCalc 배치: stacked (고른 배치 hingeSplit) 안내 — 창 841x701.5, '
          '화면 특징 [], 폴더블=false @60.0ms',
    ]);
  });

  test('배치는 바뀔 때만 남긴다 (빌드마다 불러도 줄이 늘지 않는다)', () {
    layout();
    now += 1000;
    layout();
    expect(lines, hasLength(1));
    layout(window: const Size(701.5, 841));
    layout(window: const Size(701.5, 841));
    expect(lines, hasLength(2));
    // 다른 줄이 끼어도 배치가 같으면 다시 남기지 않는다
    LayoutLog.foldableQuery((foldable: true, fold: true));
    layout(window: const Size(701.5, 841));
    expect(lines, hasLength(3));
    // 다시 켜면 처음부터 — 첫 배치를 남긴다
    enable();
    layout(window: const Size(701.5, 841));
    expect(lines, hasLength(4));
  });

  group('프레임 시각', () {
    test('배치가 바뀌기 전에는 남기지 않는다', () {
      enable(frameTimings: true);
      LayoutLog.onFrameTimings([frame(1, 5, 20)]);
      expect(lines, isEmpty);
    });

    test('배치가 바뀌기 100ms 전 ~ 바뀐 뒤 2초 안에 빌드를 시작한 프레임만 남긴다', () {
      enable(frameTimings: true);
      now += 200000; // 200ms에 배치 빌드
      layout(drawn: ScreenArrangement.stacked);
      expect(LayoutLog.frameWatchMicros, 2000000);
      expect(LayoutLog.frameMarginMicros, 100000);
      LayoutLog.onFrameTimings([
        frame(1, 99.9, 120), // 구간 앞 — 바뀌기 전 프레임
        frame(2, 100, 120), // 구간 시작 — 남긴다
        frame(3, 199.5, 350.25), // 이 배치를 빌드한 프레임
        frame(4, 2200, 2216), // 감시 끝(200ms + 2초)에 시작 — 남긴다
      ]);
      expect(lines.skip(1), [
        'AltCalc 프레임 #2: 빌드 @100.0ms ~ 래스터 끝 @120.0ms',
        'AltCalc 프레임 #3: 빌드 @199.5ms ~ 래스터 끝 @350.3ms',
        'AltCalc 프레임 #4: 빌드 @2200.0ms ~ 래스터 끝 @2216.0ms',
      ]);
    });

    test('구간이 지나도 시각 보고는 떼지 않는다 — 릴리스에서 다음 변화 앞 프레임을 잃지 않게', () {
      enable(frameTimings: true);
      expect(LayoutLog.watchingFrames, isFalse);
      layout(drawn: ScreenArrangement.stacked);
      expect(LayoutLog.watchingFrames, isTrue);
      LayoutLog.onFrameTimings([frame(1, 10, 20), frame(2, 3000, 3010)]);
      expect(LayoutLog.watchingFrames, isTrue);
      expect(lines.last, startsWith('AltCalc 프레임 #1: '));
      // 끄면 뗀다
      LayoutLog.disable();
      expect(LayoutLog.watchingFrames, isFalse);
    });

    test('배치가 바뀔 때마다 따로 구간을 둔다 — 구간 사이의 프레임은 남기지 않는다', () {
      enable(frameTimings: true);
      layout(drawn: ScreenArrangement.stacked); // 0ms → 구간 -100 ~ 2000
      now += 3000000;
      layout(); // 3000ms → 구간 2900 ~ 5000
      LayoutLog.onFrameTimings([
        frame(1, 1999, 2010),
        frame(2, 2500, 2510), // 두 구간 사이
        frame(3, 2950, 2960),
        frame(4, 5001, 5010),
      ]);
      expect(
        lines
            .where((l) => l.startsWith('AltCalc 프레임 '))
            .map((l) => l.split(':').first),
        ['AltCalc 프레임 #1', 'AltCalc 프레임 #3'],
      );
    });

    test('구간은 최근 ${LayoutLog.maxFrameWindows}개만 둔다', () {
      enable(frameTimings: true);
      for (var i = 0; i <= LayoutLog.maxFrameWindows; i++) {
        layout(window: Size(800 + i.toDouble(), 700));
        now += 10000000; // 10초씩 — 구간이 겹치지 않는다
      }
      LayoutLog.onFrameTimings([frame(1, 0, 10), frame(2, 10000, 10010)]);
      expect(lines.last, startsWith('AltCalc 프레임 #2: '));
      expect(lines.where((l) => l.startsWith('AltCalc 프레임 #1')), isEmpty);
    });

    test('frameTimings: false면 프레임 시각을 남기지 않는다', () {
      layout();
      LayoutLog.onFrameTimings([frame(1, 0, 10)]);
      expect(lines, hasLength(1));
    });
  });
}

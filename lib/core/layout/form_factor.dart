import 'dart:math' as math;
import 'dart:ui'
    show
        DisplayFeature,
        DisplayFeatureState,
        DisplayFeatureType,
        FlutterView,
        Rect,
        Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 기기 종류 — 화면 방향 고정을 고를 때 쓴다 (#24).
enum DeviceKind {
  /// 일반 폰
  phone,

  /// 폴더블 — 시작 시 폴더블로 판정했거나([FormFactor.queryFoldableDevice]) 그 뒤 화면 정보로 알아본
  /// (`DeviceOrientationLock.foldableDevice` — 접히는 부분 보고, [FormFactor.isOtherScreen]) 기기 (커버 화면 포함)
  foldable,

  /// 태블릿 — 짧은 변 [FormFactor.largeScreenMinShortestSide] 이상인 폴더블이 아닌 기기
  tablet,
}

/// 계산기 화면 배치 종류 (#24, 접힘선 기준 배치는 #25, 가로형은 #142).
enum ScreenArrangement {
  /// 위아래 배치("세로형", #141): 위 LCD, 아래 실물 배열 키패드 (폰 세로 화면, 세로·좁은 창, 폴더블 커버 화면)
  stacked,

  /// 가로형 배치 (#142): 아래에 넓은 키패드 배열(함수부 옆에 숫자부), 위 띠에 활성 LCD(숫자부 위)와 계산 기록(함수부 위).
  /// 숫자부와 활성 LCD는 주로 쓰는 손 쪽이다 (태블릿 가로, 가로로 돌린 폰, 분할 화면·데스크톱의 가로 창).
  landscape,

  /// 세로 접힘선 기준 좌우 배치 (폴더블 내부 화면, 책 자세): 접힘선 한쪽 절반에 키패드(주로 쓰는 손 쪽),
  /// 다른 절반에 LCD. 어느 것도 접힘선을 가로지르지 않는다.
  hingeSplit,

  /// 가로 접힘선 기준 위아래 배치 (반 접어 세운 테이블톱 자세, 물리 힌지 — 펼친 폭 0 가로 접힘선은 제외):
  /// 접힘선 위 절반에 LCD, 아래 절반에 키패드. 어느 것도 접힘선을 가로지르지 않는다.
  hingeStacked,
}

/// 앱 시작 시 폴더블 판정 결과 ([FormFactor.queryFoldableDevice], #158).
/// - `foldable`: 폴더블 기기인지
/// - `fold`: Android 창 배치 정보 첫 값에 접히는 부분이 있었는지 — 참이면 접힘 정보가 곧 화면 정보로 온다.
///   `null`은 모름(첫 값을 받지 못함·조회 실패·Android 아님) — 진단 로그가 "없음"과 구분해 적는다.
typedef FoldableStartup = ({bool foldable, bool? fold});

/// 기기 종류·화면 크기별로 요청할 화면 방향 정책 (#24, 폴더블은 #25)
enum OrientationPolicy {
  /// 세로만 (폰, 폴더블 커버 화면)
  portrait,

  /// 가로 두 방향 (태블릿)
  landscape,

  /// 네 방향 모두 (폴더블 내부 화면 — 배치가 접힘선 방향을 따른다)
  any,
}

/// 기기·창 크기에 따른 화면 구분 규칙 (#24).
///
/// 두 가지를 따로 판정한다.
/// - **기기 종류**([deviceKindOf]): 물리 화면(디스플레이) 크기와 힌지 유무로 정한다. 앱 시작 시 방향 고정에 쓴다.
/// - **배치**([arrangementOf]): 앱 **창** 크기로 정한다. 방향 고정은 대부분의 대화면에서 지켜지지 않으므로(아래)
///   화면 배치는 항상 실제 창 크기를 따른다.
///
/// ## 태블릿 가로 고정이 실제로 동작하는 범위
/// 태블릿에는 가로를 요청하지만, **Android 15 이하 태블릿에서만** 지켜진다.
/// - Android 16 이상: targetSdk 36(Flutter 기본값)이면 짧은 변 600dp 이상 화면은 앱의 방향 고정을 **항상** 무시한다.
///   이를 끄는 `android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY`는 targetSdk 37에서 없어지는
///   임시 장치라 쓰지 않는다.
/// - iPad: 멀티태스킹(Split View·Slide Over·Stage Manager)을 지원하는 앱은 전체 화면에서도 방향 고정이
///   반영되지 않는다(전체 화면 강제 `UIRequiresFullScreen`을 켜야 반영되는데, iPadOS 26부터 폐기 예정이다).
///   계산기는 다른 앱과 나란히 쓰는 경우가 많아 멀티태스킹을 끄지 않는다 — `Info.plist`의 iPad 방향은
///   네 방향 모두 허용한 채로 둔다(멀티태스킹 요건).
/// - 분할 화면·팝업 창처럼 창 자체가 화면보다 작은 경우. 폰도 마찬가지라, 세로 고정과 무관하게 낮은 창이 생긴다.
///   그런 창은 화면이 본체 크기로 다시 판정해 키가 큰 배치로 그리거나 창을 키워 달라는 안내를 띄운다
///   (`CalculatorScreen`, `CalcTheme` "짧은 창" 절, #38). 분할 화면·팝업 창 자체는 막지 않는다
///   (`resizeableActivity`·최소 창 크기를 선언하지 않는 이유도 그 절).
/// 그래서 태블릿을 세로로 들면 대개 세로 창이 되고, 그때는 위아래 배치로 보여 준다.
abstract final class FormFactor {
  /// 대화면 기준 짧은 변 (dp). Material 창 크기 등급 medium(폭 600dp) 이상과 같고, Android가 방향
  /// 고정을 무시하는 대화면 기준과도 같다.
  static const double largeScreenMinShortestSide = 600.0;

  /// 기기 특성 조회 채널 (Android `MainActivity`)
  @visibleForTesting
  static const MethodChannel deviceChannel = MethodChannel('altcalc/device');

  /// [deviceChannel]의 폴더블 판정 메서드 이름 ([queryFoldableDevice])
  @visibleForTesting
  static const String foldableDeviceMethod = 'isFoldableDevice';

  /// [features]에 접히는 부분(fold·hinge)이 있는지. 화면 구멍(cutout)은 세지 않는다.
  static bool hasFoldOrHinge(Iterable<DisplayFeature> features) => features.any(
    (f) =>
        f.type == DisplayFeatureType.fold || f.type == DisplayFeatureType.hinge,
  );

  /// 폴더블 기기인지 (#24, 보강 #70). 폴더블 기기를 앱 시작 시점에 구분하는 데 쓴다 — 접히는 부분 정보
  /// ([FlutterView.displayFeatures])는 화면이 붙은 뒤 비동기로 와서 시작 시점에는 비어 있고, 비어 있어도
  /// "아직 안 옴"인지 "없음"인지 구분할 수 없다.
  ///
  /// Android `MainActivity`(`FoldableDeviceProbe`)가 다음 중 하나라도 있으면 폴더블로 답한다.
  /// 1. 힌지 각도 센서 기능 선언 (`FEATURE_SENSOR_HINGE_ANGLE`, API 30+) — 제조사가 선언해야만 보고된다.
  /// 2. 힌지 각도 센서 자체 (`Sensor.TYPE_HINGE_ANGLE`, API 30+)
  /// 3. Jetpack WindowManager 창 배치 정보 첫 값의 접히는 부분 — Samsung처럼 OEM 확장으로 접힘 정보만 주는 기기 대비.
  ///    창이 붙은 뒤 오므로 Android 쪽이 최대 500ms 기다린다(그동안 시작 화면이 남는다). 1·2가 있어도 기다린다(#158).
  ///
  /// 답의 `fold`는 3의 첫 값에 접히는 부분이 있었는지다 — 참이면 [FlutterView.displayFeatures]에도 곧 오므로,
  /// `main()`이 그것이 올 때까지 첫 화면을 미룬다(`DeviceOrientationLock.waitForFoldFeature`). 미루지 않으면 펼친
  /// 내부 화면에서 시작할 때 첫 프레임이 위아래 배치였다가 접힘선 기준 배치로 바뀐다(#158, Pixel Fold 에뮬레이터).
  ///
  /// Android가 아니거나, 조회에 실패하거나, [foldableQueryTimeout] 안에 응답이 없으면 폴더블 아님·접힘 모름(`null`) —
  /// 앱 시작(`main()`)이 이 조회를 기다리므로 어떤 경우에도 오류를 내거나 멈추지 않는다.
  ///
  /// 한계: 1·2가 없는 폴더블을 접은 커버 화면에서 시작하면 3도 없어(창이 접힘선에 걸치지 않는다) 폰으로 판정된다.
  /// 펼치면 `DeviceOrientationLock`이 물리 화면이 바뀐 것([isOtherScreen])을 보고 폴더블로 기억한다.
  /// 에뮬레이터 기록은 Android `FoldableDeviceProbe` 주석에 있다. Samsung 실기기 기록은 #175에서 이어 한다.
  static Future<FoldableStartup> queryFoldableDevice() async {
    const none = (foldable: false, fold: null);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return none;
    }
    try {
      final result = await deviceChannel
          .invokeMapMethod<String, Object?>(foldableDeviceMethod)
          .timeout(foldableQueryTimeout);
      if (result == null) return none;
      final fold = result[foldKey];
      return (
        foldable: result[foldableKey] == true,
        fold: fold is bool ? fold : null,
      );
    } on MissingPluginException {
      return none;
    } catch (error) {
      debugPrint('폴더블 판정 조회 실패: $error');
      return none;
    }
  }

  /// [queryFoldableDevice] 응답(map)의 폴더블 여부 키 — Android `FoldableDeviceProbe.KEY_FOLDABLE`과 같아야 한다
  @visibleForTesting
  static const String foldableKey = 'foldable';

  /// [queryFoldableDevice] 응답의 "창 배치 첫 값에 접히는 부분 있음" 키 — Android `FoldableDeviceProbe.KEY_FOLD`와 같아야 한다.
  /// 값이 `null`이면 첫 값을 받지 못한 것이다(제한 시간 초과·구독 실패·취소).
  @visibleForTesting
  static const String foldKey = 'fold';

  /// 폴더블 판정 조회 응답 제한 시간. Android 쪽이 창 배치 정보를 기다리는 최대 시간(`FoldableDeviceProbe`
  /// `LAYOUT_TIMEOUT_MILLIS`)보다 넉넉히 길어야 한다 — `test/unit/main_activity_source_test.dart`가 대조한다.
  /// #158부터 힌지 신호가 있는 폴더블도 Android가 첫 값을 기다리므로, 메인 스레드 지연 여유는 이 시간 − 500ms다. 이 시간을
  /// 넘기면 힌지 신호까지 잃고 폴더블 아님으로 시작한다(화면 정보가 오면 `DeviceOrientationLock`이 바로잡는다).
  static const Duration foldableQueryTimeout = Duration(seconds: 1);

  /// 기기 종류를 정한다.
  /// - [displaySize]: 물리 화면 크기 (dp)
  /// - [features]: 화면 특징 (접히는 부분 등)
  /// - [foldableDevice]: 앱 시작 시 판정한 폴더블 기기 여부 ([queryFoldableDevice])
  ///
  /// 폴더블 내부 화면은 짧은 변이 600dp를 넘어 크기로는 태블릿과 구분되지 않으므로, 시작 시 판정이나 접히는
  /// 부분 정보로 구분한다. 폴더블은 접은 커버 화면에서도 [DeviceKind.foldable]이다.
  static DeviceKind deviceKindOf(
    Size displaySize,
    Iterable<DisplayFeature> features, {
    bool foldableDevice = false,
  }) {
    if (foldableDevice || hasFoldOrHinge(features)) return DeviceKind.foldable;
    if (displaySize.shortestSide >= largeScreenMinShortestSide) {
      return DeviceKind.tablet;
    }
    return DeviceKind.phone;
  }

  /// [view]가 놓인 물리 화면 크기 (dp). 플랫폼이 화면 크기를 알려주지 않으면(크기 0) 창 크기를 쓴다.
  static Size displaySizeOf(FlutterView view) =>
      reportedDisplaySizeOf(view) ?? view.physicalSize / view.devicePixelRatio;

  /// 플랫폼이 알려 준 [view]의 물리 화면 크기 (dp). 알려 주지 않으면(크기 0) `null` — 창 크기로 대신하지 않는다.
  static Size? reportedDisplaySizeOf(FlutterView view) {
    final display = view.display;
    if (display.size.isEmpty || !(display.devicePixelRatio > 0)) return null;
    return display.size / display.devicePixelRatio;
  }

  /// 물리 화면이 바뀌었다고 볼 화면 비율(긴 변 ÷ 짧은 변) 차이 (작은 쪽 비율에 대한 상대값). 폴더블의 커버 ↔ 내부
  /// 화면은 비율이 크게 다르다(Galaxy Z Fold 커버 약 2.6 ↔ 내부 약 1.2, Z Flip 내부 약 2.4 ↔ 커버 약 1.0).
  static const double otherScreenAspectTolerance = 0.15;

  /// 물리 화면 크기 [before]에서 [after]로 바뀐 것이 **폴더블의 다른 화면**으로 바뀐 것인지 (#70) — 커버 ↔ 내부 화면
  /// 전환이다. 다음 두 조건을 모두 만족할 때만 참이다.
  /// - 비율(긴 변 ÷ 짧은 변)이 [otherScreenAspectTolerance]보다 많이 다르다. 회전(가로·세로가 맞바뀜)과 화면 크기·글자
  ///   확대 설정(dp 크기만 바뀐다)은 비율이 그대로라 세지 않는다.
  /// - 적어도 한쪽이 폰 크기(짧은 변 [largeScreenMinShortestSide] 미만)다. 폴더블은 한쪽이 늘 폰 크기다(Fold·Flip의 커버,
  ///   Flip의 내부). 양쪽이 모두 대화면인 전환 — 노트북 화면 ↔ 모니터(ChromeOS·Mac), iPad ↔ 외부 모니터, 태블릿 ↔
  ///   모니터 — 은 다른 디스플레이로 옮긴 것이라 세지 않는다. 플랫폼은 창이 놓인 디스플레이의 크기를 알려 주는데,
  ///   어느 디스플레이인지는 알 수 없다(Android는 늘 같은 디스플레이 번호를 준다).
  ///
  /// 한계: 폰을 외부 디스플레이(DeX 등)로 옮기면 참이 된다 — 그러면 폴더블로 기억해 접힘선 없는 넓은 창도 위아래 배치가
  /// 된다([arrangementOf]의 폴더블 외부 디스플레이 제약과 같다). 폰 화면 자체의 정책은 폴더블이어도 같다(세로).
  static bool isOtherScreen(Size before, Size after) {
    if (before.isEmpty || after.isEmpty) return false;
    if (before.shortestSide >= largeScreenMinShortestSide &&
        after.shortestSide >= largeScreenMinShortestSide) {
      return false;
    }
    double aspect(Size s) => s.longestSide / s.shortestSide;
    final a = aspect(before);
    final b = aspect(after);
    return (a - b).abs() / math.min(a, b) > otherScreenAspectTolerance;
  }

  /// 기기 종류([kind])와 물리 화면 크기([displaySize], dp)별 방향 정책.
  /// - 폰: 세로 — 가로 화면에서는 키패드가 쓸 수 없을 만큼 작아진다.
  /// - 태블릿: 가로 — 가로형 배치(위 띠에 기록·활성 LCD, 아래에 넓은 키패드 배열, #142)로 보여 준다 (지켜지는 범위는
  ///   클래스 설명 참조).
  /// - 폴더블의 짧은 변 [largeScreenMinShortestSide] 미만 화면: 폰과 같이 세로. Fold 계열의 접은 커버 화면과
  ///   Galaxy Z Flip 계열의 내부 화면(세로로 긴 폰 크기, 가로 접힘선)이 여기에 든다.
  /// - 폴더블 대화면(Fold 계열 내부 화면): 네 방향 모두 허용한다 (#25). 내부 화면의 기본 방향이 기기마다
  ///   달라(Galaxy Z Fold는 세로, Pixel Fold는 가로) 세로로 고정하면 Pixel Fold에서는 오히려 접힘선이 가로로
  ///   눕는다. 배치는 고정 대신 접힘선 방향을 따른다([arrangementOf]). Android 16 이상은 대화면에서 어차피
  ///   방향 고정을 무시하므로, 어떤 버전에서도 같은 동작이 된다.
  /// - 펼친 트라이폴드(창을 가로지르는 접힘선이 둘 이상 — [multipleHinges], [crossesMultipleHinges], #144): 화면 크기와
  ///   상관없이 네 방향 모두. 배치는 태블릿과 같지만(가로형·세로형) 세로로 돌려도 세로형으로 쓸 수 있게 가로로 고정하지
  ///   않는다. 크기로만 정하지 않는 것은 짧은 변이 600dp 경계에 가깝기 때문이다 — Galaxy Z TriFold 공개 해상도는 밀도
  ///   2.625 가정으로 약 823×603dp라, 화면 크기 설정을 키우면 600 아래로 내려가 세로로 고정될 수 있다. [multipleHinges]는
  ///   접힘 정보가 온 뒤에만 참이다 — 그 전(시작 직후)에는 크기 규칙을 따르지만, 앱 시작은 접힘 정보가 올 때까지 첫 방향
  ///   요청을 미룬다(#158, `main()`).
  static OrientationPolicy orientationPolicyOf(
    DeviceKind kind,
    Size displaySize, {
    bool multipleHinges = false,
  }) => switch (kind) {
    DeviceKind.phone => OrientationPolicy.portrait,
    DeviceKind.tablet => OrientationPolicy.landscape,
    DeviceKind.foldable =>
      multipleHinges || displaySize.shortestSide >= largeScreenMinShortestSide
          ? OrientationPolicy.any
          : OrientationPolicy.portrait,
  };

  /// [policy]로 요청할 방향 목록. 빈 목록은 플랫폼에서 "제한 없음"이 되므로 [OrientationPolicy.any]도
  /// 네 방향을 명시한다.
  static List<DeviceOrientation> preferredOrientationsOf(
    OrientationPolicy policy,
  ) => switch (policy) {
    OrientationPolicy.portrait => const [DeviceOrientation.portraitUp],
    OrientationPolicy.landscape => const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    OrientationPolicy.any => const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
    ],
  };

  /// 접힘선이 창을 다 가로지르는지 볼 때의 허용 오차 (dp)
  static const double _hingeSpanTolerance = 1.0;

  /// 접힘선 기준으로 나눌 때 접힘선 양쪽 각각이 가져야 하는 최소 길이 (dp, 창 좌표·접힘선에 수직인 방향).
  /// 접힘선이 창 가장자리에 치우친 창이나 인셋 안의 접힘선처럼 한쪽 패널(LCD 쪽 포함)이 쓸 수 없게 좁아지는
  /// 경우를 걸러 내는 거친 사전 판정이다. 인셋·화면 여백을 뺀 실제 키패드가 터치 하한을 지키는지는 화면이
  /// 본체 크기로 다시 판정한다(`CalculatorScreen`, `KeypadMetrics.minKeyTouchHeightOf`).
  static const double hingeMinPanelExtent = 280.0;

  /// 창([windowSize], dp)을 한 축으로 끝까지 가로지르는 접히는 부분(fold·hinge) 모두 (#144). 영역은 창 좌표이고,
  /// 순서는 [features] 그대로이고, 같은 자리(허용 오차 안)에 두 번 온 접힘선은 앞의 것 하나만 남긴다. 화면 구멍(cutout)과, 창 밖·창 가장자리에 있거나 창을 끝까지 가로지르지 않는 접힘 정보는
  /// 세지 않는다.
  ///
  /// 접힘 정보의 좌표는 그 정보를 담은 `MediaQuery`가 가리키는 화면(창)의 좌표다. 실제 앱에서는 창 = 화면이다.
  static List<DisplayFeature> crossingHingesOf(
    Size windowSize,
    Iterable<DisplayFeature> features,
  ) {
    final crossing = <DisplayFeature>[];
    for (final f in features) {
      if (!_crossesWindow(windowSize, f)) continue;
      // 같은 자리의 접힘선이 두 번 보고되어도 하나로 센다 — 개수가 2가 되면 접힘선 1개 기기가 접힘선을 잃는다(#144 R1)
      final duplicate = crossing.any(
        (c) => _sameRect(c.bounds, f.bounds, _hingeSpanTolerance),
      );
      if (!duplicate) crossing.add(f);
    }
    return crossing;
  }

  /// 두 영역의 네 변이 [tolerance] 안에서 같은지
  static bool _sameRect(Rect a, Rect b, double tolerance) =>
      (a.left - b.left).abs() <= tolerance &&
      (a.top - b.top).abs() <= tolerance &&
      (a.right - b.right).abs() <= tolerance &&
      (a.bottom - b.bottom).abs() <= tolerance;

  /// [f]가 창([windowSize])을 한 축으로 끝까지 가로지르는 접히는 부분인지 ([crossingHingesOf])
  static bool _crossesWindow(Size windowSize, DisplayFeature f) {
    const t = _hingeSpanTolerance;
    if (f.type != DisplayFeatureType.fold &&
        f.type != DisplayFeatureType.hinge) {
      return false;
    }
    final b = f.bounds;
    if (!(b.left.isFinite &&
        b.top.isFinite &&
        b.right.isFinite &&
        b.bottom.isFinite)) {
      return false;
    }
    final spansHeight = b.top <= t && b.bottom >= windowSize.height - t;
    final spansWidth = b.left <= t && b.right >= windowSize.width - t;
    final insideX = b.left >= -t && b.right <= windowSize.width + t;
    final insideY = b.top >= -t && b.bottom <= windowSize.height + t;
    // 접힘선 양쪽에 창이 남는지 (창 가장자리에 놓인 접힘선은 창을 나누지 않는다)
    final splitsX = b.left > t && b.right < windowSize.width - t;
    final splitsY = b.top > t && b.bottom < windowSize.height - t;
    // 세로 접힘선: 위에서 아래까지 정확히 창 높이만큼, 좌우로는 창 안쪽 (가로 접힘선은 반대).
    // 창보다 긴 접힘 정보는 받지 않는다 — 회전 직후 창 크기는 새 값인데 접힘 정보는 이전 방향 값으로
    // 몇 프레임 늦게 올 수 있다(#25 R2). 그동안은 접힘선이 없는 것으로 본다(폴더블이면 위아래 배치).
    // 창 가장자리의 접힘선은 세지 않는다 — 트라이폴드에서 두 장에 걸친 분할 화면 창은 둘째 접힘선이 창 경계에 오는데,
    // 이것을 세면 접힘선 2개로 판정되어 창 가운데의 접힘선까지 무시하게 된다(#144). 그 창은 접힘선 1개 규칙을 탄다 —
    // 장 폭이 [hingeMinPanelExtent] 이상이면 가운데 접힘선 기준 배치, 아니면(공개 사양 근사 약 274dp) 위아래 배치다.
    // 가장자리 접힘선은 어차피 배치를 나누지 않는다(한쪽 패널 길이 0 < [hingeMinPanelExtent]).
    if (spansHeight && splitsX && insideY) return true;
    return spansWidth && splitsY && insideX;
  }

  /// 창을 가로지르는 접힘선이 [multiHingeMinCount]개 이상인지 (#144) — 펼친 트라이폴드(세 장, 접힘선 2개)다.
  /// 이런 창은 접힘선을 무시하고 접힘선 없는 창과 같은 배치로 그린다([arrangementOf] 1번, [picksFormByKeySize]).
  static bool crossesMultipleHinges(
    Size windowSize,
    Iterable<DisplayFeature> features,
  ) => crossingHingesOf(windowSize, features).length >= multiHingeMinCount;

  /// 접힘선을 무시하는 창의 가로지르는 접힘선 개수 하한 ([crossesMultipleHinges], #144)
  static const int multiHingeMinCount = 2;

  /// 배치에 쓰는 접힘선 — 창([windowSize], dp)을 끝까지 가로지르는 접히는 부분([crossingHingesOf])이 **하나뿐일 때** 그것.
  /// 없거나 둘 이상(펼친 트라이폴드, [crossesMultipleHinges])이면 `null`이다. 영역은 창 좌표다.
  static DisplayFeature? hingeOf(
    Size windowSize,
    Iterable<DisplayFeature> features,
  ) {
    final crossing = crossingHingesOf(windowSize, features);
    return crossing.length == 1 ? crossing.single : null;
  }

  /// [hinge]가 세로 접힘선(위에서 아래로 가로지름)인지. 폭이 0인 접힘선도 판정된다.
  static bool isVerticalHinge(Rect hinge) => hinge.height >= hinge.width;

  /// [hinge]가 화면을 실제로 두 부분으로 나누는지 — 물리 힌지(종류가 hinge이거나 폭이 있음)이거나 반 접힌 상태.
  /// Android `FoldingFeature.isSeparating`(HINGE 종류는 항상 나눔)에 맞추고, Flutter `DisplayFeatureSubScreen`의
  /// 기준(폭이 있거나 반 접힘)을 포함한다.
  static bool separates(DisplayFeature hinge) =>
      hinge.type == DisplayFeatureType.hinge ||
      hinge.bounds.shortestSide > 0 ||
      hinge.state == DisplayFeatureState.postureHalfOpened;

  /// 화면이 본체 크기로 세로형과 가로형 중 키가 큰 쪽을 고르는 창인지 (#142) — [arrangementOf] 3번의 창이다.
  /// - 접힘 정보([features])가 없고 폴더블 기기([foldableDevice])도 아닌 창
  /// - 창([windowSize])을 가로지르는 접힘선이 둘 이상인 창([crossesMultipleHinges] — 펼친 트라이폴드, #144).
  ///   폴더블 기기여도 그렇다 — 접힘 정보가 이미 왔으므로 아래 깜빡임 방지 규칙의 대상이 아니다.
  static bool picksFormByKeySize(
    Size windowSize,
    Iterable<DisplayFeature> features, {
    bool foldableDevice = false,
  }) =>
      (!foldableDevice && !hasFoldOrHinge(features)) ||
      crossesMultipleHinges(windowSize, features);

  /// 앱 창([windowSize], dp)의 배치.
  ///
  /// 1. 창을 가로지르는 접힘선이 하나뿐이고([hingeOf]) 그 양쪽이 모두 [hingeMinPanelExtent] 이상이면 접힘선을 경계로
  ///    나눈다 (#25). 가로지르는 접힘선이 둘 이상이면([crossesMultipleHinges] — 펼친 트라이폴드) 접힘선을 모두 무시하고
  ///    3번 창으로 다룬다(#144, 아래 "트라이폴드").
  ///    - 세로 접힘선: 항상 [ScreenArrangement.hingeSplit]. 펼친 상태(flat)여도 나눈다 — 주름이 키·글자 한가운데를
  ///      지나지 않게 하는 것이 이슈 요구이고, 좌우로 나눠도 각 절반이 폰 폭이라 키 크기 손해가 작다.
  ///    - 가로 접힘선: 화면을 실제로 나눌 때([separates] — 반 접은 테이블톱 자세, 물리 힌지)만
  ///      [ScreenArrangement.hingeStacked]. 펼친 폭 0 가로 접힘선(Fold 내부 화면을 가로로 돌림, Flip을 펼침)은
  ///      나누지 않는다(아래 2번). #25에서는 나누면 키패드가 아래 절반에 갇혀 터치 하한(28dp) 아래로 작아진다는 것이
  ///      근거였으나, 넓은 키패드 배열(#80)이 생긴 뒤로는 Fold 가로도 나누는 쪽 키가 더 크다(위아래 32.1dp, 나누면
  ///      39.9dp) — 펼친 가로 접힘선을 나눌지는 후속 이슈에서 다시 정한다.
  /// 2. 접힘 정보는 있는데 위 조건에 맞지 않거나, 폴더블 기기([foldableDevice])인데 접힘선이 없으면
  ///    위아래 배치다. 폴더블 내부 화면은 접힘 정보가 창이 붙은 뒤 늦게 오므로, 그 전 몇 프레임 동안
  ///    접힘선을 무시한 가로형으로 그렸다가 바뀌는 깜빡임을 막는다. 접은 커버 화면은 어차피 위아래 배치다.
  ///    제약: 폴더블 여부는 기기 단위라, 폴더블을 외부 디스플레이(DeX 등)에 띄운 넓은 창도 위아래 배치다.
  ///    시작 구간에만 기기 단위로 보려면 "접힘 정보가 아직 안 옴"과 "접힘선 없음"을 구분해야 하는데 그런
  ///    신호가 없고, 시간 제한을 두면 펼칠 때마다 배치가 한 번씩 튄다. 드문 경우라 위아래 배치로 둔다 (#25 검토).
  /// 3. 그 밖의 창([picksFormByKeySize] — 접힘 정보가 없는 폴더블이 아닌 창, 접힘선이 둘 이상 가로지르는 창)은 창 모양으로
  ///    답한다: 가로(폭 > 높이) 창이면
  ///    [ScreenArrangement.landscape], 아니면 위아래 배치다. 화면은 이 창들을 모두 인셋·화면 여백을 뺀 본체 크기로
  ///    세로형과 가로형 중 키가 큰 쪽으로 다시 고른다 (`CalculatorScreen`, #142) — 그래서 이 답은 창 모양에서 기대하는
  ///    배치일 뿐이고, 정사각형에 가까운 가로 창(768×768 전후)이나 아주 작은 세로 창은 다른 쪽으로 그려질 수 있다.
  ///
  /// ## 트라이폴드 (#144, 2026-11-26 사용자 결정)
  /// 세 장을 모두 펼친 트라이폴드는 접힘선이 2개다. 접힘선 하나를 경계로 나누면 키패드가 다른 접힘선에 걸치므로,
  /// **태블릿으로 다룬다** — 가로로 들면 가로형, 세로로 돌리면 세로형이다(화면이 본체 크기로 키가 큰 쪽을 고른다).
  /// 접힘선 2개가 LCD와 키 열 위를 지나가지만 키 모양을 우선한다. 자세(펼침·반 접힘)와 상관없이 같다 — Galaxy Z TriFold는
  /// Flex 모드가 없어 펴서만 쓰는 것으로 알려져 있고(기사 한 건 기준, 공식 문서 미확인), 힌지 각도를 유지하는 Z자형 기기
  /// (Huawei Mate XT)를 꺾어 쓰는 경우는 따로 대응하지 않는다.
  /// - 접은 커버 화면은 접힘선이 창을 가로지르지 않아 폰과 같은 규칙(2번 — 폴더블 기기의 위아래 배치, 짧은 창 비교)이다.
  ///   두 장만 펼친 상태(그런 기기가 있으면)나, 분할 화면 창이 접힘선 하나에만 걸친 경우는 접힘선 1개 규칙(1번)이다.
  /// - 시작 깜빡임 방지(2번)는 접힘 정보가 **오기 전**에만 위아래 배치로 둔다. 트라이폴드는 접힘 정보가 오면 이 3번이
  ///   되므로 가로형을 막지 않는다. 앱 시작 때는 Android가 창 배치 첫 값에 접히는 부분이 있다고 알리면 `main()`이 접힘
  ///   정보가 올 때까지 첫 화면을 미루므로(#158) 첫 프레임부터 가로형이다.
  /// - 회전 직후 몇 프레임은 접힘 정보가 이전 방향 값이라 창을 가로지르지 않을 수 있다([crossingHingesOf]) — 그동안은
  ///   2번(위아래 배치)이다. 폴더블의 회전과 같다(아래 에뮬레이터 기록에서는 보이지 않았다).
  /// - 방향 정책은 화면 크기와 상관없이 네 방향이다([orientationPolicyOf]의 `multipleHinges`).
  /// - **가정 (미확인)**: 펼친 트라이폴드가 Jetpack WindowManager로 접히는 부분(`FoldingFeature`) 2개를 보고한다는 것과
  ///   펼친 화면 dp 크기·접힘선 위치는 실기기로 확인하지 못했다(트라이폴드 에뮬레이터 기기 정의가 없다). 미리보기 프리셋은
  ///   Galaxy Z TriFold 공개 해상도 2160×1584 px를 밀도 2.625로 바꾼 823×603dp에 세 장 같은 폭(접힘선 x≈274·549)을
  ///   가정했다(이슈가 처음 가정한 크기는 960×704dp). 실기기 확인은 출시 QA(M8, #200)에서 한다.
  /// - 에뮬레이터 기록 (#144, Pixel Fold 에뮬레이터 Android 16 진단 릴리스 빌드 — 흉내 낸 값이라 실기기 보고 값은 아니다):
  ///   `adb shell wm size`로 화면 크기를 바꾸고 `adb shell settings put global display_features 'fold-[…];fold-[…]'`(Jetpack
  ///   확장이 읽는 접힘 정보 덮어쓰기)로 접힘선 2개를 주었다. 세 크기 모두 Flutter 화면 특징에 폭 0 `fold`·`postureFlat`
  ///   2개가 왔다. 시작 판정 첫 값이 "접힘"이라 첫 프레임부터 가로형이었고, 방향 요청은 네 방향이었다.
  ///   - 2160×1584 px(밀도 420 → 822.9×603.4dp, 접힘선 x=274.3·548.6): 가로형, 세로로 돌리면 세로형, 다시 돌리면 가로형.
  ///   - 같은 화면을 밀도 480으로 확대(720×528dp): 가로형·세로형은 같다. 회전할 때 접힘 정보가 늦게 와 창을 가로지르지
  ///     않는 순간에 세로 고정을 한 번 요청했다가 푸는 것이 보여, 창 크기를 기억해 막았다(`DeviceOrientationLock`
  ///     "트라이폴드 방향 기억"). 고친 뒤에는 네 번 돌려도 방향 요청이 다시 나가지 않았다. 세로→가로에서 창이 아직
  ///     세로인 프레임(약 0.5초)은 위아래 배치였다 — 회전 중 창 크기 그대로다.
  ///   - 2520×1848 px(960×704dp, 이슈의 처음 가정)과 원래 크기(841×701dp)에 접힘선 2개: 가로형.
  ///   - 7.6" Fold-in 에뮬레이터(Android 14)는 원래 설정(힌지 1개)에서도 접힘 정보를 보고하지 않아 쓸 수 없었다.
  ///
  /// 2번에서 위아래 배치를 돌려받은 창이라도 짧은 변이 [largeScreenMinShortestSide] 미만이면(폴더블 커버 화면의 분할 화면
  /// 등) 화면이 본체 크기로 가로형과 비교해 키가 더 큰 쪽으로 그린다 (짧은 창, #38). 접힘선 기준 배치를 쓸 수 없을 때
  /// 위아래 배치로 대체하는 것과 같이, 본체 크기가 필요한 판정은 화면이 한다.
  static ScreenArrangement arrangementOf(
    Size windowSize,
    Iterable<DisplayFeature> features, {
    bool foldableDevice = false,
  }) {
    // 접힘선이 둘 이상 가로지르면 hingeOf가 null이다(트라이폴드 — 접힘선 없는 창으로 다룬다, #144)
    final hinge = hingeOf(windowSize, features);
    if (hinge != null) {
      final b = hinge.bounds;
      final vertical = isVerticalHinge(b);
      final before = vertical ? b.left : b.top;
      final after = vertical
          ? windowSize.width - b.right
          : windowSize.height - b.bottom;
      if (before >= hingeMinPanelExtent && after >= hingeMinPanelExtent) {
        if (vertical) return ScreenArrangement.hingeSplit;
        if (separates(hinge)) return ScreenArrangement.hingeStacked;
      }
    }
    if (!picksFormByKeySize(
      windowSize,
      features,
      foldableDevice: foldableDevice,
    )) {
      return ScreenArrangement.stacked;
    }
    return windowSize.width > windowSize.height
        ? ScreenArrangement.landscape
        : ScreenArrangement.stacked;
  }
}

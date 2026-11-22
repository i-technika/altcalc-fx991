import 'dart:ui' show DisplayFeature, DisplayFeatureType, FlutterView, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 기기 종류 — 화면 방향 고정을 고를 때 쓴다 (#24).
enum DeviceKind {
  /// 일반 폰
  phone,

  /// 폴더블 — 힌지 각도 센서가 있거나 접히는 부분(fold/hinge)이 보고되는 기기 (커버 화면 포함)
  foldable,

  /// 태블릿 — 짧은 변 [FormFactor.largeScreenMinShortestSide] 이상인 폴더블이 아닌 기기
  tablet,
}

/// 계산기 화면 배치 종류 (#24). 힌지 기준 분할은 #25에서 더한다.
enum ScreenArrangement {
  /// 위아래 배치: 위 LCD, 아래 키패드 (폰 세로 화면, 세로·좁은 창)
  stacked,

  /// 좌우 분할 배치: LCD와 키패드를 좌우로 나누고 주로 쓰는 손 쪽에 키패드 (대화면 가로 창)
  split,
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
/// - 분할 화면·팝업 창처럼 창 자체가 화면보다 작은 경우.
/// 그래서 태블릿을 세로로 들면 대개 세로 창이 되고, 그때는 위아래 배치로 보여 준다.
abstract final class FormFactor {
  /// 대화면 기준 짧은 변 (dp). Material 창 크기 등급 medium(폭 600dp) 이상과 같고, Android가 방향
  /// 고정을 무시하는 대화면 기준과도 같다.
  static const double largeScreenMinShortestSide = 600.0;

  /// 기기 특성 조회 채널 (Android `MainActivity`)
  @visibleForTesting
  static const MethodChannel deviceChannel = MethodChannel('altcalc/device');

  /// [features]에 접히는 부분(fold·hinge)이 있는지. 화면 구멍(cutout)은 세지 않는다.
  static bool hasFoldOrHinge(Iterable<DisplayFeature> features) => features.any(
    (f) =>
        f.type == DisplayFeatureType.fold || f.type == DisplayFeatureType.hinge,
  );

  /// 기기에 힌지 각도 센서가 있는지 (Android `FEATURE_SENSOR_HINGE_ANGLE`). 폴더블 기기를 앱 시작 시점에
  /// 구분하는 데 쓴다 — 접히는 부분 정보([FlutterView.displayFeatures])는 화면이 붙은 뒤 비동기로 와서
  /// 시작 시점에는 비어 있다. Android가 아니거나 조회에 실패하면 `false`.
  static Future<bool> queryHingeSensor() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await deviceChannel.invokeMethod<bool>('hasHingeSensor') ?? false;
    } on PlatformException catch (error) {
      debugPrint('힌지 센서 조회 실패: $error');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 기기 종류를 정한다.
  /// - [displaySize]: 물리 화면 크기 (dp)
  /// - [features]: 화면 특징 (접히는 부분 등)
  /// - [hasHingeSensor]: 힌지 각도 센서 유무 ([queryHingeSensor])
  ///
  /// 폴더블 내부 화면은 짧은 변이 600dp를 넘어 크기로는 태블릿과 구분되지 않으므로, 힌지 센서나 접히는
  /// 부분 정보로 구분한다. 폴더블은 접은 커버 화면에서도 [DeviceKind.foldable]이다.
  static DeviceKind deviceKindOf(
    Size displaySize,
    Iterable<DisplayFeature> features, {
    bool hasHingeSensor = false,
  }) {
    if (hasHingeSensor || hasFoldOrHinge(features)) return DeviceKind.foldable;
    if (displaySize.shortestSide >= largeScreenMinShortestSide) {
      return DeviceKind.tablet;
    }
    return DeviceKind.phone;
  }

  /// [view]가 놓인 물리 화면 크기 (dp). 플랫폼이 화면 크기를 알려주지 않으면(크기 0) 창 크기를 쓴다.
  static Size displaySizeOf(FlutterView view) {
    final display = view.display;
    if (!display.size.isEmpty && display.devicePixelRatio > 0) {
      return display.size / display.devicePixelRatio;
    }
    return view.physicalSize / view.devicePixelRatio;
  }

  /// 기기 종류별로 요청할 화면 방향.
  /// - 폰: 세로 — 가로 화면에서는 키패드가 쓸 수 없을 만큼 작아진다.
  /// - 태블릿: 가로 — LCD와 키패드를 좌우로 나눠 보여 준다 (지켜지는 범위는 클래스 설명 참조).
  /// - 폴더블: 지금은 폰과 같이 세로다. TODO(#25): 힌지 기준 좌우 분할과 함께 정한다.
  static List<DeviceOrientation> preferredOrientationsFor(DeviceKind kind) =>
      switch (kind) {
        DeviceKind.tablet => const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        DeviceKind.phone ||
        DeviceKind.foldable => const [DeviceOrientation.portraitUp],
      };

  /// 앱 창([windowSize], dp)의 배치.
  ///
  /// 짧은 변이 [largeScreenMinShortestSide] 이상인 가로(폭 > 높이) 창이면 좌우 분할이다. 기기 종류가 아니라
  /// 창 크기로 정하므로, 방향 고정이 무시된 태블릿 세로 화면이나 분할 화면의 좁은 창은 위아래 배치가 된다.
  ///
  /// 폴더블 기기([foldableDevice])이거나 접히는 부분이 창을 지나면 위아래 배치로 둔다 — 좌우 분할이 힌지를
  /// 가로지르지 않게 나누는 일은 TODO(#25). 폴더블 기기를 따로 받는 이유: 접히는 부분 정보가 늦게 와서
  /// 그 전 몇 프레임 동안 좌우 분할로 그렸다가 위아래 배치로 바뀌는 깜빡임을 막는다.
  static ScreenArrangement arrangementOf(
    Size windowSize,
    Iterable<DisplayFeature> features, {
    bool foldableDevice = false,
  }) {
    if (foldableDevice || hasFoldOrHinge(features)) {
      return ScreenArrangement.stacked;
    }
    return windowSize.shortestSide >= largeScreenMinShortestSide &&
            windowSize.width > windowSize.height
        ? ScreenArrangement.split
        : ScreenArrangement.stacked;
  }
}

import 'dart:ui' show DisplayFeature, DisplayFeatureType, FlutterView, Size;

import 'package:flutter/services.dart' show DeviceOrientation;

/// 기기 종류 — 화면 방향 고정을 고를 때 쓴다 (#24).
enum DeviceKind {
  /// 일반 폰 (폴더블 커버 화면 포함)
  phone,

  /// 폴더블 내부(펼친) 화면 — 접히는 부분(fold/hinge)이 보고되는 화면
  foldable,

  /// 태블릿 — 짧은 변 [FormFactor.largeScreenMinShortestSide] 이상이고 접히는 부분이 없는 화면
  tablet,
}

/// 기기·창 크기에 따른 화면 구분 규칙 (#24).
///
/// 두 가지를 따로 판정한다.
/// - **기기 종류**([deviceKindOf]): 물리 화면(디스플레이) 크기로 정한다. 앱 시작 시 방향 고정에 쓴다.
/// - **배치**([usesSplitLayout]): 앱 **창** 크기로 정한다. 방향 고정은 지켜지지 않을 수 있으므로
///   (아래) 화면 배치는 항상 실제 창 크기를 따른다.
///
/// ## 방향 고정이 지켜지지 않는 경우
/// - Android 16(targetSdk 36) 이상: 짧은 변 600dp 이상 화면(태블릿·폴더블 내부)은 앱의 방향 고정을 무시한다.
/// - iPad: 멀티태스킹(Split View·Slide Over·Stage Manager)을 지원하는 앱의 방향 고정을 무시한다.
///   이 앱은 iPad 멀티태스킹을 끄지 않는다 — 전체 화면 강제(`UIRequiresFullScreen`)는 iPadOS 26부터
///   폐기 예정이고, 계산기는 다른 앱과 나란히 쓰는 경우가 많다. 그래서 `Info.plist`의 iPad 방향은
///   네 방향을 모두 허용한 채로 두고(멀티태스킹 요건), 좁거나 세로인 창은 위아래 배치로 보여 준다.
/// - 분할 화면·팝업 창처럼 창 자체가 화면보다 작은 경우.
abstract final class FormFactor {
  /// 대화면 기준 짧은 변 (dp). Material 창 크기 등급 medium(폭 600dp) 이상과 같고, Android가 방향
  /// 고정을 무시하는 대화면 기준과도 같다.
  static const double largeScreenMinShortestSide = 600.0;

  /// [features]에 접히는 부분(fold·hinge)이 있는지. 화면 구멍(cutout)은 세지 않는다.
  static bool hasFoldOrHinge(Iterable<DisplayFeature> features) => features.any(
    (f) =>
        f.type == DisplayFeatureType.fold || f.type == DisplayFeatureType.hinge,
  );

  /// 물리 화면 크기([displaySize], dp)와 화면 특징([features])으로 기기 종류를 정한다.
  ///
  /// 폴더블 내부 화면은 짧은 변이 600dp를 넘어 태블릿과 크기로 구분되지 않으므로, 접히는 부분이
  /// 보고되는지로 구분한다(Android Jetpack WindowManager가 펼친 상태에서 fold를 보고한다).
  /// 접은 상태의 커버 화면은 접히는 부분이 없고 폰 크기라 [DeviceKind.phone]이다.
  static DeviceKind deviceKindOf(
    Size displaySize,
    Iterable<DisplayFeature> features,
  ) {
    if (hasFoldOrHinge(features)) return DeviceKind.foldable;
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
  /// - 태블릿: 가로 — LCD와 키패드를 좌우로 나눠 보여 준다.
  /// - 폴더블 내부: 지금은 폰과 같이 세로다. TODO(#25): 힌지 기준 좌우 분할과 함께 정한다.
  static List<DeviceOrientation> preferredOrientationsFor(DeviceKind kind) =>
      switch (kind) {
        DeviceKind.tablet => const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        DeviceKind.phone ||
        DeviceKind.foldable => const [DeviceOrientation.portraitUp],
      };

  /// 앱 창([windowSize], dp)이 LCD/키패드 좌우 분할 배치를 쓰는지.
  ///
  /// 짧은 변이 [largeScreenMinShortestSide] 이상인 가로(폭 > 높이) 창이면 좌우로 나눈다.
  /// 기기 종류가 아니라 창 크기로 정하므로, 방향 고정이 무시된 태블릿 세로 화면이나 분할 화면의 좁은 창은
  /// 위아래 배치가 된다. 접히는 부분이 창을 지나면 위아래 배치로 둔다 — 좌우 분할이 힌지를 가로지르지
  /// 않게 나누는 일은 TODO(#25).
  static bool usesSplitLayout(
    Size windowSize,
    Iterable<DisplayFeature> features,
  ) {
    if (hasFoldOrHinge(features)) return false;
    return windowSize.shortestSide >= largeScreenMinShortestSide &&
        windowSize.width > windowSize.height;
  }
}

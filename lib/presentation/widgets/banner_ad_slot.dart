import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';

/// 화면 최하단 배너 광고 슬롯.
///
/// 구성 (위 → 아래):
/// ```
///  ──────────────────────────────  ← 키패드 최하단 행
///   (safetyMargin: 8~12dp 여백)      ← 오터치 방지 안전 여백 (본체 배경이 비치며 터치를 흡수)
///  ┌────────────────────────────┐
///  │         [ 배너 광고 ]         │  ← 슬롯 (height)
///  └────────────────────────────┘
///   (시스템 하단 인셋)                ← 홈 인디케이터·내비게이션 바 영역 (슬롯 배경색으로 채움)
/// ```
///
/// ## 높이 계약
/// - 광고 높이는 [height]로 주입한다. `null`이면 [defaultHeightFor]로 화면 크기에 맞는 기본값
///   ([CalcTheme.adSlotHeight] / 대형 화면 [CalcTheme.adSlotMaxHeight])을 쓴다.
///   M6 적응형 배너(#18)는 SDK가 산출한 실제 배너 높이를 [height]로 넘긴다.
/// - **슬롯 높이는 실제 광고 높이와 같아야 한다.** 슬롯은 광고를 자르지 않으며(광고를 가리거나
///   잘라 보이게 하는 것은 AdMob 정책 위반), [child]에는 슬롯 크기를 최대값으로 하는 제약만 준다.
/// - 광고가 아직 로드되지 않았거나([child]가 `null`) 로드에 실패해도 **같은 높이를 유지**해,
///   광고 로드 시점에 키패드가 밀리거나 찌그러지지 않는다.
/// - 광고 제거(인앱결제) 시에는 부모가 이 위젯을 빼고 키패드에 공간을 돌려준다 (M6).
///
/// ## 배치 계약
/// - 부모 폭을 가득 채우므로 가로 제약이 유한해야 한다(`Row` 안에 직접 두지 않는다).
/// - 시스템 인셋([MediaQueryData.padding])의 하단·좌우만큼 광고를 안쪽으로 들여 시스템 UI와
///   겹치지 않게 한다. 부모가 이미 [SafeArea]로 인셋을 소비했다면 0이 되어 중복되지 않는다.
/// - 안전 여백은 하한([CalcTheme.adSlotMinSafetyMargin])만 강제한다. 넓히는 것은 공간만 더 쓸 뿐
///   오터치 위험이 없으므로 상한은 두지 않는다(권장 범위는 8~12dp).
class BannerAdSlot extends StatelessWidget {
  /// 광고 슬롯 높이 (dp). `null`이면 [defaultHeightFor].
  final double? height;

  /// 키패드와 광고 사이의 오터치 방지 여백 (dp). [CalcTheme.adSlotMinSafetyMargin] 이상이어야 한다.
  final double safetyMargin;

  /// 광고 위젯 (`null`이면 빈 슬롯)
  final Widget? child;

  const BannerAdSlot({
    super.key,
    this.height,
    this.safetyMargin = CalcTheme.adSlotSafetyMargin,
    this.child,
  }) : assert(height == null || height > 0, 'height는 양수여야 한다'),
       assert(
         safetyMargin >= CalcTheme.adSlotMinSafetyMargin,
         'safetyMargin은 오터치 방지를 위해 '
         '${CalcTheme.adSlotMinSafetyMargin}dp 이상이어야 한다',
       );

  /// 화면 크기에 맞는 기본 슬롯 높이.
  /// 짧은 변이 [CalcTheme.adSlotLargeScreenShortestSide] 이상인 대형 화면은 [CalcTheme.adSlotMaxHeight].
  ///
  /// TODO(#18): 적응형 배너 높이는 광고 폭(슬롯 폭) 기준으로 정해지므로 M6에서 SDK 산출값으로 대체한다.
  static double defaultHeightFor(Size screenSize) =>
      screenSize.shortestSide >= CalcTheme.adSlotLargeScreenShortestSide
      ? CalcTheme.adSlotMaxHeight
      : CalcTheme.adSlotHeight;

  @override
  Widget build(BuildContext context) {
    final slotHeight = height ?? defaultHeightFor(MediaQuery.sizeOf(context));
    final insets = MediaQuery.paddingOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 오터치 방지 여백: 아무것도 그리지 않지만 터치를 흡수해, 부모가 겹쳐 배치(Stack 등)해도
        // 여백을 누른 터치가 뒤쪽 위젯이나 광고로 전달되지 않는다.
        Listener(
          key: const ValueKey('banner-ad-slot-safety-margin'),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(height: safetyMargin),
        ),
        ColoredBox(
          key: const ValueKey('banner-ad-slot-background'),
          color: CalcTheme.adSlotBackground,
          child: Padding(
            padding: EdgeInsets.only(
              left: insets.left,
              right: insets.right,
              bottom: insets.bottom,
            ),
            child: SizedBox(
              key: const ValueKey('banner-ad-slot'),
              height: slotHeight,
              child: Center(child: child),
            ),
          ),
        ),
      ],
    );
  }
}

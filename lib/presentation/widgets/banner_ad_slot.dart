import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';

/// 화면 최하단 배너 광고 슬롯.
///
/// 구성 (위 → 아래):
/// ```
///  ──────────────────────────────  ← 키패드 최하단 행
///   (safetyMargin: 8~12dp 빈 여백)  ← 오터치 방지 안전 여백 (본체 배경이 비침, 터치 무반응)
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
/// - 광고가 아직 로드되지 않았거나([child]가 `null`) 로드에 실패해도 **같은 높이를 유지**해,
///   광고 로드 시점에 키패드가 밀리거나 찌그러지지 않는다.
/// - 광고 제거(인앱결제) 시에는 부모가 이 위젯을 빼고 키패드에 공간을 돌려준다 (M6).
/// - 하단 시스템 인셋([MediaQueryData.padding] 하단)만큼 아래 여백을 더해 광고가 시스템 UI와 겹치지 않게 한다.
///   부모가 이미 [SafeArea]로 하단 인셋을 소비했다면 0이 되어 중복되지 않는다.
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
  static double defaultHeightFor(Size screenSize) =>
      screenSize.shortestSide >= CalcTheme.adSlotLargeScreenShortestSide
      ? CalcTheme.adSlotMaxHeight
      : CalcTheme.adSlotHeight;

  @override
  Widget build(BuildContext context) {
    final slotHeight = height ?? defaultHeightFor(MediaQuery.sizeOf(context));
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 오터치 방지 여백: 아무것도 그리지 않으며 터치를 받는 위젯도 없다.
        SizedBox(height: safetyMargin),
        ColoredBox(
          key: const ValueKey('banner-ad-slot-background'),
          color: CalcTheme.adSlotBackground,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SizedBox(
              key: const ValueKey('banner-ad-slot'),
              height: slotHeight,
              // 광고 위젯이 슬롯보다 커도 키패드 쪽으로 넘쳐 그려지지 않게 자른다.
              child: ClipRect(child: Center(child: child)),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import '../providers/calc_provider.dart';
import '../widgets/banner_ad_slot.dart';
import '../widgets/calc_keypad.dart';
import '../widgets/lcd_display.dart';

/// 계산기 메인 화면: LCD + 50키 키패드 + 최하단 광고 슬롯.
///
/// 구성 (위 → 아래):
/// ```
///  ┌──────────────────────────┐  ← 상단 시스템 인셋 (SafeArea)
///  │          LCD             │  ← [lcdHeightFor]
///  │        (간격)            │
///  │     50키 키패드          │  ← 남은 높이 (가로/세로 비 제한, 가운데 정렬)
///  ├──────────────────────────┤
///  │ 안전 여백 + 광고 슬롯    │  ← [BannerAdSlot] (하단·좌우 시스템 인셋은 슬롯이 처리)
///  └──────────────────────────┘
/// ```
///
/// - 키패드는 스크롤 영역 밖에 고정 배치한다(`CalcKeyButton`은 누르는 순간 입력한다).
/// - LCD만 상태를 구독하고 키패드는 notifier만 읽으므로, 키 입력으로 키패드 50개가 다시 그려지지 않는다.
/// - 좌우 여백은 [CalcTheme.screenPadding]만 둔다. 가장자리 열의 바깥쪽 일부가 Android 제스처
///   내비게이션 영역에 걸릴 수 있지만, `CalcKeyButton`이 그 영역에서 시작한 터치를 손을 뗄 때
///   확정하므로 뒤로가기 제스처와 충돌하지 않는다. 제스처 폭만큼 여백을 두면 모든 폰에서 키패드가 좁아진다.
/// - 세로 화면 기준이다(`lockPortraitOrientation`). 태블릿·폴더블 좌우 분할은 #24·#25,
///   LCD 비율 기준은 #23에서 다룬다.
class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  /// 광고 슬롯을 뺀 본체 영역 [body]에서 LCD 높이를 정한다.
  ///
  /// 기본은 [CalcTheme.screenLcdHeightRatio] (최소 [CalcTheme.screenLcdMinHeight])이고,
  /// 세로로 긴 화면에서 키패드가 가로/세로 비 하한에 걸려 남는 높이는 LCD에 준다.
  /// 본체가 아주 낮으면 키패드 높이가 0이 될 때까지만 LCD를 키운다.
  static double lcdHeightFor(Size body) {
    final available = math.max(0.0, body.height - CalcTheme.screenLcdKeypadGap);
    final keypadMaxHeight = body.width / CalcTheme.keypadMinAspectRatio;
    final lcd = math.max(
      math.max(
        body.height * CalcTheme.screenLcdHeightRatio,
        CalcTheme.screenLcdMinHeight,
      ),
      available - keypadMaxHeight,
    );
    return math.min(lcd, available);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalcTheme.bodyBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CalcTheme.screenPadding,
                  CalcTheme.screenPadding,
                  CalcTheme.screenPadding,
                  0,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final lcdHeight = lcdHeightFor(constraints.biggest);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: lcdHeight, child: const _LcdPanel()),
                        const SizedBox(height: CalcTheme.screenLcdKeypadGap),
                        const Expanded(child: _KeypadPanel()),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // TODO(#18): M6에서 적응형 배너 광고를 child로 연결한다.
          const BannerAdSlot(),
        ],
      ),
    );
  }
}

/// 상태를 구독해 LCD를 그린다. M1에서는 마지막 입력 기능의 각인을 입력 줄에 보여준다.
/// TODO(M2): 수식 AST(`MathNodeWidget`)와 결과 표시로 대체한다.
class _LcdPanel extends ConsumerWidget {
  const _LcdPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(lcdStatusProvider);
    final lastLabel = ref.watch(calcProvider.select((s) => s.lastInput?.label));
    return LcdDisplay(
      status: status,
      input: Text(lastLabel ?? '', key: const ValueKey('lcd-input-text')),
    );
  }
}

/// 키 입력을 notifier로 전달하는 키패드. 상태를 구독하지 않는다.
class _KeypadPanel extends ConsumerWidget {
  const _KeypadPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CalcKeypad(
      onKeyPressed: (id) => ref.read(calcProvider.notifier).pressKey(id),
      onKeyRepeat: (id) => ref.read(calcProvider.notifier).repeatKey(id),
    );
  }
}

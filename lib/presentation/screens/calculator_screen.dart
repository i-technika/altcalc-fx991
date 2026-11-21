import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import '../../domain/models/calc_state.dart';
import '../l10n/calc_semantic_strings.dart';
import '../providers/calc_provider.dart';
import '../widgets/banner_ad_slot.dart';
import '../widgets/calc_keypad.dart';
import '../widgets/lcd_display.dart';

/// 광고 슬롯을 뺀 본체 영역의 세로 배치 (위 → 아래: 상단 띠 · LCD · 간격 · 키패드).
///
/// 기준은 [CalcTheme]의 "화면 배치" 절을 따른다 (#23).
/// - LCD: [CalcTheme.screenLcdHeightRatio] 목표, [CalcTheme.screenLcdMinHeight] ~
///   (폭 / [CalcTheme.screenLcdMinAspectRatio]) 범위.
/// - 키패드: 나머지 높이 중 가로/세로 비 하한([CalcTheme.keypadMinAspectRatio])이 허용하는 만큼.
///   키패드가 쓰지 못하는 높이는 LCD 최대 높이까지 LCD에 주고, 그래도 남으면 [top]으로 둔다.
/// - 본체가 아주 낮으면 키패드 높이가 0이 될 때까지만 LCD를 최소 높이로 지킨다 (TODO(#38)).
///   본체가 간격보다 낮으면 간격도 본체 높이로 줄어, 어떤 경우에도 합계가 본체 높이를 넘지 않는다.
@immutable
class CalcScreenLayout {
  /// LCD 위 상단 띠 높이 (dp)
  final double top;

  /// LCD 높이 (dp)
  final double lcdHeight;

  /// LCD와 키패드 사이 간격 (dp) — [CalcTheme.screenLcdKeypadGap], 본체가 그보다 낮으면 본체 높이
  final double gap;

  /// 키패드 영역 높이 (dp)
  final double keypadHeight;

  const CalcScreenLayout._({
    required this.top,
    required this.lcdHeight,
    required this.gap,
    required this.keypadHeight,
  });

  /// [body] (광고 슬롯·화면 여백을 뺀 본체 영역)의 세로 배치.
  /// `top + lcdHeight + gap + keypadHeight`는 본체 높이와 같다 (음수·비유한 크기는 0으로 본다).
  factory CalcScreenLayout.of(Size body) {
    double finite(double v) => v.isFinite ? math.max(0.0, v) : 0.0;
    final width = finite(body.width);
    final height = finite(body.height);
    final gap = math.min(CalcTheme.screenLcdKeypadGap, height);
    final available = height - gap;
    final keypadMax = width / CalcTheme.keypadMinAspectRatio;
    final lcdMax = math.max(
      CalcTheme.screenLcdMinHeight,
      width / CalcTheme.screenLcdMinAspectRatio,
    );
    final lcd = math.min(
      math
          .max(height * CalcTheme.screenLcdHeightRatio, available - keypadMax)
          .clamp(CalcTheme.screenLcdMinHeight, lcdMax),
      available,
    );
    final keypad = math.min(available - lcd, keypadMax);
    return CalcScreenLayout._(
      top: available - lcd - keypad,
      lcdHeight: lcd,
      gap: gap,
      keypadHeight: keypad,
    );
  }

  @override
  String toString() =>
      'CalcScreenLayout(top: $top, lcd: $lcdHeight, gap: $gap, '
      'keypad: $keypadHeight)';
}

/// 계산기 메인 화면: LCD + 50키 키패드 + 최하단 광고 슬롯.
///
/// 구성 (위 → 아래):
/// ```
///  ┌──────────────────────────┐  ← 상단 시스템 인셋 (SafeArea)
///  │       (상단 띠)          │  ← [CalcScreenLayout.top] — 세로로 긴 화면에서만 생긴다
///  │          LCD             │  ← [CalcScreenLayout.lcdHeight]
///  │        (간격)            │
///  │     50키 키패드          │  ← [CalcScreenLayout.keypadHeight]
///  ├──────────────────────────┤
///  │ 안전 여백 + 광고 슬롯    │  ← [BannerAdSlot] (하단·좌우 시스템 인셋은 슬롯이 처리)
///  └──────────────────────────┘
/// ```
///
/// - 키패드는 스크롤 영역 밖에 고정 배치한다(`CalcKeyButton`은 누르는 순간 입력한다).
/// - LCD만 상태를 구독하고 키패드는 notifier만 읽으므로, 키 입력으로 키패드 50개가 다시 그려지지 않는다.
/// - LCD 글자 크기는 LCD가 자기 크기에서 [LcdFontSizes.forSize]로 산출한다 (`fitFontsToSize`).
/// - 좌우 여백은 [CalcTheme.screenPadding]만 둔다. 가장자리 열의 바깥쪽 일부가 Android 제스처
///   내비게이션 영역에 걸릴 수 있지만, `CalcKeyButton`이 그 영역에서 시작한 터치를 손을 뗄 때
///   확정하므로 뒤로가기 제스처와 충돌하지 않는다. 제스처 폭만큼 여백을 두면 모든 폰에서 키패드가 좁아진다.
/// - 세로 화면 기준이다(`lockPortraitOrientation`). 태블릿·폴더블 좌우 분할은 #24·#25.
class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

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
                    final layout = CalcScreenLayout.of(constraints.biggest);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // TODO(#41): 상단 띠 활용 (장식·설정 진입 등)
                        SizedBox(height: layout.top),
                        SizedBox(
                          height: layout.lcdHeight,
                          child: const _LcdPanel(),
                        ),
                        SizedBox(height: layout.gap),
                        // 남는 높이(반올림 오차 등)는 키패드가 받는다.
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
    final lastInput = ref.watch(calcProvider.select((s) => s.lastInput));
    final strings = CalcSemanticStrings.of(context);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        LcdDisplay(
          status: status,
          fitFontsToSize: true,
          input: Text(
            lastInput?.label ?? '',
            key: const ValueKey('lcd-input-text'),
            // 각인 기호 대신 기능 이름을 읽는다 (#20)
            semanticsLabel: lastInput == null
                ? null
                : strings.keyFunction(lastInput.id, lastInput.layer),
          ),
        ),
        // 스크린리더 알림 전용 노드 (LCD 왼쪽 위 1dp — 화면에 보이지 않고 터치를 가로채지 않는다)
        const Positioned(
          left: 0,
          top: 0,
          width: 1,
          height: 1,
          child: IgnorePointer(child: ScreenReaderAnnouncer()),
        ),
      ],
    );
  }
}

/// 계산기 상태 변화를 스크린리더로 알린다 (#20). 무엇을 알릴지는 [announcementFor]가 정한다.
///
/// 플랫폼마다 알리는 방법이 다르다 — Flutter 자체 위젯(InputDecorator)과 같은 기준
/// (`MediaQuery.supportsAnnounceOf`)으로 나눈다.
/// - **알림 지원(iOS 등)**: `SemanticsService.sendAnnouncement`. 스크린리더가 꺼져 있으면 보내지 않는다.
/// - **알림 미지원(Android)**: 이 위젯의 liveRegion 노드 라벨을 바꾼다. Android 엔진은 알림을 지원하지 않고
///   (Android 16부터 API 폐기 예정), liveRegion 노드는 **라벨이 바뀔 때만** 읽힌다. 같은 말이 이어져도
///   ("7" → "7") 읽히도록 매번 보이지 않는 문자(U+200B)를 붙였다 뗐다 해 라벨을 바꾼다.
///
/// 상태 표시줄·입력 줄을 liveRegion으로 두지 않는 이유: 상태 표시줄 전체가 매번 다시 읽히고, 켜짐/꺼짐
/// 의미가 전달되지 않으며, 같은 입력이 이어지면 입력 줄 라벨이 그대로라 읽히지 않는다(리뷰 R2).
@visibleForTesting
class ScreenReaderAnnouncer extends ConsumerStatefulWidget {
  const ScreenReaderAnnouncer({super.key});

  /// 연속된 같은 말을 구분하려고 번갈아 붙이는 글자 (스크린리더는 읽지 않는다)
  static const String repeatMarker = '\u200B';

  @override
  ConsumerState<ScreenReaderAnnouncer> createState() =>
      _ScreenReaderAnnouncerState();
}

class _ScreenReaderAnnouncerState extends ConsumerState<ScreenReaderAnnouncer> {
  String _message = '';
  bool _marked = false;

  @override
  Widget build(BuildContext context) {
    final strings = CalcSemanticStrings.of(context);
    final supportsAnnounce = MediaQuery.supportsAnnounceOf(context);
    final view = View.of(context);
    final direction = Directionality.of(context);
    ref.listen(
      calcProvider.select((s) => (s.modifier, s.inputCount, s.lastInput)),
      (previous, next) {
        // 직전 선택 값이 없으면(오류 등) 비교할 수 없으므로 알리지 않는다.
        if (previous == null) return;
        final message = announcementFor(strings, previous, next);
        if (message == null) return;
        if (supportsAnnounce) {
          if (!SemanticsBinding.instance.semanticsEnabled) return;
          unawaited(
            SemanticsService.sendAnnouncement(view, message, direction),
          );
        } else {
          setState(() {
            _marked = !_marked;
            _message = _marked
                ? message
                : '$message${ScreenReaderAnnouncer.repeatMarker}';
          });
        }
      },
    );
    if (supportsAnnounce) return const SizedBox.shrink();
    return Semantics(
      key: const ValueKey('screen-reader-announcer'),
      container: true,
      liveRegion: true,
      label: _message,
      child: const SizedBox.expand(),
    );
  }
}

/// 상태 변화([previous] → [next])에 대해 스크린리더로 알릴 말. 알릴 것이 없으면 `null`. (#20)
///
/// 상태는 `(모디파이어 대기, 입력 수, 마지막 입력)`이다.
/// - 기능이 입력되면(입력 수 증가) 그 기능 이름을 알린다. 시프트·알파 대기가 그 입력으로 풀렸다는 것도
///   이것으로 전달된다(예: 시프트 → sin → "아크사인"). 길게 눌러 반복되는 입력은 알리지 않는다.
/// - 입력 없이 대기만 바뀌면: 켜짐("시프트 켜짐"), 또는 꺼짐(같은 키를 다시 누름, 기능 없는 층의 키).
@visibleForTesting
String? announcementFor(
  CalcSemanticStrings strings,
  (KeyModifier, int, KeyInput?) previous,
  (KeyModifier, int, KeyInput?) next,
) {
  final (before, countBefore, _) = previous;
  final (after, countAfter, input) = next;
  if (countAfter != countBefore) {
    if (input == null || input.isRepeat) return null;
    return strings.keyFunction(input.id, input.layer);
  }
  if (before == after) return null;
  if (after != KeyModifier.none) {
    return strings.modifierChanged(after, on: true);
  }
  return strings.modifierChanged(before, on: false);
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

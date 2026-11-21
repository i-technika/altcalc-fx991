import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/key_definitions.dart';
import '../../core/theme/calc_theme.dart';

/// fx-991EX 스타일의 단일 키 버튼.
///
/// 구성 (위 → 아래):
/// ```
///  ┌──────────────────────┐
///  │ SOLVE            =   │  ← 각인 띠: SHIFT(금색, 좌) / ALPHA(빨강, 우), 본체 배경 위
///  │ ┌──────────────────┐ │
///  │ │       CALC       │ │  ← 키캡: 카테고리 색 + 메인 라벨 (터치 영역)
///  │ └──────────────────┘ │
///  └──────────────────────┘
/// ```
///
/// ## 크기 계약
/// - 크기는 부모(그리드 셀)가 정한다. 한 축이라도 제약이 무한하면 [fallbackSize]를 쓴다.
/// - 글자 크기는 [CalcTheme]의 비율 상수로 계산하며, 키패드 전체의 글자 크기를 맞추려면
///   부모가 [legendFontSize]/[mainLabelFontSize]를 주입한다. 넘치는 라벨은 [FittedBox]로 축소한다.
///
/// ## 입력 계약
/// - 실물 키처럼 **누르는 순간** [onPressed]를 호출하고 [HapticFeedback.lightImpact]를 실행한다.
///   손가락을 미끄러뜨려도 취소되지 않는다.
/// - 한 키에서는 첫 번째 손가락만 인식한다(동시에 닿은 다른 손가락은 무시).
/// - 터치 영역은 키캡뿐이며 각인 띠는 터치를 받지 않는다.
/// - 포인터를 직접 처리하므로 스크롤 컨테이너 안에 두면 스크롤 시작 터치도 입력된다.
///   키패드는 스크롤 영역 밖에 배치한다.
/// - [autoRepeat]이면 누르고 있는 동안 [repeatDelay] 후 [repeatInterval]마다 반복 입력한다
///   (커서·DEL 키용, 반복 입력에는 햅틱을 내지 않는다).
/// - [onPressed]가 `null`이면 비활성이다(반응·햅틱 없음, 라벨 흐림).
///
/// SHIFT/ALPHA 래치 상태는 실물처럼 LCD 상태 표시줄(S/A)로 보여주며, 키 자체에는 표시하지 않는다.
class CalcKeyButton extends StatefulWidget {
  /// 표시할 키 명세
  final CalcKeyDef keyDef;

  /// 키 입력 콜백. `null`이면 비활성.
  final ValueChanged<CalcKeyId>? onPressed;

  /// 햅틱 피드백 사용 여부 (설정 연동용)
  final bool enableHaptics;

  /// 누르고 있는 동안 반복 입력할지 여부
  final bool autoRepeat;

  /// 반복 입력 시작까지의 지연
  final Duration repeatDelay;

  /// 반복 입력 간격
  final Duration repeatInterval;

  /// 상단 각인 띠 표시 여부. `false`면 키캡이 셀 전체를 쓴다(커서 패드 등).
  final bool showLegendBand;

  /// 각인 글자 크기 (dp). `null`이면 셀 높이 비율로 계산.
  final double? legendFontSize;

  /// 메인 라벨 글자 크기 (dp). `null`이면 키캡 높이 비율로 계산.
  final double? mainLabelFontSize;

  const CalcKeyButton({
    super.key,
    required this.keyDef,
    this.onPressed,
    this.enableHaptics = true,
    this.autoRepeat = false,
    this.repeatDelay = defaultRepeatDelay,
    this.repeatInterval = defaultRepeatInterval,
    this.showLegendBand = true,
    this.legendFontSize,
    this.mainLabelFontSize,
  });

  /// 기본 반복 시작 지연
  static const Duration defaultRepeatDelay = Duration(milliseconds: 500);

  /// 기본 반복 간격
  static const Duration defaultRepeatInterval = Duration(milliseconds: 100);

  /// 부모 제약이 무한할 때 사용하는 기본 크기 (dp)
  static const Size fallbackSize = Size(56, 64);

  /// [id] 키의 키캡 위젯 식별용 키 (화면 테스트에서 특정 키캡을 찾을 때 사용)
  static Key keycapKeyOf(CalcKeyId id) => ValueKey(('calc_keycap', id));

  @override
  State<CalcKeyButton> createState() => _CalcKeyButtonState();
}

class _CalcKeyButtonState extends State<CalcKeyButton> {
  /// 현재 이 키를 누르고 있는 포인터 ID (없으면 null)
  int? _activePointer;
  Timer? _repeatTimer;

  bool get _enabled => widget.onPressed != null;
  bool get _pressed => _activePointer != null;

  @override
  void didUpdateWidget(covariant CalcKeyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 누른 채 비활성으로 바뀌면 눌림 표시와 반복 입력을 즉시 해제한다.
    if (!_enabled && _pressed) {
      _cancelRepeat();
      _activePointer = null;
    } else if (!widget.autoRepeat) {
      _cancelRepeat();
    }
  }

  @override
  void dispose() {
    _cancelRepeat();
    super.dispose();
  }

  void _cancelRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  void _emit() => widget.onPressed?.call(widget.keyDef.id);

  void _handlePointerDown(PointerDownEvent event) {
    if (!_enabled || _pressed) return; // 비활성이거나 이미 다른 손가락이 누르는 중
    setState(() => _activePointer = event.pointer);
    if (widget.enableHaptics) HapticFeedback.lightImpact();
    _emit();
    if (widget.autoRepeat) {
      _repeatTimer = Timer(widget.repeatDelay, () {
        if (!mounted || !_pressed) return;
        _emit();
        _repeatTimer = Timer.periodic(widget.repeatInterval, (_) {
          if (mounted && _pressed) _emit();
        });
      });
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    // 누른 채 위젯이 제거된 뒤에도 기존 히트 테스트 경로로 up 이벤트가 올 수 있다.
    if (!mounted || event.pointer != _activePointer) return;
    _cancelRepeat();
    setState(() => _activePointer = null);
  }

  /// 접근성(스크린리더) 활성화 시 호출 — 포인터 다운이 없으므로 햅틱 후 바로 입력한다.
  void _handleSemanticTap() {
    if (widget.enableHaptics) HapticFeedback.lightImpact();
    _emit();
  }

  String get _semanticLabel {
    final def = widget.keyDef;
    return [
      def.mainLabel,
      if (def.hasShift) 'SHIFT ${def.shiftLabel}',
      if (def.hasAlpha) 'ALPHA ${def.alphaLabel}',
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled,
      label: _semanticLabel,
      onTap: _enabled ? _handleSemanticTap : null,
      excludeSemantics: true,
      child: LayoutBuilder(builder: _buildLayout),
    );
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final bounded = constraints.hasBoundedWidth && constraints.hasBoundedHeight;
    final width = bounded
        ? constraints.maxWidth
        : CalcKeyButton.fallbackSize.width;
    final height = bounded
        ? constraints.maxHeight
        : CalcKeyButton.fallbackSize.height;

    final legendHeight = widget.showLegendBand
        ? height * CalcTheme.keyLegendHeightRatio
        : 0.0;
    final capHeight = height - legendHeight;
    final textScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: CalcTheme.keyMaxTextScaleFactor);

    final keycap = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: _Keycap(
        keyDef: widget.keyDef,
        pressed: _pressed,
        enabled: _enabled,
        fontSize:
            widget.mainLabelFontSize ??
            capHeight * CalcTheme.keyMainLabelFontRatio,
        horizontalPadding: width * CalcTheme.keyCapHorizontalPaddingRatio,
        textScaler: textScaler,
      ),
    );

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          if (widget.showLegendBand)
            SizedBox(
              height: legendHeight,
              width: width,
              child: _LegendRow(
                shiftLabel: widget.keyDef.shiftLabel,
                alphaLabel: widget.keyDef.alphaLabel,
                fontSize:
                    widget.legendFontSize ??
                    legendHeight * CalcTheme.keyLegendFontRatio,
                maxGap: width * CalcTheme.keyLegendGapMaxWidthRatio,
                textScaler: textScaler,
              ),
            ),
          SizedBox(height: capHeight, width: width, child: keycap),
        ],
      ),
    );
  }
}

/// 키캡 위 본체 영역의 SHIFT/ALPHA 각인 띠.
///
/// 두 각인이 모두 있으면 글자 수에 비례해 폭을 나눠, 짧은 쪽이 남긴 폭을 긴 쪽이 쓰게 한다.
class _LegendRow extends StatelessWidget {
  final String? shiftLabel;
  final String? alphaLabel;
  final double fontSize;
  final double maxGap;
  final TextScaler textScaler;

  const _LegendRow({
    required this.shiftLabel,
    required this.alphaLabel,
    required this.fontSize,
    required this.maxGap,
    required this.textScaler,
  });

  @override
  Widget build(BuildContext context) {
    final shift = shiftLabel;
    final alpha = alphaLabel;
    if (shift == null && alpha == null) return const SizedBox.shrink();

    Widget legend(String text, TextStyle style, Alignment alignment) {
      return Expanded(
        flex: math.max(1, text.runes.length),
        child: Align(
          alignment: alignment,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              textScaler: textScaler,
              style: style.copyWith(fontSize: fontSize),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        if (shift != null)
          legend(shift, CalcTheme.keyShiftLabelStyle, Alignment.bottomLeft),
        if (shift != null && alpha != null)
          SizedBox(
            width: math.min(fontSize * CalcTheme.keyLegendGapRatio, maxGap),
          ),
        if (alpha != null)
          legend(alpha, CalcTheme.keyAlphaLabelStyle, Alignment.bottomRight),
      ],
    );
  }
}

/// 카테고리 색과 눌림 반응을 가진 키캡 본체.
class _Keycap extends StatelessWidget {
  final CalcKeyDef keyDef;
  final bool pressed;
  final bool enabled;
  final double fontSize;
  final double horizontalPadding;
  final TextScaler textScaler;

  const _Keycap({
    required this.keyDef,
    required this.pressed,
    required this.enabled,
    required this.fontSize,
    required this.horizontalPadding,
    required this.textScaler,
  });

  @override
  Widget build(BuildContext context) {
    final category = keyDef.category;
    final background = pressed
        ? Color.alphaBlend(CalcTheme.keyPressedOverlay, category.background)
        : category.background;
    final labelColor = enabled
        ? category.foreground
        : category.foreground.withValues(
            alpha: CalcTheme.keyDisabledLabelOpacity,
          );

    // 눌리면 그림자가 사라지고 살짝 아래로 내려가 실물 키의 눌림을 흉내 낸다.
    return Transform.translate(
      offset: Offset(0, pressed ? CalcTheme.keyPressedOffset : 0),
      child: AnimatedContainer(
        key: CalcKeyButton.keycapKeyOf(keyDef.id),
        duration: CalcTheme.keyPressAnimationDuration,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(CalcTheme.keyBorderRadius),
          border: Border.all(
            color: CalcTheme.keyBorder,
            width: CalcTheme.keyBorderWidth,
          ),
          boxShadow: pressed
              ? const []
              : const [
                  BoxShadow(
                    color: CalcTheme.keyShadow,
                    blurRadius: CalcTheme.keyElevation,
                    offset: Offset(0, CalcTheme.keyElevation),
                  ),
                ],
        ),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            keyDef.mainLabel,
            maxLines: 1,
            softWrap: false,
            textScaler: textScaler,
            style: CalcTheme.keyMainLabelStyle.copyWith(
              fontSize: fontSize,
              color: labelColor,
            ),
          ),
        ),
      ),
    );
  }
}

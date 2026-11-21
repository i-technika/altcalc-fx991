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
///  │ │       CALC       │ │  ← 키캡: 카테고리 색 + 메인 라벨
///  │ └──────────────────┘ │
///  └──────────────────────┘
/// ```
/// - 크기는 부모가 정한다(그리드 셀). 글자 크기는 [CalcTheme]의 비율 상수로 계산하고,
///   긴 라벨은 [FittedBox]로 축소해 어떤 화면비에서도 넘치지 않는다.
/// - 누르는 순간 시각 반응과 [HapticFeedback.lightImpact]를 실행하고,
///   손을 뗄 때 [onPressed]를 호출한다. 키 밖으로 끌어내면 입력이 취소된다.
/// - [onPressed]가 `null`이면 비활성(반응·햅틱 없음)이다.
class CalcKeyButton extends StatefulWidget {
  /// 표시할 키 명세
  final CalcKeyDef keyDef;

  /// 키 입력 콜백. `null`이면 비활성.
  final ValueChanged<CalcKeyId>? onPressed;

  /// 햅틱 피드백 사용 여부 (설정 연동용)
  final bool enableHaptics;

  const CalcKeyButton({
    super.key,
    required this.keyDef,
    this.onPressed,
    this.enableHaptics = true,
  });

  /// 키캡 위젯 식별용 키 (테스트·골든 비교용)
  static const Key keycapKey = ValueKey('calc_key_button.keycap');

  /// 부모 제약이 무한할 때 사용하는 기본 크기 (dp)
  static const Size fallbackSize = Size(56, 64);

  @override
  State<CalcKeyButton> createState() => _CalcKeyButtonState();
}

class _CalcKeyButtonState extends State<CalcKeyButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  @override
  void didUpdateWidget(covariant CalcKeyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 눌린 상태에서 비활성으로 바뀌면 눌림 표시가 남지 않도록 해제한다.
    if (!_enabled && _pressed) _pressed = false;
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTapDown(TapDownDetails _) {
    if (!_enabled) return;
    _setPressed(true);
    if (widget.enableHaptics) HapticFeedback.lightImpact();
  }

  void _handleTap() {
    _setPressed(false);
    widget.onPressed?.call(widget.keyDef.id);
  }

  /// 접근성(스크린리더) 활성화 시 호출 — 터치 다운이 없으므로 햅틱 후 바로 입력한다.
  void _handleSemanticTap() {
    if (!_enabled) return;
    if (widget.enableHaptics) HapticFeedback.lightImpact();
    widget.onPressed?.call(widget.keyDef.id);
  }

  String get _semanticLabel {
    final def = widget.keyDef;
    return [
      def.mainLabel,
      if (def.shiftLabel != null) 'SHIFT ${def.shiftLabel}',
      if (def.alphaLabel != null) 'ALPHA ${def.alphaLabel}',
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? _handleTapDown : null,
        onTap: _enabled ? _handleTap : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        child: LayoutBuilder(builder: _buildLayout),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : CalcKeyButton.fallbackSize.width;
    final height = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : CalcKeyButton.fallbackSize.height;

    final legendHeight = height * CalcTheme.keyLegendHeightRatio;
    final capHeight = height - legendHeight;

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          SizedBox(
            height: legendHeight,
            width: width,
            child: _LegendRow(
              shiftLabel: widget.keyDef.shiftLabel,
              alphaLabel: widget.keyDef.alphaLabel,
              fontSize: legendHeight * CalcTheme.keyLegendFontRatio,
            ),
          ),
          SizedBox(
            height: capHeight,
            width: width,
            child: _Keycap(
              keyDef: widget.keyDef,
              pressed: _pressed,
              enabled: _enabled,
              fontSize: capHeight * CalcTheme.keyMainLabelFontRatio,
              horizontalPadding: width * CalcTheme.keyCapHorizontalPaddingRatio,
            ),
          ),
        ],
      ),
    );
  }
}

/// 키캡 위 본체 영역의 SHIFT/ALPHA 각인 띠.
class _LegendRow extends StatelessWidget {
  final String? shiftLabel;
  final String? alphaLabel;
  final double fontSize;

  const _LegendRow({
    required this.shiftLabel,
    required this.alphaLabel,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (shiftLabel == null && alphaLabel == null) {
      return const SizedBox.shrink();
    }
    // 시스템 글자 크기 설정과 무관하게 각인이 띠 안에 들어가도록 FittedBox로만 축소한다.
    Widget legend(String text, TextStyle style, Alignment alignment) {
      return Align(
        alignment: alignment,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            textScaler: TextScaler.noScaling,
            style: style.copyWith(fontSize: fontSize),
          ),
        ),
      );
    }

    return Row(
      children: [
        if (shiftLabel != null)
          Expanded(
            child: legend(
              shiftLabel!,
              CalcTheme.keyShiftLabelStyle,
              Alignment.bottomLeft,
            ),
          ),
        if (shiftLabel != null && alphaLabel != null)
          SizedBox(width: fontSize * 0.3),
        if (alphaLabel != null)
          Expanded(
            child: legend(
              alphaLabel!,
              CalcTheme.keyAlphaLabelStyle,
              Alignment.bottomRight,
            ),
          ),
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

  const _Keycap({
    required this.keyDef,
    required this.pressed,
    required this.enabled,
    required this.fontSize,
    required this.horizontalPadding,
  });

  static const Duration _animDuration = Duration(milliseconds: 60);

  @override
  Widget build(BuildContext context) {
    final category = keyDef.category;
    final background = pressed
        ? Color.alphaBlend(CalcTheme.keyPressedOverlay, category.background)
        : category.background;

    return AnimatedContainer(
      key: CalcKeyButton.keycapKey,
      duration: _animDuration,
      // 눌리면 그림자가 사라지고 살짝 아래로 내려가 실물 키의 눌림을 흉내 낸다.
      transform: Matrix4.translationValues(
        0,
        pressed ? CalcTheme.keyPressedOffset : 0,
        0,
      ),
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
                  color: Color(0x66000000),
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
          textScaler: TextScaler.noScaling,
          style: CalcTheme.keyMainLabelStyle.copyWith(
            fontSize: fontSize,
            // 비활성 키는 라벨을 흐리게 표시한다.
            color: enabled
                ? category.foreground
                : category.foreground.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

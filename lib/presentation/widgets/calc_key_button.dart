import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/key_definitions.dart';
import '../../core/theme/calc_theme.dart';
import '../l10n/calc_semantic_strings.dart';
import 'screen_coordinate_root.dart';

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
/// - 크기는 부모(그리드 셀)가 정한다. 제약이 무한한 축에만 [fallbackSize]의 해당 축 값을 쓴다.
/// - 글자 크기는 [CalcTheme]의 비율 상수로 계산하며, 키패드 전체의 글자 크기를 맞추려면
///   부모가 [legendFontSize]/[mainLabelFontSize]를 주입한다. 넘치는 라벨은 [FittedBox]로 축소한다.
/// - 시스템 글자 배율은 [CalcTheme.keyMaxTextScaleFactor]까지 반영하지만, 이미 폭이 꽉 찬
///   여러 글자 라벨은 [FittedBox]가 다시 줄이므로 사실상 공간이 남는 라벨(주로 한 글자)에만 효과가 있다.
///   키패드 전체를 고르게 키우려면 부모가 배율을 반영한 글자 크기를 주입한다.
/// - 눌림 이동([CalcTheme.keyPressedOffset])만큼 키캡 아래에 여유를 두어 셀 밖으로 그려지지 않는다.
///
/// ## 입력 계약
/// - 실물 키처럼 **누르는 순간** [onPressed]를 호출하고 [HapticFeedback.lightImpact]를 실행한다.
///   손가락을 미끄러뜨려도 첫 입력은 취소되지 않는다.
/// - 단, 시스템 제스처 영역([MediaQueryData.systemGestureInsets], Android 뒤로가기 등)에서 시작된
///   터치는 시스템이 가로챌 수 있으므로 **손을 뗄 때** 확정하고, 취소되거나 키 밖으로 벗어나면 버린다.
///   가장자리 판정은 화면 좌표로 한다. 실제 앱은 전역 좌표가 화면 좌표이고, 화면을 흉내 내는 곳(미리보기)은
///   [ScreenCoordinateRoot]가 원점을 알려준다. 키 위쪽에서 MediaQuery의 `size`·`systemGestureInsets`를
///   영역 기준으로 덮어쓰면 판정이 틀어지므로, 분할 배치 등에서도 View의 값을 그대로 물려준다.
/// - 한 키에서는 첫 번째 손가락만 인식한다. 마우스는 주 버튼만, 스타일러스 지우개 끝은 무시한다.
/// - 터치 영역은 기본적으로 키캡뿐이며, [extendHitAreaToLegend]이면 각인 띠까지 넓힌다.
///   [hitShape]가 있으면 그림([shape])과 별도로 버튼 상자 ∩ [hitShape]가 터치 영역이다(커서 패드, #64).
/// - 포인터를 직접 처리하므로 스크롤 컨테이너 안에 두면 스크롤 시작 터치도 입력된다.
///   키패드는 스크롤 영역 밖에 배치한다.
/// - [onRepeat]이 있으면 누르고 있는 동안 [repeatDelay] 후 [repeatInterval]마다 [onRepeat]을
///   호출한다(반복 입력에는 햅틱 없음). 손가락이 터치 영역을 벗어나면 반복을 멈춘다.
///   반복 대상 키는 [autoRepeatKeys] 참고. 지연·간격 변경은 다음 누름부터 적용된다.
/// - [onPressed]가 `null`이면 비활성이다(반응·햅틱 없음, 라벨 흐림). 누른 채 비활성이 되거나
///   [keyDef]가 다른 키로 바뀌면 눌림과 반복을 즉시 해제한다.
///
/// SHIFT/ALPHA 래치 상태는 실물처럼 LCD 상태 표시줄(S/A)로 보여주며, 키 자체에는 표시하지 않는다.
class CalcKeyButton extends StatefulWidget {
  /// 표시할 키 명세
  final CalcKeyDef keyDef;

  /// 키 입력 콜백 (누르는 순간 1회). `null`이면 비활성.
  final ValueChanged<CalcKeyId>? onPressed;

  /// 길게 누를 때의 반복 입력 콜백. `null`이면 반복하지 않는다.
  final ValueChanged<CalcKeyId>? onRepeat;

  /// 햅틱 피드백 사용 여부 (설정 연동용)
  final bool enableHaptics;

  /// 반복 입력 시작까지의 지연
  final Duration repeatDelay;

  /// 반복 입력 간격
  final Duration repeatInterval;

  /// 상단 각인 띠 표시 여부. `false`면 키캡이 셀 전체를 쓴다(커서 패드 등).
  final bool showLegendBand;

  /// 터치 영역을 각인 띠까지 넓힐지 여부 (작은 화면에서 터치 영역 확보용)
  final bool extendHitAreaToLegend;

  /// 각인 글자 크기 (dp). `null`이면 셀 높이 비율로 계산.
  final double? legendFontSize;

  /// 메인 라벨 글자 크기 (dp). `null`이면 키캡 높이 비율로 계산.
  final double? mainLabelFontSize;

  /// 키 모양 — 그림 상자 크기를 받아 그 좌표의 닫힌 경로를 돌려준다. `null`이면 사각형.
  ///
  /// 그리기를 이 경로 안으로 제한한다. [hitShape]가 없으면 누름 판정(히트 테스트)과 누른 채 이동할 때의
  /// 이탈 판정(반복 중단)도 이 경로 안으로 제한한다(커서 패드 방향 구역 등).
  /// 경로는 상자 크기나 함수가 바뀔 때만 다시 만든다.
  final Path Function(Size size)? shape;

  /// 터치 모양 — 버튼 상자(부모가 정한 크기, [hitOutset] 포함) 크기를 받아 그 좌표의 닫힌 경로를 돌려준다.
  ///
  /// 지정하면 누름 판정과 이동 이탈 판정을 버튼 상자 ∩ 이 경로로 하고, [shape]는 그리기에만 쓴다.
  /// 그려진 키보다 넓은 터치 영역을 줄 때 쓴다(커서 패드 외곽 밖·셀 여백, #64).
  /// 이때 [extendHitAreaToLegend]는 쓰지 않는다(터치 영역은 이 경로가 정한다).
  final Path Function(Size size)? hitShape;

  /// 터치 영역만 넓힌 여백 — 버튼 상자에서 이만큼 안쪽 상자(그림 상자)에 키를 그린다.
  /// [hitShape]가 있을 때만 쓸 수 있고(없으면 [EdgeInsets.zero]여야 한다) 음수일 수 없다.
  /// 상자보다 크면 키를 그리지 않고 터치 영역만 남는다.
  final EdgeInsets hitOutset;

  const CalcKeyButton({
    super.key,
    required this.keyDef,
    this.onPressed,
    this.onRepeat,
    this.enableHaptics = true,
    this.repeatDelay = defaultRepeatDelay,
    this.repeatInterval = defaultRepeatInterval,
    this.showLegendBand = true,
    this.extendHitAreaToLegend = false,
    this.legendFontSize,
    this.mainLabelFontSize,
    this.shape,
    this.hitShape,
    this.hitOutset = EdgeInsets.zero,
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

  /// 시스템 제스처 영역에서 시작되어 손을 뗄 때 확정할 누름인지 여부
  bool _deferred = false;

  Timer? _repeatTimer;

  /// 터치 영역 크기 (Listener 로컬 좌표 기준, 레이아웃마다 갱신)
  Size _hitSize = Size.zero;

  /// 버튼 좌표에서 터치 영역(Listener)의 원점 (각인 띠를 빼면 띠 높이만큼 아래)
  Offset _hitOrigin = Offset.zero;

  /// 그림 상자 크기에 맞춘 [CalcKeyButton.shape] 경로 (그림과, [CalcKeyButton.hitShape]가 없을 때의
  /// 누름·이동 이탈 판정이 같은 인스턴스를 쓴다)
  final _PathCache _shapePath = _PathCache();

  /// 버튼 상자 크기에 맞춘 [CalcKeyButton.hitShape] 경로 (누름·이동 이탈 판정이 같은 인스턴스를 쓴다)
  final _PathCache _hitPath = _PathCache();

  /// Listener 로컬 좌표가 터치 영역 안인지 판정한다.
  /// [CalcKeyButton.hitShape]가 있으면 버튼 상자 ∩ 터치 모양, 없으면 터치 사각형 ∩ 키 모양이다.
  bool _hitAreaContains(Offset localPosition) {
    if (!(Offset.zero & _hitSize).contains(localPosition)) return false;
    final hit = _hitPath.path;
    if (hit != null) return hit.contains(localPosition);
    final path = _shapePath.path;
    return path == null || path.contains(localPosition + _hitOrigin);
  }

  bool get _enabled => widget.onPressed != null;
  bool get _pressed => _activePointer != null;

  @override
  void didUpdateWidget(covariant CalcKeyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pressed && (!_enabled || oldWidget.keyDef.id != widget.keyDef.id)) {
      // 누른 채 비활성이 되거나 다른 키로 바뀌면 눌림과 반복을 즉시 해제한다.
      _release();
    } else if (widget.onRepeat == null) {
      _cancelRepeat();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // 핫 리로드로 모양 상수가 바뀌어도 모양 함수는 같은 인스턴스라 캐시가 남는다 — 비워서 다시 만든다.
    _shapePath.clear();
    _hitPath.clear();
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

  /// 눌림 상태를 해제한다 (setState 없이 — 호출부에서 필요 시 감싼다).
  void _release() {
    _cancelRepeat();
    _activePointer = null;
    _deferred = false;
  }

  void _commitPress() {
    if (widget.enableHaptics) HapticFeedback.lightImpact();
    widget.onPressed?.call(widget.keyDef.id);
  }

  void _startRepeat() {
    if (widget.onRepeat == null) return;
    _repeatTimer = Timer(widget.repeatDelay, () {
      if (!mounted || !_pressed) return;
      widget.onRepeat?.call(widget.keyDef.id);
      _repeatTimer = Timer.periodic(widget.repeatInterval, (_) {
        if (mounted && _pressed) widget.onRepeat?.call(widget.keyDef.id);
      });
    });
  }

  /// 마우스 보조 버튼, 스타일러스 지우개 끝 등 입력으로 취급하지 않을 포인터인지 판정한다.
  bool _isIgnoredPointer(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.invertedStylus) return true;
    return (event.buttons & kPrimaryButton) == 0;
  }

  /// 전역 좌표가 시스템 제스처 영역(화면 가장자리) 안인지 판정한다.
  ///
  /// 인셋과 화면 크기는 MediaQuery가 정의한 화면 영역의 좌표이므로, 터치 좌표도
  /// [ScreenCoordinateRoot.globalToScreen]으로 그 영역의 로컬 좌표로 바꿔 비교한다(#50).
  /// 화면이 원점이 아닌 곳에 있거나 축소된 경우(개발용 미리보기)에도 판정이 맞는다.
  bool _inSystemGestureZone(Offset globalPosition) {
    final insets = MediaQuery.systemGestureInsetsOf(context);
    if (insets == EdgeInsets.zero) return false;
    final screen = MediaQuery.sizeOf(context);
    final p = ScreenCoordinateRoot.globalToScreen(context, globalPosition);
    return p.dx < insets.left ||
        p.dx > screen.width - insets.right ||
        p.dy < insets.top ||
        p.dy > screen.height - insets.bottom;
  }

  void _handlePointerDown(PointerDownEvent event) {
    // 비활성, 이미 다른 손가락이 누르는 중, 입력으로 취급하지 않는 포인터는 무시한다.
    if (!_enabled || _pressed || _isIgnoredPointer(event)) return;
    final deferred = _inSystemGestureZone(event.position);
    setState(() {
      _activePointer = event.pointer;
      _deferred = deferred;
    });
    if (deferred) return; // 손을 뗄 때 확정
    _commitPress();
    _startRepeat();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!mounted || event.pointer != _activePointer) return;
    if (_hitAreaContains(event.localPosition)) return;
    if (_deferred) {
      // 시스템 제스처일 가능성이 높으므로 확정하지 않고 버린다.
      setState(_release);
    } else {
      _cancelRepeat();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    // 누른 채 위젯이 제거된 뒤에도 기존 히트 테스트 경로로 up 이벤트가 올 수 있다.
    if (!mounted || event.pointer != _activePointer) return;
    final commit = _deferred;
    setState(_release);
    if (commit) _commitPress();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!mounted || event.pointer != _activePointer) return;
    setState(_release);
  }

  /// 접근성(스크린리더) 활성화 시 호출 — 포인터 다운이 없으므로 햅틱 후 바로 입력한다.
  void _handleSemanticTap() => _commitPress();

  @override
  Widget build(BuildContext context) {
    final strings = CalcSemanticStrings.of(context);
    return Semantics(
      button: true,
      enabled: _enabled,
      // 표시 각인(`sin⁻¹`, `∫◻◻◼` 등) 대신 기능을 읽는 음성 라벨 (#20).
      // 메인 기능은 라벨, SHIFT·ALPHA 기능은 힌트로 나눠 키를 훑을 때 짧게 읽히게 한다.
      label: strings.keyButton(widget.keyDef.id),
      hint: strings.keyButtonHint(widget.keyDef.id),
      onTap: _enabled ? _handleSemanticTap : null,
      excludeSemantics: true,
      child: LayoutBuilder(builder: _buildLayout),
    );
  }

  Widget _wrapHitArea(Widget child) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: child,
    );
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    assert(
      widget.hitShape != null || widget.hitOutset == EdgeInsets.zero,
      'hitOutset은 hitShape와 함께 써야 한다 (터치 영역을 정할 경로가 없다)',
    );
    assert(widget.hitOutset.isNonNegative, 'hitOutset은 음수일 수 없다');
    assert(
      widget.hitShape == null || !widget.extendHitAreaToLegend,
      'hitShape가 있으면 터치 영역은 그 경로가 정한다 — extendHitAreaToLegend와 함께 쓰지 않는다',
    );
    final outer = constraints.constrain(
      Size(
        constraints.hasBoundedWidth
            ? constraints.maxWidth
            : CalcKeyButton.fallbackSize.width,
        constraints.hasBoundedHeight
            ? constraints.maxHeight
            : CalcKeyButton.fallbackSize.height,
      ),
    );
    final hitPath = _hitPath.resolve(widget.hitShape, outer);
    final hitMode = hitPath != null;
    final outset = hitMode ? widget.hitOutset : EdgeInsets.zero;
    // 그림 상자 = 버튼 상자에서 터치 여백을 뺀 안쪽 (여백이 상자보다 크면 0 — 아래에서 그리지 않는다)
    final width = math.max(0.0, outer.width - outset.horizontal);
    final height = math.max(0.0, outer.height - outset.vertical);

    final legendHeight = widget.showLegendBand
        ? height * CalcTheme.keyLegendHeightRatio
        : 0.0;
    final capHeight = height - legendHeight;
    // 눌림 이동이 셀 밖으로 나가지 않도록 키캡 아래에 이동량만큼 여유를 둔다.
    final pressRoom = math.min(CalcTheme.keyPressedOffset, capHeight);
    final textScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: CalcTheme.keyMaxTextScaleFactor);

    final shapePath = _shapePath.resolve(widget.shape, Size(width, height));
    final extendToLegend = !hitMode && widget.extendHitAreaToLegend;
    _hitSize = hitMode
        ? outer
        : extendToLegend
        ? Size(width, height)
        : Size(width, capHeight);
    _hitOrigin = hitMode || extendToLegend
        ? Offset.zero
        : Offset(0, legendHeight);

    Widget keycap = Padding(
      padding: EdgeInsets.only(bottom: pressRoom),
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
    if (!hitMode && !extendToLegend) keycap = _wrapHitArea(keycap);

    final column = Column(
      children: [
        if (widget.showLegendBand)
          SizedBox(
            height: legendHeight,
            width: width,
            child: _LegendRow(
              shiftLabel: widget.keyDef.shiftLabel,
              alphaLabel: widget.keyDef.alphaLabel,
              width: width,
              fontSize:
                  widget.legendFontSize ??
                  legendHeight * CalcTheme.keyLegendFontRatio,
              maxGap: width * CalcTheme.keyLegendGapMaxWidthRatio,
              textScaler: textScaler,
            ),
          ),
        SizedBox(height: capHeight, width: width, child: keycap),
      ],
    );

    final body = SizedBox(
      width: width,
      height: height,
      child: extendToLegend ? _wrapHitArea(column) : column,
    );
    // ClipPath는 그림과 히트 테스트를 함께 경로 안으로 제한한다.
    final clipped = shapePath == null
        ? body
        : ClipPath(clipper: _ShapeClipper(shapePath), child: body);
    if (!hitMode) return clipped;
    // 그림 상자가 비면 키를 그리지 않는다(0 크기 글자는 레이아웃 assert를 낸다). 터치 영역은 남는다.
    final drawn = width > 0 && height > 0 ? clipped : const SizedBox.shrink();
    // 터치 모양이 따로 있으면: 버튼 상자 전체를 받는 Listener를 터치 경로로 거르고,
    // 그림은 터치 여백 안쪽에 그린다(그림 클립은 Listener 안이라 터치 영역을 줄이지 않는다).
    return _HitTestPath(
      path: hitPath,
      child: _wrapHitArea(
        SizedBox.fromSize(
          size: outer,
          child: Padding(padding: outset, child: drawn),
        ),
      ),
    );
  }
}

/// 모양 함수와 상자 크기로 만든 경로 캐시 — 둘 다 같으면 다시 만들지 않는다
/// (포인터 이동마다 경로를 새로 만들지 않도록).
class _PathCache {
  Path? path;
  Size? _size;
  Path Function(Size size)? _source;

  /// [source]로 [size] 상자의 경로를 돌려준다 (`source`가 없으면 `null`).
  Path? resolve(Path Function(Size size)? source, Size size) {
    if (source == null) {
      clear();
      return null;
    }
    if (!identical(source, _source) || size != _size) {
      path = source(size);
      _source = source;
      _size = size;
    }
    return path;
  }

  void clear() {
    path = null;
    _source = null;
    _size = null;
  }
}

/// 히트 테스트만 [path] 안으로 제한한다 (그리기·레이아웃에는 영향 없음).
class _HitTestPath extends SingleChildRenderObjectWidget {
  final Path path;

  const _HitTestPath({required this.path, super.child});

  @override
  _RenderHitTestPath createRenderObject(BuildContext context) =>
      _RenderHitTestPath(path);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHitTestPath renderObject,
  ) {
    renderObject.path = path;
  }
}

class _RenderHitTestPath extends RenderProxyBox {
  _RenderHitTestPath(this.path);

  Path path;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!path.contains(position)) return false;
    return super.hitTest(result, position: position);
  }
}

/// [CalcKeyButton.shape]로 만든 경로를 적용하는 클리퍼 (경로는 버튼 상자 크기에 맞춰 이미 만들어져 있다)
class _ShapeClipper extends CustomClipper<Path> {
  final Path path;

  const _ShapeClipper(this.path);

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_ShapeClipper oldClipper) =>
      !identical(oldClipper.path, path);
}

/// 키캡 위 본체 영역의 SHIFT/ALPHA 각인 띠.
///
/// 두 각인이 모두 있으면 글자 수에 비례해 폭을 나눠, 넘치면 함께 같은 비율로 줄어든다.
/// 단, 짧은 쪽이 [CalcTheme.keyLegendPriorityMaxRunes]글자 이하(변수 이름 `A`~`F`, `y` 등)면
/// 짧은 쪽이 자연 폭을 먼저(띠 폭의 절반까지) 쓰고 긴 쪽이 남은 폭을 써서, 한 글자 각인은
/// 긴 이웃 때문에 줄어들지 않는다. (`KeypadMetrics`의 폭 측정도 같은 규칙이다.)
class _LegendRow extends StatelessWidget {
  final String? shiftLabel;
  final String? alphaLabel;
  final double width;
  final double fontSize;
  final double maxGap;
  final TextScaler textScaler;

  const _LegendRow({
    required this.shiftLabel,
    required this.alphaLabel,
    required this.width,
    required this.fontSize,
    required this.maxGap,
    required this.textScaler,
  });

  @override
  Widget build(BuildContext context) {
    final shift = shiftLabel;
    final alpha = alphaLabel;
    if (shift == null && alpha == null) return const SizedBox.shrink();

    final gap = shift != null && alpha != null
        ? math.min(fontSize * CalcTheme.keyLegendGapRatio, maxGap)
        : 0.0;
    // 자연 폭 우선 배분을 받을 짧은 각인 (둘 다 있고, 짧은 쪽이 충분히 짧을 때만)
    final shiftRunes = shift?.runes.length ?? 0;
    final alphaRunes = alpha?.runes.length ?? 0;
    final both = shift != null && alpha != null;
    final shiftIsShort =
        both &&
        shiftRunes <= alphaRunes &&
        shiftRunes <= CalcTheme.keyLegendPriorityMaxRunes;
    final alphaIsShort =
        both &&
        alphaRunes < shiftRunes &&
        alphaRunes <= CalcTheme.keyLegendPriorityMaxRunes;
    final shortMaxWidth = math.max(0.0, (width - gap) / 2);

    Widget legend(
      String text,
      TextStyle style,
      Alignment alignment, {
      required bool short,
      required bool priorityLayout,
    }) {
      final label = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          textScaler: textScaler,
          style: style.copyWith(fontSize: fontSize),
          strutStyle: _labelStrut(style.copyWith(fontSize: fontSize)),
        ),
      );
      if (short) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: shortMaxWidth),
          child: Align(alignment: alignment, widthFactor: 1, child: label),
        );
      }
      return Expanded(
        // 우선 배분이면 긴 쪽이 남은 폭 전부, 아니면 글자 수 비례
        flex: priorityLayout ? 1 : math.max(1, text.runes.length),
        child: Align(alignment: alignment, child: label),
      );
    }

    final priority = shiftIsShort || alphaIsShort;
    return Row(
      children: [
        if (shift != null)
          legend(
            shift,
            CalcTheme.keyShiftLabelStyle,
            Alignment.bottomLeft,
            short: shiftIsShort,
            priorityLayout: priority,
          ),
        if (both) SizedBox(width: gap),
        if (alpha != null)
          legend(
            alpha,
            CalcTheme.keyAlphaLabelStyle,
            Alignment.bottomRight,
            short: alphaIsShort,
            priorityLayout: priority,
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
        ? category.pressedBackground
        : category.background;
    final labelColor = enabled
        ? category.foreground
        : category.foreground.withValues(
            alpha: CalcTheme.keyDisabledLabelOpacity,
          );

    // 눌리면 그림자가 사라지고 살짝 아래로 내려가 실물 키의 눌림을 흉내 내며, 배경 명도와 테두리가 바뀐다(#22).
    // 누를 때는 즉시 바꾸고 뗄 때만 애니메이션한다 — 짧은 탭에서도 눌림 색이 끝까지 보이게 한다.
    return Transform.translate(
      offset: Offset(0, pressed ? CalcTheme.keyPressedOffset : 0),
      child: AnimatedContainer(
        key: CalcKeyButton.keycapKeyOf(keyDef.id),
        duration: pressed ? Duration.zero : CalcTheme.keyPressAnimationDuration,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(CalcTheme.keyBorderRadius),
          border: Border.all(
            color: pressed ? CalcTheme.keyPressedBorder : CalcTheme.keyBorder,
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
            strutStyle: _labelStrut(
              CalcTheme.keyMainLabelStyle.copyWith(fontSize: fontSize),
            ),
          ),
        ),
      ),
    );
  }
}

/// 키 라벨 줄 높이를 기본 글꼴(Noto Sans Mono) 기준 `fontSize × height`로 고정하는 strut.
///
/// 대체 글꼴(Noto Sans Math — `∑`·`∛`·`∫`)은 descent가 더 깊어(423 vs 293/1000), 그대로 두면 그 글자가
/// 섞인 라벨만 줄이 약 7% 높아진다(#16 실측: 20 → 21dp). 키패드 글자 크기 계산(`KeypadMetrics`의
/// `fitFontSizeToHeight`)이 전제하는 줄 높이와 맞추고, 라벨 사이 기준선을 같게 한다.
///
/// strut는 줄 상자만 고정하고 잉크(글리프 모양)는 자르지 않는다. `∛`는 줄 상자 위로 약 0.27em,
/// `∫`·`∑`는 아래로 약 0.025em 넘쳐 그려진다(#16 리뷰 R2 실측). 각인은 아래 정렬이라 `∛◼`의 윗부분이
/// 키 사이 간격 쪽으로 나오며, 실기기에서 위 행 키캡에 닿지 않는지 확인한다(에픽 #1 실기기 점검).
StrutStyle _labelStrut(TextStyle style) =>
    StrutStyle.fromTextStyle(style, forceStrutHeight: true);

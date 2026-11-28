import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/key_definitions.dart';
import '../../core/layout/layout_log.dart';
import '../../core/theme/calc_theme.dart';
import '../l10n/calc_semantic_strings.dart';
import 'focus_ring.dart';
import 'key_legend_view.dart';
import 'round_key_face.dart';
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
/// 원형 버튼 키([KeyFace.roundButton] — SHIFT·ALPHA·MENU·ON 자리의 설정 키, #190·#156)는 키캡 자리 가운데에 원형 은색
/// 버튼([RoundKeyFace])을 그리고 버튼 면에는 글자를 쓰지 않는다. 메인 각인은 실물처럼 버튼 위 본체(각인 띠 가운데)에
/// 인쇄한다(SHIFT 금색·ALPHA 자홍색·나머지 흰색 — [CalcPalette.bodyPrintOf]):
/// ```
///  ┌──────────────────────┐
///  │        SETUP         │  ← 각인 띠: 메인 각인(흰색, 가운데)
///  │         (◉)          │  ← 원형 버튼 (터치 영역은 셀 전체)
///  └──────────────────────┘
/// ```
///
/// ## 크기 계약
/// - 크기는 부모(그리드 셀)가 정한다. 제약이 무한한 축에만 [fallbackSize]의 해당 축 값을 쓴다.
/// - 글자 크기는 [CalcTheme]의 비율 상수로 계산하며(상한은 없다 — #264, 키가 커지면 글자도 실물 비율로 커진다),
///   키패드 전체의 글자 크기를 맞추려면 부모가 [legendFontSize]/[mainLabelFontSize]를 주입한다. 넘치는 라벨은
///   [FittedBox]로 축소한다.
/// - 시스템 글자 배율은 [CalcTheme.keyMaxTextScaleFactor]까지 반영하지만, 이미 폭이 꽉 찬
///   여러 글자 라벨은 [FittedBox]가 다시 줄이므로 사실상 공간이 남는 라벨(주로 한 글자)에만 효과가 있다.
///   키패드 전체를 고르게 키우려면 부모가 배율을 반영한 글자 크기를 주입한다.
/// - 눌림 이동([CalcTheme.keyPressedOffset])만큼 키캡 아래에 여유를 두어 셀 밖으로 그려지지 않는다. 키캡 옆면
///   ([CalcTheme.keyCapSideDepth], #156)도 이 여유에 그린다. 그림자는 셀 아래 키 사이 간격으로 조금 번질 수 있다.
///
/// ## 외관 (#156)
/// 키캡은 카테고리 색 위에 윗면 광택·아래 옆면·그림자를 더해 실물처럼 입체로 그린다([CalcTheme] "키캡 입체감" 절).
/// 모서리 반경은 키 종류마다 다르다(함수부는 둥글게, 숫자부는 덜 둥글게). 고대비 모드에서는 광택·옆면을 그리지 않는다
/// ([CalcPalette.drawsRelief]).
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
/// - 터치 영역은 기본적으로 각인 띠 아래 키캡 줄의 셀 폭 전체다 — 그린 키캡이 셀보다 좁아도([keycapMaxAspectRatio], #220)
///   키캡 옆 빈 곳까지 그 키다. [extendHitAreaToLegend]이면 각인 띠까지 넓힌다. 원형 버튼 키는 그린 버튼이
///   작아도 늘 셀 전체(각인 띠 포함)가 터치 영역이다(#190). 이렇게 셀 전체로 넓힌 키는 셀 바깥의 키 사이 간격 몫
///   ([gapInsets])까지 터치·스크린리더 영역이다(#236).
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
///
/// ## 키보드 (#190)
/// [focusable]이면 키보드 포커스를 받고, 포커스가 있을 때 Enter·Space(앱 기본 단축키의 활성화 동작)로 누른 것과 같이
/// [onPressed]를 부른다. 포커스 테두리는 [FocusRing]이 키캡(원형 버튼은 고리) 모양으로 그린다. 계산기 키의 하드웨어
/// 키보드 입력은 #39에서 정하므로 지금은 설정 키(ON)만 포커스를 받는다 — 없어진 설정 버튼의 키보드 경로(#106)를
/// 잇는다. 비활성 키는 포커스를 받지 않는다.
///
/// 색은 기기의 고대비 설정에 맞는 [CalcPalette]에서 가져온다(#54).
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

  /// 각인 띠 높이 (dp). `null`이면 셀 높이 × [CalcTheme.keyLegendHeightRatio]이고, 셀보다 높으면 셀 높이에서 멈춘다.
  /// 키패드는 모든 구역에 함수부 띠 높이(`KeypadMetrics.legendBandHeight`)를 준다 — 숫자부 셀이 높은 몫은 키캡이 받는다(#220).
  final double? legendHeight;

  /// 키캡 위 각인(SHIFT·ALPHA 각인, 원형 버튼 위 인쇄)의 줄 상자를 각인 띠 아래끝에서 올리는 거리 (dp, #264 — 실물은 각인이
  /// 키에 붙어 있지 않다, [CalcTheme] "글자 크기 실물 대조 (#264)" 절). 키패드가 모든 키에 같은 값을 준다
  /// (`KeypadMetrics.legendBaseLift` — 각인 기준선이 키캡 위끝에서 `legendBaselineGap`만큼 떨어지는 거리). 0이면 줄 상자를
  /// 띠 아래끝에 붙인다(기준선은 줄 상자 깊이만큼 위). 올린 각인은 띠 위끝을 넘어 셀 위쪽 간격 몫([gapInsets]의 위)까지
  /// 쓸 수 있다. 한 줄 아래로 넘치는 각인(#260)은 여기서 더 올리며 간격의 나머지 절반까지 쓸 수 있고, 그보다 위로는 가지
  /// 않는다(각인마다 그 여유까지만 올린다).
  final double legendBaseLift;

  /// 그린 키캡의 가로/세로 비 상한 (#220). 키캡이 이보다 납작하면 셀 가운데에 폭을 줄여 그린다
  /// ([keyCapFaceWidth] — 셀 폭의 [CalcTheme.keyCapMinWidthRatio] 아래로는 줄이지 않는다). 터치 영역은 셀 폭 그대로다.
  /// `null`이면 셀 폭 전체에 그린다. 원형 버튼과 모양([shape])이 있는 키에는 쓰지 않는다.
  final double? keycapMaxAspectRatio;

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

  /// 메인 라벨 자리에서 뺄 여백 — 키캡(그림 상자) 안에서 이만큼 뺀 나머지의 가운데에 라벨을 놓는다.
  /// 라벨이 그 나머지보다 크면 줄여 그리고, 남는 자리가 없으면 그리지 않는다. 키캡 일부가 다른 그림에 덮이는 키에 쓴다.
  /// 예: 커서 패드 방향 키는 가운데 쪽 허브만큼 뺀다(#65). 음수일 수 없다.
  final EdgeInsets labelInsets;

  /// 키보드 포커스를 받을지 (위 "키보드" 절)
  final bool focusable;

  /// 셀 바깥에서 이 키가 맡는 키 사이 간격 몫 (#236) — 키패드는 이웃 키와의 간격 절반씩을 셀 둘레 여백으로 두고 그 값을
  /// 넘긴다. 버튼 상자(셀)와 그림은 그대로이고, 터치 영역을 셀 전체로 넓힌 키([extendHitAreaToLegend], 원형 버튼)만
  /// 누름 판정과 스크린리더 영역(의미 노드 경계 — 접근성 검사기가 터치 대상 크기로 재는 상자)을 이만큼 바깥으로 넓힌다.
  /// - 목적: 키캡이 48dp보다 낮아 셀 전체를 터치 영역으로 쓰는 작은 화면에서도 터치 높이를 늘린다. 셀이 48dp에 못
  ///   미쳐도 키 사이 간격(폰 세로에서 약 5.6~8.3dp)을 더하면 키패드가 충분히 높은 폰에서 48dp를 넘는다(Accessibility
  ///   Scanner 지적, #236 — 기준과 실측표는 [CalcTheme.keyMinTouchTargetHeight]).
  /// - 간격을 누르면 가장 가까운 키가 눌린다(예전에는 아무 키도 눌리지 않았다). 이웃 키의 몫과 겹치지 않는다 — 키패드가
  ///   간격을 절반씩 나누기 때문이다.
  /// - 셀 전체로 넓히지 않는 키(키캡이 [CalcTheme.keyMinTouchTargetHeight] 이상)는 키캡 줄만 터치 영역이다(이 값을 쓰지 않음).
  /// - [hitShape]가 있는 키(커서 패드 방향 키)는 이 여백의 누름을 감싼 쪽(커서 패드의 [GapSemantics])이 버튼 상자 가장자리로 당겨
  ///   넘긴다. 이 키는 누른 채 이동할 때의 이탈 판정만 같은 규칙(여백 안의 점은 상자 가장자리로 당겨 터치 경로로 판정)으로
  ///   한다. 의미 노드는 넓히지 않는다(커서 패드가 방향별 노드를 따로 둔다).
  /// 음수일 수 없다.
  final EdgeInsets gapInsets;

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
    this.legendHeight,
    this.legendBaseLift = 0,
    this.keycapMaxAspectRatio,
    this.shape,
    this.hitShape,
    this.hitOutset = EdgeInsets.zero,
    this.labelInsets = EdgeInsets.zero,
    this.focusable = false,
    this.gapInsets = EdgeInsets.zero,
  });

  /// 셀 전체(각인 띠 포함)가 터치 영역인지 — [extendHitAreaToLegend]이거나 원형 버튼이고, 터치 모양([hitShape])이 없다.
  /// 이때만 [gapInsets]까지 넓힌다.
  bool get hitsWholeCell =>
      hitShape == null &&
      (extendHitAreaToLegend ||
          (keyDef.face == KeyFace.roundButton && showLegendBand));

  /// 터치·스크린리더 영역이 셀 밖으로 넓어지는 여백 — [hitsWholeCell]이면 [gapInsets], 아니면 없음.
  /// 테스트가 그린 키의 터치 영역을 같은 규칙으로 잰다.
  EdgeInsets get hitGapInsets => hitsWholeCell ? gapInsets : EdgeInsets.zero;

  /// 기본 반복 시작 지연
  static const Duration defaultRepeatDelay = Duration(milliseconds: 500);

  /// 기본 반복 간격
  static const Duration defaultRepeatInterval = Duration(milliseconds: 100);

  /// 부모 제약이 무한할 때 사용하는 기본 크기 (dp)
  static const Size fallbackSize = Size(56, 64);

  /// [id] 키의 키캡 위젯 식별용 키 (화면 테스트에서 특정 키캡을 찾을 때 사용)
  static Key keycapKeyOf(CalcKeyId id) => ValueKey(('calc_keycap', id));

  /// 그림 상자 높이 [height]에서 이 키의 각인 띠 높이 (dp) — [showLegendBand]가 아니면 0, [legendHeight]가 없으면
  /// [height] × [CalcTheme.keyLegendHeightRatio]이고, [height]를 넘지 않는다. 키캡(터치 영역을 띠까지 넓히지 않을 때의
  /// 터치 높이)은 [height]에서 이 값을 뺀 높이다 — 테스트가 그린 키의 터치 높이를 같은 규칙으로 잰다.
  double legendBandHeightFor(double height) {
    if (!showLegendBand) return 0.0;
    final h = math.max(0.0, height);
    return math.min(
      h,
      math.max(0.0, legendHeight ?? h * CalcTheme.keyLegendHeightRatio),
    );
  }

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

  /// 터치 영역이 Listener 상자 밖으로 넓어지는 여백 (#236 — 키 사이 간격 몫, [CalcKeyButton.hitGapInsets])
  EdgeInsets _hitGap = EdgeInsets.zero;

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
    if (!_hitGap.inflateRect(Offset.zero & _hitSize).contains(localPosition)) {
      return false;
    }
    final hit = _hitPath.path;
    // 간격 몫(#236)의 점은 버튼 상자 가장자리로 당겨 터치 경로로 판정한다 (커서 패드의 [GapSemantics]가 누름을 넘기는 규칙과 같다).
    if (hit != null) return hit.contains(clampIntoBox(localPosition, _hitSize));
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
      _logRelease(key: oldWidget.keyDef.id);
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
    if (_pressed) {
      _logRelease(key: widget.keyDef.id);
    }
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

  /// 진단 로그 (#118) — 진단 빌드에서만 남는다([LayoutLog.keyInput]). [at]은 전역 좌표다.
  /// 꺼져 있으면 좌표 변환도 하지 않는다.
  void _log(KeyInputEvent event, {required Offset at}) {
    if (!LayoutLog.enabled) return;
    LayoutLog.keyInput(
      event,
      key: widget.keyDef.id.name,
      at: ScreenCoordinateRoot.globalToScreen(context, at),
    );
  }

  /// 좌표 없는 진단 로그 — 위젯 쪽 사정으로 눌림이 끝날 때(dispose에서도 부르므로 context를 쓰지 않는다).
  /// [key]는 누르던 키다(다른 키로 바뀐 경우 옛 키).
  void _logRelease({required CalcKeyId key}) {
    if (!LayoutLog.enabled) return;
    LayoutLog.keyInput(
      _deferred
          ? KeyInputEvent.releasedDeferred
          : KeyInputEvent.releasedAfterPress,
      key: key.name,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    // 비활성, 이미 다른 손가락이 누르는 중, 입력으로 취급하지 않는 포인터는 무시한다.
    if (!_enabled || _pressed || _isIgnoredPointer(event)) return;
    final deferred = _inSystemGestureZone(event.position);
    setState(() {
      _activePointer = event.pointer;
      _deferred = deferred;
    });
    _log(
      deferred ? KeyInputEvent.deferred : KeyInputEvent.pressed,
      at: event.position,
    );
    if (deferred) return; // 손을 뗄 때 확정
    _commitPress();
    _startRepeat();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!mounted || event.pointer != _activePointer) return;
    if (_hitAreaContains(event.localPosition)) return;
    if (_deferred) {
      // 시스템 제스처일 가능성이 높으므로 확정하지 않고 버린다.
      _log(KeyInputEvent.discardedMovedOut, at: event.position);
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
    if (commit) {
      _log(KeyInputEvent.committedOnRelease, at: event.position);
      _commitPress();
    } else {
      _log(KeyInputEvent.liftedAfterPress, at: event.position);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!mounted || event.pointer != _activePointer) return;
    _log(
      _deferred
          ? KeyInputEvent.cancelledDeferred
          : KeyInputEvent.cancelledAfterPress,
      at: event.position,
    );
    setState(_release);
  }

  /// 접근성(스크린리더) 활성화 시 호출 — 포인터 다운이 없으므로 햅틱 후 바로 입력한다.
  void _handleSemanticTap() => _commitPress();

  /// 키보드 활성화(Enter·Space)로 누름 — 스크린리더 활성화와 같이 바로 입력한다.
  late final Map<Type, Action<Intent>> _keyboardActions = {
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) => _activateByKeyboard(),
    ),
    ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
      onInvoke: (_) => _activateByKeyboard(),
    ),
  };

  /// 키보드 포커스를 가졌는지 ([CalcKeyButton.focusable]일 때만) — 스크린리더에 포커스 상태로 알린다.
  bool _focused = false;

  Object? _activateByKeyboard() {
    if (_enabled) _commitPress();
    return null;
  }

  /// [CalcKeyButton.focusable]이면 [keycap]에 포커스 노드·활성화 동작·포커스 테두리를 씌운다. 포커스 노드의 영역이
  /// 키캡(원형 버튼은 고리를 품은 자리)이라 테두리가 그 모양에 맞는다.
  /// 사각 키캡의 포커스 테두리는 그린 키캡과 같은 모서리 반경([cornerRadius], #156)을 쓴다.
  Widget _wrapFocus(
    Widget keycap, {
    required bool round,
    required double cornerRadius,
  }) {
    if (!widget.focusable) return keycap;
    return FocusRing(
      shape: round
          ? const CircleBorder()
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(cornerRadius)),
            ),
      child: Actions(
        actions: _keyboardActions,
        child: Focus(
          canRequestFocus: _enabled,
          onFocusChange: (focused) {
            if (focused != _focused) setState(() => _focused = focused);
          },
          // 키 버튼의 시맨틱은 바깥 Semantics 하나다(포커스 상태도 그쪽에 싣는다).
          includeSemantics: false,
          child: keycap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = CalcSemanticStrings.of(context);
    final focusable = widget.focusable && _enabled;
    final gap = widget.hitGapInsets;
    _hitGap = widget.hitShape != null ? widget.gapInsets : gap;
    // 터치 영역을 셀 밖 간격 몫까지 넓히는 키는 누름 판정과 의미 노드 경계를 함께 넓힌다 (#236, [GapSemantics]).
    return GapSemantics(
      gap: gap,
      excludeSemantics: true,
      properties: SemanticsProperties(
        button: true,
        enabled: _enabled,
        // 키보드 포커스를 받는 키(설정 키, #190)는 포커스를 받을 수 있는지와 지금 포커스 상태를 알린다(스크린리더 포커스로
        // 입력 포커스를 옮기는 동작 `onFocus`는 싣지 않는다 — 활성화는 탭 동작으로 한다).
        focused: focusable ? _focused : null,
        // 표시 각인(`sin⁻¹`, `∫◻◻◼` 등) 대신 기능을 읽는 음성 라벨 (#20).
        // 메인 기능은 라벨, SHIFT·ALPHA 기능은 힌트로 나눠 키를 훑을 때 짧게 읽히게 한다.
        label: strings.keyButton(widget.keyDef.id),
        hint: strings.keyButtonHint(widget.keyDef.id),
        onTap: _enabled ? _handleSemanticTap : null,
      ),
      // 키 하나를 따로 그리는 층으로 둔다 (#156) — 키캡에 그림자·옆면·광택을 더해 그리기가 무거워졌으므로, 키를 누르고 뗄
      // 때 이 키만 다시 그리고 이웃 키·본체 바탕은 다시 그리지 않는다.
      child: RepaintBoundary(child: LayoutBuilder(builder: _buildLayout)),
    );
  }

  /// 키캡을 셀 가운데에 [faceWidth] 폭(#220 — 셀 폭 이하)으로 둔다. 셀 폭과 같아도 늘 같은 위젯으로 감싼다 — 창 크기가
  /// 바뀌어 키캡 폭이 셀 폭 문턱을 넘나들 때 위젯 트리가 바뀌면 키캡의 애니메이션·포커스 상태가 다시 만들어진다(#220 R1).
  static Widget _centerFace({
    required double faceWidth,
    required Widget child,
  }) => Center(
    child: SizedBox(width: faceWidth, child: child),
  );

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
    assert(widget.labelInsets.isNonNegative, 'labelInsets는 음수일 수 없다');
    assert(widget.gapInsets.isNonNegative, 'gapInsets는 음수일 수 없다');
    assert(
      widget.shape == null ||
          widget.hitShape != null ||
          widget.hitGapInsets == EdgeInsets.zero,
      '모양(shape)이 있는 키는 간격 몫(gapInsets)까지 터치를 넓히지 않는다 — 당긴 점이 모양 밖일 수 있다',
    );
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

    final legendHeight = widget.legendBandHeightFor(height);
    final capHeight = height - legendHeight;
    // 눌림 이동이 셀 밖으로 나가지 않도록 키캡 아래에 이동량만큼 여유를 둔다.
    final pressRoom = math.min(CalcTheme.keyPressedOffset, capHeight);
    final textScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: CalcTheme.keyMaxTextScaleFactor);

    final shapePath = _shapePath.resolve(widget.shape, Size(width, height));
    // 원형 버튼은 그린 버튼이 작아 터치 영역을 늘 셀 전체로 둔다 (#190).
    final round = widget.keyDef.face == KeyFace.roundButton;
    // 셀 전체 터치 규칙은 위젯 쪽 판정([CalcKeyButton.hitsWholeCell])과 같게 쓴다 — 간격 몫(#236)을 줄지와 어긋나지 않게.
    final extendToLegend = !hitMode && widget.hitsWholeCell;
    _hitSize = hitMode
        ? outer
        : extendToLegend
        ? Size(width, height)
        : Size(width, capHeight);
    _hitOrigin = hitMode || extendToLegend
        ? Offset.zero
        : Offset(0, legendHeight);

    final cornerRadius = keyCapCornerRadius(
      widget.keyDef.category,
      capHeight - pressRoom,
    );
    // 그린 키캡 폭 (#220) — 셀 가운데에 가로/세로 비 상한까지 좁힌다. 터치 영역은 아래 Listener가 셀 폭 전체로 받는다.
    final aspect = widget.keycapMaxAspectRatio;
    final faceWidth = aspect == null || round || widget.shape != null
        ? width
        : keyCapFaceWidth(
            cellWidth: width,
            faceHeight: capHeight - pressRoom,
            maxAspectRatio: aspect,
          );
    Widget keycap = Padding(
      padding: EdgeInsets.only(bottom: pressRoom),
      child: _centerFace(
        faceWidth: faceWidth,
        child: _wrapFocus(
          round
              ? _RoundKeycap(
                  id: widget.keyDef.id,
                  pressed: _pressed,
                  enabled: _enabled,
                )
              : _Keycap(
                  keyDef: widget.keyDef,
                  pressed: _pressed,
                  enabled: _enabled,
                  cornerRadius: cornerRadius,
                  fontSize:
                      widget.mainLabelFontSize ??
                      capHeight * CalcTheme.keyMainLabelFontRatio,
                  horizontalPadding:
                      faceWidth * CalcTheme.keyCapHorizontalPaddingRatio,
                  labelInsets: widget.labelInsets,
                  textScaler: textScaler,
                ),
          round: round,
          cornerRadius: cornerRadius,
        ),
      ),
    );
    if (!hitMode && !extendToLegend) keycap = _wrapHitArea(keycap);

    final legendFontSize =
        widget.legendFontSize ?? legendHeight * CalcTheme.keyLegendFontRatio;
    // 각인을 놓을 수 있는 높이 (#264) — 띠에 키 사이 세로 간격(셀 위쪽 간격 몫의 두 배)을 더한다. 키캡 사이 빈 본체는 띠와
    // 키 사이 간격을 합친 높이이고, 각인은 그 안에서 키캡 위끝에서 띄워 인쇄한다. 띠 위로 넘는 몫은 그리기만 넘는다(셀·터치
    // 영역은 그대로다). 키패드는 각인 글자 크기와 올리는 거리를 띠 + 간격의 절반(자기 몫, `KeypadMetrics.legendExtent`)에
    // 맞추므로, 나머지 절반까지 가는 것은 한 줄 아래로 넘쳐 더 올리는 각인(`d/dx◼`·`∑◻◻◼`, #260)뿐이다.
    final legendExtent =
        legendHeight + (hitMode ? 0.0 : 2 * widget.gapInsets.top);
    assert(widget.legendBaseLift >= 0, 'legendBaseLift는 음수일 수 없다');
    // 각인 줄 상자를 띠 아래끝에서 올릴 거리 — 각인마다 위쪽 여유까지만 올린다([KeyLegendView.bandLifts])
    final legendBaseLift = widget.showLegendBand ? widget.legendBaseLift : 0.0;
    final column = Column(
      children: [
        if (widget.showLegendBand)
          SizedBox(
            height: legendHeight,
            width: width,
            // 각인 줄은 띠 아래끝에 맞춘 채 위로 [legendExtent]까지 쓴다 (넘는 몫은 셀 위쪽 간격에 그려진다)
            child: OverflowBox(
              alignment: Alignment.bottomCenter,
              minHeight: legendExtent,
              maxHeight: legendExtent,
              child: round
                  ? _BodyPrintLabel(
                      keyDef: widget.keyDef,
                      fontSize: legendFontSize,
                      height: legendExtent,
                      baseLift: legendBaseLift,
                      textScaler: textScaler,
                    )
                  // SHIFT·ALPHA 각인은 실물처럼 그린 키캡 폭에 맞춰 인쇄하고(#220 R1, 좌우 자리는 #265), 긴 쌍만 키캡 밖
                  // 셀 폭까지 쓴다(#264 — 실물 `Ran# RanInt`는 키캡보다 넓다).
                  : _LegendRow(
                      shiftLegend: widget.keyDef.shiftLegend,
                      alphaLegend: widget.keyDef.alphaLegend,
                      width: width,
                      faceWidth: faceWidth,
                      height: legendExtent,
                      fontSize: legendFontSize,
                      maxGap: faceWidth * CalcTheme.keyLegendGapMaxWidthRatio,
                      sideInset: keyLegendSideInset(
                        faceWidth: faceWidth,
                        cornerRadius: cornerRadius,
                      ),
                      baseLift: legendBaseLift,
                      textScaler: textScaler,
                    ),
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
    // 그림 상자가 비면 키를 그리지 않는다(보이지 않는 키캡·라벨을 배치할 이유가 없다). 터치 영역은 남는다.
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

/// 누름 판정(히트 테스트)과 의미 노드 경계를 상자 밖으로 [gap]만큼 넓히는 [Semantics] (#236). 키 버튼과 커서 패드
/// (방향별 노드를 묶는 노드 — Android 엔진의 터치 탐색은 부모 노드 경계 밖의 자식에 닿지 않는다)가 쓴다.
///
/// 레이아웃·그리기는 버튼 상자 그대로다. 넓힌 몫은 부모(키패드 셀의 여백 [Padding])가 차지한 키 사이 간격이고, 부모는
/// 자기 상자 안의 점을 자식에게 넘기므로(셀 여백 안의 점도) 여기서 받아들일 수 있다. 받아들인 점은 버튼 상자 안쪽으로
/// 당겨서 자식에게 묻는다 — 자식(셀 전체를 덮는 [Listener])이 그 누름을 받고, 이벤트 좌표는 실제 위치 그대로 간다.
/// 의미 노드 경계([semanticBounds])도 넓히므로 스크린리더 터치 탐색과 접근성 검사기의 터치 대상이 같은 영역이다.
class GapSemantics extends Semantics {
  final EdgeInsets gap;

  const GapSemantics({
    super.key,
    required this.gap,
    required super.properties,
    super.container,
    super.explicitChildNodes,
    super.excludeSemantics,
    super.child,
  }) : super.fromProperties();

  @override
  RenderSemanticsAnnotations createRenderObject(BuildContext context) =>
      _RenderGapSemantics(
        gap: gap,
        container: container,
        explicitChildNodes: explicitChildNodes,
        excludeSemantics: excludeSemantics,
        blockUserActions: blockUserActions,
        properties: properties,
        localeForSubtree: localeForSubtree,
        // `Semantics`와 같은 규칙: 글자 속성이 있을 때만 주변 글자 방향 (업데이트는 상위 클래스가 같은 규칙으로 한다)
        textDirection: _textDirectionOf(context),
      );

  /// `Semantics`가 쓰는 규칙(프레임워크 내부 `_getTextDirection`)과 같다 — 지정한 방향이 없으면, 글자 속성(라벨·값·
  /// 힌트·툴팁)이 있을 때만 주변 글자 방향을 쓰고 없으면 `null`이다. 생성 때와 갱신 때(상위 클래스)가 같은 값을 준다.
  TextDirection? _textDirectionOf(BuildContext context) {
    final p = properties;
    if (p.textDirection != null) return p.textDirection;
    final hasText =
        p.label != null ||
        p.attributedLabel != null ||
        p.value != null ||
        p.attributedValue != null ||
        p.increasedValue != null ||
        p.attributedIncreasedValue != null ||
        p.decreasedValue != null ||
        p.attributedDecreasedValue != null ||
        p.hint != null ||
        p.attributedHint != null ||
        p.tooltip != null;
    return hasText ? Directionality.maybeOf(context) : null;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSemanticsAnnotations renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _RenderGapSemantics).gap = gap;
  }
}

class _RenderGapSemantics extends RenderSemanticsAnnotations {
  _RenderGapSemantics({
    required this._gap,
    required super.properties,
    super.container,
    super.explicitChildNodes,
    super.excludeSemantics,
    super.blockUserActions,
    super.localeForSubtree,
    super.textDirection,
  });

  EdgeInsets _gap;
  EdgeInsets get gap => _gap;
  set gap(EdgeInsets value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsSemanticsUpdate();
  }

  @override
  Rect get semanticBounds => _gap.inflateRect(Offset.zero & size);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      _gap == EdgeInsets.zero
      ? super.hitTest(result, position: position)
      : _hitTestWithGap(this, _gap, result, position);
}

/// [point]를 [size] 상자 안쪽(네 변 모두 0.01dp 안쪽)으로 당긴다 — 키 사이 간격 몫(#236)의 점을 상자 가장자리 바로
/// 안쪽의 점으로 바꿔 판정할 때 쓴다. 변 위가 아니라 안쪽으로 당겨, 터치 경로의 변 위 판정에 기대지 않는다.
/// 상자가 0.02dp보다 작으면 가운데로 당긴다.
@visibleForTesting
Offset clampIntoBox(Offset point, Size size) {
  const inset = 0.01;
  double clampAxis(double v, double extent) =>
      extent <= 2 * inset ? extent / 2 : v.clamp(inset, extent - inset);
  return Offset(
    clampAxis(point.dx, size.width),
    clampAxis(point.dy, size.height),
  );
}

/// [box] 상자를 [gap]만큼 넓힌 영역의 점을 받아들이고, 상자 가장자리로 당겨 자식에게 묻는 히트 테스트 (#236).
/// 이벤트 좌표는 실제 위치 그대로 간다(히트 항목에 원래 위치를 넣는다).
bool _hitTestWithGap(
  RenderProxyBox box,
  EdgeInsets gap,
  BoxHitTestResult result,
  Offset position,
) {
  if (!gap.inflateRect(Offset.zero & box.size).contains(position)) {
    return false;
  }
  // 두 렌더 객체 모두 자기 자신은 맞지 않는다(`hitTestSelf`가 거짓) — 자식(셀을 덮는 Listener 등)만 묻는다.
  if (box.hitTestChildren(result, position: clampIntoBox(position, box.size))) {
    result.add(BoxHitTestEntry(box, position));
    return true;
  }
  return false;
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
/// 두 각인이 모두 있으면 자연 폭(2차원 각인 포함, [KeyLegendView.emSize])에 비례해 폭을 나눠, 넘치면 함께
/// 같은 비율로 줄어든다. 단, 짧은 쪽이 한 줄 표기로 [CalcTheme.keyLegendPriorityMaxRunes]글자 이하(변수 이름
/// `A`~`F`, `y` 등)면 짧은 쪽이 자연 폭을 먼저(띠 폭의 절반까지) 쓰고 긴 쪽이 남은 폭을 써서, 한 글자 각인은
/// 긴 이웃 때문에 줄어들지 않는다. (`KeypadMetrics`의 폭 측정도 같은 규칙이다.)
///
/// 폭 [width]는 셀 폭이다 — 각인은 그 가운데의 그린 키캡에 맞춰 놓되, 긴 각인은 키캡 밖 셀 폭까지 쓴다(#264).
/// 가로로는 실물처럼 놓는다([CalcTheme] "각인 띠 좌우 정렬 (#265)" 절):
/// - 각인이 하나면 키캡 가운데다.
/// - 둘이면 SHIFT 각인은 왼쪽, ALPHA 각인은 오른쪽이고, 두 바깥 끝을 키캡 둥근 모서리 안쪽([sideInset])에 맞춘다. 두 각인의
///   폭과 사이 간격을 빼고 남는 폭이 모자라면 들이는 거리를 양쪽 똑같이 줄인다 — 두 각인 사이가 들이는 거리보다 좁아지지
///   않는 만큼만 들여, 바깥을 들이느라 두 각인이 서로 붙지 않게 한다([keyLegendPairInset]). 가장 긴 쌍(`Ran# RanInt`)은 실물처럼
///   키캡보다 넓게 셀 폭까지 쓴다(키캡 폭에 들어가지 않는 쌍은 가운데에 둔 채 키캡 양옆으로 똑같이 나간다 — 들이는 거리가
///   음수다). 셀 폭에도 들어가지 않으면 위의 폭 배분대로 각인이 줄어든다 — `KeypadMetrics`의 폭 기준도 셀 폭이다.
///
/// 세로로는 띠 아래끝에 정렬한 뒤 [baseLift]만큼 올려 모든 키의 각인이 기준선을 함께 쓴다(#252, 올림은 #264 — 기준선을 키캡
/// 위끝에서 띄운다). 한 줄 아래로 넘치는 2차원 각인(`d/dx◼`·`∑◻◻◼`)이 있는 키만 실물처럼 그 잉크 아래끝이 그 기준선에 오게,
/// 짝 각인(`:`)과 함께 높이 [height] 안에서 더 올린다([KeyLegendView.bandLifts], #260 — 그리는 자리만 옮긴다. 폭 배분·줄임
/// 배율은 그대로다).
class _LegendRow extends StatelessWidget {
  final KeyLegend? shiftLegend;
  final KeyLegend? alphaLegend;

  /// 셀 폭 (dp) — 각인이 쓸 수 있는 폭
  final double width;

  /// 그린 키캡 폭 (dp, 셀 가운데) — 각인을 맞춰 놓는 기준
  final double faceWidth;

  /// 각인을 놓을 수 있는 높이 (dp) — 각인 띠에 키 사이 세로 간격을 더한 값(#264). 각인을 올릴 수 있는 여유를 잰다
  final double height;
  final double fontSize;
  final double maxGap;

  /// 각인이 둘일 때 두 바깥 끝을 키캡 끝에서 들이는 거리의 상한 (dp, [keyLegendSideInset])
  final double sideInset;

  /// 각인 줄 상자를 띠 아래끝에서 올리는 거리 (dp, #264 — `CalcKeyButton.legendBaseLift`)
  final double baseLift;
  final TextScaler textScaler;

  const _LegendRow({
    required this.shiftLegend,
    required this.alphaLegend,
    required this.width,
    required this.faceWidth,
    required this.height,
    required this.fontSize,
    required this.maxGap,
    required this.sideInset,
    required this.baseLift,
    required this.textScaler,
  });

  @override
  Widget build(BuildContext context) {
    final shift = shiftLegend;
    final alpha = alphaLegend;
    if (shift == null && alpha == null) return const SizedBox.shrink();
    final palette = CalcPalette.of(context);

    final gap = shift != null && alpha != null
        ? math.min(fontSize * CalcTheme.keyLegendGapRatio, maxGap)
        : 0.0;
    // 자연 폭 우선 배분을 받을 짧은 각인 (둘 다 있고, 짧은 쪽이 충분히 짧을 때만)
    final shiftRunes = shift?.plainText.runes.length ?? 0;
    final alphaRunes = alpha?.plainText.runes.length ?? 0;
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
    // 한 줄 아래로 넘치는 각인이 있는 키는 각인들을 띠 아래끝에서 올린다 (#260) — 그리는 글자 크기(배율 반영)로 잰다
    final scaledFontSize = textScaler.scale(fontSize);
    // 각인 둘의 바깥 끝을 들이는 거리 (#265) — 두 각인이 그려질 폭과 사이 간격을 빼고 남는 폭에서 정한다.
    // 그려질 폭은 자연 폭(큰 글자 크기로 잰 비율 × 그리는 글자 크기)이고, 띠 높이보다 높은 각인은 높이에 맞춰 줄어든 폭이다
    // (키패드 밖에서 글자 크기를 주입받지 않은 키 버튼 — 키패드는 띠 높이에 맞춘 크기를 준다). 높이는 그리는 글자 크기의 실제
    // 줄 상자로 잰다(정수 dp로 반올림된다 — 올리는 거리 [KeyLegendView.bandLifts]와 같은 기준, #265 R2).
    double drawnWidth(KeyLegend legend, TextStyle style) {
      final metrics = KeyLegendView.emMetrics(legend, style);
      final naturalWidth = metrics.size.width * scaledFontSize;
      final naturalHeight = KeyLegendView.tallestAt(
        [metrics],
        style,
        scaledFontSize,
      );
      return naturalHeight > height && naturalHeight > 0
          ? naturalWidth * height / naturalHeight
          : naturalWidth;
    }

    // 키캡 옆 여백 (셀 폭과 그린 키캡 폭의 차의 절반) — 키캡 폭에 들어가지 않는 쌍이 나갈 수 있는 자리 (#264)
    final faceMargin = math.max(0.0, (width - faceWidth) / 2);
    // 각인 줄(셀 폭)의 좌우 여백 = 키캡 옆 여백 + 키캡 끝에서 들이는 거리(키캡 밖으로 나가면 음수)
    final inset = both
        ? faceMargin +
              keyLegendPairInset(
                width: faceWidth,
                gap: gap,
                leftWidth: drawnWidth(shift, CalcTheme.keyShiftLabelStyle),
                rightWidth: drawnWidth(alpha, CalcTheme.keyAlphaLabelStyle),
                sideInset: sideInset,
                outerMargin: faceMargin,
              )
        : 0.0;
    final lifts = KeyLegendView.bandLifts(
      [
        if (shift != null)
          (
            shift,
            CalcTheme.keyShiftLabelStyle.copyWith(fontSize: scaledFontSize),
          ),
        if (alpha != null)
          (
            alpha,
            CalcTheme.keyAlphaLabelStyle.copyWith(fontSize: scaledFontSize),
          ),
      ],
      height,
      baseLift: baseLift,
    );

    Widget legend(
      KeyLegend legend,
      TextStyle style,
      Alignment alignment, {
      required bool short,
      required bool priorityLayout,
      required double lift,
    }) {
      final sized = style.copyWith(fontSize: fontSize);
      final drawn = _legendLabel(
        legend,
        sized,
        textScaler,
        snapToDrawnBaseline: true,
      );
      final label = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        // 올리는 거리는 그리는 자리만 옮긴다 — 여백으로 띄우면 띠 높이에 꼭 맞는 각인이 부동소수 오차만큼 줄어든다(#260 R1)
        child: lift > 0
            ? Transform.translate(offset: Offset(0, -lift), child: drawn)
            : drawn,
      );
      if (short) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: shortMaxWidth),
          child: Align(alignment: alignment, widthFactor: 1, child: label),
        );
      }
      return Expanded(
        // 우선 배분이면 긴 쪽이 남은 폭 전부, 아니면 자연 폭 비례 (고정폭 글자만이면 글자 수 비례와 같다)
        flex: priorityLayout
            ? 1
            : math.max(
                1,
                (KeyLegendView.emSize(legend, style).width * 1000).round(),
              ),
        child: Align(alignment: alignment, child: label),
      );
    }

    final priority = shiftIsShort || alphaIsShort;
    // 각인이 하나면 키캡 가운데, 둘이면 SHIFT 왼쪽·ALPHA 오른쪽 (#265)
    final row = Row(
      children: [
        if (shift != null)
          legend(
            shift,
            CalcTheme.keyShiftLabelStyle.copyWith(color: palette.shiftLabel),
            both ? Alignment.bottomLeft : Alignment.bottomCenter,
            short: shiftIsShort,
            priorityLayout: priority,
            lift: lifts.first,
          ),
        if (both) SizedBox(width: gap),
        if (alpha != null)
          legend(
            alpha,
            CalcTheme.keyAlphaLabelStyle.copyWith(color: palette.alphaLabel),
            both ? Alignment.bottomRight : Alignment.bottomCenter,
            short: alphaIsShort,
            priorityLayout: priority,
            lift: lifts.last,
          ),
      ],
    );
    // 들이는 거리가 0이어도 같은 트리를 쓴다 — 0을 넘나들 때 각인 줄을 다시 만들지 않는다
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: row,
    );
  }
}

/// 각인 둘(SHIFT·ALPHA)의 바깥 끝을 키캡 끝에서 들이는 거리의 상한 (dp, #265) — 그린 키캡 폭 [faceWidth]의
/// [CalcTheme.keyLegendSideInsetRatio]와 키캡 모서리 반경 [cornerRadius] 가운데 큰 쪽이다. 실물 각인의 바깥 끝은 키캡 폭의
/// 0.08~0.10만큼 들어와 있다. 각인 끝을 키캡 윗변이 곧은 구간(둥근 모서리 안쪽)에 맞추려고 반경을 하한으로 둔다 — 함수부 키는
/// 대개 반경이 폭의 0.10~0.12라 실물보다 0.02~0.04 더 들어온다([CalcTheme] "각인 띠 좌우 정렬 (#265)" 절). 키캡 폭의 절반을 넘지 않는다.
@visibleForTesting
double keyLegendSideInset({
  required double faceWidth,
  required double cornerRadius,
}) {
  final face = math.max(0.0, faceWidth);
  return math.min(
    face / 2,
    math.max(face * CalcTheme.keyLegendSideInsetRatio, cornerRadius),
  );
}

/// 그린 키캡 폭 [width]에 왼쪽 묶음(폭 [leftWidth])과 오른쪽 묶음(폭 [rightWidth])을 최소 사이 간격 [gap]으로 놓을 때 양쪽
/// 바깥 끝을 키캡 끝에서 들이는 거리 (dp, #265). 지금은 묶음이 SHIFT 각인 하나·ALPHA 각인 하나다(모드 전용 각인과 괄호는 #266).
///
/// 상한 [sideInset]까지 들이되 두 가지를 넘지 않는다.
/// - 묶음과 최소 간격을 빼고 남는 폭의 절반 — 두 묶음 사이가 [gap]보다 좁아지지 않는다.
/// - `(남는 폭 + gap) ÷ 3` — 두 묶음 사이(`gap + 남는 폭 − 2 × 들이는 거리`)가 들이는 거리보다 좁아지지 않는다. 바깥을 들이느라
///   두 각인이 붙어 보이지 않게 한다(실물 `INS UNDO`도 사이가 바깥 여백보다 넓다).
///
/// 남는 폭이 없으면(키캡 폭에 들어가지 않으면) 음수다 — 쌍을 키캡 가운데에 둔 채 양옆으로 똑같이 내보낸다(#264 — 실물
/// `Ran# RanInt`는 키보다 넓다). 키캡 옆 여백 [outerMargin]보다 더 나가지는 않는다(−[outerMargin]에서 멈추고, 그래도 넘치면
/// 각인 줄이 줄인다). [outerMargin]이 0이면(키캡이 셀 폭을 다 쓴다) 0에서 멈춘다.
@visibleForTesting
double keyLegendPairInset({
  required double width,
  required double gap,
  required double leftWidth,
  required double rightWidth,
  required double sideInset,
  double outerMargin = 0,
}) {
  final spare = width - gap - leftWidth - rightWidth;
  if (spare < 0) return math.max(-math.max(0.0, outerMargin), spare / 2);
  return math.min(sideInset, math.min(spare / 2, (spare + gap) / 3));
}

/// 키캡([KeyFace.keycap]) 모서리 반경 (#156) — 숫자부 키(흰 키·파란 키)는 [CalcTheme.keyCapNumberCornerRadiusRatio],
/// 나머지(함수부·조작부·커서)는 [CalcTheme.keyCapCornerRadiusRatio]에 키캡 높이 [height]를 곱하고
/// [CalcTheme.keyCapMaxCornerRadius]에서 멈춘다. 커서 패드 키는 방향 구역 모양으로 잘려 반경이 보이지 않는다.
@visibleForTesting
double keyCapCornerRadius(KeyCategory category, double height) {
  final ratio = switch (category) {
    KeyCategory.number ||
    KeyCategory.operator ||
    KeyCategory.equals ||
    KeyCategory.ac ||
    KeyCategory.del => CalcTheme.keyCapNumberCornerRadiusRatio,
    _ => CalcTheme.keyCapCornerRadiusRatio,
  };
  return math.max(
    0.0,
    math.min(height * ratio, CalcTheme.keyCapMaxCornerRadius),
  );
}

/// 그린 키캡 폭 (#220, [CalcTheme] "키캡 크기 (#220)" 절) — 셀 폭 [cellWidth]의 키캡을 그린 높이 [faceHeight]에서
/// 가로/세로 비 [maxAspectRatio]를 넘지 않는 폭으로 줄이되, 셀 폭의 [CalcTheme.keyCapMinWidthRatio] 아래로는 줄이지 않는다.
/// 키캡이 그보다 납작하지 않으면 셀 폭 그대로다. 키패드 글자 크기 계산(`KeypadMetrics`)이 라벨 폭을 잴 때도 쓴다.
double keyCapFaceWidth({
  required double cellWidth,
  required double faceHeight,
  required double maxAspectRatio,
}) {
  final cell = math.max(0.0, cellWidth);
  return math.min(
    cell,
    math.max(
      cell * CalcTheme.keyCapMinWidthRatio,
      math.max(0.0, faceHeight) * maxAspectRatio,
    ),
  );
}

/// 원형 버튼 키의 각인 띠 (#190) — 버튼 위 본체에 인쇄한 메인 각인을 가운데에 쓴다. 띠 폭을 넘으면 줄인다.
/// SHIFT·ALPHA 각인처럼 띠 아래끝에서 [baseLift]만큼 올려 그린다(#264 — 높이 [height] 안에서).
/// 원형 버튼에는 SHIFT·ALPHA 각인이 없다(#253 — 실물 MENU 위 `MENU SETUP`의 `SETUP`은 앱에서 뺐다, `CalcKeyDef` assert).
/// 메인 각인 색은 키마다 다르다 — SHIFT 금색, ALPHA 자홍색, 나머지 흰색([CalcPalette.bodyPrintOf], #156).
/// 키패드 글자 크기 계산(`KeypadMetrics`)도 같은 각인을 잰다.
class _BodyPrintLabel extends StatelessWidget {
  final CalcKeyDef keyDef;
  final double fontSize;

  /// 각인을 놓을 수 있는 높이 (dp) — 각인 띠에 키 사이 세로 간격을 더한 값
  final double height;

  /// 각인 줄 상자를 띠 아래끝에서 올리는 거리 (dp)
  final double baseLift;
  final TextScaler textScaler;

  const _BodyPrintLabel({
    required this.keyDef,
    required this.fontSize,
    required this.height,
    required this.baseLift,
    required this.textScaler,
  });

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    final label = _legendLabel(
      keyDef.mainLegend,
      CalcTheme.keyBodyPrintStyle.copyWith(
        color: palette.bodyPrintOf(keyDef.category),
        fontSize: fontSize,
      ),
      textScaler,
      snapToDrawnBaseline: true,
    );
    final lift = KeyLegendView.bandLifts(
      [
        (
          keyDef.mainLegend,
          CalcTheme.keyBodyPrintStyle.copyWith(
            fontSize: textScaler.scale(fontSize),
          ),
        ),
      ],
      height,
      baseLift: baseLift,
    ).single;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomCenter,
      // 올리는 거리는 그리는 자리만 옮긴다 (SHIFT·ALPHA 각인 줄과 같다)
      child: lift > 0
          ? Transform.translate(offset: Offset(0, -lift), child: label)
          : label,
    );
  }
}

/// 원형 버튼 키의 키캡 자리 — 가운데에 [RoundKeyFace]를 그린다. 눌리면 키캡처럼 아래로 조금 내려간다.
class _RoundKeycap extends StatelessWidget {
  final CalcKeyId id;
  final bool pressed;
  final bool enabled;

  const _RoundKeycap({
    required this.id,
    required this.pressed,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: CalcKeyButton.keycapKeyOf(id),
      child: Transform.translate(
        offset: Offset(0, pressed ? CalcTheme.keyPressedOffset : 0),
        child: RoundKeyFace(pressed: pressed, enabled: enabled),
      ),
    );
  }
}

/// 카테고리 색과 눌림 반응을 가진 키캡 본체.
class _Keycap extends StatelessWidget {
  final CalcKeyDef keyDef;
  final bool pressed;
  final bool enabled;
  final double cornerRadius;
  final double fontSize;
  final double horizontalPadding;
  final EdgeInsets labelInsets;
  final TextScaler textScaler;

  const _Keycap({
    required this.keyDef,
    required this.pressed,
    required this.enabled,
    required this.cornerRadius,
    required this.fontSize,
    required this.horizontalPadding,
    required this.labelInsets,
    required this.textScaler,
  });

  @override
  Widget build(BuildContext context) {
    final category = keyDef.category;
    final palette = CalcPalette.of(context);
    final background = pressed
        ? palette.keyPressedBackground(category)
        : palette.keyBackground(category);
    final foreground = pressed
        ? palette.keyPressedForeground(category)
        : palette.keyForeground(category);
    final labelColor = enabled
        ? foreground
        : foreground.withValues(alpha: CalcTheme.keyDisabledLabelOpacity);
    // 누를 때는 즉시, 뗄 때는 [CalcTheme.keyPressAnimationDuration] 동안 바꾼다. 라벨 색도 배경과 같은 시간에
    // 돌아오게 해야 고대비 반전 키(#54)가 흰 배경에 흰 라벨로 보이는 프레임이 없다.
    final duration = pressed
        ? Duration.zero
        : CalcTheme.keyPressAnimationDuration;

    // 눌리면 그림자·옆면이 사라지고 옆면 깊이만큼 아래로 내려가 실물 키의 눌림을 흉내 내며, 배경 명도와 테두리가 바뀐다(#22).
    // 누를 때는 즉시 바꾸고 뗄 때만 애니메이션한다 — 짧은 탭에서도 눌림 색이 끝까지 보이게 한다.
    // 고대비 모드에서는 흰 라벨 키의 배경·라벨이 반전되고(#54, [CalcPalette.invertsOnPress]) 광택·옆면을 그리지 않는다(#156).
    final relief = palette.drawsRelief;
    final radius = BorderRadius.circular(cornerRadius);
    return Transform.translate(
      offset: Offset(0, pressed ? CalcTheme.keyPressedOffset : 0),
      child: AnimatedContainer(
        key: CalcKeyButton.keycapKeyOf(keyDef.id),
        duration: duration,
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: Border.all(
            color: pressed ? palette.keyPressedBorder : palette.keyBorder,
            width: CalcTheme.keyBorderWidth,
          ),
          // 그림자 목록은 먼저 둔 것부터 그린다 — 번지는 그림자 위에 옆면(번지지 않는 같은 모양의 어두운 면)을 얹는다.
          boxShadow: pressed
              ? const []
              : [
                  BoxShadow(
                    color: CalcTheme.keyShadow,
                    blurRadius: CalcTheme.keyElevation,
                    offset: Offset(
                      0,
                      CalcTheme.keyElevation +
                          (relief ? CalcTheme.keyCapSideDepth : 0),
                    ),
                  ),
                  if (relief)
                    BoxShadow(
                      color: Color.alphaBlend(CalcTheme.keyCapSide, background),
                      offset: const Offset(0, CalcTheme.keyCapSideDepth),
                    ),
                ],
        ),
        // 광택은 라벨 아래에 그린다(CustomPaint는 자식보다 먼저 그린다). 라벨 여백은 애니메이션하지 않는다 — 창 크기가
        // 바뀔 때 라벨이 즉시 그린 허브 등과 함께 움직이게 한다.
        child: CustomPaint(
          painter: relief
              ? KeycapSheenPainter(
                  cornerRadius: cornerRadius,
                  dark: background.computeLuminance() < 0.18,
                )
              : null,
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: horizontalPadding) +
                labelInsets,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                // 라벨 색이 바뀌지 않는 키(일반 모드 전부, 고대비 밝은 키)에서는 애니메이션이 일어나지 않는다.
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: labelColor),
                  duration: duration,
                  builder: (context, color, _) {
                    final legend = keyDef.mainLegend;
                    final style = CalcTheme.keyMainLabelStyleFor(legend);
                    final scaledFontSize = textScaler.scale(fontSize);
                    // 잉크 가운데를 키캡 면 가운데에 둔다 (#230, CalcTheme "메인 각인 세로 위치" 절)
                    return InkCenteredLabel(
                      inkCenter:
                          mainLegendInkCenter(legend, style) * scaledFontSize,
                      // 숫자부 연산 기호는 줄 상자가 아니라 잉크 높이를 상자로 본다 (#264) — 실물 비율로 키운 기호는 줄 상자가
                      // 키캡보다 높아도 잉크는 키캡의 절반쯤이다. 줄 상자로 재면 `FittedBox`가 기호만 줄인다.
                      boxHeight: CalcTheme.isKeyOperatorLegend(legend)
                          ? mainLegendInkHeight(legend, style) * scaledFontSize
                          : null,
                      child: _legendLabel(
                        legend,
                        style.copyWith(fontSize: fontSize, color: color),
                        textScaler,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 키캡 윗면 광택 (#156, [CalcTheme] "키캡 입체감" 절) — 테두리 안쪽에 위쪽은 밝게, 아래쪽은 어둡게 세로 그라데이션을
/// 칠한다. 가운데(글자 자리)는 투명이다. 어두운 키([dark] — 검정·파랑)는 위쪽 광택을 [CalcTheme.keyCapGloss]로,
/// 밝은 키는 [CalcTheme.keyCapSheen]으로 칠한다.
@visibleForTesting
class KeycapSheenPainter extends CustomPainter {
  /// 키캡 모서리 반경 (dp)
  final double cornerRadius;

  /// 어두운 키캡인지
  final bool dark;

  const KeycapSheenPainter({required this.cornerRadius, required this.dark});

  /// 광택 그라데이션 색 (위 → 아래)
  List<Color> get colors => [
    dark ? CalcTheme.keyCapGloss : CalcTheme.keyCapSheen,
    const Color(0x00FFFFFF),
    const Color(0x00000000),
    CalcTheme.keyCapShade,
  ];

  /// [colors]의 위치 (키캡 높이 대비)
  static const List<double> stops = [
    0.0,
    CalcTheme.keyCapSheenClearStart,
    CalcTheme.keyCapSheenClearEnd,
    1.0,
  ];

  /// 받는 상자는 키캡 테두리 안쪽이다 — 키캡(`AnimatedContainer`)이 장식의 테두리 두께만큼 자식을 안쪽에 둔다.
  /// 그래서 더 줄이지 않고, 모서리 반경만 테두리 안쪽 곡선에 맞춘다(바깥 반경 − 테두리 두께, #156 R1).
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.max(0.0, cornerRadius - CalcTheme.keyBorderWidth)),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(KeycapSheenPainter oldDelegate) =>
      oldDelegate.cornerRadius != cornerRadius || oldDelegate.dark != dark;
}

/// 각인 하나를 그린다. 글자만 있는 각인은 `Text`, 2차원 각인(분수·첨자·근호)은 [KeyLegendView]다 (#155).
/// 글자에 변수 이탤릭 글자가 있으면 그 글자만 다른 글꼴로 그린다([keyLabelSpan], #156).
///
/// 두 위젯은 같은 strut 한 줄 상자([keyLabelStrut] — 줄 간격 배분까지 고정해 앱 테마와 상관없다, #252)와 기준선을 쓰므로,
/// 2차원 각인이 한 줄을 넘지 않으면 크기·보고한 기준선이 같다. 단 `Text`는 보고한 기준선을 정수 dp로 반올림한 곳에 글자를
/// 그린다([InkCenteredLabel] 설명). [snapToDrawnBaseline]이면 `Text`를 [DrawnBaselineLabel]로 감싸 보고한 기준선에 글자가
/// 그려지게 한다 — 아래 정렬로 같은 행의 이웃 각인과 기준선을 함께 쓰는 각인 띠(SHIFT·ALPHA, 원형 버튼 위 인쇄)가 쓴다(#252).
/// 메인 각인은 [InkCenteredLabel]이 그린 기준선으로 맞추므로 감싸지 않는다.
Widget _legendLabel(
  KeyLegend legend,
  TextStyle style,
  TextScaler textScaler, {
  bool snapToDrawnBaseline = false,
}) {
  if (legend case LegendText(:final text)) {
    final span = keyLabelSpan(text, style);
    final strut = keyLabelStrut(style);
    final Widget label = span.children == null
        ? Text(
            text,
            maxLines: 1,
            softWrap: false,
            textScaler: textScaler,
            style: style,
            strutStyle: strut,
          )
        : Text.rich(
            TextSpan(children: span.children),
            maxLines: 1,
            softWrap: false,
            textScaler: textScaler,
            style: style,
            strutStyle: strut,
          );
    return snapToDrawnBaseline ? DrawnBaselineLabel(child: label) : label;
  }
  return KeyLegendView(legend: legend, style: style, textScaler: textScaler);
}

/// 자식 [RenderBox]가 글자를 실제로 그리는 기준선 — 보고한 알파벳 기준선 [baseline](자식 상자 위끝에서의 거리)에서 구한다.
///
/// `Text`(`RenderParagraph`)는 보고한 기준선을 정수 dp로 반올림한 곳에 글자를 그린다([InkCenteredLabel] 설명). 그 밖의
/// 자식([KeyLegendView]·[DrawnBaselineLabel])은 보고한 기준선에 그린다.
///
/// `Text`는 상황에 따라 `RenderParagraph`를 다른 렌더 객체로 감싼다 — 위에 선택 영역이 있으면 `MouseRegion`, `semanticsLabel`을
/// 주면 `Semantics`·`ExcludeSemantics`(#252 R1). 그 감싸개(`RenderMouseRegion`·`RenderSemanticsAnnotations`·`RenderExcludeSemantics`)는 자식을 제자리(오프셋 0, 크기
/// 그대로)에 두므로 그 사슬만 따라 내려가 `RenderParagraph`를 찾는다 — 그래야 감싸개가 끼어도 반올림 보정이 조용히 빠지지 않는다.
/// 자식을 옮기거나 줄이는 [RenderProxyBox](`RenderTransform`·`RenderFittedBox` 등)는 따라가지 않는다(#252 R2) — 그런 렌더 객체는
/// 자식 기준선을 변환 없이 보고하므로 반올림한 거리가 그린 곳이 아니다.
double drawnBaselineOf(RenderBox child, double baseline) {
  RenderObject? node = child;
  while (node is RenderMouseRegion ||
      node is RenderSemanticsAnnotations ||
      node is RenderExcludeSemantics) {
    node = (node! as RenderProxyBox).child;
  }
  return node is RenderParagraph ? baseline.roundToDouble() : baseline;
}

/// `Text` 각인([child])을 보고한 기준선에 글자가 그려지도록 세로로만 옮겨 그린다 (#252).
///
/// `Text`는 보고한 기준선(글자 상자 위끝에서 소수 거리)을 정수 dp로 반올림한 곳에 글자를 그린다([drawnBaselineOf]). 그래서
/// 같은 줄 상자·기준선을 보고하는 [KeyLegendView](글자 조각을 계산한 기준선에 그린다)와 나란히 놓으면 그린 기준선이 최대
/// 0.5dp 어긋난다(#252 실측 — 줄 간격 배분을 고친 뒤 800×1280 태블릿 SHIFT `sin⁻¹`·ALPHA `D` 0.37dp, 가로 폰 800×360 글자 배율 1.3에서
/// 0.50dp). 이 위젯은 크기·보고한 기준선은 [child] 그대로 두고
/// 반올림 차만큼 [child]를 옮겨(−0.5~+0.5dp), 보고한 기준선 = 그린 기준선이 되게 한다. 그래서 감싸는 아래 정렬·기준선 정렬
/// 배치가 그린 기준선을 맞춘다. 기준선이 없는 자식은 옮기지 않는다.
class DrawnBaselineLabel extends SingleChildRenderObjectWidget {
  const DrawnBaselineLabel({super.key, required Widget super.child});

  @override
  RenderDrawnBaselineLabel createRenderObject(BuildContext context) =>
      RenderDrawnBaselineLabel();
}

/// [DrawnBaselineLabel]의 렌더 객체 — 크기·보고한 기준선은 자식 그대로이고, 자식을 세로로만 옮겨 둔다.
class RenderDrawnBaselineLabel extends RenderShiftedBox {
  RenderDrawnBaselineLabel() : super(null);

  /// 자식을 아래로 옮긴 거리 (dp, 위로 옮기면 음수) — 마지막 배치의 값
  double get shift =>
      child == null ? 0 : (child!.parentData! as BoxParentData).offset.dy;

  /// 보고한 알파벳 기준선 [baseline]인 자식을 옮길 거리 — 그린 기준선을 보고한 기준선으로 옮긴다 (기준선이 없으면 0)
  static double _shiftFor(RenderBox child, double? baseline) =>
      baseline == null ? 0 : baseline - drawnBaselineOf(child, baseline);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      child?.getDryLayout(constraints) ?? constraints.smallest;

  // 크기·보고한 기준선은 자식 그대로다 — 옮긴 자식의 그린 기준선이 그 자리에 온다.
  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => child?.getDryBaseline(constraints, baseline);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      child?.getDistanceToActualBaseline(baseline);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(child.size);
    final dy = _shiftFor(
      child,
      child.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true),
    );
    (child.parentData! as BoxParentData).offset = Offset(0, dy);
  }
}

/// 메인 각인 [legend]([style]로 그린다)를 키캡 면 세로 가운데에 맞출 때 면 가운데에 두는 높이 — 기준선 위, 글자 크기 대비
/// (#230, [CalcTheme] "메인 각인 세로 위치" 절).
///
/// 기준선 글자가 있는 각인([CalcTheme.hasKeyBaselineText])은 대문자·숫자 잉크 가운데([CalcTheme.keyMainLegendInkCenter])다
/// — 실물처럼 모든 각인의 기준선이 맞는다. 없는 각인은 자기 잉크 범위(잉크 범위 표 `KeyLegendView.glyphInk`로 잰
/// [KeyLegendView.emMetrics])의 가운데다. 표에 없는 글자는 한 줄 상자를 잉크로 보므로 줄 상자 가운데가 된다(#230 전과 같다).
double mainLegendInkCenter(KeyLegend legend, TextStyle style) {
  if (CalcTheme.hasKeyBaselineText(legend)) {
    return CalcTheme.keyMainLegendInkCenter;
  }
  final m = KeyLegendView.emMetrics(legend, style);
  return (m.inkTop + m.inkBottom) / 2;
}

/// 메인 각인 [legend]([style]로 그린다)의 잉크 높이 — 글자 크기 대비 (#264). 잉크 범위 표(`KeyLegendView.glyphInk`)로 잰
/// [KeyLegendView.emMetrics]의 위끝·아래끝 차다. 숫자부 연산 기호의 상자 높이([InkCenteredLabel.boxHeight])와 키패드의 높이
/// 기준(`KeypadMetrics` — 기호 잉크가 키캡 안쪽 높이에 들어가는 크기)이 함께 쓴다.
double mainLegendInkHeight(KeyLegend legend, TextStyle style) {
  final m = KeyLegendView.emMetrics(legend, style);
  return math.max(0.0, m.inkTop - m.inkBottom);
}

/// 각인 라벨([child] — `Text` 또는 [KeyLegendView])을 기준선 위 [inkCenter](dp) 높이가 자기 상자의 세로 가운데에 오도록
/// 옮겨 그린다 (#230).
///
/// 크기는 [child] 그대로라 감싸는 `Center`·`FittedBox`의 배치(글자 줄이기 포함)는 바뀌지 않고, 그 상자 안에서 [child]만
/// 위아래로 옮긴다(`FittedBox`가 줄이면 옮긴 거리도 함께 준다). [boxHeight]를 주면 상자 높이만 그 값으로 줄인다(#264 —
/// [child]는 [inkCenter]를 가운데에 둔 채 상자 위아래로 넘쳐 그려진다. 줄 상자가 잉크보다 훨씬 높은 연산 기호에 쓴다). 옮기는 거리는 [child]가 글자를 실제로 그리는 기준선으로
/// 정한다 — 줄 상자 높이(글자 크기를 반올림한 정수 dp)·줄 상자 안 기준선 위치(#252부터 [keyLabelStrut]이 줄 간격 배분을
/// 고정해 약 0.785em — 그 전에는 앱 테마의 `TextLeadingDistribution.even`을 받은 `Text`만 약 0.888em이었다)·2차원 각인의 큰
/// 상자와 상관없이 [inkCenter] 높이가 정확히 가운데에 온다.
/// 기준선이 없는 자식은 옮기지 않는다.
///
/// `Text`(`RenderParagraph`)는 보고한 기준선이 아니라 그 거리(글자 상자 위끝에서 소수 거리)를 정수 dp로 반올림한 곳에 글자를
/// 그린다 — 글자 배치 엔진 SkParagraph의 `TextLine::paintText`(`correctedBaseline`)다. 반올림 차는 최대 0.5dp(360×800 폰
/// 숫자 18.62dp에서 0.47dp)라 반올림한 기준선으로 맞춘다. [KeyLegendView]는 글자 조각을 계산한 기준선에 맞춰 그리므로
/// (`_text`) 보고한 기준선 그대로다. Flutter SDK를 올릴 때 엔진의 이 반올림이 바뀌면 그린 픽셀로 재는 테스트
/// (`test/widget/main_legend_ink_center_test.dart` "실물 사진 대조")가 잡는다.
class InkCenteredLabel extends SingleChildRenderObjectWidget {
  /// 상자 세로 가운데에 둘 높이 — 자식 기준선 위 거리 (dp, 글자 배율 반영)
  final double inkCenter;

  /// 상자 높이 상한 (dp, 글자 배율 반영, #264). `null`이면 자식 높이 그대로다. 자식보다 낮으면 상자만 낮아지고 자식은
  /// [inkCenter]를 상자 가운데에 둔 채 위아래로 넘쳐 그려진다.
  final double? boxHeight;

  const InkCenteredLabel({
    super.key,
    required this.inkCenter,
    this.boxHeight,
    required Widget super.child,
  });

  @override
  RenderInkCenteredLabel createRenderObject(BuildContext context) =>
      RenderInkCenteredLabel(inkCenter, boxHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderInkCenteredLabel renderObject,
  ) {
    renderObject
      ..inkCenter = inkCenter
      ..boxHeight = boxHeight;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('inkCenter', inkCenter))
      ..add(DoubleProperty('boxHeight', boxHeight, defaultValue: null));
  }
}

/// [InkCenteredLabel]의 렌더 객체 — 크기는 자식 크기(높이는 [boxHeight]까지)이고, 자식을 세로로만 옮겨 둔다.
class RenderInkCenteredLabel extends RenderShiftedBox {
  /// 상자 세로 가운데에 둘 자식 기준선 위 높이 [_inkCenter](dp)와 상자 높이 상한 [_boxHeight](dp)로 만든다.
  RenderInkCenteredLabel(this._inkCenter, [this._boxHeight]) : super(null);

  double _inkCenter;
  double? _boxHeight;

  /// 상자 높이 상한 (dp) — `null`이면 자식 높이 그대로
  double? get boxHeight => _boxHeight;
  set boxHeight(double? value) {
    if (value == _boxHeight) return;
    _boxHeight = value;
    markNeedsLayout();
  }

  /// 자식 크기 [childSize]에서 정한 상자 크기 — 높이만 [boxHeight]로 줄인다
  Size _boxSize(BoxConstraints constraints, Size childSize) {
    final limit = _boxHeight;
    return constraints.constrain(
      limit == null
          ? childSize
          : Size(childSize.width, math.min(childSize.height, limit)),
    );
  }

  /// 상자 세로 가운데에 둘 자식 기준선 위 높이 (dp)
  double get inkCenter => _inkCenter;
  set inkCenter(double value) {
    if (value == _inkCenter) return;
    _inkCenter = value;
    markNeedsLayout();
  }

  /// 자식을 아래로 옮긴 거리 (dp, 위로 옮기면 음수) — 마지막 배치의 값
  double get shift =>
      child == null ? 0 : (child!.parentData! as BoxParentData).offset.dy;

  /// 높이 [height]인 자식 상자를, 보고한 알파벳 기준선 [baseline]으로 옮길 거리 (기준선이 없으면 0)
  double _shiftFor(RenderBox child, double height, double? baseline) {
    if (baseline == null) return 0;
    // `Text`는 기준선 거리를 반올림한 곳에 글자를 그린다 (클래스 설명)
    return height / 2 - (drawnBaselineOf(child, baseline) - _inkCenter);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    return child == null
        ? constraints.smallest
        : _boxSize(constraints, child.getDryLayout(constraints));
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) return null;
    final result = child.getDryBaseline(constraints, baseline);
    if (result == null) return null;
    final height = _boxSize(
      constraints,
      child.getDryLayout(constraints),
    ).height;
    final alphabetic = baseline == TextBaseline.alphabetic
        ? result
        : child.getDryBaseline(constraints, TextBaseline.alphabetic);
    return result + _shiftFor(child, height, alphabetic);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = _boxSize(constraints, child.size);
    final dy = _shiftFor(
      child,
      size.height,
      child.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true),
    );
    (child.parentData! as BoxParentData).offset = Offset(0, dy);
  }
}

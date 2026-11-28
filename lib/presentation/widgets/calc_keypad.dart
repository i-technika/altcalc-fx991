import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/key_definitions.dart';
import '../../core/theme/calc_theme.dart';
import '../l10n/calc_semantic_strings.dart';
import 'calc_key_button.dart';
import 'key_legend_view.dart';
import 'text_fit.dart';

/// 키패드 구역 배열 (#80).
///
/// 두 배열 모두 구역 안의 키 배열·행 수는 실물 그대로이고, 구역(상단 조작부+함수부 / 숫자부)을 놓는 방향만 다르다.
/// ```
///  standard (실물)           wide (낮고 넓은 영역)
///  ┌───────────────┐         ┌───────────────┐   ┌────────────┐
///  │ 상단 조작부 2행 │         │ 상단 조작부 2행 │   │            │
///  │ 함수부 3행      │         │ 함수부 3행      │   │ 숫자부 4행  │
///  ├───────────────┤         └───────────────┘   └────────────┘
///  │ 숫자부 4행      │          └─── 블록 ───┘ 간격 └── 블록 ──┘
///  └───────────────┘
/// ```
enum KeypadArrangement {
  /// 실물 배열 — 숫자부가 함수부 아래에 있다.
  standard,

  /// 숫자부를 함수부 옆에 나란히 둔다. 가로형 배치(`CalcLandscapeLayout`, #142)와 가로 접힘선 기준 배치의 아래 패널
  /// (`CalcTabletopLayout`, #80·#143)처럼 낮고 넓은 영역에서 [standard]보다 키가 클 때 쓴다. 높이가 [standard]의 약 절반이라
  /// 같은 높이에서 키가 약 2배가 된다(#80 당시 Fold 가로 반 접힘 19.9 → 39.9dp).
  /// 숫자부는 기본으로 오른쪽이고(블록 순서는 실물의 "함수부 다음 숫자부"를 읽는 순서로 옮긴 것), `CalcKeypad.numbersOnLeft`로
  /// 좌우를 맞바꿀 수 있다 — 두 배치 모두 손잡이에 따라 숫자부를 주로 쓰는 손 쪽에 둔다(#142, #143, 사용자 결정).
  wide,
}

/// 숫자부 메인 각인의 종류 (#225) — 종류마다 글자 크기가 다르다([KeypadMetrics.numberLabelKindOf],
/// [CalcTheme] "숫자부 메인 각인 크기 (#225)" 절).
enum NumberLabelKind {
  /// 숫자 0~9·소수점 — [KeypadMetrics.numberMainLabelFontSize]
  digit,

  /// 글자 각인 DEL·AC·Ans·×10ˣ — 숫자의 [CalcTheme.keyNumberWordLabelScale]배
  word,

  /// 연산 기호 × ÷ + − = — 숫자의 [CalcTheme.keyNumberOperatorLabelScale]배
  operator,
}

/// 키패드 크기에서 산출한 배치·글자 치수. 화면 크기와 시스템 글자 배율, 라벨 글자 폭, 구역 배열로 정해진다.
///
/// 세로 배치 (행 높이 단위, 숫자부 행은 [CalcTheme.keypadNumberRowHeightRatio]배 — [KeypadArrangement.standard]):
/// ```
///  상단 조작부  2행 (좌 2×2 · 커서 패드 · 우 2×2, 각 2열 폭 = 함수부 6열과 같은 열 폭)
///  함수부       3행 × 6열
///  (구역 간격)
///  숫자부       4행 × 5열
/// ```
/// [KeypadArrangement.wide]는 위 두 구역을 같은 폭의 블록([blockWidth])으로 좌우에 놓는다. 숫자부 4행이 함수부 5행과
/// 같은 높이를 나누므로 숫자부 행은 함수부 행의 1.25배다(실물 비 1.2에 가깝다). 키 사이 간격과 블록의 가로/세로 비
/// 범위는 같은 함수부 행 높이의 [KeypadArrangement.standard] 키패드와 같게 맞춰, 배열만 다르고 키 하나의 모양은
/// 같은 범위다.
@immutable
class KeypadMetrics {
  /// 구역 배열
  final KeypadArrangement arrangement;

  /// 실제 키패드 크기 (가로/세로 비 제한 반영, 주어진 영역 이하)
  final Size size;

  /// 구역 블록 폭 (dp) — [KeypadArrangement.standard]는 키패드 폭, [KeypadArrangement.wide]는 좌우 블록 하나의 폭
  final double blockWidth;

  /// 키 사이 가로 간격 (dp)
  final double horizontalGap;

  /// 키 사이 세로 간격 (dp)
  final double verticalGap;

  /// 함수부와 숫자부 사이 간격 (dp) — [KeypadArrangement.standard]는 세로, [KeypadArrangement.wide]는 가로 간격
  final double sectionGap;

  /// 상단 조작부·함수부 행 높이 (간격 포함, dp)
  final double functionRowHeight;

  /// 숫자부 행 높이 (간격 포함, dp)
  final double numberRowHeight;

  /// 키패드 전체에 통일해 주입하는 각인 글자 크기 (배율 반영 전, dp)
  final double legendFontSize;

  /// 키캡 위 각인의 줄 상자를 각인 띠 아래끝에서 올리는 거리 (dp, 글자 배율 반영, #264) — 모든 키에 같은 값을 주어
  /// ([CalcKeyButton.legendBaseLift]) 기준선이 한 줄이다(#252). 각인 기준선이 키캡 위끝에서 [legendBaselineGap]만큼 떨어지는
  /// 거리(목표 − 줄 상자 깊이)다. 각인 글자 크기의 높이 기준이 이 자리를 먼저 떼어 두므로 글자 배율이 커도 목표 그대로다
  /// (글자 크기가 하한 1dp에서도 높이 조건을 만족하지 못할 때만, 가장 높은 각인이 [legendExtent]를 넘지 않는 만큼으로
  /// 줄어든다 — 실제 키패드 크기에서는 닿지 않는다). 한 줄 아래로 넘치는 각인(`d/dx◼`·`∑◻◻◼`, #260)은 키 버튼이 여기서 더
  /// 올린다(키 사이 간격 전체까지).
  final double legendBaseLift;

  /// 상단 조작부·함수부(커서 패드 포함)에 통일해 주입하는 메인 라벨 글자 크기 (배율 반영 전, dp)
  final double mainLabelFontSize;

  /// 숫자부 숫자(0~9·소수점) 메인 라벨 글자 크기 (배율 반영 전, dp, #156·#225).
  ///
  /// 실물 숫자부 각인은 함수부보다 훨씬 크다. 숫자부 키캡 높이 × [CalcTheme.keyNumberMainLabelFontRatio]를 목표로 하고
  /// ([CalcTheme] "숫자부 메인 각인 크기 (#225)" 절), 숫자부 키캡 높이·숫자 폭에 들어가는 크기까지 줄이되 [mainLabelFontSize]
  /// 아래로는 내리지 않는다. 숫자부의 글자 각인·연산 기호는 이 크기의 배수로 따로 정한다([numberWordLabelFontSize]·
  /// [numberOperatorLabelFontSize]). 키마다 쓸 크기는 [mainLabelFontSizeOf]다.
  final double numberMainLabelFontSize;

  /// 숫자부 글자 각인(DEL·AC·Ans·×10ˣ) 글자 크기 (배율 반영 전, dp, #225) — [numberMainLabelFontSize] ×
  /// [CalcTheme.keyNumberWordLabelScale]를 목표로 키캡 높이·폭에 들어가게 줄이되 [mainLabelFontSize] 아래로는 내리지 않는다.
  final double numberWordLabelFontSize;

  /// 숫자부 연산 기호(× ÷ + − =) 글자 크기 (배율 반영 전, dp, #225) — [numberMainLabelFontSize] ×
  /// [CalcTheme.keyNumberOperatorLabelScale]를 목표로 키캡 높이·폭에 들어가게 줄이되 [numberMainLabelFontSize] 아래로는
  /// 내리지 않는다. [CalcTheme.keyNumberOperatorLabelStyle]로 그린다.
  final double numberOperatorLabelFontSize;

  /// 함수부·상단 조작부 키의 터치 영역을 각인 띠까지 넓힐지 여부
  final bool extendFunctionHitArea;

  /// 숫자부 키의 터치 영역을 각인 띠까지 넓힐지 여부
  final bool extendNumberHitArea;

  const KeypadMetrics._({
    required this.arrangement,
    required this.size,
    required this.blockWidth,
    required this.horizontalGap,
    required this.verticalGap,
    required this.sectionGap,
    required this.functionRowHeight,
    required this.numberRowHeight,
    required this.legendFontSize,
    required this.legendBaseLift,
    required this.mainLabelFontSize,
    required this.numberMainLabelFontSize,
    required this.numberWordLabelFontSize,
    required this.numberOperatorLabelFontSize,
    required this.extendFunctionHitArea,
    required this.extendNumberHitArea,
  });

  /// 상단 조작부 행 수
  static const int controlRowCount = 2;

  /// 상단 조작부 + 함수부 행 수 (같은 행 높이를 쓴다)
  static int get functionRowCount => controlRowCount + functionRows.length;

  /// [KeypadArrangement.standard] 키패드 높이(구역 간격 제외)를 함수부 행 높이 단위로 센 값 (9.8)
  static double get _standardRowUnits =>
      functionRowCount +
      numberRows.length * CalcTheme.keypadNumberRowHeightRatio;

  /// [KeypadArrangement.wide] 키패드 높이에 곱하면 함수부 행 높이가 같은 [KeypadArrangement.standard] 키패드 높이가
  /// 되는 배수 (2.0). 키 사이 세로 간격과 블록의 가로/세로 비 범위를 그 "같은 행 높이의 표준 키패드"에 맞춘다.
  static double get wideHeightFactor =>
      _standardRowUnits /
      (1 - CalcTheme.keypadSectionGapRatio) /
      functionRowCount;

  /// [KeypadArrangement.wide] 키패드 폭을 블록 폭 단위로 센 값 (블록 2개 + 블록 사이 간격)
  static const double _wideWidthUnits = 2 + CalcTheme.keypadWideSectionGapRatio;

  /// [KeypadArrangement.wide] 키패드 폭 [width]에서 블록 하나의 폭 (dp). 블록 사이 간격은 `width - 2 × 블록 폭`이다.
  ///
  /// 블록 사이 간격은 보통 블록 폭 × [CalcTheme.keypadWideSectionGapRatio]다. [minSectionGap]이 그보다 넓으면 간격을 그만큼
  /// 넓히고 블록을 줄인다 — 책 자세(#285)는 두 블록 사이에 접힘선과 그 양쪽 여백([CalcTheme.screenHingeMargin])을 둔다.
  static double wideBlockWidthOf(double width, {double minSectionGap = 0}) {
    final w = math.max(0.0, width);
    final natural = w / _wideWidthUnits;
    final gap = minSectionGap.isFinite ? math.max(0.0, minSectionGap) : 0.0;
    if (w - 2 * natural >= gap) return natural;
    return math.max(0.0, (w - gap) / 2);
  }

  /// 키패드 치수 [metrics]의 셀·키캡 폭에서 폭 기준이 허락하는 (배율 반영) 최대 글자 크기 — 메인 라벨·각인.
  ///
  /// [compute]의 2단계(폭 기준)와 같은 계산이다. [where]로 키를 골라 재면, 어떤 키들이 통일 글자 크기를 정하는지
  /// 테스트가 제품 규칙 그대로 확인할 수 있다(#186 R1 — 2차원 각인이 폭 기준을 정하지 않는지).
  /// 폭은 [metrics]에서 읽는다 — 셀 너비만 따로 받으면 그린 키캡 폭(#220)을 빠뜨려 제품과 다른 규칙을 잴 수 있다(#220 R1).
  @visibleForTesting
  static ({
    double main,
    double numberMain,
    double numberWord,
    double numberOperator,
    double legend,
  })
  debugWidthLimits(
    KeypadMetrics metrics, {
    bool Function(CalcKeyDef def)? where,
    Set<KeyFeature> releasedFeatures = releasedKeyFeatures,
  }) {
    final limits = _LabelLimits.measure(
      functionKeyWidth: metrics.functionKeyWidth,
      numberKeyWidth: metrics.numberKeyWidth,
      functionCapWidth: metrics.functionCapWidth,
      numberCapWidth: metrics.numberCapWidth,
      releasedFeatures: releasedFeatures,
      where: where,
    );
    return (
      main: limits.main,
      numberMain: limits.numberMain,
      numberWord: limits.numberWord,
      numberOperator: limits.numberOperator,
      legend: limits.legend,
    );
  }

  /// 상단 조작부·함수부 키의 셀 너비 (간격 제외, dp)
  double get functionKeyWidth =>
      math.max(0.0, blockWidth / functionColumns - horizontalGap);

  /// 숫자부 키의 셀 너비 (간격 제외, dp)
  double get numberKeyWidth =>
      math.max(0.0, blockWidth / numberColumns - horizontalGap);

  /// 상단 조작부·함수부 키의 셀 높이 (간격 제외, dp)
  double get functionKeyHeight =>
      math.max(0.0, functionRowHeight - verticalGap);

  /// 숫자부 키의 셀 높이 (간격 제외, dp)
  double get numberKeyHeight => math.max(0.0, numberRowHeight - verticalGap);

  /// 각인 띠 높이 (dp) — 함수부 셀 높이 × [CalcTheme.keyLegendHeightRatio]. 숫자부 키도 같은 높이다(#220 — 실물처럼
  /// 숫자부 셀이 높은 몫은 키캡이 받는다, [CalcTheme] "키캡 크기 (#220)" 절).
  double get legendBandHeight => _legendBandHeightOf(functionKeyHeight);

  /// 키캡 위 각인의 기준선을 키캡 위끝에서 띄우는 거리의 목표 (dp, #264) — 함수부 행 높이 ×
  /// [CalcTheme.keyLegendBaselineGapRatio]. 실제로 올리는 거리는 [legendBaseLift]다.
  double get legendBaselineGap =>
      functionRowHeight * CalcTheme.keyLegendBaselineGapRatio;

  /// 키캡 위 각인이 쓸 수 있는 높이 (dp, #264) — 각인 띠에 셀 위쪽 간격 몫(키 사이 세로 간격의 절반)을 더한 값이다.
  /// 글자 크기의 높이 기준과 [legendBaseLift]가 이 높이로 잰다. 한 줄 아래로 넘치는 각인을 더 올릴 때만(#260) 키 버튼이
  /// 간격의 나머지 절반까지 쓴다.
  double get legendExtent => legendBandHeight + verticalGap / 2;

  /// 상단 조작부·함수부 키캡 높이 (각인 띠 아래, 눌림 여유 포함, dp)
  double get functionCapHeight =>
      math.max(0.0, functionKeyHeight - legendBandHeight);

  /// 숫자부 키캡 높이 (각인 띠 아래, 눌림 여유 포함, dp)
  double get numberCapHeight =>
      math.max(0.0, numberKeyHeight - legendBandHeight);

  /// 상단 조작부·함수부의 그린 키캡 폭 (dp, #220) — [CalcKeyButton]이 같은 규칙([keyCapFaceWidth])으로 그린다
  double get functionCapWidth => _capFaceWidthOf(
    functionKeyWidth,
    functionCapHeight,
    CalcTheme.keyCapMaxAspectRatio,
  );

  /// 숫자부의 그린 키캡 폭 (dp, #220)
  double get numberCapWidth => _capFaceWidthOf(
    numberKeyWidth,
    numberCapHeight,
    CalcTheme.keyCapNumberMaxAspectRatio,
  );

  /// 숫자부 키(숫자·사칙연산·`=`·DEL·AC 등 [numberRows])인지 — 숫자부 글자 크기·키캡 비 상한을 고를 때 쓴다
  static bool isNumberKey(CalcKeyId id) => _numberKeyIds.contains(id);

  static final Set<CalcKeyId> _numberKeyIds = {
    for (final row in numberRows)
      for (final def in row) def.id,
  };

  /// 숫자부 키 [def]의 메인 각인 종류 (#225) — 숫자부가 아니면 `null`.
  /// - [NumberLabelKind.operator]: 연산 기호 한 글자([CalcTheme.isKeyOperatorLegend]) — × ÷ + − =
  /// - [NumberLabelKind.word]: 두 글자 이상(한 줄 표기 기준) — DEL·AC·Ans·×10ˣ
  /// - [NumberLabelKind.digit]: 나머지 한 글자 — 0~9·소수점
  static NumberLabelKind? numberLabelKindOf(CalcKeyDef def) {
    if (!isNumberKey(def.id)) return null;
    if (CalcTheme.isKeyOperatorLegend(def.mainLegend)) {
      return NumberLabelKind.operator;
    }
    return def.mainLegend.plainText.runes.length > 1
        ? NumberLabelKind.word
        : NumberLabelKind.digit;
  }

  /// 키 [def]에 주입할 메인 라벨 글자 크기 (배율 반영 전, dp) — 상단 조작부·함수부는 [mainLabelFontSize], 숫자부는 각인
  /// 종류([numberLabelKindOf])별 크기다(#156·#225).
  double mainLabelFontSizeOf(CalcKeyDef def) =>
      switch (numberLabelKindOf(def)) {
        null => mainLabelFontSize,
        NumberLabelKind.digit => numberMainLabelFontSize,
        NumberLabelKind.word => numberWordLabelFontSize,
        NumberLabelKind.operator => numberOperatorLabelFontSize,
      };

  /// [id] 키캡의 가로/세로 비 상한 (#220) — 숫자부는 [CalcTheme.keyCapNumberMaxAspectRatio], 나머지는
  /// [CalcTheme.keyCapMaxAspectRatio]. 키패드가 키에 주는 값과 글자 크기 계산이 같은 값을 쓴다.
  static double keycapMaxAspectRatioOf(CalcKeyId id) => isNumberKey(id)
      ? CalcTheme.keyCapNumberMaxAspectRatio
      : CalcTheme.keyCapMaxAspectRatio;

  /// 함수부 셀 높이 [functionCell]의 각인 띠 높이 (dp)
  static double _legendBandHeightOf(double functionCell) =>
      math.max(0.0, functionCell) * CalcTheme.keyLegendHeightRatio;

  /// 키캡 높이 [capHeight](눌림 여유 포함)의 그린 키캡 폭 — [CalcKeyButton]처럼 눌림 여유를 뺀 높이로 비를 잰다
  static double _capFaceWidthOf(
    double cellWidth,
    double capHeight,
    double maxAspectRatio,
  ) => keyCapFaceWidth(
    cellWidth: cellWidth,
    faceHeight: capHeight - math.min(CalcTheme.keyPressedOffset, capHeight),
    maxAspectRatio: maxAspectRatio,
  );

  /// [available] 영역 안에서 [arrangement] 배열이 세로로 길어지지 않는 가장 큰 키패드 크기.
  ///
  /// 폭은 언제나 영역 폭 전체다 — 가로 쪽 상한은 없다(#141, 사용자 결정 "가로로는 구역을 끝까지 채운다").
  /// 높이만 영역 높이와 다음 상한 중 작은 쪽으로 줄인다. 그래서 키는 가로로 넓어질 수는 있어도 세로로 길어지지 않는다.
  /// - [KeypadArrangement.standard]: 키패드 폭 / [CalcTheme.keypadMinAspectRatio].
  /// - [KeypadArrangement.wide]: 블록 폭 / ([CalcTheme.keypadMinAspectRatio] × [wideHeightFactor]) — 같은 행 높이의
  ///   표준 키패드와 키 모양의 세로 한계가 같다. 블록 폭은 영역 폭에서 블록 사이 간격
  ///   (블록 폭 × [CalcTheme.keypadWideSectionGapRatio], [minSectionGap]이 더 넓으면 그 값 — [wideBlockWidthOf])을 뺀 절반이다.
  static Size fitSize(
    Size available, [
    KeypadArrangement arrangement = KeypadArrangement.standard,
    double minSectionGap = 0,
  ]) {
    final width = available.width.isFinite
        ? math.max(0.0, available.width)
        : 0.0;
    final availableHeight = math.max(0.0, available.height);
    final maxHeight = switch (arrangement) {
      KeypadArrangement.standard => width / CalcTheme.keypadMinAspectRatio,
      KeypadArrangement.wide =>
        wideBlockWidthOf(width, minSectionGap: minSectionGap) /
            (CalcTheme.keypadMinAspectRatio * wideHeightFactor),
    };
    return Size(width, math.min(availableHeight, maxHeight));
  }

  /// [available] 영역에서 키가 더 큰 배열 — [KeypadArrangement.wide]의 가장 낮은 키 셀([minKeyCellHeightOf])이
  /// [KeypadArrangement.standard]보다 **높을 때만** wide다(같으면 실물 배열). 가로 접힘선 기준 배치의 아래 패널에서 쓴다
  /// (#80, #143). 셀 높이로 비교하는 이유는 가로형·세로형 비교(`CalculatorScreen`, #142)와 같다 — 터치 높이는 키가 커질 때
  /// 각인 띠를 빼며 한 번 줄어 큰 영역의 비교가 뒤집힌다. #143 전에는 터치 높이로 비교했다.
  static KeypadArrangement preferredArrangementFor(Size available) =>
      minKeyCellHeightOf(available, KeypadArrangement.wide) >
          minKeyCellHeightOf(available, KeypadArrangement.standard)
      ? KeypadArrangement.wide
      : KeypadArrangement.standard;

  /// 키패드 크기 [size]의 치수:
  /// (블록 폭, 키 사이 가로 간격, 키 사이 세로 간격, 구역 간격, 함수부 행 높이, 숫자부 행 높이)
  static (double, double, double, double, double, double) _geometryOf(
    Size size,
    KeypadArrangement arrangement, [
    double minSectionGap = 0,
  ]) {
    switch (arrangement) {
      case KeypadArrangement.standard:
        final sectionGap = size.height * CalcTheme.keypadSectionGapRatio;
        final rowUnit =
            math.max(0.0, size.height - sectionGap) / _standardRowUnits;
        return (
          size.width,
          size.width * CalcTheme.keyHorizontalGapRatio,
          size.height * CalcTheme.keyVerticalGapRatio,
          sectionGap,
          rowUnit,
          rowUnit * CalcTheme.keypadNumberRowHeightRatio,
        );
      case KeypadArrangement.wide:
        final block = wideBlockWidthOf(
          size.width,
          minSectionGap: minSectionGap,
        );
        return (
          block,
          block * CalcTheme.keyHorizontalGapRatio,
          // 함수부 행 높이가 같은 표준 키패드와 같은 세로 간격
          size.height * wideHeightFactor * CalcTheme.keyVerticalGapRatio,
          math.max(0.0, size.width - 2 * block),
          size.height / functionRowCount,
          size.height / numberRows.length,
        );
    }
  }

  /// [available] 영역에 [arrangement] 배열 키패드를 놓았을 때 가장 낮은 키의 셀 높이 (dp, 키 사이 간격 제외 — 각인 띠와
  /// 키캡을 합친 높이, 커서 패드 제외). 두 배열 모두 함수부 행이 가장 낮다.
  ///
  /// 키패드 크기에 대해 단조 증가한다 — 세로형과 가로형 중 키가 큰 쪽을 고를 때 쓴다(#142). [minKeyTouchHeightOf]는
  /// 키캡이 [CalcTheme.keyMinTouchTargetHeight]를 넘는 순간 각인 띠를 터치 영역에서 빼므로 키가 커질 때 줄어든다 — 실물
  /// 배열은 두 번이다(#220 뒤: 함수부 셀 약 50.3dp에서 숫자부 키캡이 48dp를 넘어 50.2 → 48dp, 함수부 셀 66.7dp에서 함수부
  /// 키캡이 넘어 63.7 → 48dp). 그 값으로 비교하면 키가 큰 배치를 버리게 된다 — 창 920×1100(인셋 없음, 본체 904×1084)은
  /// 세로형(셀 68.2dp, 터치 49.1dp)이 가로형(셀·터치 49.7dp)보다 키가 큰데 터치 높이로는 가로형이 이긴다.
  static double minKeyCellHeightOf(
    Size available,
    KeypadArrangement arrangement, {
    double minSectionGap = 0,
  }) {
    final (
      _,
      _,
      verticalGap,
      _,
      functionRowHeight,
      numberRowHeight,
    ) = _geometryOf(
      fitSize(available, arrangement, minSectionGap),
      arrangement,
      minSectionGap,
    );
    return math.max(
      0.0,
      math.min(functionRowHeight, numberRowHeight) - verticalGap,
    );
  }

  /// [available] 영역에 [arrangement] 배열 키패드를 놓았을 때 가장 낮은 키의 터치 높이 (dp, 커서 패드 제외).
  ///
  /// [CalcKeyButton]과 같은 규칙으로 구한다: 키캡이 [CalcTheme.keyMinTouchTargetHeight]보다 낮으면 각인 띠까지
  /// 넓힌 셀 높이, 아니면 키캡 높이. 셀 둘레 키 사이 간격 몫(#236 — 셀 전체를 터치하는 키가 더 받는 위아래 간격)은 빼고
  /// 잰다. 배치 판정의 문턱(#38 등)이 이 값으로 정해져 있어서다 — 실제 터치 높이는 여기에 행 간격 몫을 더한 값이다.
  /// 글자 크기를 재지 않으므로 [compute]보다 가볍다 — 배치를 고를 때 쓴다 (#25).
  ///
  /// [arrangement]는 기본값 없이 받는다 — 빠뜨리면 넓은 배열 키패드를 실물 배열로 재어 배치 판정이 조용히 틀린다(#80 R1).
  static double minKeyTouchHeightOf(
    Size available,
    KeypadArrangement arrangement, {
    double minSectionGap = 0,
  }) {
    final (
      _,
      _,
      verticalGap,
      _,
      functionRowHeight,
      numberRowHeight,
    ) = _geometryOf(
      fitSize(available, arrangement, minSectionGap),
      arrangement,
      minSectionGap,
    );
    // 각인 띠는 모든 구역이 함수부 띠 높이다 (#220).
    final band = _legendBandHeightOf(functionRowHeight - verticalGap);
    double touchOf(double rowHeight) {
      final cell = math.max(0.0, rowHeight - verticalGap);
      final cap = math.max(0.0, cell - band);
      return cap < CalcTheme.keyMinTouchTargetHeight ? cell : cap;
    }

    return math.min(touchOf(functionRowHeight), touchOf(numberRowHeight));
  }

  /// 높이 기준 글자 크기: 배율을 반영한 한 줄 높이(정수 올림, [fitFontSizeToHeight])와 [tallLegends]
  /// (한 줄보다 높을 수 있는 2차원 각인, #155)의 실제 높이([KeyLegendView.tallestAt])가 모두 [maxHeight] 이하인
  /// 가장 큰 글자 크기 (배율 반영 전).
  ///
  /// 2차원 각인의 높이는 잉크(비례)와 한 줄 상자(작은 글자에서 반올림)를 합친 값이다. 비례 높이로만 판정하면
  /// 작은 글자에서 넘치고(#155 R2), 전체를 정수로 올리면 실제로는 들어가는데도 줄어든다(#155 R1). 그래서 실제
  /// 높이로 판정한다. 테스트가 같은 판정을 쓰도록 공개한다.
  @visibleForTesting
  static double fitToHeight(
    double fontSize, {
    required double maxHeight,
    required TextScaler textScaler,
    required TextStyle style,
    required List<KeyLegendEmMetrics> tallLegends,
  }) => _fitToHeight(
    fontSize,
    maxHeight: maxHeight,
    textScaler: textScaler,
    style: style,
    tallLegends: tallLegends,
  );

  /// 숫자부 연산 기호 메인 각인 가운데 가장 높은 잉크 (글자 크기 대비, #264) — 기호 글자 크기의 높이 기준이다
  /// ([mainLegendInkHeight], 잉크 범위 표 `KeyLegendView.glyphInk`).
  static double get _tallestOperatorInkEm => [
    for (final def in allKeys)
      if (CalcTheme.isKeyOperatorLegend(def.mainLegend))
        mainLegendInkHeight(
          def.mainLegend,
          CalcTheme.keyNumberOperatorLabelStyle,
        ),
  ].reduce(math.max);

  static double _fitToHeight(
    double fontSize, {
    required double maxHeight,
    required TextScaler textScaler,
    required TextStyle style,
    required List<KeyLegendEmMetrics> tallLegends,
  }) => fitFontSize(
    fontSize,
    textScaler: textScaler,
    fits: (scaled) =>
        (scaled * (style.height ?? 1.0)).ceilToDouble() <= maxHeight &&
        (tallLegends.isEmpty ||
            KeyLegendView.tallestAt(tallLegends, style, scaled) <= maxHeight),
  );

  /// [available] 영역과 시스템 글자 배율([textScaler], `MediaQuery` 값 그대로)로 치수를 계산한다.
  ///
  /// ## 글자 크기 통일
  /// 각인·메인 라벨 글자 크기를 각각 하나로 정해 모든 키에 주입한다. 배율은 [CalcKeyButton]과 같이
  /// [CalcTheme.keyMaxTextScaleFactor]까지 반영하며, 다음 순서로 정한다.
  /// 1. **높이 기준**: 함수부 셀 높이에서 [CalcKeyButton]과 같은 비율(실물 비율, [CalcTheme] "글자 크기 실물 대조 (#264)"
  ///    절)로 구한 크기를, 배율을 반영해도 각인이 쓸 수 있는 높이([legendExtent] — 각인을 키캡에서 띄울 자리
  ///    [legendBaseLift]를 뺀 나머지)·키캡 안쪽 높이를 넘지 않도록 줄인다.
  ///    글자 크기 상한은 없다(#264, 사용자 결정 — 키가 커지면 글자도 실물 비율로 커진다. #141의 상한을 없앴다).
  ///    폭 기준은 줄이기만 하므로 키가 가로로 넓어져도 글자는 이 높이 기준보다 커지지 않는다.
  /// 2. **폭 기준**: 실제 글꼴로 모든 라벨의 폭을 재어, 배율을 반영해도 메인 라벨은 자기 키의 그린 키캡 폭(#220)에,
  ///    키캡 위 각인은 셀 폭(#264 — 긴 각인 쌍은 실물처럼 키캡보다 넓게 인쇄한다)에 들어가는 크기까지 줄인다. 그래서
  ///    대부분의 키는 `FittedBox`가 따로 줄이지 않고 같은 크기로 그려진다.
  /// 3. **하한**: 긴 라벨 몇 개 때문에 전체가 지나치게 작아지지 않도록, 높이 기준의
  ///    [CalcTheme.keypadUniformFontMinRatio]배 아래로는 내리지 않는다. 이보다 긴 라벨만
  ///    `FittedBox`가 개별로 줄인다.
  /// 4. **숫자부 메인 라벨** (#156·#225): 1~3으로 정한 메인 크기는 상단 조작부·함수부 키에 쓴다. 숫자부 숫자는 숫자부
  ///    키캡 높이 × [CalcTheme.keyNumberMainLabelFontRatio]를 목표로 키캡 높이·숫자 폭에 들어가게 줄이고(함수부 크기
  ///    아래로는 내리지 않는다), 글자 각인·연산 기호는 그 숫자 크기의 배수를 목표로 각각 키캡 높이·자기 폭에 맞춘다
  ///    ([numberMainLabelFontSize]·[numberWordLabelFontSize]·[numberOperatorLabelFontSize]). 연산 기호의 높이는 줄 상자가
  ///    아니라 잉크로 잰다(#264 — 기호 잉크는 글자 크기의 절반쯤이라, 줄 상자로 재면 숫자보다 훨씬 작아진다).
  ///
  /// 커서 패드 키(화살표 한 글자)는 키캡 상자(패드 반쪽)가 함수부 키캡보다 크므로 폭 계산에서 뺀다.
  ///
  /// 각인은 [releasedFeatures]가 배포됐을 때 인쇄하는 것만 잰다(#267 — 키 버튼이 그리는 목록과 같아야 한다).
  factory KeypadMetrics.compute(
    Size available,
    TextScaler textScaler, {
    KeypadArrangement arrangement = KeypadArrangement.standard,
    Set<KeyFeature> releasedFeatures = releasedKeyFeatures,
    double minSectionGap = 0,
  }) {
    final size = fitSize(available, arrangement, minSectionGap);
    final (
      blockWidth,
      horizontalGap,
      verticalGap,
      sectionGap,
      functionRowHeight,
      numberRowHeight,
    ) = _geometryOf(
      size,
      arrangement,
      minSectionGap,
    );

    // CalcKeyButton 내부 치수와 같은 방식으로 각인 띠·키캡 높이를 구한다. 각인 띠는 모든 구역이 함수부 띠 높이다(#220).
    final cellHeight = math.max(0.0, functionRowHeight - verticalGap);
    final legendHeight = _legendBandHeightOf(cellHeight);
    double capHeightOf(double rowHeight) =>
        math.max(0.0, rowHeight - verticalGap - legendHeight);
    final capHeight = capHeightOf(functionRowHeight);
    final scaler = textScaler.clamp(
      maxScaleFactor: CalcTheme.keyMaxTextScaleFactor,
    );
    final functionKeyWidth = math.max(
      0.0,
      blockWidth / functionColumns - horizontalGap,
    );
    final numberKeyWidth = math.max(
      0.0,
      blockWidth / numberColumns - horizontalGap,
    );
    final limits = _LabelLimits.measure(
      functionKeyWidth: functionKeyWidth,
      numberKeyWidth: numberKeyWidth,
      // 메인 라벨은 그린 키캡 폭에 맞춘다 (#220 — 키캡이 셀보다 좁을 수 있다)
      functionCapWidth: _capFaceWidthOf(
        functionKeyWidth,
        capHeight,
        CalcTheme.keyCapMaxAspectRatio,
      ),
      numberCapWidth: _capFaceWidthOf(
        numberKeyWidth,
        capHeightOf(numberRowHeight),
        CalcTheme.keyCapNumberMaxAspectRatio,
      ),
      releasedFeatures: releasedFeatures,
    );

    // 1. 높이 기준 — 실물 비율이고 상한은 없다 (#264). 가장 높은 각인(분수 등 2차원 각인, #155)까지
    //    띠·키캡 안에 들어가게 한다.
    // 각인은 띠에 셀 위쪽 간격 몫을 더한 높이까지 쓴다 (#264 — CalcKeyButton의 각인 줄과 같다). 그 높이에서 각인을 올릴
    // 자리(기준선을 키캡 위끝에서 띄우는 거리 − 줄 상자 깊이)를 먼저 뗀 나머지에 가장 높은 각인이 들어가는 크기까지 줄인다
    // — 글자 배율이 커도 각인이 키캡에 붙지 않는다(R1: 올릴 자리를 떼지 않으면 배율 1.3의 낮은 키패드에서 올림이 0이 된다).
    const legendStyle = CalcTheme.keyShiftLabelStyle;
    final legendExtent = legendHeight + verticalGap / 2;
    final legendBaselineGap =
        functionRowHeight * CalcTheme.keyLegendBaselineGapRatio;
    final legendLine = KeyLegendView.emMetrics(
      const LegendText(' '),
      legendStyle,
    );
    // 그리는 글자 크기 [scaled]에서 올릴 거리(목표 − 그린 줄 상자 깊이)와, 가장 높은 각인(한 줄 상자·2차원 각인)의 높이
    double legendLiftAt(double scaled) => math.max(
      0.0,
      legendBaselineGap - KeyLegendView.lineDepthAt(legendStyle, scaled),
    );
    double tallestLegendAt(double scaled) => KeyLegendView.tallestAt(
      [legendLine, ...limits.tallLegends],
      legendStyle,
      scaled,
    );
    // 그린 줄 상자의 높이·깊이는 정수 dp로 반올림돼 이 조건은 글자 크기에 단조가 아니다 — 이분 탐색([fitFontSize])은 맞는
    // 크기를 지나쳐 각인을 더 작게 정하므로(R2), 위에서부터 훑는 탐색([fitFontSizeScanning])을 쓴다.
    bool legendFitsHeight(double scaled) =>
        (scaled * (legendStyle.height ?? 1.0)).ceilToDouble() +
                legendLiftAt(scaled) <=
            legendExtent &&
        tallestLegendAt(scaled) + legendLiftAt(scaled) <= legendExtent;
    final legendByHeight = fitFontSizeScanning(
      math.max(minFittedFontSize, legendHeight * CalcTheme.keyLegendFontRatio),
      textScaler: scaler,
      fits: legendFitsHeight,
    );
    // 키캡 안쪽 높이: 눌림 이동 여유와 테두리를 뺀다.
    final capInnerHeight =
        capHeight -
        math.min(CalcTheme.keyPressedOffset, capHeight) -
        2 * CalcTheme.keyBorderWidth;
    final mainByHeight = _fitToHeight(
      math.max(minFittedFontSize, capHeight * CalcTheme.keyMainLabelFontRatio),
      maxHeight: capInnerHeight,
      textScaler: scaler,
      style: CalcTheme.keyMainLabelStyle,
      tallLegends: limits.tallMains,
    );

    // 2·3. 폭 기준 + 하한
    final widths = limits;
    double unify(double byHeight, double maxScaledByWidth) => math.max(
      fitFontSize(
        byHeight,
        textScaler: scaler,
        fits: (scaled) => scaled <= maxScaledByWidth,
      ),
      byHeight * CalcTheme.keypadUniformFontMinRatio,
    );

    final mainLabelFontSize = unify(mainByHeight, widths.main);

    // 4. 숫자부 메인 라벨 (#156·#225) — 숫자는 숫자부 키캡 높이의 비율을 목표로, 글자 각인·연산 기호는 숫자 크기의 배수를
    //    목표로 각각 키캡 높이·자기 폭에 들어가게 줄인다. 숫자·글자 각인은 함수부보다, 연산 기호는 숫자보다 작아지지 않는다.
    final numberCapHeight = capHeightOf(numberRowHeight);
    final numberCapInnerHeight =
        numberCapHeight -
        math.min(CalcTheme.keyPressedOffset, numberCapHeight) -
        2 * CalcTheme.keyBorderWidth;
    // [inkHeightEm]을 주면 높이를 줄 상자가 아니라 그 잉크 높이(글자 크기 대비)로 잰다 — 연산 기호 (#264)
    double fitNumber(
      double target, {
      required double floor,
      required double maxScaledByWidth,
      required TextStyle style,
      List<KeyLegendEmMetrics> tallLegends = const [],
      double? inkHeightEm,
    }) => math.max(
      floor,
      fitFontSize(
        inkHeightEm == null
            ? _fitToHeight(
                math.max(minFittedFontSize, target),
                maxHeight: numberCapInnerHeight,
                textScaler: scaler,
                style: style,
                tallLegends: tallLegends,
              )
            : fitFontSize(
                math.max(minFittedFontSize, target),
                textScaler: scaler,
                fits: (scaled) => scaled * inkHeightEm <= numberCapInnerHeight,
              ),
        textScaler: scaler,
        fits: (scaled) => scaled <= maxScaledByWidth,
      ),
    );
    final numberMainLabelFontSize = fitNumber(
      numberCapHeight * CalcTheme.keyNumberMainLabelFontRatio,
      floor: mainLabelFontSize,
      maxScaledByWidth: widths.numberMain,
      style: CalcTheme.keyMainLabelStyle,
    );
    final numberWordLabelFontSize = fitNumber(
      numberMainLabelFontSize * CalcTheme.keyNumberWordLabelScale,
      floor: mainLabelFontSize,
      maxScaledByWidth: widths.numberWord,
      style: CalcTheme.keyMainLabelStyle,
      tallLegends: limits.tallNumberMains,
    );
    final numberOperatorLabelFontSize = fitNumber(
      numberMainLabelFontSize * CalcTheme.keyNumberOperatorLabelScale,
      floor: numberMainLabelFontSize,
      maxScaledByWidth: widths.numberOperator,
      style: CalcTheme.keyNumberOperatorLabelStyle,
      inkHeightEm: _tallestOperatorInkEm,
    );

    // 키캡 위 각인을 띠 아래끝에서 올리는 거리 (#264) — 기준선이 키캡 위끝에서 목표만큼 떨어지는 거리(목표 − 그린 줄 상자
    // 깊이)다. 높이 기준이 그 자리를 떼어 두었으므로 목표 그대로다. 모든 키가 같은 거리라 기준선이 한 줄이다.
    // 폭 기준으로 줄인 크기에서 높이 조건을 한 번 더 본다 — 조건이 단조가 아니라, 높이 기준 크기보다 작은 크기에서 올릴
    // 자리가 조금(1dp 미만) 모자랄 수 있다(가로 태블릿 1280×800 배율 1.3에서 0.2dp).
    // (가장 높은 각인이 쓸 수 있는 높이를 넘지 않게 하는 상한은, 글자 크기가 하한 [minFittedFontSize]에서도 높이 조건을
    // 만족하지 못하는 경우의 안전망이다 — 실제 키패드 크기에서는 닿지 않는다.)
    final legendFontSize = fitFontSizeScanning(
      unify(legendByHeight, widths.legend),
      textScaler: scaler,
      fits: legendFitsHeight,
    );
    final scaledLegendFontSize = scaler.scale(legendFontSize);
    final legendBaseLift = math.max(
      0.0,
      math.min(
        legendLiftAt(scaledLegendFontSize),
        legendExtent - tallestLegendAt(scaledLegendFontSize),
      ),
    );

    return KeypadMetrics._(
      arrangement: arrangement,
      size: size,
      blockWidth: blockWidth,
      horizontalGap: horizontalGap,
      verticalGap: verticalGap,
      sectionGap: sectionGap,
      functionRowHeight: functionRowHeight,
      numberRowHeight: numberRowHeight,
      legendFontSize: legendFontSize,
      legendBaseLift: legendBaseLift,
      mainLabelFontSize: mainLabelFontSize,
      numberMainLabelFontSize: numberMainLabelFontSize,
      numberWordLabelFontSize: numberWordLabelFontSize,
      numberOperatorLabelFontSize: numberOperatorLabelFontSize,
      extendFunctionHitArea: capHeight < CalcTheme.keyMinTouchTargetHeight,
      extendNumberHitArea:
          capHeightOf(numberRowHeight) < CalcTheme.keyMinTouchTargetHeight,
    );
  }
}

/// 모든 라벨이 자기 키의 그린 키캡 폭(#220 — 원형 버튼의 각인 줄은 셀 폭)에 들어가는 (배율 반영) 최대 글자 크기와,
/// 가장 높은 라벨의 높이.
///
/// 크기는 실제 글꼴로 그린 각인 크기([KeyLegendView.emSize] — 2차원 각인 포함, 글자 크기 1dp당 값)로 잰다.
/// (키 라벨 스타일은 `letterSpacing: 0`을 명시하므로 자간 때문에 폭이 글자 크기에 비례하지 않는 일은 없다.)
class _LabelLimits {
  /// 메인 라벨 최대 글자 크기 (배율 반영 후, dp) — 숫자부를 뺀 키
  final double main;

  /// 숫자부 숫자(0~9·소수점) 최대 글자 크기 (배율 반영 후, dp, #156·#225)
  final double numberMain;

  /// 숫자부 글자 각인(DEL·AC·Ans·×10ˣ) 최대 글자 크기 (배율 반영 후, dp, #225)
  final double numberWord;

  /// 숫자부 연산 기호(× ÷ + − =) 최대 글자 크기 (배율 반영 후, dp, #225)
  final double numberOperator;

  /// 각인 최대 글자 크기 (배율 반영 후, dp)
  final double legend;

  /// 2차원 메인 각인의 em 치수 (한 줄보다 높을 수 있어 높이 기준이 함께 잰다, #155) — 숫자부를 뺀 키
  final List<KeyLegendEmMetrics> tallMains;

  /// 숫자부 2차원 메인 각인(`×10ˣ` — 글자 각인)의 em 치수 (#156)
  final List<KeyLegendEmMetrics> tallNumberMains;

  /// 2차원 SHIFT·ALPHA 각인의 em 치수
  final List<KeyLegendEmMetrics> tallLegends;

  const _LabelLimits(
    this.main,
    this.numberMain,
    this.numberWord,
    this.numberOperator,
    this.legend,
    this.tallMains,
    this.tallNumberMains,
    this.tallLegends,
  );

  static double _emWidth(KeyLegend legend, TextStyle style) =>
      KeyLegendView.emSize(legend, style).width;

  /// [where]가 있으면 그 키만 잰다(테스트용 — [KeypadMetrics.debugWidthLimits]).
  /// 메인 라벨은 그린 키캡 폭([functionCapWidth]·[numberCapWidth], #220)에, SHIFT·ALPHA 각인과 원형 버튼의 각인 줄은 셀
  /// 너비([functionKeyWidth]·[numberKeyWidth])에 맞춘다(#264 — 각인은 그린 키캡에 맞춰 놓되 긴 쌍은 셀 폭까지 쓴다).
  static _LabelLimits measure({
    required double functionKeyWidth,
    required double numberKeyWidth,
    required double functionCapWidth,
    required double numberCapWidth,
    required Set<KeyFeature> releasedFeatures,
    bool Function(CalcKeyDef def)? where,
  }) {
    var main = double.infinity;
    var numberMain = double.infinity;
    var numberWord = double.infinity;
    var numberOperator = double.infinity;
    var legend = double.infinity;
    final tallMains = <KeyLegendEmMetrics>[];
    final tallNumberMains = <KeyLegendEmMetrics>[];
    final tallLegends = <KeyLegendEmMetrics>[];
    final cursorIds = {for (final def in cursorPad.all) def.id};

    for (final def in allKeys) {
      if (cursorIds.contains(def.id)) continue;
      if (where != null && !where(def)) continue;
      final number = KeypadMetrics.isNumberKey(def.id);
      final width = number ? numberKeyWidth : functionKeyWidth;

      // 원형 버튼(#190): 버튼 면에는 글자가 없고, 메인 각인만 각인 띠에 인쇄한다(CalcKeyButton의 `_BodyPrintLabel` —
      // 원형 버튼에는 SHIFT·ALPHA 각인이 없다, #253). 띠 폭에 그 각인이 들어가는 각인 크기까지 줄인다.
      if (def.face == KeyFace.roundButton) {
        const style = CalcTheme.keyBodyPrintStyle;
        if (!def.mainLegend.isPlain) {
          tallLegends.add(KeyLegendView.emMetrics(def.mainLegend, style));
        }
        legend = math.min(legend, width / _emWidth(def.mainLegend, style));
        continue;
      }

      // 메인 라벨: 그린 키캡 폭에서 좌우 여백과 테두리를 뺀 폭 (CalcKeyButton의 키캡 배치와 같다)
      final capWidth = number ? numberCapWidth : functionCapWidth;
      final capInner =
          capWidth * (1 - 2 * CalcTheme.keyCapHorizontalPaddingRatio) -
          2 * CalcTheme.keyBorderWidth;
      final mainLimit =
          math.max(0.0, capInner) /
          _emWidth(
            def.mainLegend,
            CalcTheme.keyMainLabelStyleFor(def.mainLegend),
          );
      switch (KeypadMetrics.numberLabelKindOf(def)) {
        case null:
          main = math.min(main, mainLimit);
        case NumberLabelKind.digit:
          numberMain = math.min(numberMain, mainLimit);
        case NumberLabelKind.word:
          numberWord = math.min(numberWord, mainLimit);
        case NumberLabelKind.operator:
          numberOperator = math.min(numberOperator, mainLimit);
      }
      if (!def.mainLegend.isPlain) {
        (number ? tallNumberMains : tallMains).add(
          KeyLegendView.emMetrics(def.mainLegend, CalcTheme.keyMainLabelStyle),
        );
      }
      // 각인 띠의 각인 — 키 버튼이 그리는 목록 그대로다(SHIFT·ALPHA·모드 전용 각인, #266 [CalcKeyDef.bandLegendsIn].
      // 배포되지 않은 기능의 각인은 빠진다 — #267). 한쪽만 아는 각인이 생기면 그 키만 글자가 줄거나 기준선이 갈린다(#264 R1).
      final band = def.bandLegendsIn(releasedFeatures);
      for (final item in band) {
        if (!item.legend.isPlain) {
          tallLegends.add(
            KeyLegendView.emMetrics(item.legend, bandLegendStyle(item)),
          );
        }
      }

      // 각인: CalcKeyButton의 각인 띠와 같은 규칙. 두 각인이 함께 들어가려면 (어느 배분이든)
      // 두 폭의 합이 띠 폭 이하여야 하고, 짧은 쪽이 우선 배분을 받으면 절반 이하여야 한다.
      // 글자 수 비례 배분은 고정폭 글꼴에서 합 조건과 같다. 사이 간격은 상한으로 잡는다.
      // (두 칸 폭 `⇔`이 든 `a b/c⇔d/c`는 한 글자 `y`와 짝이라 우선 배분을 받으므로 비례 배분을 쓰지 않는다.)
      // 각인이 쓸 수 있는 폭은 셀 폭이다 (#264) — 각인은 그린 키캡에 맞춰 놓되(#220 R1, 좌우 자리 #265), 긴 각인은 실물
      // `Ran# RanInt`처럼 키캡 밖 셀 폭까지 쓴다. 바깥 끝을 들이는 거리(#265)는 떼어 두지 않는다 — 긴 쌍은 들이는
      // 거리를 줄인다(`keyLegendPairInset`). 사이 간격 상한은 그린 키캡 폭 기준이다(CalcKeyButton과 같다).
      // 각인의 폭은 괄호까지다([bandLegendEmWidth], #266).
      if (band.isEmpty) continue;
      if (band.length == 1) {
        legend = math.min(legend, width / bandLegendEmWidth(band.single));
        continue;
      }
      final usable = math.max(
        0.0,
        width -
            capWidth * CalcTheme.keyLegendGapMaxWidthRatio * (band.length - 1),
      );
      final totalEm = band.fold(
        0.0,
        (sum, item) => sum + bandLegendEmWidth(item),
      );
      legend = math.min(legend, usable / totalEm);
      // 셋 이상(ENG 키)은 함께 줄이므로 합 조건뿐이다. 둘이면 짧은 쪽의 우선 배분 조건을 더 본다.
      if (band.length > 2) continue;
      final firstRunes = band.first.legend.plainText.runes.length;
      final lastRunes = band.last.legend.plainText.runes.length;
      if (math.min(firstRunes, lastRunes) <=
          CalcTheme.keyLegendPriorityMaxRunes) {
        final shortEm = bandLegendEmWidth(
          firstRunes <= lastRunes ? band.first : band.last,
        );
        legend = math.min(legend, usable / 2 / shortEm);
      }
    }
    return _LabelLimits(
      main,
      numberMain,
      numberWord,
      numberOperator,
      legend,
      tallMains,
      tallNumberMains,
      tallLegends,
    );
  }
}

/// fx-991EX 50키 키패드.
///
/// 키 명세([controlLeftRows]·[cursorPad]·[controlRightRows]·[functionRows]·[numberRows])를
/// 실물 배열로 배치하고, 모든 키에 같은 글자 크기([KeypadMetrics])를 주입한다.
/// 상태 관리에 의존하지 않으며 입력은 콜백으로만 내보낸다.
///
/// ## 배치 계약
/// - 주어진 영역 안에서 [arrangement] 배열의 가로/세로 비를 제한한 크기([KeypadMetrics.fitSize])로 가운데 정렬한다.
///   제약이 무한한 축은 [fallbackSize]의 값을 쓴다. 배열은 호출자가 정한다 — 영역에서 키가 더 큰 배열은
///   [KeypadMetrics.preferredArrangementFor]로 고른다.
/// - [CalcKeyButton]은 누르는 순간 입력하므로 **스크롤 영역 안에 두지 않는다**.
/// - 키 사이 간격은 터치 영역에 넣지 않는다(실물처럼 인접 키 오입력을 막는 중립 영역).
///
/// ## 입력 계약
/// - 키를 누르면 [onKeyPressed], [autoRepeatKeys]를 누르고 있는 동안 [onKeyRepeat]을 호출한다.
///   모디파이어 해석(1회성 SHIFT/ALPHA)은 호출자(상태 머신)가 맡는다.
/// - 설정 키([settingsKey] — ON, #190)는 [onSettingsPressed]가 있으면 [onKeyPressed] 대신 그것을 부른다. 설정 키는
///   키보드 포커스를 받는다(`CalcKeyButton.focusable` — 없어진 설정 버튼의 키보드 경로, #106).
/// - [onKeyPressed]가 `null`이면 모든 키가 비활성이다(설정 키 포함).
class CalcKeypad extends StatelessWidget {
  /// 키 입력 콜백
  final ValueChanged<CalcKeyId>? onKeyPressed;

  /// 설정 키([settingsKey])를 눌렀을 때 [onKeyPressed] 대신 부르는 콜백. 인자는 설정 키 버튼의 context다 — 설정
  /// 대화상자를 그 키 쪽에 띄우는 기준 위치로 쓴다(`SettingsLauncher`). `null`이면 설정 키도 [onKeyPressed]로 간다.
  final ValueChanged<BuildContext>? onSettingsPressed;

  /// 반복 입력 콜백 ([autoRepeatKeys]에만 연결)
  final ValueChanged<CalcKeyId>? onKeyRepeat;

  /// 햅틱 피드백 사용 여부
  final bool enableHaptics;

  /// 구역 배열 (#80)
  final KeypadArrangement arrangement;

  /// [KeypadArrangement.wide]에서 숫자부를 함수부 왼쪽에 둘지 (#142 — 가로형 배치의 왼손잡이). 구역 안의 키 배열과
  /// 스크린리더 읽기 순서(함수부 다음 숫자부)는 그대로이고 블록의 좌우만 바뀐다. [KeypadArrangement.standard]에서는 쓰지 않는다.
  final bool numbersOnLeft;

  /// [KeypadArrangement.wide]의 블록 사이 최소 간격 (dp, #285) — 책 자세는 접힘선과 그 양쪽 여백이 두 블록 사이에 들어가게
  /// 이 값을 준다([KeypadMetrics.wideBlockWidthOf]). 0이면 보통 간격(블록 폭 × [CalcTheme.keypadWideSectionGapRatio])이다.
  /// [KeypadArrangement.standard]에서는 쓰지 않는다.
  final double minSectionGap;

  /// 각인 띠에 어느 기능의 각인까지 인쇄할지 (#267) — 기본은 배포된 기능([releasedKeyFeatures])이다. 글자 크기 계산
  /// ([KeypadMetrics.compute])과 키 버튼이 같은 값을 쓴다. 그리는 각인만 정한다(`CalcKeyButton.releasedFeatures`).
  final Set<KeyFeature> releasedFeatures;

  /// 제약이 무한한 축에 쓰는 기본 크기
  static const Size fallbackSize = Size(360, 420);

  const CalcKeypad({
    super.key,
    this.onKeyPressed,
    this.onKeyRepeat,
    this.onSettingsPressed,
    this.enableHaptics = true,
    this.arrangement = KeypadArrangement.standard,
    this.numbersOnLeft = false,
    this.minSectionGap = 0,
    this.releasedFeatures = releasedKeyFeatures,
  });

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    // 글꼴이 나중에 로드되면(웹 지연 로드, FontLoader 등) 라벨 폭 캐시가 비워진다. LayoutBuilder는
    // 제약이 바뀌지 않으면 다시 빌드하지 않으므로, 글꼴 변경 알림에 맞춰 다시 빌드해 글자 크기를
    // 새 글꼴로 다시 계산한다. 글꼴 변경은 드물어 평소 키 입력 리빌드에는 영향이 없다.
    return ListenableBuilder(
      listenable: PaintingBinding.instance.systemFonts,
      builder: (context, _) => _buildForFonts(textScaler),
    );
  }

  Widget _buildForFonts(TextScaler textScaler) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = Size(
          constraints.hasBoundedWidth
              ? constraints.maxWidth
              : fallbackSize.width,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : fallbackSize.height,
        );
        final metrics = KeypadMetrics.compute(
          available,
          textScaler,
          arrangement: arrangement,
          releasedFeatures: releasedFeatures,
          minSectionGap: arrangement == KeypadArrangement.wide
              ? minSectionGap
              : 0,
        );
        return Center(
          child: SizedBox.fromSize(
            key: const ValueKey('calc-keypad'),
            size: metrics.size,
            child: _KeypadBody(
              metrics: metrics,
              numbersOnLeft: numbersOnLeft,
              releasedFeatures: releasedFeatures,
              onKeyPressed: onKeyPressed,
              onKeyRepeat: onKeyRepeat,
              onSettingsPressed: onSettingsPressed,
              enableHaptics: enableHaptics,
            ),
          ),
        );
      },
    );
  }
}

class _KeypadBody extends StatelessWidget {
  final KeypadMetrics metrics;
  final bool numbersOnLeft;
  final Set<KeyFeature> releasedFeatures;
  final ValueChanged<CalcKeyId>? onKeyPressed;
  final ValueChanged<CalcKeyId>? onKeyRepeat;
  final ValueChanged<BuildContext>? onSettingsPressed;
  final bool enableHaptics;

  const _KeypadBody({
    required this.metrics,
    required this.numbersOnLeft,
    required this.releasedFeatures,
    required this.onKeyPressed,
    required this.onKeyRepeat,
    required this.onSettingsPressed,
    required this.enableHaptics,
  });

  EdgeInsets get _cellPadding => EdgeInsets.symmetric(
    horizontal: metrics.horizontalGap / 2,
    vertical: metrics.verticalGap / 2,
  );

  Widget _button(
    CalcKeyDef def, {
    bool showLegendBand = true,
    bool extendHitArea = false,
    Path Function(Size size)? shape,
    Path Function(Size size)? hitShape,
    EdgeInsets hitOutset = EdgeInsets.zero,
    EdgeInsets labelInsets = EdgeInsets.zero,
    EdgeInsets gapInsets = EdgeInsets.zero,
  }) {
    final settings = onSettingsPressed;
    if (def.id == settingsKey && settings != null && onKeyPressed != null) {
      // 설정 키는 자기 context(대화상자 기준 위치)를 넘겨야 하므로 Builder로 감싼다.
      return Builder(
        builder: (keyContext) => _keyButton(
          def,
          onPressed: (_) => settings(keyContext),
          showLegendBand: showLegendBand,
          extendHitArea: extendHitArea,
          shape: shape,
          hitShape: hitShape,
          hitOutset: hitOutset,
          labelInsets: labelInsets,
          gapInsets: gapInsets,
        ),
      );
    }
    return _keyButton(
      def,
      onPressed: onKeyPressed,
      showLegendBand: showLegendBand,
      extendHitArea: extendHitArea,
      shape: shape,
      hitShape: hitShape,
      hitOutset: hitOutset,
      labelInsets: labelInsets,
      gapInsets: gapInsets,
    );
  }

  Widget _keyButton(
    CalcKeyDef def, {
    required ValueChanged<CalcKeyId>? onPressed,
    required bool showLegendBand,
    required bool extendHitArea,
    required Path Function(Size size)? shape,
    required Path Function(Size size)? hitShape,
    required EdgeInsets hitOutset,
    required EdgeInsets labelInsets,
    required EdgeInsets gapInsets,
  }) {
    return CalcKeyButton(
      keyDef: def,
      shape: shape,
      hitShape: hitShape,
      hitOutset: hitOutset,
      labelInsets: labelInsets,
      onPressed: onPressed,
      onRepeat: autoRepeatKeys.contains(def.id) ? onKeyRepeat : null,
      enableHaptics: enableHaptics,
      showLegendBand: showLegendBand,
      extendHitAreaToLegend: showLegendBand && extendHitArea,
      legendFontSize: metrics.legendFontSize,
      // 숫자부 키는 각인 종류별 크기로 그린다 (#156·#225)
      mainLabelFontSize: metrics.mainLabelFontSizeOf(def),
      // 모든 구역이 함수부와 같은 각인 띠, 구역별 키캡 가로/세로 비 상한 (#220)
      legendHeight: metrics.legendBandHeight,
      // 각인 기준선을 키캡 위끝에서 띄운다 (#264)
      legendBaseLift: metrics.legendBaseLift,
      // 글자 크기를 잰 각인 목록 그대로 그린다 (#267)
      releasedFeatures: releasedFeatures,
      keycapMaxAspectRatio: KeypadMetrics.keycapMaxAspectRatioOf(def.id),
      focusable: def.id == settingsKey,
      gapInsets: gapInsets,
    );
  }

  /// 행 목록을 같은 높이의 행 × 같은 폭의 열로 배치한다.
  Widget _grid(List<List<CalcKeyDef>> rows, {required bool extendHitArea}) {
    return Column(
      children: [
        for (final row in rows)
          Expanded(
            child: Row(
              children: [
                for (final def in row)
                  Expanded(
                    child: Padding(
                      padding: _cellPadding,
                      // 셀 둘레 여백(키 사이 간격의 절반)은 이 키의 몫이다 — 터치를 넓힌 키는 여기까지 받는다 (#236).
                      child: _button(
                        def,
                        extendHitArea: extendHitArea,
                        gapInsets: _cellPadding,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// 구역 하나를 스크린리더 탐색 단위로 묶는다 — 넓은 배열에서 두 구역의 행 높이가 달라, 묶지 않으면 화면 위치순
  /// 정렬이 함수부와 숫자부 키를 섞어 읽는다. 키는 각자 노드로 남는다(`explicitChildNodes`).
  /// 구역 순서는 [order]로 정한다 — 숫자부를 왼쪽에 둔 넓은 배열(#142)도 화면 위치와 무관하게 함수부를 먼저 읽는다.
  static Widget _section(Widget child, double order) => Semantics(
    container: true,
    explicitChildNodes: true,
    sortKey: OrdinalSortKey(order),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final controlHeight =
        metrics.functionRowHeight * KeypadMetrics.controlRowCount;
    final extendFunction = metrics.extendFunctionHitArea;
    final wide = metrics.arrangement == KeypadArrangement.wide;
    // 두 배열을 같은 위젯 트리(`Flex` + 같은 자식 종류·순서)로 그린다 — 테이블톱 자세로 접고 펼 때 배열이 바뀌어도
    // 키 element가 유지되어 키 눌림 상태와 스크린리더 포커스가 사라지지 않는다 (#80, `_Body`의 배치 전환과 같은 이유).
    return Flex(
      direction: wide ? Axis.horizontal : Axis.vertical,
      // 넓은 배열의 좌우 대칭(#142)은 블록 순서만 거꾸로 놓는다 — 자식 순서·종류가 그대로라 손잡이를 바꿔도 키
      // element가 유지된다. 구역 안의 키 줄(`Row`)은 이 값을 물려받지 않아 키 배열은 실물 그대로다.
      textDirection: wide && numbersOnLeft
          ? TextDirection.rtl
          : TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 상단 조작부 + 함수부 — 표준 배열은 위, 넓은 배열은 왼쪽 블록
        SizedBox(
          width: wide ? metrics.blockWidth : null,
          height: wide
              ? null
              : metrics.functionRowHeight * KeypadMetrics.functionRowCount,
          child: _section(
            Column(
              children: [
                _controlSection(controlHeight, extendFunction),
                // 함수부는 블록의 남은 높이를 모두 쓴다 (부동소수 오차로 넘치지 않게).
                Expanded(
                  child: _grid(functionRows, extendHitArea: extendFunction),
                ),
              ],
            ),
            0,
          ),
        ),
        SizedBox(
          width: wide ? metrics.sectionGap : null,
          height: wide ? null : metrics.sectionGap,
        ),
        // 숫자부는 남은 높이(넓은 배열은 남은 폭)를 모두 쓴다 (부동소수 오차로 넘치지 않게).
        Expanded(
          child: _section(
            _grid(numberRows, extendHitArea: metrics.extendNumberHitArea),
            1,
          ),
        ),
      ],
    );
  }

  /// 상단 조작부: 좌 2×2 / 커서 패드 / 우 2×2 (각 2열 폭)
  Widget _controlSection(double controlHeight, bool extendFunction) {
    return SizedBox(
      height: controlHeight,
      child: Row(
        children: [
          Expanded(
            child: _grid(controlLeftRows, extendHitArea: extendFunction),
          ),
          Expanded(
            child: Padding(
              padding: _cellPadding,
              child: CursorPad(
                gapInsets: _cellPadding,
                buttonBuilder: (def, keyShape) => _button(
                  def,
                  showLegendBand: false,
                  shape: keyShape.shape,
                  hitShape: keyShape.hitShape,
                  hitOutset: keyShape.hitOutset,
                  labelInsets: keyShape.labelInsets,
                  gapInsets: keyShape.hitGap,
                ),
                onKeyPressed: onKeyPressed,
                enableHaptics: enableHaptics,
              ),
            ),
          ),
          Expanded(
            child: _grid(controlRightRows, extendHitArea: extendFunction),
          ),
        ],
      ),
    );
  }
}

/// 커서 패드 방향
enum CursorPadSector { up, down, left, right }

/// 커서 패드 방향 키 하나의 그림 모양·터치 모양·터치 여백·라벨 여백 (`CalcKeyButton`의 같은 이름 인자로 넘긴다)
typedef CursorPadKeyShape = ({
  Path Function(Size size) shape,
  Path Function(Size size) hitShape,
  EdgeInsets hitOutset,
  EdgeInsets labelInsets,
  EdgeInsets hitGap,
});

/// 커서 패드 모양 계산기 — 패드 상자([size]) 로컬 좌표의 외곽·X자 홈·허브와 방향 판정.
///
/// 패드 중심을 원점으로, 반폭 [radiusX]·반높이 [radiusY]로 정규화한 좌표 (u, v)를 쓴다.
/// - **외곽**: 45° 돌린 Lamé 곡선 |u+v|ᵖ + |u−v|ᵖ = 2 (p = [CalcTheme.cursorPadOutlineExponent]) —
///   꼭짓점이 (±1, 0)·(0, ±1)에 있고 꼭짓점 곡률이 유한한(둥근) 가로로 긴 마름모.
///   외곽선이 상자 밖으로 나가지 않도록 반지름은 선 두께 절반만큼 줄인다.
/// - **X자 홈**: |u| = k·|v| (k = [CalcTheme.cursorPadGrooveSlope]). |u| ≤ k·|v|이면 ▲·▼, 아니면 ◀·▶.
/// - **허브**: 중심에서 화면 거리 [hubRadius]인 원을 검게 그린다. 홈은 허브 가장자리에서 시작한다.
/// - **데드존**: 중심에서 [deadZoneRadius] 이내만 어느 방향에도 속하지 않는다. 허브보다 작아서,
///   허브 바깥 고리를 누르면 홈으로 나뉜 방향이 입력된다(작은 화면의 ▲·▼ 터치 깊이 확보, #43).
///
/// - **터치 영역** (#64): 외곽 안은 그림과 같이 X자 홈으로, 외곽 밖과 셀 여백은 **홈이 외곽과 만나는 점에서
///   셀 모서리로 이은 선**으로 나눈다. 그래서 셀의 네 변은 각각 그 쪽 방향 하나의 것이다(왼쪽 변 전체가 ◀).
///   셀([hitSectorAt]의 `bounds`) 안에서 데드존만 빼면 모든 점이 어느 한 방향에 속한다.
///
/// [sectorAt]·[hitSectorAt]은 위 정의를 그대로 옮긴 명세(참값) 판정이다. 실제 그림은 [sectorPath],
/// 누름·이동 이탈 판정은 [hitPath]가 다각형으로 근사해 맡는다(곡선 구간은 [_arcSegments]개 선분,
/// 경계에서 0.3dp 미만 차이). 테스트는 명세 판정과 경로가 일치하는지로 경로를 검증한다.
@immutable
class CursorPadGeometry {
  /// 패드 상자 크기
  final Size size;

  /// 외곽 반폭 (dp)
  final double radiusX;

  /// 외곽 반높이 (dp)
  final double radiusY;

  /// 그려지는 허브 반지름 (dp)
  final double hubRadius;

  /// 누를 수 없는 가운데 원의 반지름 (dp, [hubRadius] 이하)
  final double deadZoneRadius;

  /// 그리는 X자 홈의 두께 (dp, #156) — 패드 높이의 [CalcTheme.cursorPadGrooveWidthRatio]이되 [CalcTheme.cursorPadDividerWidth]
  /// 보다 가늘지 않다. 그림만 이 두께이고 터치 경계는 선이다. 화살표 라벨 검사(테스트)도 이 값을 쓴다.
  double get grooveStrokeWidth => math.max(
    CalcTheme.cursorPadDividerWidth,
    size.height * CalcTheme.cursorPadGrooveWidthRatio,
  );

  factory CursorPadGeometry(Size size) {
    const inset = CalcTheme.cursorPadDividerWidth / 2;
    final rx = math.max(0.0, size.width / 2 - inset);
    final ry = math.max(0.0, size.height / 2 - inset);
    final short = math.min(rx, ry);
    return CursorPadGeometry._(
      size,
      rx,
      ry,
      CalcTheme.cursorPadHubRadiusRatio * short,
      CalcTheme.cursorPadDeadZoneRadiusRatio * short,
    );
  }

  const CursorPadGeometry._(
    this.size,
    this.radiusX,
    this.radiusY,
    this.hubRadius,
    this.deadZoneRadius,
  );

  static const double _p = CalcTheme.cursorPadOutlineExponent;
  static const double _k = CalcTheme.cursorPadGrooveSlope;

  /// 곡선 구간(외곽 호·데드존 호) 하나를 나누는 선분 수
  static const int _arcSegments = 32;

  /// 패드 중심
  Offset get center => size.center(Offset.zero);

  bool get _isEmpty => radiusX <= 0 || radiusY <= 0;

  /// [localPosition](패드 로컬 좌표)이 속한 방향. 데드존·외곽 밖이거나 유한하지 않은 좌표면 `null`이다.
  CursorPadSector? sectorAt(Offset localPosition) {
    if (_isEmpty || !localPosition.isFinite) return null;
    final d = localPosition - center;
    if (d.distance <= deadZoneRadius) return null;
    final u = d.dx / radiusX;
    final v = d.dy / radiusY;
    if (math.pow((u + v).abs(), _p) + math.pow((u - v).abs(), _p) > 2) {
      return null;
    }
    if (u.abs() <= _k * v.abs()) {
      return v < 0 ? CursorPadSector.up : CursorPadSector.down;
    }
    return u < 0 ? CursorPadSector.left : CursorPadSector.right;
  }

  /// 정규화 좌표에서 홈이 가로축과 이루는 각 (k < 1이면 45°보다 크다 — 실측 k ≈ 0.9, #65)
  static final double _grooveAngle = math.atan2(1, _k);

  /// [sector]가 차지하는 정규화 각도 범위 (y 아래 방향, 시계 방향으로 증가)
  static (double, double) _angles(CursorPadSector sector) {
    final t = _grooveAngle;
    return switch (sector) {
      CursorPadSector.right => (-t, t),
      CursorPadSector.down => (t, math.pi - t),
      CursorPadSector.left => (math.pi - t, math.pi + t),
      CursorPadSector.up => (math.pi + t, 2 * math.pi - t),
    };
  }

  /// 정규화 각도 [phi] 방향의 외곽 위 점
  Offset _outlinePoint(double phi) {
    final c = math.cos(phi);
    final s = math.sin(phi);
    final rho = math.pow(
      2 / (math.pow((c + s).abs(), _p) + math.pow((c - s).abs(), _p)),
      1 / _p,
    );
    return center + Offset(rho * c * radiusX, rho * s * radiusY);
  }

  /// 정규화 각도 [phi] 방향 직선과 중심에서 반지름 [radius]인 원의 교점
  Offset _circlePoint(double phi, double radius) {
    final psi = math.atan2(math.sin(phi) * radiusY, math.cos(phi) * radiusX);
    return center + Offset.fromDirection(psi, radius);
  }

  /// [sector] 구역 다각형 꼭짓점 (패드 로컬 좌표): 외곽 호를 시계 방향으로 따라간 뒤,
  /// 데드존 호를 반시계 방향으로 되돌아온다 (두 호를 잇는 변이 X자 홈이다). 비어 있으면 빈 목록.
  List<Offset> sectorPolygon(CursorPadSector sector) {
    if (_isEmpty) return const [];
    final (from, to) = _angles(sector);
    return [
      for (var i = 0; i <= _arcSegments; i++)
        _outlinePoint(from + (to - from) * i / _arcSegments),
      ..._deadZoneArc(from, to),
    ];
  }

  /// 정규화 각도 [from]~[to] 구역의 데드존 호 — [to] 쪽 홈에서 [from] 쪽 홈으로 반시계 방향.
  List<Offset> _deadZoneArc(double from, double to) {
    // 화면 각도로 고르게 나눈다 (끝 각도는 시작보다 작아지게 2π 단위로 맞춘다).
    final a0 = (_circlePoint(to, 1) - center).direction;
    var a1 = (_circlePoint(from, 1) - center).direction;
    while (a1 > a0) {
      a1 -= 2 * math.pi;
    }
    return [
      for (var i = 0; i <= _arcSegments; i++)
        center +
            Offset.fromDirection(
              a0 + (a1 - a0) * i / _arcSegments,
              deadZoneRadius,
            ),
    ];
  }

  /// [sector] 구역 경로 (패드 로컬 좌표)
  Path sectorPath(CursorPadSector sector) {
    if (_isEmpty) return Path();
    return Path()..addPolygon(sectorPolygon(sector), true);
  }

  /// 외곽선 경로 (패드 로컬 좌표)
  Path outlinePath() {
    if (_isEmpty) return Path();
    const segments = _arcSegments * 4;
    return Path()..addPolygon([
      for (var i = 0; i < segments; i++)
        _outlinePoint(2 * math.pi * i / segments),
    ], true);
  }

  /// X자 홈 네 줄 — 각각 (허브 가장자리 끝, 외곽 위 끝)
  List<(Offset, Offset)> grooves() {
    if (_isEmpty) return const [];
    final t = _grooveAngle;
    return [
      for (final phi in [t, math.pi - t, math.pi + t, -t])
        (_circlePoint(phi, hubRadius), _outlinePoint(phi)),
    ];
  }

  /// 시맨틱 노드를 쌓는 순서 — 뒤의 것이 위에 놓여, 영역이 겹친 곳에서는 뒤의 방향이 읽힌다(#203).
  ///
  /// 엔진 코드상 Android(TalkBack)·iOS(VoiceOver) 브리지는 터치 탐색 때 겹친 노드 가운데 히트 테스트 순서
  /// (위에 그린 것부터)로 처음 닿는 노드를 고른다(Flutter 엔진 `AccessibilityBridge.java` `hitTest`,
  /// `SemanticsObject.mm` `search:`). [CursorPad]는 이 순서로 노드를 쌓는다.
  /// - Android는 TalkBack 에뮬레이터에서 확인했다(#203, 411×914 격자 588점이 [semanticSectorAt]과 모두 일치 — #259 전 모양.
  ///   쌓는 순서의 판정은 지금 모양([screenSemanticRect])에도 그대로다).
  /// - iOS는 엔진이 비공개 API `_accessibilityHitTest:`를 재정의해 이 순서를 쓴다. 재정의가 불리지 않으면
  ///   UIKit 기본 판정(iOS 16부터 왼쪽 위 요소 우선)이 되어 위쪽 반에서 ▲가 ◀·▶를 가린다.
  ///   실기기로만 확인할 수 있다(#181, M12 출시 QA).
  static const List<CursorPadSector> semanticStackOrder = [
    CursorPadSector.up,
    CursorPadSector.down,
    CursorPadSector.left,
    CursorPadSector.right,
  ];

  /// [sector]의 시맨틱(스크린리더 터치 탐색) 노드 영역 (패드 로컬 좌표). 네 영역은 겹치며, 겹친 곳은
  /// [semanticStackOrder]로 정한다 — 실제로 읽히는 방향은 [semanticSectorAt]이다(#203).
  ///
  /// - ▲·▼: 셀([bounds])의 위·아래 반쪽 전체. 가운데 가로선(중심 높이)에서 나뉜다.
  /// - ◀·▶: 허브 가장자리(중심에서 가로 [hubRadius])부터 셀 옆 변까지, 위아래는 중심에서 홈 끝(홈이 외곽과 만나는 점)
  ///   높이까지. 셀이 패드보다 높으면 그 높이를 셀 높이 / 패드 높이 배로 늘린다. 셀이 패드보다 넓으면
  ///   셀 반높이 쪽으로 (1 − 패드 폭 / 셀 폭)만큼 더 늘린다. ▲·▼ 위에 놓인다.
  ///
  /// 그래서 셀 안 어디를 짚어도 어느 한 방향이 읽힌다(빈 곳 없음). [bounds]를 생략하면 셀 대신 패드 상자다.
  /// [bounds]는 패드 상자를 품어야 하고([hitSectorAt]과 같은 전제), 위아래가 비대칭이면 짧은 쪽 반높이를 쓴다.
  ///
  /// ## 왜 겹치게 두는가 (#203)
  /// 터치 탐색에서 아무 노드에도 닿지 않으면 초점이 앞 방향에 남는다. 그 상태로 두 번 탭하면 손가락 아래가 아니라
  /// 앞 방향이 입력된다. 방금 짚은 곳에서는 아무것도 듣지 못했는데 다른 방향이 입력되는 것이다.
  /// 읽힌 방향이 손가락 아래의 터치 방향([hitSectorAt])과 달라도, 두 번 탭은 읽힌 방향을 입력한다.
  /// 그러므로 빈 곳을 없애는 것이 우선이다.
  /// - #166의 겹치지 않는 사각형 네 개는 각 영역이 자기 터치 영역 안에만 있었다. 대신 홈 옆 대각선과 가운데 사각형이
  ///   비어, 누르면 입력되는 곳의 약 44%만 읽혔다(#173 에뮬레이터 실측 45.5%, 허브 고리는 약 19%).
  /// - 사각형 노드는 쐐기 모양을 그대로 덮을 수 없다. 방향마다 노드를 여러 개 두면 쓸어 넘기기에서 같은 방향이
  ///   여러 번 읽힌다. 터치 탐색에 잡히는 조건(라벨·동작이 있는 노드)이 쓸어 넘기기에 들어가는 조건과 같기 때문이다.
  ///   회전 변환 노드는 Android만 변환을 따르고, iOS는 감싸는 축 정렬 사각형(`globalRect`)으로 판정한다.
  /// - 그래서 방향마다 노드 하나를 두고 겹침 순서로 모양을 만든다.
  ///   ◀·▶ 사각형을 ▲·▼ 반쪽 위에 두는 배치와, ▲·▼ 사각형을 ◀·▶ 반쪽 위에 두는 배치는 최적이 거의 같다(약 83.5%).
  ///   셀이 패드보다 넓을 때 앞쪽이 조금 낫다. X = 허브 반지름, Y = 홈 끝 높이는 X·Y를 1dp 단위로 찾은 최적보다
  ///   셀 폭 = 패드 폭에서 약 0.2~0.5%p 낮다(터치 영역 중 같은 방향이 읽히는 넓이).
  ///   셀이 패드보다 가로로 넓으면 ◀·▶ 터치 영역이 셀 옆 모서리까지 위아래로 퍼져, 최적의 Y가 더 크다.
  ///   Y를 홈 끝 높이로 고정하면 최적보다 411×452 분할 창 1.7%p, 2000×400 넓은 셀(#159) 3.5%p 낮았다(#203 R1·R2).
  ///   그래서 넓은 셀에서는 Y를 셀 반높이 쪽으로 늘린다. 셀 비(셀 폭/패드 폭) 1.19~2.02의 셀에서 83.0~83.1% →
  ///   84.0~86.3%다(0.3dp 격자). Y를 폭 비로 곱하거나 X를 늘리는 규칙은 더 나빴다.
  /// - 411×914(Android 기본 인셋, #173과 같은 셀) 1px 계산: 터치 영역 중 같은 방향이 읽히는 곳 44.4% → 83.4%,
  ///   빈 곳 55.6% → 0%. ▲·▼ 91.6%, ◀·▶ 75.4%다. 나머지 16.6%는 이웃 방향이 읽히는 곳이고, 세 가지다.
  ///   - 셀 옆 변 위아래 끝 6.5%: 누르면 ◀·▶인데 ◀·▶ 노드(중심 ±Y) 밖이라 ▲·▼로 읽힌다(411×914에서 위아래 약 17dp씩).
  ///   - 허브 고리의 ◀·▶ 쪽 5.1%: ◀·▶ 노드가 허브 가장자리에서 시작해 ▲·▼로 읽힌다. 고리는 전부 읽히고
  ///     (18.6% → 100%) 그중 57.5%가 같은 방향이다.
  ///   - 홈 근처 5.1%: 사각형 모서리가 홈 양쪽으로 넘는 곳.
  ///
  /// 이 모양은 #203의 **기본 모양**이다(◀·▶가 허브 가장자리에서 시작). 화면 커서 패드는 여기에 ◀·▶ 폭 목표를 더한
  /// [screenSemanticRect]를 쓴다(#259) — 위 수치(411×914 ▲·▼ 91.6% 등)는 기본 모양 기준이고, 화면 모양의 수치는 그쪽 문서에 있다.
  Rect semanticRect(CursorPadSector sector, [Rect? bounds]) =>
      _semanticRect(sector, bounds, EdgeInsets.zero, 0);

  /// 화면 커서 패드([CursorPad])가 쓰는 시맨틱 영역 — 기본 모양([semanticRect])에 셀 바깥 간격 몫 [outerGap](#236)과
  /// ◀·▶ 폭 목표 [semanticSideTargetWidth](#259)를 넣은 것. 화면과 같게 판정하려는 곳(테스트 포함)은 이것을 쓴다.
  ///
  /// ## ◀·▶ 폭 목표와 시작점 하한 (#259)
  /// ◀·▶ 노드 폭(셀 안 폭 + 셀 바깥 간격 몫의 옆쪽 — 접근성 검사기가 재는 노드 폭)이 [semanticSideTargetWidth](48.25dp)가
  /// 되도록 허브 쪽 시작점(중심에서 X)을 허브 가장자리에서 가운데로 당긴다. 단 [semanticSideMinStart]보다 가운데로는
  /// 당기지 않는다(둘 다 사용자 결정).
  /// - [CalcTheme.keyTouchHeightFloor]의 절반(14dp) — ◀·▶ 사이에서 ▲·▼만 읽히는 가운데 세로 띠(폭 2X)가 28dp 이상으로
  ///   남게(#166에서 정한 하한 — #173 에뮬레이터에서 21dp일 때 ▲·▼를 짚기 어려웠다. 화면 테스트 "세로 폰 화면의 키 크기
  ///   하한"이 본다). 작은 폰에서 걸리는 것은 늘 이 하한이다.
  /// - 허브 반지름의 절반([semanticSideMinStartRatio]) — 지금 패드 비([CursorPad.fitSize], 가로/세로 1.4 이상)에서는 걸리지
  ///   않는다: 허브 절반이 14dp를 넘는 큰 패드는 옆 폭이 넓어 아예 당기지 않는다. 패드 비가 바뀔 때를 위한 보호다.
  /// 터치 방향과 읽히는 방향이 같은 비율(셀 안, 0.5dp 격자, 기본 모양 → 화면 모양)과 화면 ◀·▶ 노드 폭:
  ///   390×844 83.4 → 82.8% · 411×914 83.4 → 83.3% · 430×932·Fold 841×701 약 83.4%(네 화면 모두 48.25dp)
  ///   태블릿 800×1280 83.3%·가로 915×412 83.4%(이미 넓어 허브 가장자리에서 시작 — 89.1·52.1dp)
  ///   360×800 83.4 → 83.1%(43.3dp) · 320×568 83.1 → 83.4%(36.7dp) — 둘은 띠 하한에 걸려 48dp에 못 미친다.
  ///   같은 폰의 함수 키 터치 높이(#236)는 360×800 45.9dp·320×568 37.5dp로 ◀·▶ 노드가 조금 좁다(360×640은 함수 키
  ///   38.9dp, ◀·▶ 43.3dp로 넓다). 띠 하한을 지키는 대가로 받아들였다.
  /// 방향별로는 ◀·▶를 넓힌 만큼 ▲·▼가 내준다(기본 → 화면): 390×844 ▲·▼ 91.9 → 83.7%, ◀·▶ 75.1 → 82.0% ·
  ///   411×914 91.3 → 86.5%, 75.7 → 80.2% · 360×800 91.6 → 85.0%, 75.4 → 81.2%. 폭 320~440dp 폰의 최저는 ▲·▼ 83.6%,
  ///   ◀·▶ 75.2%, 전체 82.8%다(390dp 폭 근처 — 목표 도달과 띠 하한이 만나는 곳).
  /// 허브 고리(데드존 밖 ~ 허브 둘레) 가운데 그림이 ▲·▼인 곳이 ◀·▶로 읽히는 비율은 390dp 폭 근처가 가장 크다
  ///   (390×844 3.0%, 390×720 3.1%, 360×800 0.7%, 320×568·411×914 0%). 두 번 탭은 읽힌 방향을 입력하므로 잘못 입력되지 않는다.
  /// 일치율(전체·방향별)과 고리 비율은 화면 테스트 "화면 모양의 읽기 정확도"가 고정한다.
  /// ▲·▼ 노드는 셀 반쪽 전체라 폭은 충분하고, 높이는 셀 반높이 + 간격 몫이다.
  Rect screenSemanticRect(
    CursorPadSector sector,
    Rect bounds,
    EdgeInsets outerGap,
  ) => _semanticRect(sector, bounds, outerGap, semanticSideTargetWidth);

  /// 화면 커서 패드의 ◀·▶ 의미 노드 폭 목표 (dp, #259) — 접근성 검사기 터치 대상 기준 48dp에 0.25dp 여유를 둔다.
  ///
  /// 엔진 브리지는 노드의 변마다 px로 반올림해 px 폭이 ⌊폭 × 밀도⌋ 또는 ⌈폭 × 밀도⌉가 되고, Accessibility Scanner는
  /// round(px ÷ 밀도) ≥ 48로 잰다. 정확히 48dp면 밀도 2 미만(1.5·tvdpi 1.33)에서 부동소수 오차로 1px 줄 때 47.3dp가 되어
  /// 지적받는다. 0.25dp 여유면 표준 밀도(0.75~4.0) 모두 통과한다(#259 R2 계산). 목표이지 하한이 아니다 — 작은 폰은
  /// 시작점 하한([semanticSideMinStart])에 걸려 못 미친다.
  static const double semanticSideTargetWidth =
      CalcTheme.keyMinTouchTargetHeight + 0.25;

  Rect _semanticRect(
    CursorPadSector sector,
    Rect? bounds,
    EdgeInsets outerGap,
    double minSideWidth,
  ) {
    if (_isEmpty) return Rect.zero;
    assert(bounds == null || _debugBoundsContainPad(bounds));
    final cell = bounds ?? Offset.zero & size;
    final c = center;
    // ◀·▶ 허브 쪽 시작점 — 폭 목표가 있으면 가운데로 당기되 시작점 하한(허브 반지름 × 비, ▲·▼ 띠 28dp의 절반 중 큰 값)
    // 보다 가운데로는 가지 않는다 (#259)
    final minStart = math.min(hubRadius, semanticSideMinStart(hubRadius));
    double startOf(double sideWidth) =>
        (sideWidth - minSideWidth).clamp(minStart, hubRadius);
    final xLeft = startOf(c.dx - cell.left + outerGap.left);
    final xRight = startOf(cell.right - c.dx + outerGap.right);
    // 홈 끝 높이 — 셀이 패드보다 높으면 그 비율만큼 늘린다(외곽 밖 ◀·▶ 터치 영역이 셀 모서리까지 퍼지므로).
    final groove =
        c.dy - _grooveEnd(CursorPadSector.up, CursorPadSector.left).dy;
    final halfHeight = math.min(c.dy - cell.top, cell.bottom - c.dy);
    final halfWidth = math.min(c.dx - cell.left, cell.right - c.dx);
    final tall = groove * halfHeight / c.dy;
    // 셀이 패드보다 넓으면 셀 반높이 쪽으로 늘린다 — 패드 반폭/셀 반폭이 1이면 그대로, 0에 가까우면 셀 반높이.
    final y = tall + (halfHeight - tall) * (1 - c.dx / halfWidth);
    return switch (sector) {
      CursorPadSector.up => Rect.fromLTRB(
        cell.left,
        cell.top,
        cell.right,
        c.dy,
      ),
      CursorPadSector.down => Rect.fromLTRB(
        cell.left,
        c.dy,
        cell.right,
        cell.bottom,
      ),
      CursorPadSector.left => Rect.fromLTRB(
        cell.left,
        c.dy - y,
        c.dx - xLeft,
        c.dy + y,
      ),
      CursorPadSector.right => Rect.fromLTRB(
        c.dx + xRight,
        c.dy - y,
        cell.right,
        c.dy + y,
      ),
    };
  }

  /// ◀·▶ 노드 허브 쪽 시작점을 가운데로 당길 수 있는 한계 — 허브 반지름에 대한 비 (#259, [screenSemanticRect]
  /// "◀·▶ 폭 목표와 시작점 하한").
  static const double semanticSideMinStartRatio = 0.5;

  /// 허브 반지름 [hubRadius]일 때 ◀·▶ 노드 허브 쪽 시작점(중심에서 가로 거리)의 하한 (dp, #259) — 허브 반지름 × 비와
  /// 가운데 ▲·▼ 세로 띠 폭 하한([CalcTheme.keyTouchHeightFloor])의 절반 중 큰 값. 허브 반지름보다 크면 허브 반지름이 쓰인다.
  static double semanticSideMinStart(double hubRadius) => math.max(
    hubRadius * semanticSideMinStartRatio,
    CalcTheme.keyTouchHeightFloor / 2,
  );

  /// 터치 탐색으로 [localPosition](패드 로컬 좌표)을 짚으면 읽히는 방향 — [semanticRect] 영역을
  /// [semanticStackOrder]의 위(뒤)부터 찾아 처음 닿는 방향이다. 영역 판정은 엔진 브리지처럼 왼쪽·위 변은 넣고
  /// 오른쪽·아래 변은 뺀다. 셀 밖·유한하지 않은 좌표면 `null`이다.
  /// #203 모양([semanticRect]) 기준이다. 화면 커서 패드와 같게 판정하려면 [screenSemanticSectorAt]을 쓴다.
  CursorPadSector? semanticSectorAt(Offset localPosition, [Rect? bounds]) =>
      _semanticSectorAt(localPosition, (s) => semanticRect(s, bounds));

  /// 화면 커서 패드([CursorPad]) 모양([screenSemanticRect])으로 [semanticSectorAt]과 같이 판정한다 (#236·#259).
  CursorPadSector? screenSemanticSectorAt(
    Offset localPosition,
    Rect bounds,
    EdgeInsets outerGap,
  ) => _semanticSectorAt(
    localPosition,
    (s) => screenSemanticRect(s, bounds, outerGap),
  );

  CursorPadSector? _semanticSectorAt(
    Offset localPosition,
    Rect Function(CursorPadSector sector) rectOf,
  ) {
    if (_isEmpty || !localPosition.isFinite) return null;
    for (final sector in semanticStackOrder.reversed) {
      if (rectOf(sector).contains(localPosition)) return sector;
    }
    return null;
  }

  /// [sector] 구역 넓이 (dp², [sectorPath] 다각형의 신발끈 공식)
  double sectorArea(CursorPadSector sector) =>
      _isEmpty ? 0 : polygonArea(sectorPolygon(sector));

  /// 닫힌 다각형 [points]의 넓이 (dp², 신발끈 공식)
  static double polygonArea(List<Offset> points) {
    var twice = 0.0;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final q = points[(i + 1) % points.length];
      twice += p.dx * q.dy - q.dx * p.dy;
    }
    return twice.abs() / 2;
  }

  /// [localPosition](패드 로컬 좌표)을 누르면 입력될 방향 (#64). 셀 [bounds](패드 로컬 좌표, 패드 상자를 품는다)
  /// 안에서 데드존만 뺀다. 외곽 안은 [sectorAt]과 같고(X자 홈), 외곽 밖은 그 사분면의 홈 끝(홈이 외곽과
  /// 만나는 점)과 셀 모서리를 이은 선의 어느 쪽인지로 정한다. 셀 밖·데드존·유한하지 않은 좌표면 `null`이다.
  CursorPadSector? hitSectorAt(Offset localPosition, Rect bounds) {
    if (_isEmpty || bounds.isEmpty || !localPosition.isFinite) return null;
    assert(_debugBoundsContainPad(bounds));
    if (!_closedContains(bounds, localPosition)) return null;
    final d = localPosition - center;
    if (d.distance <= deadZoneRadius) return null;
    final u = d.dx / radiusX;
    final v = d.dy / radiusY;
    final horizontal = u < 0 ? CursorPadSector.left : CursorPadSector.right;
    final vertical = v < 0 ? CursorPadSector.up : CursorPadSector.down;
    if (math.pow((u + v).abs(), _p) + math.pow((u - v).abs(), _p) <= 2) {
      return u.abs() <= _k * v.abs() ? vertical : horizontal;
    }
    // 외곽 밖: 홈 끝 → 셀 모서리 선을 기준으로, 셀 위·아래 변 쪽이면 ▲·▼, 옆 변 쪽이면 ◀·▶
    final end = _grooveEnd(vertical, horizontal);
    final corner = _cornerOf(vertical, horizontal, bounds);
    final reference = Offset(
      end.dx,
      corner.dy,
    ); // 홈 끝 바로 위(아래)의 셀 변 위 점 — ▲·▼ 쪽
    return _sameSide(end, corner, localPosition, reference)
        ? vertical
        : horizontal;
  }

  /// 셀 [bounds]가 패드 상자를 품는지 (터치 영역 계산의 전제, 부동소수 오차 허용) — 디버그 assert용
  bool _debugBoundsContainPad(Rect bounds) {
    assert(
      bounds.left <= 1e-6 &&
          bounds.top <= 1e-6 &&
          bounds.right >= size.width - 1e-6 &&
          bounds.bottom >= size.height - 1e-6,
      '셀 $bounds가 패드 상자 $size를 품지 않는다',
    );
    return true;
  }

  /// 경계 포함 사각형 판정 ([Rect.contains]는 오른쪽·아래 변을 뺀다)
  static bool _closedContains(Rect r, Offset p) =>
      p.dx >= r.left && p.dx <= r.right && p.dy >= r.top && p.dy <= r.bottom;

  /// [vertical]·[horizontal] 사분면의 홈이 외곽과 만나는 점
  Offset _grooveEnd(CursorPadSector vertical, CursorPadSector horizontal) {
    final t = _grooveAngle;
    final phi = switch ((vertical, horizontal)) {
      (CursorPadSector.down, CursorPadSector.right) => t,
      (CursorPadSector.down, _) => math.pi - t,
      (CursorPadSector.up, CursorPadSector.left) => math.pi + t,
      _ => -t,
    };
    return _outlinePoint(phi);
  }

  /// [vertical]·[horizontal] 사분면의 셀 모서리
  static Offset _cornerOf(
    CursorPadSector vertical,
    CursorPadSector horizontal,
    Rect bounds,
  ) => Offset(
    horizontal == CursorPadSector.left ? bounds.left : bounds.right,
    vertical == CursorPadSector.up ? bounds.top : bounds.bottom,
  );

  /// [p]와 [q]가 [a]–[b] 직선의 같은 쪽(또는 선 위)인지
  static bool _sameSide(Offset a, Offset b, Offset p, Offset q) {
    final ab = b - a;
    double cross(Offset x) => ab.dx * (x.dy - a.dy) - ab.dy * (x.dx - a.dx);
    return cross(p) * cross(q) >= 0;
  }

  /// [sector]의 터치 영역 다각형 (패드 로컬 좌표): 한쪽 홈 끝 → 셀 모서리 둘 → 다른 홈 끝 → 데드존 호.
  /// 외곽 안 부분은 [sectorPolygon]과 같고(외곽 호가 안쪽 선이 될 뿐), 셀의 그쪽 변 전체를 가진다.
  /// 패드나 셀이 비어 있으면 빈 목록. [bounds](셀)는 패드 상자를 품어야 한다.
  List<Offset> hitPolygon(CursorPadSector sector, Rect bounds) {
    if (_isEmpty || bounds.isEmpty) return const [];
    assert(_debugBoundsContainPad(bounds));
    final (from, to) = _angles(sector);
    final corners = switch (sector) {
      CursorPadSector.right => [bounds.topRight, bounds.bottomRight],
      CursorPadSector.down => [bounds.bottomRight, bounds.bottomLeft],
      CursorPadSector.left => [bounds.bottomLeft, bounds.topLeft],
      CursorPadSector.up => [bounds.topLeft, bounds.topRight],
    };
    return [
      _outlinePoint(from),
      ...corners,
      _outlinePoint(to),
      ..._deadZoneArc(from, to),
    ];
  }

  /// [sector] 터치 영역 경로 (패드 로컬 좌표, [hitPolygon])
  Path hitPath(CursorPadSector sector, Rect bounds) {
    final points = hitPolygon(sector, bounds);
    if (points.isEmpty) return Path();
    return Path()..addPolygon(points, true);
  }

  /// [sector] 터치 영역 넓이 (dp², [hitPolygon])
  double hitArea(CursorPadSector sector, Rect bounds) =>
      polygonArea(hitPolygon(sector, bounds));
}

/// 실물 fx-991EX 리플레이 패드처럼 가로로 긴 둥근 마름모를 X자 홈으로 4분할한 방향 키 묶음
/// (각인 띠 없음, 모양은 [CursorPadGeometry], 치수는 실측 — [CalcTheme.cursorPadGrooveSlope] 등, #65).
///
/// ```
///      ╲    ▲    ╱       ▲·▼: 위·아래 호를 따라 휜 띠
///   ◀    ╲  ●  ╱    ▶    ◀·▶: 옆으로 뭉툭한 넓은 구역
///        ╱     ╲         ●: 검은 허브 (지름 = 패드 높이의 약 1/2, 한가운데 작은 원만 데드존)
///      ╱    ▼    ╲
/// ```
/// 외곽은 가로로 긴 둥근 마름모이고, 외곽 밖도 가까운 방향의 터치 영역이다.
/// 각 방향 키캡은 [sectorBox](패드를 반으로 나눈 사각형)에 그리고 [CalcKeyButton.shape]로 구역 경로를
/// 넘겨 그림을 구역 안으로 제한한다.
///
/// ## 터치 영역은 셀 전체로 넓힌다 (#64)
/// 패드 상자의 약 30%는 외곽 밖이다. #64 당시 모양(홈 기울기 실측 #65 전)에서는 ◀·▶ 구역이 좁았다
/// (세로 폰에서 함수 키 셀의 약 0.55배).
/// 그래서 그림은 그대로 두고, 버튼 상자를 셀의 반쪽([sectorBox]에 셀 크기를 넣은 것)으로 넓혀
/// [CalcKeyButton.hitShape]·[CalcKeyButton.hitOutset]으로 터치 영역을 [CursorPadGeometry.hitPolygon]으로 준다.
/// - 외곽 안은 그림과 같이 X자 홈으로 나눈다(그린 구역 = 누르는 구역).
/// - 외곽 밖·셀 여백은 **홈이 외곽과 만나는 점에서 셀 모서리로 이은 선**으로 나눈다. 셀의 네 변이 각각
///   그쪽 방향 하나의 것이 되어, 이웃 키(ALPHA·MENU)와 맞닿은 옆 변은 전부 ◀·▶이고 위·아래 변은 ▲·▼다.
///   - 홈을 그대로 연장하는 방식은 (#64 당시 모양에서) 되찾은 넓이의 약 80%를 이미 넓던 ▲·▼에 주고,
///     옆 변의 위·아래 끝까지 ▲·▼로 만들었다(왼쪽 가장자리를 눌렀는데 ▲ — 리뷰 R1).
///   - 홈 기울기 실측(#65) 뒤 터치 넓이는 함수 키 셀 대비 ◀·▶ 약 1.14~1.20배, ▲·▼ 약 1.05~1.11배다.
///     셀이 패드 비율 상한보다 넓은 키패드에서는 ▲·▼가 셀 비에 따라 더 낮아진다(600×610 창 0.88배, 2000×300 창 0.62배).
///     함수 키가 옆으로만 넓어지기 때문이다. ▲·▼ 내접원은 함수 키 터치 높이 대비 보통 셀 이상(약 0.98배)이라서 모양은 그대로 둔다
///     ([CalcTheme.cursorPadMaxAspectRatio], #159).
///   - 방향 키에 들어가는 가장 큰 원(내접원)은 셀이 패드와 비슷하면 셀까지 넓혀도 조금만 는다(▲·▼ 약 +1~4dp).
///     홈 사이 쐐기와 셀 변이 정하기 때문이며, 쐐기는 실물 모양이라 바꾸지 않는다. 지금은 실물처럼 ▲·▼ 쪽이
///     좁다(세로 폰 ▲·▼ 약 30~46dp, ◀·▶ 약 36~52dp). 셀이 패드보다 가로로 긴 배치(분할 화면 등)에서는
///     옆 여백을 받는 ◀·▶ 내접원이 약 +12dp 커진다.
///   - 경계는 외곽에서 꺾이지만 끊기지 않고, 누른 채 이동할 때의 이탈 판정도 같은 경로를 쓴다.
/// - 셀 밖(셀 여백 `_cellPadding`, 키 사이 간격의 절반)도 다른 키처럼 패드의 몫이다(#236, [gapInsets]). 그 점은 셀
///   가장자리 안쪽(0.01dp)으로 당겨 셀 기준 터치 경로로 판정하므로, 셀 변마다 그쪽 방향 키(옆 변 ◀·▶, 위·아래 변 ▲·▼)가
///   바깥 간격까지 받는다. 모서리 바깥의 간격은 셀 모서리 점으로 당겨지고, 그 점은 홈 끝 → 셀 모서리 선이 가른다.
///   (#236 전에는 넓히지 않았다 — 그때는 다른 키도 셀 여백을 받지 않았다.)
/// - 한가운데 데드존은 그대로 누를 수 없고, 누른 채 데드존이나 다른 방향·셀 밖으로 나가면 반복이 멈춘다.
/// - 스크린리더 시맨틱 영역도 셀 전체를 덮는다([CursorPadGeometry.semanticRect]의 `bounds`, #203). 셀 둘레 간격 몫(#236)은
///   각 영역의 바깥쪽 변을 늘려 덮는다. 셀 안의 ◀·▶ 시작점은 노드 폭 목표(#259, 간격 몫 포함)에 맞춰 허브 가장자리보다
///   가운데로 당겨질 수 있다([CursorPadGeometry.screenSemanticRect]).
/// - 패드 상자는 셀 **가운데**에 있다고 가정한다([hitPath]가 상자 크기만으로 셀·패드를 되돌린다).
///
/// ## 허브 한가운데만 데드존이다 (#43)
/// 가운데는 네 방향이 만나 손가락이 어느 쪽을 노렸는지 가장 모호한 곳이다. 가까운 방향으로 보내면
/// 의도와 다른 방향으로 커서가 움직이는 오입력이 생기고(되돌리기 어렵다), 무시하면 다시 누르기만 하면 된다.
/// 그래서 한가운데([CursorPadGeometry.deadZoneRadius])는 누를 수 없게 두고, 누른 채 그리로 미끄러지면
/// 반복 입력도 멈춘다. 다만 그려진 허브 전체를 데드존으로 두면 작은 폰에서 ▲·▼ 터치 깊이가 28dp 아래로
/// 줄어들어, 허브 바깥 고리는 홈으로 나뉜 방향 키에 준다(실물보다 누를 수 있는 곳이 넓다 — 실측 허브는
/// 지름이 패드 높이의 약 1/2이라 고리가 넓다, #65).
///
/// 패드 상자는 셀 가운데에 [fitSize]로 가로/세로 비를 제한해 놓는다(셀의 남는 부분도 위 규칙의 터치 영역).
///
/// 버튼의 시맨틱 영역은 반쪽 사각형이라 그대로 두면 터치 탐색으로 ▲·▼에 닿을 수 없다(◀·▶ 상자가 위에 놓인다).
/// 그래서 버튼 시맨틱은 빼고, 방향별 시맨틱 노드를 화면 모양([CursorPadGeometry.screenSemanticRect]) 영역에 따로 둔다. 노드는 겹치게 쌓아
/// 셀 어디를 짚어도 한 방향이 읽히게 한다([CursorPadGeometry.semanticStackOrder], #203).
/// 쓸어 넘기기 순서는 쌓는 순서와 따로 [semanticTraversalOrder]로 정한다.
class CursorPad extends StatelessWidget {
  /// 방향 키 위젯 생성기. [CursorPadKeyShape]의 다섯 값을 `CalcKeyButton`의 `shape`·`hitShape`·`hitOutset`·`labelInsets`·
  /// `gapInsets`(← `hitGap`)에 넘겨야 한다(보통 `showLegendBand: false`인 [CalcKeyButton]).
  final Widget Function(CalcKeyDef def, CursorPadKeyShape shape) buttonBuilder;

  /// 시맨틱 탭(스크린리더) 입력 콜백. `null`이면 시맨틱 노드가 비활성이다.
  final ValueChanged<CalcKeyId>? onKeyPressed;

  /// 시맨틱 탭 햅틱 사용 여부 (버튼과 같게 맞춘다)
  final bool enableHaptics;

  /// 셀 바깥에서 패드가 맡는 키 사이 간격 몫 (#236) — 키패드가 셀 둘레 여백으로 둔 값. 다른 키와 같이 터치 영역·시맨틱
  /// 영역을 이만큼 넓힌다(위 "터치 영역" 절).
  final EdgeInsets gapInsets;

  const CursorPad({
    super.key,
    required this.buttonBuilder,
    this.onKeyPressed,
    this.enableHaptics = true,
    this.gapInsets = EdgeInsets.zero,
  });

  /// 셀([cell], 셀 로컬 좌표 원점) 안의 사각형 [rect]에서 셀 변에 닿은 변만 셀 둘레 간격 몫 [gap]만큼 바깥으로 늘린다 (#236).
  /// 셀 변에 닿지 않은 변은 그대로다 — 셀 안의 나눔을 바꾸지 않는다. 방향별 시맨틱 영역에 쓴다.
  static Rect inflateOnCellEdges(Rect rect, Size cell, EdgeInsets gap) {
    const eps = 1e-6;
    return Rect.fromLTRB(
      rect.left <= eps ? rect.left - gap.left : rect.left,
      rect.top <= eps ? rect.top - gap.top : rect.top,
      rect.right >= cell.width - eps ? rect.right + gap.right : rect.right,
      rect.bottom >= cell.height - eps ? rect.bottom + gap.bottom : rect.bottom,
    );
  }

  /// [sector] 버튼 상자(셀의 반쪽)의 바깥쪽 변들에 붙는 간격 몫 — 셀 둘레 간격 몫 [gap]에서 패드 안쪽(가운데) 변을 뺀다.
  static EdgeInsets hitGapOf(CursorPadSector sector, EdgeInsets gap) =>
      switch (sector) {
        CursorPadSector.up => gap.copyWith(bottom: 0),
        CursorPadSector.down => gap.copyWith(top: 0),
        CursorPadSector.left => gap.copyWith(right: 0),
        CursorPadSector.right => gap.copyWith(left: 0),
      };

  /// [sector] 구역 경로 생성기 (정적 함수라 매 빌드 같은 인스턴스 — 불필요한 재클립 방지)
  static Path Function(Size size) shapeOf(CursorPadSector sector) =>
      switch (sector) {
        CursorPadSector.up => _upPath,
        CursorPadSector.down => _downPath,
        CursorPadSector.left => _leftPath,
        CursorPadSector.right => _rightPath,
      };

  static Path _upPath(Size s) => sectorPath(CursorPadSector.up, s);
  static Path _downPath(Size s) => sectorPath(CursorPadSector.down, s);
  static Path _leftPath(Size s) => sectorPath(CursorPadSector.left, s);
  static Path _rightPath(Size s) => sectorPath(CursorPadSector.right, s);

  /// [sector] 터치 경로 생성기 (`CalcKeyButton.hitShape`용, 정적 함수라 매 빌드 같은 인스턴스)
  static Path Function(Size size) hitShapeOf(CursorPadSector sector) =>
      switch (sector) {
        CursorPadSector.up => _upHitPath,
        CursorPadSector.down => _downHitPath,
        CursorPadSector.left => _leftHitPath,
        CursorPadSector.right => _rightHitPath,
      };

  static Path _upHitPath(Size s) => hitPath(CursorPadSector.up, s);
  static Path _downHitPath(Size s) => hitPath(CursorPadSector.down, s);
  static Path _leftHitPath(Size s) => hitPath(CursorPadSector.left, s);
  static Path _rightHitPath(Size s) => hitPath(CursorPadSector.right, s);

  /// 셀([cell]) 안에서 패드 상자가 놓이는 사각형 (셀 로컬 좌표, 가운데 정렬)
  static Rect padRectIn(Size cell) {
    final pad = fitSize(cell);
    return Offset(
          (cell.width - pad.width) / 2,
          (cell.height - pad.height) / 2,
        ) &
        pad;
  }

  /// [sector] 버튼 상자(셀의 반쪽)에서 그림 상자(패드의 반쪽)까지의 여백 (`CalcKeyButton.hitOutset`)
  static EdgeInsets hitOutsetOf(CursorPadSector sector, Size cell) {
    final outer = sectorBox(sector, cell);
    final pad = padRectIn(cell);
    final inner = sectorBox(sector, pad.size).shift(pad.topLeft);
    // 패드 중심 = 셀 중심이라 가운데 쪽 변은 0이어야 하지만 부동소수 오차로 음수가 될 수 있어 자른다.
    // (오차보다 큰 음수면 패드가 셀 가운데에 있다는 가정이 깨진 것이다 — [hitPath]가 어긋난다.)
    double side(double v) {
      assert(v > -1e-6, '패드 상자가 셀 반쪽 밖으로 나갔다 ($v)');
      return math.max(0.0, v);
    }

    return EdgeInsets.fromLTRB(
      side(inner.left - outer.left),
      side(inner.top - outer.top),
      side(outer.right - inner.right),
      side(outer.bottom - inner.bottom),
    );
  }

  /// [sector] 키캡(패드의 반쪽, 패드 크기 [size])에서 라벨 자리를 뺄 여백 (`CalcKeyButton.labelInsets`, #65).
  ///
  /// - 가운데 쪽 변: 허브 반지름 + 둘레선 반 두께를 뺀다.
  /// - 바깥쪽 변: 외곽선 두께를 뺀다. 반쪽 상자 변에서 외곽선 안쪽 가장자리까지의 거리다.
  ///
  /// 그러면 라벨이 허브 둘레선과 외곽선 사이 가운데쯤에 놓인다. 키캡 아래 눌림 여유 1dp 때문에 ±1dp
  /// 어긋나고, ▲는 눌리면 1dp 허브 쪽으로 내려간다. 눌린 상태에서도 허브에 닿지 않는지는 키패드 테스트가 확인한다.
  /// 그 사이가 라벨보다 좁으면 라벨을 줄여 그린다. 예: 가로로 긴 800×300 키패드, 글자 배율 1.3의 ▲·▼.
  /// 실측 허브는 지름이 패드 높이의 약 1/2이다. 반쪽 상자 가운데(허브 가장자리)에 두면 라벨 절반이 허브에 덮인다.
  static EdgeInsets labelInsetsOf(CursorPadSector sector, Size size) {
    final inner =
        CursorPadGeometry(size).hubRadius + CalcTheme.cursorPadDividerWidth / 2;
    const outer = CalcTheme.cursorPadDividerWidth;
    return switch (sector) {
      CursorPadSector.up => EdgeInsets.only(top: outer, bottom: inner),
      CursorPadSector.down => EdgeInsets.only(top: inner, bottom: outer),
      CursorPadSector.left => EdgeInsets.only(left: outer, right: inner),
      CursorPadSector.right => EdgeInsets.only(left: inner, right: outer),
    };
  }

  /// [sector] 버튼 상자(셀의 반쪽, 크기 [boxSize]) 로컬 좌표의 터치 경로 — 상자 크기만으로 셀·패드 크기를
  /// 되돌려 계산한다([CursorPadGeometry.hitPolygon]).
  static Path hitPath(CursorPadSector sector, Size boxSize) {
    final cell = padSizeOf(sector, boxSize);
    final pad = padRectIn(cell);
    final box = sectorBox(sector, cell);
    final bounds = (Offset.zero & cell).shift(-pad.topLeft); // 패드 로컬 좌표의 셀
    return CursorPadGeometry(pad.size)
        .hitPath(sector, bounds)
        .shift(pad.topLeft - box.topLeft);
  }

  /// 쓸어 넘기기(다음 항목) 순서 — TalkBack 에뮬레이터에서 확인한 #173의 위치순 순서를 그대로 지킨다.
  /// 영역이 겹쳐 위치순 정렬로는 순서가 정해지지 않으므로 정렬 키로 고정한다(#203).
  static const List<CursorPadSector> semanticTraversalOrder = [
    CursorPadSector.left,
    CursorPadSector.up,
    CursorPadSector.down,
    CursorPadSector.right,
  ];

  /// 패드 셀([cell]) 안에 놓을 패드 상자 크기 — 가로/세로 비를
  /// [CalcTheme.cursorPadMinAspectRatio]~[CalcTheme.cursorPadMaxAspectRatio]로 제한한 가장 큰 크기.
  static Size fitSize(Size cell) {
    final w = math.max(0.0, cell.width);
    final h = math.max(0.0, cell.height);
    if (w <= 0 || h <= 0) return Size.zero;
    final aspect = w / h;
    if (aspect > CalcTheme.cursorPadMaxAspectRatio) {
      return Size(h * CalcTheme.cursorPadMaxAspectRatio, h);
    }
    if (aspect < CalcTheme.cursorPadMinAspectRatio) {
      return Size(w, w / CalcTheme.cursorPadMinAspectRatio);
    }
    return Size(w, h);
  }

  /// 방향별 키 명세
  static CalcKeyDef defOf(CursorPadSector sector) => switch (sector) {
    CursorPadSector.up => cursorPad.up,
    CursorPadSector.down => cursorPad.down,
    CursorPadSector.left => cursorPad.left,
    CursorPadSector.right => cursorPad.right,
  };

  /// [size] 패드 안에서 [sector] 키캡을 그리는 상자 (구역을 감싸는 반쪽 사각형)
  static Rect sectorBox(CursorPadSector sector, Size size) {
    final w = size.width;
    final h = size.height;
    return switch (sector) {
      CursorPadSector.up => Rect.fromLTWH(0, 0, w, h / 2),
      CursorPadSector.down => Rect.fromLTWH(0, h / 2, w, h / 2),
      CursorPadSector.left => Rect.fromLTWH(0, 0, w / 2, h),
      CursorPadSector.right => Rect.fromLTWH(w / 2, 0, w / 2, h),
    };
  }

  /// [sectorBox] 크기([boxSize])로부터 패드 크기를 되돌린다.
  static Size padSizeOf(CursorPadSector sector, Size boxSize) =>
      switch (sector) {
        CursorPadSector.up ||
        CursorPadSector.down => Size(boxSize.width, boxSize.height * 2),
        CursorPadSector.left ||
        CursorPadSector.right => Size(boxSize.width * 2, boxSize.height),
      };

  /// [sectorBox] 로컬 좌표의 [sector] 구역 경로 — 상자 크기만으로 패드 크기를 되돌려 계산한다.
  static Path sectorPath(CursorPadSector sector, Size boxSize) {
    final padSize = padSizeOf(sector, boxSize);
    final origin = sectorBox(sector, padSize).topLeft;
    return CursorPadGeometry(padSize).sectorPath(sector).shift(-origin);
  }

  @override
  Widget build(BuildContext context) {
    // 네 방향 노드를 한 노드 아래에 묶는다 — 정렬 키가 이웃 키와 섞이지 않고 네 노드끼리만 비교된다.
    // 묶는 노드는 라벨·동작이 없어 스크린리더 초점을 받지 않는다.
    // 셀 둘레 간격 몫(#236)의 누름을 셀 가장자리로 당겨 방향 키에 넘기고, 묶는 노드의 경계도 그만큼 넓힌다 —
    // 방향별 노드가 간격 몫까지 나가므로 부모 경계가 좁으면 터치 탐색이 닿지 않는다. 부모(셀 여백)가 넘겨준 점을 바로
    // 받아야 하므로 레이아웃 빌더보다 바깥에 둔다.
    return GapSemantics(
      gap: gapInsets,
      container: true,
      explicitChildNodes: true,
      properties: const SemanticsProperties(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.biggest;
          if (!cell.isFinite || cell.isEmpty) return const SizedBox.shrink();
          final padRect = padRectIn(cell);
          final size = padRect.size;
          // 패드 로컬 좌표의 셀 — 방향 나눔(터치·시맨틱)은 셀 기준 그대로다(#64·#203). 셀 둘레 간격 몫은 바깥 변에만 붙인다.
          final bounds = (Offset.zero & cell).shift(-padRect.topLeft);
          final press = onKeyPressed;
          final strings = CalcSemanticStrings.of(context);
          return SizedBox.fromSize(
            size: cell,
            child: Stack(
              // 시맨틱 영역이 셀 둘레 간격 몫까지 나간다 — 잘라 내지 않는다 (#236)
              clipBehavior: Clip.none,
              children: [
                // 방향 키: 버튼 상자는 셀의 반쪽(터치 영역), 그림은 그 안의 패드 반쪽 (#64)
                for (final sector in CursorPadSector.values)
                  Positioned.fromRect(
                    rect: sectorBox(sector, cell),
                    child: ExcludeSemantics(
                      child: buttonBuilder(defOf(sector), (
                        shape: shapeOf(sector),
                        hitShape: hitShapeOf(sector),
                        hitOutset: hitOutsetOf(sector, cell),
                        labelInsets: labelInsetsOf(sector, size),
                        hitGap: hitGapOf(sector, gapInsets),
                      )),
                    ),
                  ),
                Positioned.fromRect(
                  rect: padRect,
                  child: Stack(
                    key: const ValueKey('cursor-pad'),
                    children: [
                      // X자 홈·외곽선·허브 (터치는 통과시켜 아래 방향 키가 받는다 — 한가운데는 키 경로 밖이라 데드존)
                      // 키를 누를 때마다 장식(128각형 외곽 등)을 다시 그리지 않도록 레이어를 분리한다.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _CursorPadDecorationPainter(
                                CalcPalette.of(context).cursorPadGroove,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 겹쳐 쌓은 시맨틱 영역 — 뒤에 쌓은 ◀·▶가 겹친 곳을 가진다 (자식이 없어 터치는 받지 않는다, #203)
                for (final sector in CursorPadGeometry.semanticStackOrder)
                  Positioned.fromRect(
                    // 셀 기준 영역에서 셀 변에 닿은 변만 간격 몫까지 늘린다 (#236) — 셀 안의 나눔은 화면 모양(#259) 그대로다. 간격 고리도
                    // 셀 안의 터치·시맨틱 불일치를 물려받는다: 옆 간격 띠의 위·아래 끝과 네 바깥 모서리는 탭하면 ◀·▶,
                    // 터치 탐색으로는 ▲·▼다(간격 고리의 약 7~14%, R2 실측). 두 번 탭은 읽힌 방향을 입력하므로 잘못 입력되지 않는다.
                    rect: inflateOnCellEdges(
                      CursorPadGeometry(size)
                          .screenSemanticRect(sector, bounds, gapInsets)
                          .shift(padRect.topLeft),
                      cell,
                      gapInsets,
                    ),
                    child: Semantics(
                      container: true,
                      sortKey: OrdinalSortKey(
                        semanticTraversalOrder.indexOf(sector).toDouble(),
                      ),
                      button: true,
                      enabled: press != null,
                      label: strings.keyButton(defOf(sector).id),
                      onTap: press == null
                          ? null
                          : () {
                              if (enableHaptics) HapticFeedback.lightImpact();
                              press(defOf(sector).id);
                            },
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 커서 패드 X자 홈·외곽선과 가운데 허브
class _CursorPadDecorationPainter extends CustomPainter {
  /// 홈·외곽선·허브 둘레 색 ([CalcPalette.cursorPadGroove] — 은색 키 사이의 어두운 틈, 고대비 모드에서 바뀐다, #156)
  final Color lineColor;

  const _CursorPadDecorationPainter(this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = CursorPadGeometry(size);
    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = CalcTheme.cursorPadDividerWidth;
    // X자 홈은 실물처럼 넓은 어두운 틈으로 그린다 (#156) — 터치 경계는 선 그대로다.
    final groove = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = geometry.grooveStrokeWidth;
    for (final (from, to) in geometry.grooves()) {
      canvas.drawLine(from, to, groove);
    }
    canvas
      ..drawPath(geometry.outlinePath(), line)
      ..drawCircle(
        geometry.center,
        geometry.hubRadius,
        Paint()..color = CalcTheme.cursorPadHub,
      )
      ..drawCircle(geometry.center, geometry.hubRadius, line);
  }

  @override
  bool shouldRepaint(_CursorPadDecorationPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}

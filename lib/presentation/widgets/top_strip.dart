import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';
import 'text_fit.dart';

/// LCD 위 상단 띠의 장식 (#41): 왼쪽 워드마크(앱 이름)와 태양전지 모양.
///
/// 실물 fx-991EX 앞면에서 LCD 위는 로고·모델명·태양전지 자리다. 앱은 CASIO 상표와 모델명을 쓰지 않고
/// 앱 이름([wordmarkText])과 기능 없는 태양전지 모양만 그린다. 무엇을 어디에 그릴지는 `CalcTopStripLayout`이
/// 정해 넘긴다(기준은 [CalcTheme] "상단 띠" 절) — 이 위젯은 받은 자리에 그리기만 한다.
///
/// - 크기는 부모가 정한다(내용 줄 영역). [wordmark]·[solarPanel]은 이 위젯 좌표의 자리이고, `null`이면 그리지 않는다.
/// - 장식이라 터치를 받지 않고 스크린리더에 읽히지 않는다.
/// - 워드마크 글자 배율은 키 각인처럼 [CalcTheme.keyMaxTextScaleFactor]까지 반영하되, 자리 높이·폭을 넘지 않게 줄인다.
/// - 워드마크 색은 설정 아이콘과 같고([CalcPalette.settingsIcon]), 태양전지 테두리는 키캡 테두리와 같다
///   ([CalcPalette.keyBorder]) — 기기 고대비 설정을 함께 따른다.
class TopStripDecoration extends StatelessWidget {
  /// 워드마크 자리 (이 위젯 좌표, dp). `null`이면 그리지 않는다.
  final Rect? wordmark;

  /// 워드마크 글자 크기 (dp, 배율 반영 전)
  final double wordmarkFontSize;

  /// 태양전지 장식 자리 (이 위젯 좌표, dp). `null`이면 그리지 않는다.
  final Rect? solarPanel;

  const TopStripDecoration({
    super.key,
    this.wordmark,
    this.wordmarkFontSize = CalcTheme.topStripWordmarkMaxFontSize,
    this.solarPanel,
  });

  /// 워드마크 글자 — 앱 이름. CASIO 상표·모델명(fx-991 등)은 넣지 않는다 (#41).
  static const String wordmarkText = 'AltCalc';

  /// 워드마크 글자 위젯 키
  static const Key wordmarkKey = ValueKey('top-strip-wordmark');

  /// 태양전지 장식 위젯 키
  static const Key solarPanelKey = ValueKey('top-strip-solar-panel');

  /// 태양전지 장식의 [index]번째 칸 위젯 키
  static Key solarCellKeyOf(int index) =>
      ValueKey('top-strip-solar-cell-$index');

  @override
  Widget build(BuildContext context) {
    final wordmark = this.wordmark;
    final solarPanel = this.solarPanel;
    final palette = CalcPalette.of(context);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          children: [
            if (wordmark != null)
              Positioned.fromRect(
                rect: wordmark,
                child: _Wordmark(
                  fontSize: wordmarkFontSize,
                  color: palette.settingsIcon,
                ),
              ),
            if (solarPanel != null)
              Positioned.fromRect(
                rect: solarPanel,
                child: _SolarPanel(borderColor: palette.keyBorder),
              ),
          ],
        ),
      ),
    );
  }
}

/// 워드마크 글자 — 자리 왼쪽·세로 가운데에 그린다.
class _Wordmark extends StatelessWidget {
  final double fontSize;
  final Color color;

  const _Wordmark({required this.fontSize, required this.color});

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: CalcTheme.keyMaxTextScaleFactor);
    const style = CalcTheme.topStripWordmarkStyle;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 배율을 반영한 글자 높이가 자리 높이를 넘지 않게 줄인다. 폭은 FittedBox가 맞춘다.
        final fitted = fitFontSizeToHeight(
          fontSize,
          maxHeight: constraints.maxHeight,
          textScaler: scaler,
          heightFactor: style.height ?? 1.0,
        );
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            TopStripDecoration.wordmarkText,
            key: TopStripDecoration.wordmarkKey,
            maxLines: 1,
            softWrap: false,
            textScaler: scaler,
            textDirection: TextDirection.ltr,
            style: style.copyWith(fontSize: fitted, color: color),
          ),
        );
      },
    );
  }
}

/// 태양전지 모양 장식 — 어두운 바탕에 [CalcTheme.topStripSolarCellCount]칸.
class _SolarPanel extends StatelessWidget {
  final Color borderColor;

  const _SolarPanel({required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxHeight * CalcTheme.topStripSolarCellGapRatio;
        return DecoratedBox(
          key: TopStripDecoration.solarPanelKey,
          decoration: BoxDecoration(
            color: CalcTheme.solarPanelBackground,
            borderRadius: const BorderRadius.all(
              Radius.circular(CalcTheme.topStripSolarBorderRadius),
            ),
            border: Border.all(
              color: borderColor,
              width: CalcTheme.keyBorderWidth,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(CalcTheme.keyBorderWidth + gap),
            child: Row(
              textDirection: TextDirection.ltr,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < CalcTheme.topStripSolarCellCount; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
                      child: ColoredBox(
                        key: TopStripDecoration.solarCellKeyOf(i),
                        color: CalcTheme.solarPanelCell,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

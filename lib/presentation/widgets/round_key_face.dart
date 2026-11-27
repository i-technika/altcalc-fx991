import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';

/// 실물 SHIFT·ALPHA·MENU·ON 같은 작은 원형 은색 버튼의 면 (#190, [CalcTheme] "원형 버튼" 절).
///
/// 받은 자리 가운데에 짧은 변을 지름으로 하는 어두운 테두리 고리를 그리고, 그 안에 바람개비 무늬의 은색 원판을
/// [CalcTheme.roundKeyDiscRatio] 크기로 그린다. 버튼 면에는 글자가 없다 — 이름은 버튼 위 본체에 인쇄한다
/// (`CalcKeyButton`의 각인 띠).
///
/// - 눌리면 원판이 어두워지고([CalcTheme.roundKeyPressedOverlay]) 고리 바깥 경계가 [CalcPalette.keyPressedBorder]로
///   바뀐다 — 키캡의 눌림 표시(#22)와 같은 공통 단서다. 아래로 내려가는 이동은 부모가 한다(`CalcKeyButton`).
/// - 평소 고리 바깥 경계는 [CalcPalette.keyBorder]다 — 어두운 고리가 본체와 구분되게 한다(키캡 테두리와 같은 이유).
/// - 비활성이면 원판을 흐리게 그린다.
/// - 크기는 부모가 정한다. 터치·포커스는 다루지 않는다(그리기만 한다).
///
/// 다른 원형 키(#156의 SHIFT·ALPHA·MENU)도 이 위젯으로 그린다.
class RoundKeyFace extends StatelessWidget {
  /// 눌린 상태인지
  final bool pressed;

  /// 활성 상태인지
  final bool enabled;

  const RoundKeyFace({super.key, this.pressed = false, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return CustomPaint(
      painter: RoundKeyFacePainter(
        pressed: pressed,
        enabled: enabled,
        edge: pressed ? palette.keyPressedBorder : palette.keyBorder,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// [RoundKeyFace]를 그리는 painter. 상자 가운데에 짧은 변 지름의 고리와 은색 원판을 그린다.
@visibleForTesting
class RoundKeyFacePainter extends CustomPainter {
  /// 눌린 상태인지
  final bool pressed;

  /// 활성 상태인지
  final bool enabled;

  /// 고리 바깥 경계 색
  final Color edge;

  const RoundKeyFacePainter({
    required this.pressed,
    required this.enabled,
    required this.edge,
  });

  /// 상자 [size] 안의 테두리 고리 (지름 = 짧은 변, 가운데)
  static Rect bezelOf(Size size) {
    final diameter = math.max(0.0, size.shortestSide);
    return Rect.fromCenter(
      center: size.center(Offset.zero),
      width: diameter,
      height: diameter,
    );
  }

  /// 상자 [size] 안의 은색 원판 (고리 지름 × [CalcTheme.roundKeyDiscRatio], 가운데)
  static Rect discOf(Size size) {
    final bezel = bezelOf(size);
    final diameter = bezel.width * CalcTheme.roundKeyDiscRatio;
    return Rect.fromCenter(
      center: bezel.center,
      width: diameter,
      height: diameter,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bezel = bezelOf(size);
    if (bezel.isEmpty) return;
    canvas.drawOval(bezel, Paint()..color = CalcTheme.roundKeyBezel);

    final disc = discOf(size);
    // 돌려 깎은 금속처럼 밝은 결과 어두운 결이 번갈아 도는 바람개비 무늬
    const streaks = CalcTheme.roundKeySilverStreaks;
    final colors = <Color>[
      for (var i = 0; i < streaks; i++) ...[
        CalcTheme.roundKeySilverLight,
        CalcTheme.roundKeySilverDark,
      ],
      CalcTheme.roundKeySilverLight,
    ];
    final opacity = enabled ? 1.0 : CalcTheme.keyDisabledLabelOpacity;
    canvas.drawOval(
      disc,
      Paint()
        ..shader = SweepGradient(
          colors: [for (final c in colors) c.withValues(alpha: opacity)],
          // 결이 정확히 위·아래를 향하지 않게 조금 돌린다(사진의 무늬처럼 비스듬하다)
          transform: const GradientRotation(math.pi / 12),
        ).createShader(disc),
    );
    if (pressed) {
      canvas.drawOval(disc, Paint()..color = CalcTheme.roundKeyPressedOverlay);
    }

    // 고리 바깥 경계 — 선을 고리 안쪽에 그려 상자 밖으로 나가지 않게 한다.
    const stroke = CalcTheme.keyBorderWidth;
    canvas.drawOval(
      bezel.deflate(stroke / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(RoundKeyFacePainter oldDelegate) =>
      oldDelegate.pressed != pressed ||
      oldDelegate.enabled != enabled ||
      oldDelegate.edge != edge;
}

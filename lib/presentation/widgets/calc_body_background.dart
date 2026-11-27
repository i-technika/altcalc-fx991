import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/calc_theme.dart';

/// 계산기 본체 바탕 (#156, [CalcTheme] "본체 색상" 절) — 화면 전체에 실물 본체처럼 옅은 세로 그라데이션과 잔무늬를 깔고,
/// 시스템 인셋 안쪽 둘레에 얇은 가장자리 선을 긋는다. [child](계산기 화면 내용)는 그 위에 그린다.
///
/// - 잔무늬: 근접 사진의 본체 무늬처럼 기울어진 작은 면이 엇갈리는 셰브런 줄이다. 밝은 면은 [CalcTheme.bodyFrame],
///   어두운 면은 [CalcTheme.bodyBottomGradient]로, 각인이 이 색들 위에서도 대비 기준을 지킨다(테스트).
/// - 성능: 무늬 한 칸을 그림 한 장([ui.Image])으로 한 번 만들어 반복 셰이더로 칠한다(칸마다 경로를 그리지 않는다).
///   바탕은 [RepaintBoundary] 안이라 키를 누를 때 다시 그리지 않는다. 그림은 기기 픽셀 배율이 바뀔 때만 다시 만든다.
/// - 고대비 모드([CalcPalette.drawsRelief]가 `false`)에서는 아무것도 더 그리지 않는다 — 본체는 단색([CalcTheme.bodyBackground],
///   `Scaffold` 배경)이다.
/// - 터치는 받지 않는다.
class CalcBodyBackground extends StatefulWidget {
  /// 바탕 위에 그릴 화면 내용
  final Widget child;

  const CalcBodyBackground({super.key, required this.child});

  /// 바탕 그림 위젯 식별용 키 (테스트용)
  static const Key paintKey = ValueKey('calc-body-background');

  @override
  State<CalcBodyBackground> createState() => _CalcBodyBackgroundState();
}

class _CalcBodyBackgroundState extends State<CalcBodyBackground> {
  ui.Image? _tile;
  double? _tileScale;

  @override
  void dispose() {
    _tile?.dispose();
    super.dispose();
  }

  /// [scale](기기 픽셀 배율)에 맞춘 잔무늬 한 칸 그림
  ui.Image _tileFor(double scale) {
    final tile = _tile;
    if (tile != null && _tileScale == scale) return tile;
    tile?.dispose();
    _tileScale = scale;
    return _tile = BodyTexture.paintTile(scale);
  }

  @override
  Widget build(BuildContext context) {
    final relief = CalcPalette.of(context).drawsRelief;
    final scale = MediaQuery.devicePixelRatioOf(context);
    final insets = MediaQuery.paddingOf(context);
    // 고대비를 켜고 꺼도 트리 모양을 바꾸지 않는다 — [child]가 다시 만들어지면 화면 상태(키보드 포커스·눌린 키 등)를 잃는다.
    // 고대비에서는 바탕 그림만 비운다(단색 본체 그대로, 만든 무늬 그림은 고대비를 끌 때 다시 쓰도록 남긴다).
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                key: CalcBodyBackground.paintKey,
                painter: relief
                    ? BodyTexturePainter(
                        tile: _tileFor(scale),
                        tileScale: scale,
                        insets: insets,
                      )
                    : null,
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// 본체 잔무늬 한 칸의 모양 (#156).
///
/// 한 칸은 폭 [CalcTheme.bodyTexturePitch], 높이 그 절반인 줄 두 개다. 줄마다 `^` 모양 셰브런이 놓이고, 셰브런의 왼쪽
/// 팔(빛을 받는 면)은 밝게, 오른쪽 팔(그늘)은 어둡게 칠한다. 둘째 줄은 반 칸 밀려 엇갈린다 — 근접 사진의 무늬처럼
/// 비스듬한 면이 지그재그로 이어진다.
abstract final class BodyTexture {
  /// 한 칸 크기 (dp) — 정사각형
  static const double pitch = CalcTheme.bodyTexturePitch;

  /// 한 칸 그림을 [scale] 배율(기기 픽셀)로 만든다. 크기는 정수 픽셀로 반올림한다(반복할 때 이음매가 생기지 않게).
  static ui.Image paintTile(double scale) {
    final pixels = (pitch * scale).round().clamp(2, 512);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixels / pitch);
    final light = Paint()..color = CalcTheme.bodyFrame;
    final dark = Paint()..color = CalcTheme.bodyBottomGradient;
    const row = pitch / 2;
    for (var r = 0; r < 2; r++) {
      final y = r * row;
      final shift = r.isOdd ? pitch / 2 : 0.0;
      // 칸 경계를 넘는 셰브런도 이어지도록 왼쪽·오른쪽 이웃 칸 자리까지 그린다 (그림 밖은 잘린다).
      for (final x in [shift - pitch, shift, shift + pitch]) {
        canvas
          ..drawPath(_arm(x, y, row, left: true), light)
          ..drawPath(_arm(x, y, row, left: false), dark);
      }
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(pixels, pixels);
    picture.dispose();
    return image;
  }

  /// (x, y) 칸의 셰브런 한쪽 팔 — 꼭대기(칸 가운데 위)에서 아래 가장자리로 내려가는 띠
  static Path _arm(double x, double y, double row, {required bool left}) {
    final peak = x + pitch / 2;
    final end = left ? x : x + pitch;
    return Path()
      ..moveTo(end, y + row * 0.8)
      ..lineTo(peak, y + row * 0.2)
      ..lineTo(peak, y + row * 0.55)
      ..lineTo(end, y + row * 1.15)
      ..close();
  }
}

/// 본체 바탕을 그린다 — 세로 그라데이션, 잔무늬, 가장자리 선 ([CalcBodyBackground]).
@visibleForTesting
class BodyTexturePainter extends CustomPainter {
  /// 잔무늬 한 칸 그림 ([BodyTexture.paintTile])
  final ui.Image tile;

  /// [tile]을 만든 배율 (기기 픽셀 / dp)
  final double tileScale;

  /// 시스템 인셋 — 가장자리 선은 그 안쪽에 긋는다
  final EdgeInsets insets;

  const BodyTexturePainter({
    required this.tile,
    required this.tileScale,
    required this.insets,
  });

  /// 그라데이션 색 (위 → 아래) — 아래 끝은 바탕과 [CalcTheme.bodyBottomGradient]의 가운데라, 각인이 놓이는 곳의 색은 늘
  /// 대비를 검사한 두 색 사이다.
  static final List<Color> gradient = [
    CalcTheme.bodyBackground,
    Color.lerp(CalcTheme.bodyBackground, CalcTheme.bodyBottomGradient, 0.5)!,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient,
        ).createShader(rect),
    );
    // 그림 픽셀 → dp: 한 칸 그림이 정확히 [BodyTexture.pitch] dp가 되도록 줄인다.
    final toDp = BodyTexture.pitch / tile.width;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ImageShader(
          tile,
          TileMode.repeated,
          TileMode.repeated,
          Matrix4.diagonal3Values(toDp, toDp, 1).storage,
        ),
    );
    // 가장자리 선 — 화면 여백([CalcTheme.screenPadding])의 가운데, 시스템 인셋 안쪽
    final rim = insets.deflateRect(rect).deflate(CalcTheme.screenPadding / 2);
    if (rim.width > 0 && rim.height > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rim,
          const Radius.circular(CalcTheme.screenPadding),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = CalcTheme.bodyRimWidth
          ..color = CalcTheme.bodyRim,
      );
    }
  }

  @override
  bool shouldRepaint(BodyTexturePainter oldDelegate) =>
      !identical(oldDelegate.tile, tile) || oldDelegate.insets != insets;
}

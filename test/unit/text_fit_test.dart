import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/presentation/widgets/text_fit.dart';
import 'package:material_ui/material_ui.dart';

/// 작은 글자를 더 많이 키우는 비선형 배율 (안드로이드 14 이상 흉내)
class _NonLinearScaler extends TextScaler {
  const _NonLinearScaler();

  @override
  double scale(double fontSize) => fontSize < 20 ? fontSize * 2 : fontSize + 20;

  @override
  double get textScaleFactor => 2;

  @override
  TextScaler clamp({double minScaleFactor = 0, double maxScaleFactor = 99}) =>
      this;
}

void main() {
  group('fitFontSizeToHeight', () {
    test('이미 들어가면 요청 크기를 그대로 반환한다', () {
      expect(
        fitFontSizeToHeight(
          10,
          maxHeight: 20,
          textScaler: TextScaler.noScaling,
        ),
        10,
      );
    });

    test('배율을 반영한 (올림) 높이가 최대 높이 이하가 되도록 줄인다', () {
      const scaler = TextScaler.linear(1.5);
      final size = fitFontSizeToHeight(
        20,
        maxHeight: 15,
        textScaler: scaler,
        heightFactor: 1.2,
      );
      expect((scaler.scale(size) * 1.2).ceilToDouble(), lessThanOrEqualTo(15));
      expect(size, greaterThan(7)); // 지나치게 줄이지 않는다 (15 / 1.8 ≈ 8.3 근처)
    });

    test('비선형 배율에서도 높이 안에 들어간다', () {
      const scaler = _NonLinearScaler();
      final size = fitFontSizeToHeight(30, maxHeight: 30, textScaler: scaler);
      expect(scaler.scale(size).ceilToDouble(), lessThanOrEqualTo(30));
      expect(size, greaterThan(14));
    });

    test('하한으로도 들어가지 않으면 하한을 반환한다', () {
      expect(
        fitFontSizeToHeight(12, maxHeight: 0, textScaler: TextScaler.noScaling),
        minFittedFontSize,
      );
    });
  });

  group('fitFontSizeScanning (#264 — 단조가 아닌 조건)', () {
    // 줄 상자 반올림을 흉내 낸 조건: 5 이하이거나 8~9 사이에서만 참이다
    bool bumpy(double scaled) => scaled <= 5 || (scaled >= 8 && scaled <= 9);

    test('위쪽에 다시 참이 되는 구간이 있으면 그 구간의 가장 큰 크기를 찾는다 (이분 탐색은 지나친다)', () {
      final scanned = fitFontSizeScanning(
        10,
        textScaler: TextScaler.noScaling,
        fits: bumpy,
      );
      expect(scanned, closeTo(9, 1e-3));
      expect(bumpy(scanned), isTrue);
      // 같은 조건에 이분 탐색을 쓰면 아래 구간(5 이하)에서 멈춘다
      final bisected = fitFontSize(
        10,
        textScaler: TextScaler.noScaling,
        fits: bumpy,
      );
      expect(bisected, lessThanOrEqualTo(5 + 1e-6));
    });

    test('단조 조건에서는 이분 탐색과 같은 크기를 찾는다', () {
      bool monotone(double scaled) => scaled <= 7.3;
      for (final scaler in const <TextScaler>[
        TextScaler.noScaling,
        TextScaler.linear(1.3),
        _NonLinearScaler(),
      ]) {
        expect(
          fitFontSizeScanning(20, textScaler: scaler, fits: monotone),
          closeTo(fitFontSize(20, textScaler: scaler, fits: monotone), 1e-3),
          reason: '$scaler',
        );
      }
    });

    test('이미 만족하면 요청 크기 그대로, 어느 크기도 만족하지 않으면 하한이다', () {
      expect(
        fitFontSizeScanning(4, textScaler: TextScaler.noScaling, fits: bumpy),
        4,
      );
      expect(
        fitFontSizeScanning(
          10,
          textScaler: TextScaler.noScaling,
          fits: (_) => false,
        ),
        minFittedFontSize,
      );
      // 배율을 반영한 크기로 판정한다 — 그리는 크기 9가 되는 6.92
      final scaled = fitFontSizeScanning(
        10,
        textScaler: const TextScaler.linear(1.3),
        fits: bumpy,
      );
      expect(scaled * 1.3, closeTo(9, 1e-2));
    });
  });
}

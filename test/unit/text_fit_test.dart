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
}

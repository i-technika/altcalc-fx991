import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/layout/form_factor.dart';

/// 세로 접힘선 (폴더블 내부 화면 펼침)
const _fold = DisplayFeature(
  bounds: Rect.fromLTWH(420, 0, 0, 701),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureFlat,
);

/// 물리 힌지 (Surface Duo 등 두 화면 기기)
const _hinge = DisplayFeature(
  bounds: Rect.fromLTWH(540, 0, 34, 720),
  type: DisplayFeatureType.hinge,
  state: DisplayFeatureState.postureFlat,
);

/// 화면 구멍 (카메라 노치)
const _cutout = DisplayFeature(
  bounds: Rect.fromLTWH(180, 0, 40, 30),
  type: DisplayFeatureType.cutout,
  state: DisplayFeatureState.unknown,
);

void main() {
  group('기기 종류 판정', () {
    test('짧은 변 600dp 미만은 폰이다 (가로·세로 무관)', () {
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(430, 932),
        Size(344, 882), // 폴더블 커버 화면
        Size(844, 390),
        Size(599.9, 1000),
      ]) {
        expect(FormFactor.deviceKindOf(size, const []), DeviceKind.phone);
      }
    });

    test('짧은 변 600dp 이상이고 접히는 부분이 없으면 태블릿이다 (가로·세로 무관)', () {
      for (final size in const [
        Size(600, 960),
        Size(800, 1280),
        Size(1280, 800),
        Size(744, 1133), // iPad mini
        Size(1366, 1024), // iPad Pro 12.9
      ]) {
        expect(FormFactor.deviceKindOf(size, const []), DeviceKind.tablet);
      }
    });

    test('접히는 부분(fold·hinge)이 있으면 크기와 무관하게 폴더블이다', () {
      for (final f in const [_fold, _hinge]) {
        expect(
          FormFactor.deviceKindOf(const Size(841, 701), [f]),
          DeviceKind.foldable,
        );
        expect(
          FormFactor.deviceKindOf(const Size(1280, 800), [f]),
          DeviceKind.foldable,
        );
      }
    });

    test('화면 구멍(cutout)은 접히는 부분이 아니다', () {
      expect(FormFactor.hasFoldOrHinge(const [_cutout]), isFalse);
      expect(
        FormFactor.deviceKindOf(const Size(1280, 800), const [_cutout]),
        DeviceKind.tablet,
      );
      expect(FormFactor.hasFoldOrHinge(const [_cutout, _fold]), isTrue);
    });
  });

  group('방향 요청', () {
    test('폰·폴더블은 세로, 태블릿은 가로 두 방향', () {
      expect(FormFactor.preferredOrientationsFor(DeviceKind.phone), [
        DeviceOrientation.portraitUp,
      ]);
      expect(FormFactor.preferredOrientationsFor(DeviceKind.foldable), [
        DeviceOrientation.portraitUp,
      ]);
      expect(FormFactor.preferredOrientationsFor(DeviceKind.tablet), [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });

    test('모든 기기 종류가 방향을 하나 이상 요청한다 (빈 목록은 "제한 없음"이 된다)', () {
      for (final kind in DeviceKind.values) {
        expect(FormFactor.preferredOrientationsFor(kind), isNotEmpty);
      }
    });
  });

  group('좌우 분할 배치 판정 (창 크기 기준)', () {
    test('대화면 가로 창은 좌우 분할이다', () {
      for (final size in const [
        Size(1280, 800),
        Size(1024, 768),
        Size(1194, 834),
        Size(1366, 1024),
        Size(960, 600),
      ]) {
        expect(
          FormFactor.usesSplitLayout(size, const []),
          isTrue,
          reason: '$size',
        );
      }
    });

    test('세로 창·정사각형 창·짧은 변 600dp 미만 창은 위아래 배치다', () {
      for (final size in const [
        Size(800, 1280), // 태블릿 세로 (방향 고정 무시)
        Size(768, 768), // 정사각형
        Size(678, 1024), // iPad Split View 절반
        Size(390, 844), // 폰
        Size(844, 390), // 가로 폰 — 짧은 창 대응은 #38
        Size(1280, 599), // 낮고 넓은 팝업 창
      ]) {
        expect(
          FormFactor.usesSplitLayout(size, const []),
          isFalse,
          reason: '$size',
        );
      }
    });

    test('접히는 부분이 창을 지나면 위아래 배치다 (힌지 기준 분할은 #25)', () {
      expect(
        FormFactor.usesSplitLayout(const Size(1280, 800), [_fold]),
        isFalse,
      );
      expect(
        FormFactor.usesSplitLayout(const Size(1280, 800), [_hinge]),
        isFalse,
      );
      expect(
        FormFactor.usesSplitLayout(const Size(1280, 800), const [_cutout]),
        isTrue,
      );
    });
  });
}

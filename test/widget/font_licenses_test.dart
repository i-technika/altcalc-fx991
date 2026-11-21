import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itechnika_altcalc_fx991/core/theme/font_licenses.dart';

/// 일부 에셋만 가진 가짜 번들 (없는 키는 로드 실패).
class _PartialBundle extends CachingAssetBundle {
  final Map<String, String> files;
  _PartialBundle(this.files);

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw FlutterError('에셋 없음: $key');
    return ByteData.sublistView(utf8.encode(text));
  }
}

/// [LicenseRegistry]는 전역 상태라 다른 테스트와 섞이지 않도록 파일을 분리한다.
/// `LicenseRegistry.reset`은 바인딩이 등록한 수집기까지 지우므로 쓰지 않고, 등록 전후 차이만 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<LicenseEntry>> fontEntries() async => [
    for (final entry in await LicenseRegistry.licenses.toList())
      if (entry.packages.any(bundledFontLicenseAssets.containsKey)) entry,
  ];

  test('번들 글꼴 라이선스(OFL 전문)가 글꼴마다 한 번씩 등록된다', () async {
    expect(await fontEntries(), isEmpty);

    registerFontLicenses();
    registerFontLicenses(); // 두 번 불러도 중복 등록되지 않는다.

    final entries = await fontEntries();
    for (final family in bundledFontLicenseAssets.keys) {
      final matching = entries.where((e) => e.packages.contains(family));
      expect(matching, hasLength(1), reason: family);
      final text = matching.single.paragraphs.map((p) => p.text).join(' ');
      expect(text, contains('SIL Open Font License, Version 1.1'));
      expect(text, contains('The Noto Project Authors'));
    }
  });

  test('라이선스 에셋 하나를 읽지 못해도 나머지는 내보내고 오류를 보고한다', () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    final entries = await collectFontLicenses(
      assets: const {'A': 'missing.txt', 'B': 'ok.txt'},
      bundle: _PartialBundle({'ok.txt': 'B 라이선스 전문'}),
    ).toList();

    expect(entries.map((e) => e.packages.single), ['B']);
    expect(reported, hasLength(1));
    expect(reported.single.library, 'font_licenses');
  });
}

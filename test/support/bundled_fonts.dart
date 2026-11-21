import 'dart:convert';

import 'package:flutter/services.dart';

/// 앱 번들의 `FontManifest.json`(= `pubspec.yaml`의 `fonts:`)에 등록된 글꼴을 모두 로드한다.
///
/// `flutter test`는 기본적으로 모든 글자를 정사각형으로 그리는 테스트 글꼴을 쓴다. 실제 글꼴 폭을
/// 재야 하는 테스트는 `setUpAll`에서 이 함수를 불러 번들 글꼴을 엔진에 등록한다.
/// 로드된 글꼴은 같은 테스트 파일 안에서 계속 유지된다.
///
/// 돌려주는 값은 로드한 패밀리 이름 목록이다.
Future<List<String>> loadBundledFonts() async {
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  final families = <String>[];
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final family = entry['family'] as String;
    final loader = FontLoader(family);
    for (final font
        in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
    families.add(family);
  }
  return families;
}

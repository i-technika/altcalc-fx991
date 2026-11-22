import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// VS Code 실행 구성(`.vscode/`)의 불변식 (#21, #52).
/// 진입점 파일 이름을 바꾸거나 기기마다 다른 SDK 경로를 저장소 설정에 넣는 실수를 막는다.

/// VS Code의 JSONC 파일을 읽는다. 이 저장소는 줄 전체 주석(`//`)만 쓰므로 그 줄만 지우고 해석한다.
Map<String, Object?> _readJsonc(String path) {
  final lines = File(path)
      .readAsLinesSync()
      .where((line) => !line.trimLeft().startsWith('//'));
  return jsonDecode(lines.join('\n')) as Map<String, Object?>;
}

void main() {
  group('.vscode/launch.json', () {
    final configs =
        (_readJsonc('.vscode/launch.json')['configurations']! as List)
            .cast<Map<String, Object?>>();

    test('README에 적은 세 구성이 있고 이름이 겹치지 않는다', () {
      final names = configs.map((c) => c['name']).toList();
      expect(names, [
        'AltCalc (앱)',
        'Key Preview (Chrome)',
        'Key Preview (Windows)',
      ]);
      expect(names.toSet().length, names.length);
    });

    test('모든 구성이 Dart 확장으로 실행되고 진입점 파일이 존재한다', () {
      for (final c in configs) {
        expect(c['type'], 'dart', reason: '${c['name']}');
        expect(c['request'], 'launch', reason: '${c['name']}');
        final program = c['program']! as String;
        expect(
          File(program).existsSync(),
          isTrue,
          reason: '${c['name']}의 진입점 $program이 없다',
        );
      }
    });

    test('미리보기 구성은 기기를 고정하고, 앱 구성은 상태 표시줄 기기 선택을 따른다', () {
      final byName = {for (final c in configs) c['name']: c};
      expect(byName['Key Preview (Chrome)']!['deviceId'], 'chrome');
      expect(byName['Key Preview (Windows)']!['deviceId'], 'windows');
      expect(byName['AltCalc (앱)']!.containsKey('deviceId'), isFalse);
    });
  });

  test('.vscode/extensions.json은 Dart·Flutter 확장을 추천한다', () {
    final recs = _readJsonc('.vscode/extensions.json')['recommendations'];
    expect(recs, containsAll(['dart-code.dart-code', 'dart-code.flutter']));
  });

  group('.vscode/settings.json', () {
    final settings = _readJsonc('.vscode/settings.json');

    test('기기마다 다른 SDK 경로 설정을 저장소에 넣지 않는다', () {
      for (final key in [
        'dart.flutterSdkPath',
        'dart.sdkPath',
        'dart.flutterSdkPaths',
        'dart.sdkPaths',
      ]) {
        expect(settings.containsKey(key), isFalse, reason: key);
      }
    });

    test('작업 영역 안의 git 워크트리를 Dart 분석에서 제외한다', () {
      expect(
        settings['dart.analysisExcludedFolders'],
        contains('.claude/worktrees'),
      );
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// VS Code 실행 구성(`.vscode/`)의 불변식 (#21, #52).
/// 진입점 파일 이름 변경, README 표와의 불일치, 기기마다 다른 경로를 저장소 설정에 넣는 실수를 막는다.
/// 경로는 `flutter test`의 작업 디렉터리인 패키지 루트 기준이다.

/// `s[start]`의 `"`에서 시작한 문자열 리터럴이 끝난 바로 다음 위치. 이스케이프(`\"`)를 따른다.
int _stringEnd(String s, int start) {
  var i = start + 1;
  while (i < s.length && s[i] != '"') {
    i += s[i] == r'\' ? 2 : 1;
  }
  return i + 1;
}

/// 문자열 리터럴 밖의 글자만 [handle]에 넘기며 [source]를 다시 쓴다.
/// [handle]은 그 위치에서 처리한 뒤의 다음 위치를 돌려준다.
String _rewriteOutsideStrings(
  String source,
  int Function(String s, int i, StringBuffer out) handle,
) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (source[i] == '"') {
      final end = _stringEnd(source, i);
      out.write(source.substring(i, end.clamp(0, source.length)));
      i = end;
    } else {
      i = handle(source, i, out);
    }
  }
  return out.toString();
}

/// VS Code가 허용하는 JSONC(주석 `//`·`/* */`, 끝 쉼표)를 일반 JSON으로 바꾼다.
/// 문자열 안의 `//`·`/*`·쉼표는 건드리지 않는다.
String stripJsonc(String source) {
  // 1단계: 주석을 지운다.
  final noComments = _rewriteOutsideStrings(source, (s, i, out) {
    if (s.startsWith('//', i)) {
      final end = s.indexOf('\n', i);
      return end < 0 ? s.length : end;
    }
    if (s.startsWith('/*', i)) {
      final end = s.indexOf('*/', i + 2);
      // VS Code도 오류로 보는 파일이므로 뒤를 삼키지 않고 실패시킨다.
      if (end < 0) throw FormatException('끝나지 않은 블록 주석', s, i);
      return end + 2;
    }
    out.write(s[i]);
    return i + 1;
  });
  // 2단계: 주석이 빠져 `}`·`]` 바로 앞에 남은 끝 쉼표를 지운다.
  final closing = RegExp(r'\s*[}\]]');
  return _rewriteOutsideStrings(noComments, (s, i, out) {
    if (s[i] != ',' || closing.matchAsPrefix(s, i + 1) == null) out.write(s[i]);
    return i + 1;
  });
}

Map<String, Object?> _readJsonc(String path) =>
    jsonDecode(stripJsonc(File(path).readAsStringSync()))
        as Map<String, Object?>;

/// 값 트리의 모든 문자열 값(경로와 함께)과 키 이름을 콜백에 넘긴다.
void _walk(
  Object? node,
  String path,
  void Function(String path, String value) onString,
  void Function(String key) onKey,
) {
  if (node is Map) {
    for (final e in node.entries) {
      onKey(e.key as String);
      _walk(e.value, '$path.${e.key}', onString, onKey);
    }
  } else if (node is List) {
    for (var i = 0; i < node.length; i++) {
      _walk(node[i], '$path[$i]', onString, onKey);
    }
  } else if (node is String) {
    onString(path, node);
  }
}

/// README "## VS Code에서 실행" 절 표의 (구성 이름, 진입점, 기기 열) 행.
List<(String, String, String)> _readmeLaunchTable() {
  final readme = File('README.md').readAsStringSync().replaceAll('\r\n', '\n');
  final start = RegExp(
    r'^## VS Code에서 실행[ \t]*$',
    multiLine: true,
  ).firstMatch(readme)?.start;
  expect(start, isNotNull, reason: 'README에 "## VS Code에서 실행" 절이 없다');
  final next = RegExp(
    r'^## ',
    multiLine: true,
  ).allMatches(readme).where((m) => m.start > start!).firstOrNull;
  final section = readme.substring(start!, next?.start ?? readme.length);
  final row = RegExp(
    r'^\| `([^`]+)` \| `([^`]+)` \| ([^|]+?) \|',
    multiLine: true,
  );
  return [for (final m in row.allMatches(section)) (m[1]!, m[2]!, m[3]!)];
}

/// README 표의 기기 열 → launch.json의 `deviceId` (`null`이면 지정하지 않음)
const _readmeDeviceToId = <String, String?>{
  'Chrome': 'chrome',
  'Windows 데스크톱': 'windows',
  '상태 표시줄에서 고른 기기': null,
};

/// 기기마다 다를 수 있는 경로 표기.
/// - Windows 드라이브(`C:\`, `C:/`)·UNC(`\\server`)·홈(`~/`): 값 처음이나 `=`·공백 뒤(인자 안)
/// - POSIX 절대경로: 값 처음 (`/api` 같은 값이 생기면 그때 좁힌다)
/// - `file://`, `${userHome}`, `${env:X}`, `%X%`: 어디서든
final _machineSpecific = RegExp(
  r'(^|[=\s])([A-Za-z]:[\\/]|\\\\|~[\\/])'
  r'|^/'
  r'|file://'
  r'|\$\{(userHome|env:[^}]+)\}'
  r'|%\w+%',
);

/// SDK 위치를 정하는 키 — 사용자 설정에만 둔다 (README "Flutter SDK를 찾는 순서").
/// 환경 변수 키는 `env`·`toolEnv`·`dart.env`·`terminal.integrated.env.*` 어디에 있어도 금지한다.
const _sdkKeys = {
  'dart.flutterSdkPath',
  'dart.flutterSdkPaths',
  'dart.sdkPath',
  'dart.sdkPaths',
  'dart.getFlutterSdkCommand',
  'dart.getDartSdkCommand',
  'PATH',
  'FLUTTER_ROOT',
  'DART_PATH_OVERRIDE',
};

void main() {
  group('stripJsonc', () {
    test('줄·인라인·블록 주석과 끝 쉼표를 지우고 문자열 안은 남긴다', () {
      const src = r'''
{
  // 줄 주석
  "url": "http://a//b", // 인라인 주석
  /* 블록
     주석 */ "list": ["x, }", "y",],
  "esc": "따옴표 \" // 문자열 안",
  "block": "/* 문자열 안 */",
  "drive": "C:\\",
  "nums": [1, /* c */ ],
  "last": 1, // 쉼표 뒤 줄 주석
}
''';
      expect(jsonDecode(stripJsonc(src)), {
        'url': 'http://a//b',
        'list': ['x, }', 'y'],
        'esc': '따옴표 " // 문자열 안',
        'block': '/* 문자열 안 */',
        'drive': r'C:\',
        'nums': [1],
        'last': 1,
      });
    });

    test('끝나지 않은 블록 주석·문자열은 오류로 본다', () {
      expect(() => stripJsonc('{"a": 1} /* 끝 없음'), throwsFormatException);
      expect(
        () => jsonDecode(stripJsonc('{"a": "끝 없음}')),
        throwsFormatException,
      );
    });
  });

  test('기기마다 다른 경로 표기를 찾고, 상대경로·기기 ID는 넘긴다', () {
    for (final bad in [
      r'C:\x',
      'C:/x',
      r'\\server\share',
      '~/develop/flutter',
      '/opt/flutter',
      r'--flutter-root=C:\x',
      '-d C:/x',
      'file:///C:/x',
      r'${userHome}/develop/flutter',
      r'${env:USERPROFILE}\develop',
      r'%USERPROFILE%\f',
    ]) {
      expect(_machineSpecific.hasMatch(bad), isTrue, reason: bad);
    }
    for (final ok in [
      'lib/main.dart',
      'preview/key_preview_main.dart',
      r'${workspaceFolder}/lib/main.dart',
      'chrome',
      'windows',
      '-d',
      'dart-code.flutter',
      '0.2.0',
    ]) {
      expect(_machineSpecific.hasMatch(ok), isFalse, reason: ok);
    }
  });

  group('.vscode/launch.json', () {
    late List<Map<String, Object?>> configs;
    setUpAll(() {
      configs = (_readJsonc('.vscode/launch.json')['configurations']! as List)
          .cast<Map<String, Object?>>();
    });

    test('구성 이름·진입점·기기가 README 표와 같은 순서로 일치하고 이름이 겹치지 않는다', () {
      final table = _readmeLaunchTable();
      expect(
        [for (final c in configs) (c['name'], c['program'])],
        [for (final r in table) (r.$1, r.$2)],
      );
      for (final (i, r) in table.indexed) {
        expect(
          _readmeDeviceToId.containsKey(r.$3),
          isTrue,
          reason: 'README 기기 열 "${r.$3}"에 대응하는 deviceId가 없다',
        );
        expect(configs[i]['deviceId'], _readmeDeviceToId[r.$3], reason: r.$1);
      }
      final names = configs.map((c) => c['name']).toList();
      expect(names.toSet().length, names.length);
      expect(names, [
        'AltCalc (앱)',
        'Key Preview (Chrome)',
        'Key Preview (Windows)',
      ]);
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
  });

  test('.vscode/extensions.json은 Dart·Flutter 확장을 추천한다', () {
    final recs = _readJsonc('.vscode/extensions.json')['recommendations'];
    expect(recs, containsAll(['dart-code.dart-code', 'dart-code.flutter']));
  });

  test('저장소의 VS Code 설정에 기기마다 다른 경로·SDK 설정이 없다', () {
    final files = [
      ...Directory('.vscode')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.json') || f.path.endsWith('.code-snippets'),
          ),
      ...Directory('.')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.code-workspace')),
    ];
    expect(files, isNotEmpty);
    for (final f in files) {
      _walk(
        jsonDecode(stripJsonc(f.readAsStringSync())),
        f.path,
        (path, value) => expect(
          _machineSpecific.hasMatch(value),
          isFalse,
          reason: '$path = "$value"는 기기마다 다를 수 있는 경로다',
        ),
        (key) => expect(
          _sdkKeys.contains(key) || key.toUpperCase() == 'PATH',
          isFalse,
          reason: '${f.path}: $key',
        ),
      );
    }
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/bash.dart';
import '../support/zip.dart';

/// `.github/scripts/verify-api-isolation.sh`(릴리스 APK의 새 API 참조 격리 검사, #109)를 가짜 Android SDK로 실행해 검사한다.
///
/// 가짜 SDK: `build-tools/<버전>/{dexdump,aapt2}`(인자를 기록하고 정해 둔 출력을 내는 bash 스크립트)와
/// `platforms/android-<N>/data/api-versions.xml`(작은 표본). APK는 `classes*.dex`를 담은 실제 ZIP이다 —
/// 가짜 dexdump는 dex 파일 이름으로 출력 표본을 고른다.
/// 실제 R8 결과물과의 대조(격리를 깬 빌드에서 실패하는지 등)는 CI의 `Android Release API Isolation` 잡과 PR 기록으로 확인한다.

const _script = '.github/scripts/verify-api-isolation.sh';

/// 검사 대상이 되는 API 36 전용 타입
const _listener =
    'Landroid/view/accessibility/AccessibilityManager\$HighContrastTextStateChangeListener;';

/// 오래된 클래스에 API 36에 추가된 메서드
const _newMethod =
    'Landroid/view/accessibility/AccessibilityManager;.isHighContrastTextEnabled:()Z';

/// 오래된 클래스에 API 36.1에 추가된 필드
const _newField =
    'Landroid/view/accessibility/AccessibilityManager;.FLAG_NEW:I';

const _apiVersions = '''
<?xml version="1.0" encoding="utf-8"?>
<api version="3">
	<sdk id="30" shortname="R-ext" name="R Extensions" reference="android/os/Build\$VERSION_CODES\$R"/>
	<class name="android/view/accessibility/AccessibilityManager" since="4">
		<extends name="java/lang/Object"/>
		<method name="&lt;init&gt;()V" removed="5"/>
		<method name="isEnabled()Z"/>
		<method name="isHighContrastTextEnabled()Z" since="36"/>
		<method name="addHighContrastTextStateChangeListener(Ljava/util/concurrent/Executor;Landroid/view/accessibility/AccessibilityManager\$HighContrastTextStateChangeListener;)V" since="36"/>
		<method name="isOld()Z" since="35"/>
		<field name="FLAG_NEW" since="36.1"/>
		<field name="FLAG_OLD" since="20"/>
	</class>
	<class name="android/view/accessibility/AccessibilityManager\$HighContrastTextStateChangeListener" since="36">
		<extends name="java/lang/Object"/>
		<method name="onHighContrastTextStateChanged(Z)V"/>
	</class>
	<class name="android/window/NewCallback" module="framework" since="36" sdks="0:36">
		<extends name="java/lang/Object"/>
	</class>
</api>
''';

const _mapping = '''
# compiler: R8
# {"id":"com.android.tools.r8.mapping","version":"2.2"}
com.example.app.Handler -> a:
# {"id":"sourceFile","fileName":"Handler.kt"}
    void refresh() -> b
com.example.app.Handler\$Api36 -> b:
# {"id":"sourceFile","fileName":"Handler.kt"}
    boolean isEnabled(android.view.accessibility.AccessibilityManager) -> a
com.example.app.Handler\$Api36\$\$ExternalSyntheticLambda0 -> c:
# {"id":"com.android.tools.r8.synthesized"}
io.flutter.view.Foo\$\$ExternalSyntheticApiModelOutline0 -> d:
# {"id":"com.android.tools.r8.synthesized"}
android.window.NewCallback -> android.window.NewCallback:
# {"id":"com.android.tools.r8.synthesized"}
    void <clinit>() -> <clinit>
''';

/// CRLF 체크아웃(Windows)에서도 읽혀야 한다
const _rules =
    '# 주석\r\n'
    'guard-api 36\r\n'
    '\r\n'
    r'allow com.example.app.Handler$Api36   # 끝 주석'
    '\r\n'
    r'allow com.example.app.Handler$Api36$$*'
    '\r\n'
    r'allow *$$ExternalSyntheticApiModelOutline*'
    '\r\n';

const _badging =
    "package: name='com.example.app' versionCode='1' versionName='1.0.0' "
    "platformBuildVersionName='16' platformBuildVersionCode='36' "
    "compileSdkVersion='36' compileSdkVersionCodename='16'\n"
    "minSdkVersion:'24'\n"
    "targetSdkVersion:'36'\n";

/// dexdump -d 출력의 클래스 하나 (실제 형식의 머리말 + 메서드 하나 안의 [lines])
String _dexClass(String descriptor, List<String> lines) {
  final name = descriptor.substring(1, descriptor.length - 1);
  return [
    'Class #0            -',
    "  Class descriptor  : '$descriptor'",
    '  Access flags      : 0x0011 (PUBLIC FINAL)',
    "  Superclass        : 'Ljava/lang/Object;'",
    '  Interfaces        -',
    '  Static fields     -',
    '  Instance fields   -',
    '  Direct methods    -',
    '    #0              : (in $descriptor)',
    "      name          : 'a'",
    "      type          : '()V'",
    '      access        : 0x0009 (PUBLIC STATIC)',
    '      code          -',
    '      registers     : 2',
    '029d44:                                        |[029d44] $name.a:()V',
    ...lines,
    '029d74: 0e00                                   |0010: return-void',
    '      catches       : (none)',
    '  Virtual methods   -',
    "  source_file_idx   : 1234 (SourceFile)",
    '',
  ].join('\n');
}

String _dex(String file, List<String> classes) =>
    "Processing '$file'...\nOpened '$file', DEX version '037'\n${classes.join()}";

/// 허용된 곳에만 검사 대상 참조가 있는 dex 두 개 (멀티덱스)
Map<String, String> _okDexes() => {
  'classes.dex': _dex('classes.dex', [
    // 바깥 클래스: 검사 대상이 아닌 참조만 (오래된 메서드·필드, API 35 메서드, 격리 클래스 호출)
    _dexClass('La;', [
      '0000: invoke-virtual {v0}, Landroid/view/accessibility/AccessibilityManager;.isEnabled:()Z // method@0001',
      '0003: sget v0, Landroid/view/accessibility/AccessibilityManager;.FLAG_OLD:I // field@0002',
      '0005: invoke-virtual {v0}, Landroid/view/accessibility/AccessibilityManager;.isOld:()Z // method@0003',
      '0008: invoke-static {v0}, Lb;.a:(Landroid/view/accessibility/AccessibilityManager;)Z // method@0004',
    ]),
    _dexClass('Lb;', [
      '0000: invoke-static {v0}, Ld;.a:(Ljava/lang/Object;)$_listener // method@0005',
    ]),
  ]),
  'classes2.dex': _dex('classes2.dex', [
    _dexClass('Lc;', ["    #0              : '$_listener'"]),
    _dexClass('Ld;', [
      '0000: check-cast v0, $_listener // type@0119',
      '0002: invoke-virtual {v0}, $_newMethod // method@0461',
    ]),
    _dexClass('Landroid/window/NewCallback;', [
      "      type          : '(Landroid/window/NewCallback;)V'",
    ]),
  ]),
};

late Directory _tmp;

String _posix(String path) => path.replaceAll(r'\', '/');

String get _sdk => _posix('${_tmp.path}/sdk');

/// 가짜 도구: 인자를 기록하고, dexdump는 dex 이름(`<이름>.txt`)으로, aapt2는 `badging.txt`로 출력을 고른다
const _fakeTool = r'''#!/usr/bin/env bash
tool=$(basename "$0")
printf '%s %s\n' "$tool" "$*" >>"$FAKE_LOG"
[ -z "${FAKE_FAIL:-}" ] || [ "$FAKE_FAIL" != "$tool" ] || { echo "$tool 실패 흉내" >&2; exit 1; }
case $tool in
  dexdump) [ "$1" = -d ] || exit 9; cat "$FAKE_OUT/$(basename "$2").txt" ;;
  aapt2) [ "$1 $2" = "dump badging" ] || exit 9; cat "$FAKE_OUT/badging.txt" ;;
esac
''';

void _tool(String version, String name) {
  final file = File('${_tmp.path}/sdk/build-tools/$version/$name')
    ..createSync(recursive: true)
    ..writeAsStringSync(_fakeTool);
  // Dart가 만드는 파일은 실행 권한이 없다(0644). Git Bash는 shebang만 보고 실행하지만 Linux·macOS는 권한이 있어야 한다.
  if (!Platform.isWindows) {
    final chmod = Process.runSync('chmod', ['+x', file.path]);
    expect(chmod.exitCode, 0, reason: '${chmod.stderr}');
  }
}

/// 가짜 SDK·APK·대응표·규칙을 쓰고 스크립트를 돌린다. null인 인자는 그 파일을 만들지 않는다.
({ProcessResult result, List<String> calls}) _run({
  Map<String, String>? dexes,
  String? mapping = _mapping,
  String? rules = _rules,
  String badging = _badging,
  String? apiVersions = _apiVersions,
  int platform = 36,
  String? fail,
  Map<String, String> environment = const {},
  List<String> unset = const [],
}) {
  final out = Directory('${_tmp.path}/out')..createSync();
  final dexFiles = dexes ?? _okDexes();
  for (final MapEntry(key: name, value: dump) in dexFiles.entries) {
    File('${out.path}/$name.txt').writeAsStringSync(dump);
  }
  File('${out.path}/badging.txt').writeAsStringSync(badging);
  final apk = File('${_tmp.path}/app-release.apk')
    ..writeAsBytesSync(
      storedZip({
        'AndroidManifest.xml': utf8.encode('manifest'),
        for (final name in dexFiles.keys) name: utf8.encode('dex $name'),
        'res/raw/a.txt': utf8.encode('res'),
      }),
    );
  final mappingFile = File('${_tmp.path}/mapping.txt');
  if (mapping != null) mappingFile.writeAsStringSync(mapping);
  final rulesFile = File('${_tmp.path}/rules');
  if (rules != null) rulesFile.writeAsStringSync(rules);
  if (apiVersions != null) {
    File('${_tmp.path}/sdk/platforms/android-$platform/data/api-versions.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync(apiVersions);
  }
  final log = File('${_tmp.path}/calls.log')..writeAsStringSync('');
  final result = runBashScript(
    _script,
    [_posix(apk.path), _posix(mappingFile.path)],
    environment: {
      'ANDROID_HOME': _sdk,
      'API_ISOLATION_RULES': _posix(rulesFile.path),
      'FAKE_OUT': _posix(out.path),
      'FAKE_LOG': _posix(log.path),
      'FAKE_FAIL': ?fail,
      ...environment,
    },
    // 로컬 출력 형식(`오류:`)을 본다 — CI 안에서 돌아도 같게
    // 부모 환경의 ANDROID_SDK_ROOT(CI 러너에 있다)가 가짜 SDK 대신 쓰이지 않게 지운다 — 테스트가 직접 준 값은 남긴다
    unset: [
      'GITHUB_ACTIONS',
      if (!environment.containsKey('ANDROID_SDK_ROOT')) 'ANDROID_SDK_ROOT',
      ...unset,
    ],
  );
  return (result: result, calls: log.readAsLinesSync());
}

/// 검사 대상 참조가 [lines]인 클래스 [descriptor]를 허용된 dex에 더한다
Map<String, String> _withClass(String descriptor, List<String> lines) {
  final dexes = _okDexes();
  dexes['classes3.dex'] = _dex('classes3.dex', [_dexClass(descriptor, lines)]);
  return dexes;
}

void main() {
  setUp(() {
    _tmp = Directory.systemTemp.createTempSync('api_isolation_test');
    // 버전 순서: 9.0.0 < 36.0.0 < 37.0.0 (글자순이면 9.0.0이 가장 높다). 37.0.0에는 aapt2가 없다.
    for (final version in ['9.0.0', '36.0.0']) {
      _tool(version, 'dexdump');
      _tool(version, 'aapt2');
    }
    _tool('37.0.0', 'dexdump');
  });
  tearDown(() => _tmp.deleteSync(recursive: true));

  test('인자가 둘이 아니면 사용법과 함께 2로 끝난다', () {
    for (final args in [
      <String>[],
      ['a.apk'],
      ['a.apk', 'm.txt', 'x'],
    ]) {
      final result = runBashScript(_script, args);
      expect(result.exitCode, 2, reason: '$args');
      expect(result.stderr, contains('사용:'), reason: '$args');
    }
  });

  test('검사 대상 참조가 격리 클래스·R8 아웃라인·R8 스텁에만 있으면 통과한다', () {
    final run = _run();
    expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
    final out = run.result.stdout as String;
    expect(out, contains('APK: minSdk 24, compileSdk 36'));
    expect(out, contains('dex 2개 검사'));
    expect(
      out,
      contains('허용 com.example.app.Handler\$Api36 (dex b)\n    $_listener'),
    );
    expect(
      out,
      contains(
        '허용 com.example.app.Handler\$Api36\$\$ExternalSyntheticLambda0 (dex c)',
      ),
    );
    expect(
      out,
      contains(
        '허용 io.flutter.view.Foo\$\$ExternalSyntheticApiModelOutline0 (dex d)\n'
        '    $_listener\n'
        '    $_newMethod',
      ),
    );
    expect(
      out,
      contains(
        '허용(R8 스텁) android.window.NewCallback (dex android.window.NewCallback)',
      ),
    );
    expect(out, isNot(contains('위반')));
    expect(out, contains('통과'));
    // 검사 대상이 아닌 참조(오래된 메서드·필드, API 35 메서드)만 있는 바깥 클래스는 목록에 없다
    expect(out, isNot(contains('com.example.app.Handler (dex a)')));
    // 두 도구가 모두 있는 가장 높은 버전(36.0.0)을 쓰고, dex를 모두 연다
    expect(run.calls, [
      'aapt2 dump badging ${_posix('${_tmp.path}/app-release.apk')}',
      for (final dex in ['classes.dex', 'classes2.dex'])
        allOf(startsWith('dexdump -d '), endsWith('/$dex')),
    ]);
    expect(out, contains('build-tools/36.0.0/dexdump'));
  });

  group('허용 밖의 검사 대상 참조를 잡는다', () {
    final cases = <String, List<String>>{
      '새 타입 (캐스트)': ['0000: check-cast v0, $_listener // type@0119'],
      '오래된 클래스의 새 메서드': [
        '0000: invoke-virtual {v0}, $_newMethod // method@0461',
      ],
      '오래된 클래스의 새 필드 (API 36.1)': ['0000: sget v0, $_newField // field@0007'],
      '다른 메서드 시그니처 안의 새 타입': [
        '0000: invoke-static {v0}, Ld;.a:(Ljava/lang/Object;)$_listener // method@0005',
      ],
      '구현하는 인터페이스': ["    #0              : '$_listener'"],
    };
    for (final MapEntry(key: name, value: lines) in cases.entries) {
      test(name, () {
        final run = _run(dexes: _withClass('La;', lines));
        expect(run.result.exitCode, 1, reason: '${run.result.stdout}');
        final out = run.result.stdout as String;
        expect(out, contains('위반 com.example.app.Handler (dex a)'));
        final err = run.result.stderr as String;
        expect(err, contains('오류: API 36 이상 전용 참조가 허용된 격리 클래스'));
        expect(err, contains('API 35 이하 기기'));
      });
    }

    test('대응표에 없는 클래스는 dex 이름 그대로 맞춘다', () {
      final run = _run(
        dexes: _withClass('Lcom/example/app/Kept;', [
          '0000: check-cast v0, $_listener // type@0119',
        ]),
      );
      expect(run.result.exitCode, 1);
      expect(
        run.result.stdout,
        contains('위반 com.example.app.Kept (dex com.example.app.Kept)'),
      );
    });

    test('프레임워크 이름이라도 R8 합성 표시가 없는 앱 클래스는 스텁으로 보지 않는다', () {
      final run = _run(
        mapping: '${_mapping}android.window.NewCallback -> e:\n',
        dexes: _withClass('Le;', [
          '0000: check-cast v0, $_listener // type@0119',
        ]),
      );
      expect(run.result.exitCode, 1);
      expect(
        run.result.stdout,
        contains('위반 android.window.NewCallback (dex e)'),
      );
    });

    test('glob의 점·달러는 글자 그대로 맞춘다', () {
      // `com.example.app.Handler$Api36`이 `com.example.app.HandlerXApi36`이나 접미사 붙은 이름에 맞으면 안 된다
      final run = _run(
        mapping:
            '${_mapping}com.example.app.HandlerXApi36 -> e:\ncom.example.app.Handler\$Api36Extra -> f:\n',
        dexes: {
          ..._okDexes(),
          'classes3.dex': _dex('classes3.dex', [
            _dexClass('Le;', ['0000: check-cast v0, $_listener // type@0119']),
            _dexClass('Lf;', ['0000: check-cast v0, $_listener // type@0119']),
          ]),
        },
      );
      expect(run.result.exitCode, 1);
      final out = run.result.stdout as String;
      expect(out, contains('위반 com.example.app.HandlerXApi36 (dex e)'));
      expect(out, contains('위반 com.example.app.Handler\$Api36Extra (dex f)'));
    });
  });

  group('검사가 헛돌 상황에서는 실패한다', () {
    test('검사 대상 참조가 하나도 없다', () {
      final run = _run(
        dexes: {
          'classes.dex': _dex('classes.dex', [
            _dexClass('La;', [
              '0000: invoke-virtual {v0}, Landroid/view/accessibility/AccessibilityManager;.isEnabled:()Z // method@0001',
            ]),
          ]),
        },
      );
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('하나도 찾지 못했다'));
    });

    test('dexdump 출력에서 클래스를 읽지 못한다', () {
      final run = _run(dexes: {'classes.dex': 'Processing...\n$_listener\n'});
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('클래스를 하나도 읽지 못했다'));
    });

    test('api-versions.xml에 guard-api 이상 항목이 없다', () {
      final run = _run(
        apiVersions: _apiVersions.replaceAll(
          RegExp(r'since="36(\.1)?"'),
          'since="30"',
        ),
      );
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('API 36 이상 항목이 없다'));
    });

    test('compileSdk 플랫폼의 api-versions.xml이 없다', () {
      final run = _run(platform: 35);
      expect(run.result.exitCode, 1);
      expect(
        run.result.stderr,
        contains('compileSdk 36 플랫폼의 api-versions.xml이 없다'),
      );
    });

    test('minSdk가 guard-api 이상이다', () {
      final run = _run(
        badging: _badging.replaceFirst(
          "minSdkVersion:'24'",
          "minSdkVersion:'36'",
        ),
      );
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('minSdk(36)가 guard-api(36) 이상'));
    });

    test('badging에서 SDK 수준을 읽지 못한다', () {
      final run = _run(badging: "package: name='x'\n");
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('minSdk·compileSdk를 읽지 못했다'));
    });

    test('mapping.txt가 없거나 비었다 (R8이 돌지 않은 빌드)', () {
      for (final mapping in [null, '']) {
        final run = _run(mapping: mapping);
        expect(run.result.exitCode, 1, reason: '$mapping');
        expect(run.result.stderr, contains('mapping.txt가 없거나 비었다'));
      }
    });

    test('APK에 dex가 없다', () {
      final run = _run(dexes: {});
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('classes*.dex가 없다'));
    });

    test('도구가 실패한다', () {
      for (final tool in ['dexdump', 'aapt2']) {
        final run = _run(fail: tool);
        expect(run.result.exitCode, 1, reason: tool);
        expect(run.result.stderr, contains('$tool '), reason: tool);
        expect(run.calls, contains(startsWith('$tool ')), reason: tool);
      }
    });

    test('Android SDK나 build-tools를 찾지 못한다', () {
      var run = _run(unset: ['ANDROID_HOME']);
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('Android SDK를 찾지 못했다'));

      Directory('${_tmp.path}/sdk/build-tools').deleteSync(recursive: true);
      run = _run();
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('dexdump·aapt2가 함께 있는 버전을 찾지 못했다'));
    });

    test('ANDROID_HOME이 없으면 ANDROID_SDK_ROOT를 쓴다', () {
      final run = _run(
        environment: {'ANDROID_SDK_ROOT': _sdk},
        unset: ['ANDROID_HOME'],
      );
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
    });
  });

  group('규칙 파일 형식', () {
    final bad = <String, String>{
      'guard-api 36\n': 'allow가 하나도 없다',
      'allow *\n': 'guard-api가 없다',
      'guard-api 36\nguard-api 35\nallow *\n': 'guard-api가 두 번 있다',
      'guard-api 36.1\nallow *\n': 'guard-api는 정수',
      'guard-api 36\nallow a b\n': '형식이 틀렸다',
      'guard-api 36\nallow\n': '형식이 틀렸다',
      'guard-api 36\ndeny *\n': "모르는 지시어 'deny'",
    };
    for (final MapEntry(key: rules, value: message) in bad.entries) {
      test(message, () {
        final run = _run(rules: rules);
        expect(run.result.exitCode, 1, reason: rules);
        expect(run.result.stderr, contains(message), reason: rules);
        // 규칙이 틀리면 도구를 부르기 전에 멈춘다
        expect(run.calls, isEmpty);
      });
    }

    test('규칙 파일이 없다', () {
      final run = _run(rules: null);
      expect(run.result.exitCode, 1);
      expect(run.result.stderr, contains('규칙 파일이 없다'));
    });
  });
}

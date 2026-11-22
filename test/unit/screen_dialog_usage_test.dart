import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 앱 코드는 화면 단위 대화상자를 `showScreenDialog`로만 띄운다 (#72).
///
/// 아래 함수들은 기본값이 루트 Navigator(`useRootNavigator: true`)라, 직접 부르면 개발용 미리보기에서
/// 대화상자가 기기 틀 밖(미리보기 창 전체)에 뜬다. 앱 동작은 같아서 다른 테스트로는 드러나지 않으므로
/// 소스를 검사한다.
const List<String> _rootNavigatorByDefault = [
  'showDialog',
  'showAdaptiveDialog',
  'showGeneralDialog',
  'showCupertinoDialog',
  'showCupertinoModalPopup',
  'showAboutDialog',
  'showDatePicker',
  'showDateRangePicker',
  'showTimePicker',
];

/// 직접 호출을 허용하는 파일 (공용 함수 정의)
const String _allowedFile = 'lib/presentation/widgets/screen_dialog.dart';

/// [source]에서 주석을 뺀 뒤 [_rootNavigatorByDefault] 함수를 직접 부르는 곳의 줄 번호(1부터)와 함수 이름.
List<(int, String)> findDirectDialogCalls(String source) {
  final call = RegExp(
    r'\b(' + _rootNavigatorByDefault.join('|') + r')\s*(<[^>()]*>)?\s*\(',
  );
  final found = <(int, String)>[];
  final lines = source.split('\n');
  var inBlockComment = false;
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    // 블록 주석(/* */)과 줄 주석(//, ///)을 지운다. 문자열 안의 '//'(URL 등)는 드물어 고려하지 않는다.
    if (inBlockComment) {
      final end = line.indexOf('*/');
      if (end < 0) continue;
      line = line.substring(end + 2);
      inBlockComment = false;
    }
    line = line.replaceAll(RegExp(r'/\*.*?\*/'), '');
    final open = line.indexOf('/*');
    if (open >= 0) {
      line = line.substring(0, open);
      inBlockComment = true;
    }
    final comment = line.indexOf('//');
    if (comment >= 0) line = line.substring(0, comment);
    for (final m in call.allMatches(line)) {
      found.add((i + 1, m.group(1)!));
    }
  }
  return found;
}

void main() {
  group('검사기 자체', () {
    test('직접 호출(타입 인자 포함)을 찾는다', () {
      const source = '''
void a(BuildContext c) {
  showDialog(context: c, builder: (_) => const Text('x'));
  showDialog<void>(context: c, builder: (_) => const Text('x'));
  final t = await showTimePicker (context: c, initialTime: now);
}
''';
      expect(findDirectDialogCalls(source), [
        (2, 'showDialog'),
        (3, 'showDialog'),
        (4, 'showTimePicker'),
      ]);
    });

    test('주석·다른 이름(showScreenDialog, showDialogX)은 세지 않는다', () {
      const source = '''
/// [showDialog] 대신 showScreenDialog(...)를 쓴다. showDialog(...)는 금지.
// showDialog(context: c)
/* showGeneralDialog(
   context: c) */
showScreenDialog<void>(context: c, builder: b);
showDialogX(c);
''';
      expect(findDirectDialogCalls(source), isEmpty);
    });
  });

  test(
    'lib/는 루트 Navigator가 기본인 대화상자 함수를 직접 부르지 않는다 (showScreenDialog를 쓴다)',
    () {
      final violations = <String>[];
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(files, isNotEmpty);
      for (final file in files) {
        final path = file.path.replaceAll(r'\', '/');
        if (path.endsWith(_allowedFile)) continue;
        for (final (line, name) in findDirectDialogCalls(
          file.readAsStringSync(),
        )) {
          violations.add('$path:$line $name');
        }
      }
      expect(violations, isEmpty, reason: 'showScreenDialog를 쓸 것');
    },
  );

  test('허용 파일은 존재하고 showDialog를 useRootNavigator: false로 부른다', () {
    final source = File(_allowedFile).readAsStringSync();
    expect(findDirectDialogCalls(source), isNotEmpty);
    expect(source, contains('useRootNavigator: false'));
  });
}

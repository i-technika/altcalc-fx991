import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 저장소가 추적하는 이미지·글꼴·소리 파일이 출처를 적은 목록(`.github/tracked-binary-assets`)과 같은지 지킨다 (#280).
///
/// CLAUDE.md "지식재산권 작업 규칙" 6번(외부 구성 요소는 넣기 전에 라이선스를 확인해 출처 기록에 올린다)과
/// 8번·4절(참고 자료의 사진·쪽 이미지를 저장소에 넣지 않는다)을 자동으로 확인하는 보조 검사다.
/// 출처가 맞는지는 사람이 본다 — 이 테스트는 목록에 없는 파일이 들어오거나 목록과 실제가 어긋나는 것을 잡는다.

/// 목록 파일 경로 (패키지 루트 기준)
const _listPath = '.github/tracked-binary-assets';

/// 검사 대상 확장자 (소문자). `/close-ms` 2단계의 diff 점검 확장자와 같아야 한다.
/// 참고 자료가 들어오는 가장 흔한 형식인 PDF(User's Guide·Quick Start Guide)도 넣는다(#280 R1).
const binaryAssetExtensions = {
  'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'avif', 'svg', 'ico', 'icns', 'tif', 'tiff', 'heic', //
  'ttf', 'otf', 'ttc', 'woff', 'woff2', 'eot', //
  'mp3', 'wav', 'ogg', 'm4a', 'flac', 'mp4', 'webm', //
  'pdf',
};

bool _isBinaryAsset(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  return dot > 0 &&
      binaryAssetExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// 패키지 루트에서 git을 실행한다 (경로는 UTF-8로 읽는다 — `gitattributes_test.dart`와 같다).
ProcessResult _runGit(List<String> args) => Process.runSync(
  'git',
  ['-C', Directory.current.path, ...args],
  stdoutEncoding: utf8,
  stderrEncoding: utf8,
);

/// 목록 한 줄 — 경로와 출처
typedef _Entry = ({int line, String path, String source});

List<_Entry> _parseList(String text) {
  final entries = <_Entry>[];
  final lines = const LineSplitter().convert(text);
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final space = line.indexOf(RegExp(r'\s'));
    entries.add((
      line: i + 1,
      path: space < 0 ? line : line.substring(0, space),
      source: space < 0 ? '' : line.substring(space).trim(),
    ));
  }
  return entries;
}

void main() {
  late List<String> tracked;
  late List<_Entry> entries;

  setUpAll(() {
    final probe = _runGit(['rev-parse', '--show-toplevel']);
    if (probe.exitCode != 0) {
      fail('git 저장소에서 실행해야 하는 테스트다 (git 없음 또는 .git 없음): ${probe.stderr}');
    }
    final top = Directory((probe.stdout as String).trim())
        .resolveSymbolicLinksSync();
    expect(
      top.toLowerCase(),
      Directory.current.resolveSymbolicLinksSync().toLowerCase(),
      reason: '패키지 루트에서 flutter test를 실행해야 한다',
    );
    // 추적 파일 + 아직 `git add` 하지 않은 새 파일(무시 목록 제외) — 커밋 전 로컬 `flutter test`에서 미리 잡는다(#280 R1).
    final ls = _runGit(['ls-files', '-z', '--cached', '--others', '--exclude-standard']);
    expect(ls.exitCode, 0, reason: 'git ls-files 실패: ${ls.stderr}');
    tracked = (ls.stdout as String)
        .split('\u0000')
        .where((p) => p.isNotEmpty)
        .toList();
    entries = _parseList(File(_listPath).readAsStringSync());
  });

  test('목록의 모든 줄은 경로와 출처를 함께 적는다 (중복 없음)', () {
    expect(entries, isNotEmpty);
    final seen = <String>{};
    for (final e in entries) {
      expect(e.source, isNotEmpty, reason: '$_listPath:${e.line} ${e.path} — 출처가 없다');
      expect(seen.add(e.path), isTrue, reason: '$_listPath:${e.line} ${e.path} — 중복');
      expect(
        _isBinaryAsset(e.path),
        isTrue,
        reason: '$_listPath:${e.line} ${e.path} — 검사 대상 확장자가 아니다',
      );
    }
  });

  test('추적 중인 이미지·글꼴·소리·PDF 파일은 목록과 정확히 같다', () {
    final actual = tracked.where(_isBinaryAsset).toSet();
    // 목록 형식은 첫 공백에서 경로를 나누므로 공백이 든 경로는 적을 수 없다 — 그런 파일은 이름을 바꾼다
    expect(
      actual.where((p) => p.contains(RegExp(r'\s'))),
      isEmpty,
      reason: '공백이 든 경로는 $_listPath에 적을 수 없다 — 파일 이름을 바꾼다',
    );
    final listed = entries.map((e) => e.path).toSet();
    expect(
      actual.difference(listed),
      isEmpty,
      reason: '목록에 없는 파일이 추적되고 있다 — 출처를 확인해 $_listPath에 더하거나, 참고 자료라면 지운다',
    );
    expect(
      listed.difference(actual),
      isEmpty,
      reason: '목록에는 있지만 추적되지 않는 파일이다 — 지우거나 옮긴 파일을 목록에서도 고친다',
    );
  });

  test('목록 해석: 주석·빈 줄을 건너뛰고 첫 공백에서 경로와 출처를 나눈다', () {
    final parsed = _parseList(
      '# 주석\n\n  a/b.png  출처 이름 (라이선스)\nc.ttf\n',
    );
    expect(parsed.map((e) => (e.line, e.path, e.source)), [
      (3, 'a/b.png', '출처 이름 (라이선스)'),
      (4, 'c.ttf', ''),
    ]);
  });
}

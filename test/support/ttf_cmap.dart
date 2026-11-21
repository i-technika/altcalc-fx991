import 'dart:io';
import 'dart:typed_data';

/// TrueType/OpenType 글꼴 파일의 `cmap` 테이블에서 글리프가 있는 코드 포인트 집합을 읽는다.
///
/// 테스트 전용 최소 구현이다. 유니코드 BMP(format 4)와 전체 범위(format 12) 서브테이블만 읽는다.
/// 글리프 0(`.notdef`)으로 매핑된 코드 포인트는 "글리프 없음"으로 보고 제외한다.
Set<int> readCmapCodePoints(String path) {
  final data = ByteData.sublistView(File(path).readAsBytesSync());

  // 테이블 디렉터리에서 cmap 위치를 찾는다.
  final numTables = data.getUint16(4);
  int? cmapOffset;
  for (var i = 0; i < numTables; i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes([
      for (var j = 0; j < 4; j++) data.getUint8(record + j),
    ]);
    if (tag == 'cmap') cmapOffset = data.getUint32(record + 8);
  }
  if (cmapOffset == null) throw FormatException('cmap 테이블 없음: $path');

  // 유니코드 서브테이블을 우선순위대로 고른다: (3,10) format 12 → (0,4) → (3,1) → (0,3).
  final subtables = <(int, int), int>{};
  final count = data.getUint16(cmapOffset + 2);
  for (var i = 0; i < count; i++) {
    final record = cmapOffset + 4 + i * 8;
    subtables[(data.getUint16(record), data.getUint16(record + 2))] =
        cmapOffset + data.getUint32(record + 4);
  }
  for (final key in const [(3, 10), (0, 4), (3, 1), (0, 3)]) {
    final offset = subtables[key];
    if (offset == null) continue;
    return switch (data.getUint16(offset)) {
      4 => _readFormat4(data, offset),
      12 => _readFormat12(data, offset),
      final format => throw FormatException('지원하지 않는 cmap format $format'),
    };
  }
  throw FormatException('유니코드 cmap 서브테이블 없음: $path');
}

Set<int> _readFormat4(ByteData data, int offset) {
  final segCount = data.getUint16(offset + 6) ~/ 2;
  final endCodes = offset + 14;
  final startCodes = endCodes + segCount * 2 + 2; // reservedPad 2바이트
  final idDeltas = startCodes + segCount * 2;
  final idRangeOffsets = idDeltas + segCount * 2;
  final result = <int>{};
  for (var seg = 0; seg < segCount; seg++) {
    final end = data.getUint16(endCodes + seg * 2);
    final start = data.getUint16(startCodes + seg * 2);
    final delta = data.getUint16(idDeltas + seg * 2);
    final rangeOffsetPos = idRangeOffsets + seg * 2;
    final rangeOffset = data.getUint16(rangeOffsetPos);
    for (var code = start; code <= end && code != 0xFFFF; code++) {
      int glyph;
      if (rangeOffset == 0) {
        glyph = (code + delta) & 0xFFFF;
      } else {
        final glyphPos = rangeOffsetPos + rangeOffset + (code - start) * 2;
        glyph = data.getUint16(glyphPos);
        if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
      }
      if (glyph != 0) result.add(code);
    }
  }
  return result;
}

Set<int> _readFormat12(ByteData data, int offset) {
  final groups = data.getUint32(offset + 12);
  final result = <int>{};
  for (var i = 0; i < groups; i++) {
    final group = offset + 16 + i * 12;
    final start = data.getUint32(group);
    final end = data.getUint32(group + 4);
    final startGlyph = data.getUint32(group + 8);
    for (var code = start; code <= end; code++) {
      if (startGlyph + (code - start) != 0) result.add(code);
    }
  }
  return result;
}

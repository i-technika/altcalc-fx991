import 'dart:typed_data';

/// TrueType/OpenType 글꼴 데이터의 `cmap` 테이블에서 글리프가 있는 코드 포인트 집합을 읽는다.
/// (글꼴 데이터는 `rootBundle.load`로 읽어 넘긴다 — 파일 경로·작업 디렉터리에 기대지 않는다.)
///
/// 테스트 전용 최소 구현이다. 유니코드 BMP(format 4)와 전체 범위(format 12) 서브테이블만 읽는다.
/// 글리프 0(`.notdef`)으로 매핑된 코드 포인트는 "글리프 없음"으로 보고 제외한다.
Set<int> readCmapCodePoints(ByteData data) => readCmap(data).keys.toSet();

/// [data]의 테이블 디렉터리에서 [tag] 테이블의 시작 위치를 찾는다. 없으면 `null`.
int? _tableOffset(ByteData data, String tag) {
  final numTables = data.getUint16(4);
  for (var i = 0; i < numTables; i++) {
    final record = 12 + i * 16;
    final name = String.fromCharCodes([
      for (var j = 0; j < 4; j++) data.getUint8(record + j),
    ]);
    if (name == tag) return data.getUint32(record + 8);
  }
  return null;
}

/// `cmap` 테이블의 코드 포인트 → 글리프 번호 (글리프 0으로 매핑된 코드 포인트는 뺀다).
Map<int, int> readCmap(ByteData data) {
  final cmapOffset = _tableOffset(data, 'cmap');
  if (cmapOffset == null) throw const FormatException('cmap 테이블 없음');

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
  throw const FormatException('유니코드 cmap 서브테이블 없음');
}

Map<int, int> _readFormat4(ByteData data, int offset) {
  final segCount = data.getUint16(offset + 6) ~/ 2;
  final endCodes = offset + 14;
  final startCodes = endCodes + segCount * 2 + 2; // reservedPad 2바이트
  final idDeltas = startCodes + segCount * 2;
  final idRangeOffsets = idDeltas + segCount * 2;
  final result = <int, int>{};
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
      if (glyph != 0) result[code] = glyph;
    }
  }
  return result;
}

Map<int, int> _readFormat12(ByteData data, int offset) {
  final groups = data.getUint32(offset + 12);
  final result = <int, int>{};
  for (var i = 0; i < groups; i++) {
    final group = offset + 16 + i * 12;
    final start = data.getUint32(group);
    final end = data.getUint32(group + 4);
    final startGlyph = data.getUint32(group + 8);
    for (var code = start; code <= end; code++) {
      final glyph = startGlyph + (code - start);
      if (glyph != 0) result[code] = glyph;
    }
  }
  return result;
}

/// 글리프의 세로 잉크 범위 (em 단위, 기준선 위가 +).
typedef GlyphYBounds = ({double yMin, double yMax});

/// [data] 글꼴에서 [codePoint] 글리프의 세로 잉크 범위(`glyf` 테이블의 yMin·yMax ÷ unitsPerEm)를 읽는다.
///
/// 테스트 전용 최소 구현이다. TrueType 윤곽(`glyf`·`loca`) 글꼴만 읽는다. 윤곽이 없는 글리프(공백 등)는 `null`.
GlyphYBounds? readGlyphYBounds(ByteData data, int codePoint) {
  final glyph = readCmap(data)[codePoint];
  if (glyph == null) {
    throw FormatException('글리프 없음: U+${codePoint.toRadixString(16)}');
  }
  final head = _tableOffset(data, 'head');
  final loca = _tableOffset(data, 'loca');
  final glyf = _tableOffset(data, 'glyf');
  if (head == null || loca == null || glyf == null) {
    throw const FormatException('head·loca·glyf 테이블 없음 (TrueType 윤곽 글꼴이 아니다)');
  }
  final unitsPerEm = data.getUint16(head + 18);
  final longOffsets = data.getInt16(head + 50) == 1;
  final (start, end) = longOffsets
      ? (data.getUint32(loca + glyph * 4), data.getUint32(loca + glyph * 4 + 4))
      : (
          data.getUint16(loca + glyph * 2) * 2,
          data.getUint16(loca + glyph * 2 + 2) * 2,
        );
  if (end == start) return null;
  final record = glyf + start;
  return (
    yMin: data.getInt16(record + 4) / unitsPerEm,
    yMax: data.getInt16(record + 8) / unitsPerEm,
  );
}

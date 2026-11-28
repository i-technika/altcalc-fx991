import 'dart:convert';
import 'dart:typed_data';

/// 압축하지 않은(stored) ZIP 파일을 만든다 — 테스트에서 가짜 APK를 만드는 데 쓴다 (#109).
/// `unzip`이 읽을 수 있는 최소 형식(로컬 헤더·중앙 디렉터리·끝 레코드, CRC-32 포함)만 쓴다.
Uint8List storedZip(Map<String, List<int>> entries) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  for (final MapEntry(key: name, value: data) in entries.entries) {
    final nameBytes = utf8.encode(name);
    final crc = _crc32(data);
    final offset = out.length;
    // 로컬 파일 헤더
    out
      ..add(_u32(0x04034b50))
      ..add(_u16(20)) // 풀 때 필요한 버전
      ..add(_u16(0)) // 플래그
      ..add(_u16(0)) // 압축 방식: stored
      ..add(_u16(0)) // 시각
      ..add(_u16(0x21)) // 날짜 1980-01-01
      ..add(_u32(crc))
      ..add(_u32(data.length))
      ..add(_u32(data.length))
      ..add(_u16(nameBytes.length))
      ..add(_u16(0))
      ..add(nameBytes)
      ..add(data);
    // 중앙 디렉터리 항목
    central
      ..add(_u32(0x02014b50))
      ..add(_u16(20))
      ..add(_u16(20))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u16(0x21))
      ..add(_u32(crc))
      ..add(_u32(data.length))
      ..add(_u32(data.length))
      ..add(_u16(nameBytes.length))
      ..add(_u16(0)) // 추가 필드
      ..add(_u16(0)) // 주석
      ..add(_u16(0)) // 디스크 번호
      ..add(_u16(0)) // 내부 속성
      ..add(_u32(0)) // 외부 속성
      ..add(_u32(offset))
      ..add(nameBytes);
  }
  final centralOffset = out.length;
  final centralBytes = central.takeBytes();
  out
    ..add(centralBytes)
    ..add(_u32(0x06054b50))
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(_u16(entries.length))
    ..add(_u16(entries.length))
    ..add(_u32(centralBytes.length))
    ..add(_u32(centralOffset))
    ..add(_u16(0));
  return out.takeBytes();
}

List<int> _u16(int v) => [v & 0xff, (v >> 8) & 0xff];

List<int> _u32(int v) => [
  v & 0xff,
  (v >> 8) & 0xff,
  (v >> 16) & 0xff,
  (v >> 24) & 0xff,
];

int _crc32(List<int> data) {
  var crc = 0xffffffff;
  for (final byte in data) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return crc ^ 0xffffffff;
}

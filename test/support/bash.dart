import 'dart:convert';
import 'dart:io';

/// 저장소의 셸 스크립트(`.github/scripts/*.sh`)를 테스트에서 실행하는 도구.
/// 경로는 패키지 루트(= `flutter test`의 작업 디렉터리) 기준이다.

/// 스크립트를 실행할 bash.
///
/// Windows에서는 PATH의 `bash`를 쓰지 않는다 — `C:\Windows\System32\bash.exe`(WSL 실행기)가 먼저 잡히면
/// 배포판이 없을 때 실패하고, 있어도 다른 환경(리눅스 쪽 파일 시스템·도구)에서 돈다.
/// Git for Windows에 들어 있는 bash를 git 설치 위치(`git --exec-path`의 상위 폴더)에서 찾는다.
/// CI의 Windows 러너가 `shell: bash`로 쓰는 것과 같은 bash다.
String findBash() {
  if (!Platform.isWindows) return 'bash';

  final ProcessResult result;
  try {
    result = Process.runSync('git', ['--exec-path']);
  } on ProcessException catch (e) {
    throw StateError('bash를 찾으려면 git이 PATH에 있어야 한다: $e');
  }
  if (result.exitCode != 0) {
    throw StateError('git --exec-path 실패: ${result.stderr}');
  }
  // 예: C:/Program Files/Git/mingw64/libexec/git-core → C:/Program Files/Git/bin/bash.exe
  final start = (result.stdout as String).trim();
  var dir = Directory(start);
  while (true) {
    final bash = File('${dir.path}/bin/bash.exe');
    if (bash.existsSync()) return bash.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError(
    'Git for Windows의 bash(bin/bash.exe)를 찾지 못했다 — git 위치: $start',
  );
}

/// 패키지 루트에서 bash 스크립트를 실행한다.
/// 출력은 시스템 인코딩(Windows 한국어는 cp949) 대신 UTF-8로 읽는다 — 스크립트 메시지가 한국어다.
/// [environment]는 부모 환경에 덮어쓴다.
ProcessResult runBashScript(
  String script,
  List<String> args, {
  Map<String, String> environment = const {},
}) => Process.runSync(
  findBash(),
  [script, ...args],
  workingDirectory: Directory.current.path,
  environment: environment,
  stdoutEncoding: utf8,
  stderrEncoding: utf8,
);

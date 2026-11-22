import 'dart:convert';
import 'dart:io';

/// 저장소의 셸 스크립트(`.github/scripts/*.sh`)를 테스트에서 실행하는 도구.
/// 경로는 패키지 루트(= `flutter test`의 작업 디렉터리) 기준이다.

/// 스크립트를 실행할 bash (한 번만 찾는다).
///
/// Windows에서는 PATH의 `bash`를 쓰지 않는다 — `C:\Windows\System32\bash.exe`(WSL 실행기)가 먼저 잡히면
/// 배포판이 없을 때 실패하고, 있어도 다른 환경(리눅스 쪽 파일 시스템·도구)에서 돈다.
/// Git for Windows에 들어 있는 bash를 git 설치 위치에서 찾는다.
/// CI의 Windows 러너가 `shell: bash`로 쓰는 것과 같은 bash다.
final String bashPath = _findBash();

/// `git --exec-path`에서 위로 올라가며 찾는 최대 단계 수
/// (Git for Windows는 `<루트>/mingw64/libexec/git-core`라 3단계 위가 설치 루트다)
const _maxLevelsUp = 3;

String _findBash() {
  if (!Platform.isWindows) return 'bash';

  final ProcessResult result;
  try {
    // git은 경로를 UTF-8로 내보낸다 — 시스템 인코딩(cp949)으로 읽으면 한글 사용자 이름 아래 설치된 Git을 못 찾는다
    result = Process.runSync(
      'git',
      ['--exec-path'],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  } on ProcessException catch (e) {
    throw StateError('bash를 찾으려면 git이 PATH에 있어야 한다: $e');
  }
  if (result.exitCode != 0) {
    throw StateError('git --exec-path 실패: ${result.stderr}');
  }
  // 예: C:/Program Files/Git/mingw64/libexec/git-core → C:/Program Files/Git/bin/bash.exe
  // 최대 3단계까지만 올라간다 — 드라이브 루트의 `C:\bin\bash.exe` 같은 무관한 bash를 잡지 않게.
  final start = (result.stdout as String).trim();
  final dirs = <Directory>[Directory(start)];
  for (var i = 0; i < _maxLevelsUp; i++) {
    final parent = dirs.last.parent;
    if (parent.path == dirs.last.path) break;
    dirs.add(parent);
  }
  // 가까운 폴더부터 본다. 한 폴더에서는 `bin/bash.exe`(환경을 갖춰 주는 실행기)를 먼저,
  // 없으면 `usr/bin/bash.exe`(본체)를 쓴다.
  for (final dir in dirs) {
    for (final relative in ['bin/bash.exe', 'usr/bin/bash.exe']) {
      final bash = File('${dir.path}/$relative');
      if (bash.existsSync()) return bash.path;
    }
  }
  throw StateError(
    'Git for Windows의 bash(bin/bash.exe 또는 usr/bin/bash.exe)를 찾지 못했다 — '
    'git --exec-path: $start',
  );
}

/// 패키지 루트에서 bash 스크립트를 실행한다.
/// 출력은 시스템 인코딩(Windows 한국어는 cp949) 대신 UTF-8로 읽는다 — 스크립트 메시지가 한국어다.
/// [environment]는 부모 환경에 덮어쓰고, [unset]의 변수는 스크립트를 실행하기 전에 지운다
/// (`Process`로는 부모 환경의 변수 하나만 뺄 수 없어 bash 안에서 지운다).
ProcessResult runBashScript(
  String script,
  List<String> args, {
  Map<String, String> environment = const {},
  List<String> unset = const [],
}) => Process.runSync(
  bashPath,
  unset.isEmpty
      ? [script, ...args]
      : [
          '-c',
          'unset ${unset.join(' ')}; exec "\$BASH" "\$@"',
          'bash',
          script,
          ...args,
        ],
  workingDirectory: Directory.current.path,
  environment: environment,
  stdoutEncoding: utf8,
  stderrEncoding: utf8,
);

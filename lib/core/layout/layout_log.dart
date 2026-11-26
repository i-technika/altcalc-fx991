import 'dart:developer' show Timeline;
import 'dart:ui' show DisplayFeature, FramePhase, FrameTiming, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'form_factor.dart';

/// 시작 판정·방향 요청·화면 배치 진단 로그 (#158).
///
/// 폴더블 실기기(원격 테스트 기기 포함)에서 시작할 때 화면이 한 번 돌았다가 돌아오는지(방향 요청 순서), 첫 프레임이
/// 다른 배치로 깜빡이는지(배치 변화)를 logcat으로 읽으려는 것이다. 화면 녹화로는 한두 프레임짜리 깜빡임을 놓친다.
/// Android 쪽 판정 로그(`FoldableDeviceProbe`, 태그 `AltCalc`)와 함께 본다:
/// `adb logcat -v time -s AltCalc flutter` — 이 로그는 Flutter 로그(태그 `flutter`)로 나가며 줄 앞에 [prefix]가 붙는다.
///
/// ## 켜는 법
/// 진단용으로 따로 빌드한 Android APK에서만 켜진다 — `--dart-define=ALTCALC_LAYOUT_LOG=true`([buildFlag]).
/// 일반 빌드(스토어 배포 포함)에는 이 로그가 없다. `main()`이 [enableForBuild]로 켜고, 테스트는 [enable]로 직접 켠다.
/// 진단 빌드는 릴리스로 만든다(디버그 빌드는 시작이 느려 첫 프레임 시점이 실제와 다르다):
/// `flutter build apk --release --dart-define=ALTCALC_LAYOUT_LOG=true`
/// (Android 판정 로그 `AltCalc`는 #70부터 모든 빌드에 남는다 — 판정마다 몇 줄뿐이다.)
///
/// ## 어느 배치가 화면에 나갔는지 읽는 법
/// "배치" 줄은 그 배치를 **빌드**한 때(`@` 뒤, [enable]부터 잰 ms)를 적는다. 배치가 바뀔 때마다 그 앞
/// [frameMarginMicros]부터 뒤 [frameWatchMicros]까지를 감시 구간으로 두고, 어느 구간에든 빌드를 시작한 프레임마다
/// "프레임" 줄(빌드 시작·래스터 끝 시각)을 남긴다(구간 사이의 프레임은 남기지 않는다). 어떤 배치 줄의 시각이 한 프레임의
/// 빌드 시작 ~ 래스터 끝 사이에 들면 그 배치가 그 프레임으로 화면에 나간 것이다. 빌드하고도 어떤 프레임에도 들지 않으면
/// (래스터 전에 다음 배치로 다시 빌드) 사용자는 그 배치를 보지 못했다. 프레임 줄은 엔진이 모아서 보내므로(릴리스는 약
/// 1초마다) 배치 줄보다 늦게 찍힌다.
/// - 프레임 시각 보고는 처음 배치가 바뀔 때 붙여 끌 때까지 둔다. 릴리스에서는 이 보고가 유일한 받는 곳이라, 떼면 엔진이
///   시각 수집을 멈춰 다시 붙이기 전 프레임을 잃는다. 진단 빌드에서만 켜지므로 그 비용은 받아들인다.
/// - 배치 줄 시각([Timeline.now])과 프레임 시각([FrameTiming])은 같은 단조 시계라고 본다 — Pixel Fold 에뮬레이터에서
///   배치 줄 시각이 늘 그 배치를 그린 프레임의 빌드 시작 뒤 수 ms 안에 들어 맞았다(#158).
///
/// 개인 정보는 없다(창·화면 크기, 접힘선 위치, 판정 결과, 프레임 시각뿐).
abstract final class LayoutLog {
  /// 로그 줄 머리말 — `flutter` 태그의 다른 로그와 구분한다.
  static const String prefix = 'AltCalc';

  /// 이 빌드가 진단 빌드인지 (`--dart-define=ALTCALC_LAYOUT_LOG=true`)
  static const bool buildFlag = bool.fromEnvironment('ALTCALC_LAYOUT_LOG');

  /// 배치가 바뀐 뒤 프레임 시각을 남기는 시간 (µs)
  static const int frameWatchMicros = 2000000;

  /// 배치가 바뀌기 전 프레임도 남기는 여유 (µs) — 배치 줄은 그 프레임의 빌드 시작 **뒤**에 찍히므로, 그 프레임까지 담는다.
  static const int frameMarginMicros = 100000;

  /// 감시 구간을 최근 몇 개까지 둘지 (창 크기를 끌어 바꾸는 동안처럼 배치가 계속 바뀔 때 목록이 끝없이 늘지 않게)
  static const int maxFrameWindows = 32;

  static void Function(String line)? _sink;
  static int Function() _clock = _timelineNow;
  static int _origin = 0;
  static String? _lastLayout;
  static bool _watchFrameTimings = false;
  static bool _timingsAdded = false;

  /// 프레임 시각을 남길 빌드 시작 구간들 (µs, [_clock] 기준) — 배치가 바뀔 때마다 하나씩
  static final List<(int from, int until)> _windows = [];

  /// [FrameTiming]과 같은 시계(단조 시계, µs)
  static int _timelineNow() => Timeline.now;

  /// 진단 빌드([flag], 기본 [buildFlag])의 Android 앱이면 켠다 — `main()`이 부른다. 인자는 판정을 테스트하려는 것이다.
  ///
  /// 테스트를 `--dart-define=ALTCALC_LAYOUT_LOG=true`로 돌리면 `main()`이 로그를 다시 켜, 위젯 테스트가 끼운 줄 받는
  /// 곳이 바뀐다 — 테스트는 이 정의 없이 돌린다.
  static void enableForBuild({
    bool flag = buildFlag,
    bool web = kIsWeb,
    TargetPlatform? platform,
  }) {
    if (flag &&
        !web &&
        (platform ?? defaultTargetPlatform) == TargetPlatform.android) {
      enable();
    }
  }

  /// 로그를 켠다. 시각은 지금부터 잰다.
  /// - [sink]: 줄을 받을 곳 (기본 `debugPrint`, 테스트가 바꿔 끼운다)
  /// - [frameTimings]: 배치가 바뀐 뒤 프레임 시각을 남길지 (엔진 프레임 시각 보고를 켠다 — 바인딩이 필요하다)
  /// - [clock]: 시계 (µs, 기본은 [FrameTiming]과 같은 단조 시계 — 테스트가 바꿔 끼운다)
  static void enable({
    void Function(String line)? sink,
    bool frameTimings = true,
    int Function()? clock,
  }) {
    _sink = sink ?? (line) => debugPrint(line);
    _clock = clock ?? _timelineNow;
    _origin = _clock();
    _lastLayout = null;
    _watchFrameTimings = frameTimings;
    _stopWatchingFrames();
  }

  /// 로그를 끈다 (테스트용).
  @visibleForTesting
  static void disable() {
    _sink = null;
    _lastLayout = null;
    _stopWatchingFrames();
  }

  /// 켜져 있는지
  static bool get enabled => _sink != null;

  /// 프레임 시각 보고를 받고 있는지 (테스트용)
  @visibleForTesting
  static bool get watchingFrames => _timingsAdded;

  static void _write(String message) => _sink?.call('$prefix $message');

  /// Dart가 받은 시작 시 폴더블 판정 결과 ([FormFactor.queryFoldableDevice] — 조회 실패·제한 시간 초과도 폴더블 아님).
  /// 접힘은 Android가 보낸 창 배치 첫 값 그대로 적는다 — 표기는 Android 판정 로그와 같다(있음/없음/모름, 모름은 첫 값을
  /// 받지 못한 것).
  static void foldableQuery(FoldableStartup startup) {
    if (!enabled) return;
    final fold = switch (startup.fold) {
      true => '있음',
      false => '없음',
      null => '모름',
    };
    _write('시작 판정 받음: 폴더블=${startup.foldable}, 접힘=$fold');
  }

  /// 첫 화면을 띄우기 전 접힘 정보 기다림 결과 (`DeviceOrientationLock.waitForFoldFeature`) — [arrived]가 거짓이면 제한 시간 초과
  static void foldFeatureWait({
    required bool arrived,
    required Duration waited,
  }) {
    if (!enabled) return;
    _write(
      '접힘 정보 기다림: ${arrived ? '도착' : '제한 시간 초과'} '
      '(${(waited.inMicroseconds / 1000).toStringAsFixed(1)}ms)',
    );
  }

  /// 첫 프레임 래스터가 끝났다는 것을 Dart가 알게 됐다 (`waitUntilFirstFrameRasterized`). 시각은 알게 된 때다 — 래스터가
  /// 끝난 실제 시각은 같은 프레임의 "프레임" 줄(래스터 끝)이 더 정확하다. 이때쯤 Android 시작 화면이 걷힌다.
  static void firstFrame() {
    if (!enabled) return;
    _write('첫 프레임 그림 @${_since(_clock())}');
  }

  /// 시작 판정이 놓친 폴더블을 화면 정보로 알아봤다 (`DeviceOrientationLock` "폴더블 기억").
  /// [reason]은 접힘 정보 보고·물리 화면 변경 중 무엇인지, [from]·[to]는 물리 화면 변경일 때 앞·뒤 물리 화면 크기(dp)다.
  static void foldableRemembered(String reason, {Size? from, Size? to}) {
    if (!enabled) return;
    _write(
      '폴더블 기억: $reason'
      '${from != null && to != null ? ' (${_size(from)} → ${_size(to)})' : ''}',
    );
  }

  /// 방향 요청 — [kind]·[display](물리 화면, dp)로 고른 [policy]를 보냈다. 실패하면 [error]가 있다.
  static void orientationRequest(
    OrientationPolicy policy, {
    required DeviceKind kind,
    required Size display,
    Object? error,
  }) {
    if (!enabled) return;
    _write(
      '방향 요청: ${policy.name} (기기 ${kind.name}, 화면 ${_size(display)})'
      '${error == null ? '' : ' 실패: $error'}',
    );
  }

  /// 화면 배치 — 지난번과 달라졌을 때만 남긴다(빌드마다 불러도 된다).
  /// - [chosen]: 창 크기·접힘선으로 고른 배치 ([FormFactor.arrangementOf])
  /// - [drawn]: 실제로 그린 배치 (키가 작아 접힘선 기준 배치를 못 쓰면 위아래 배치·가로형으로 대체)
  /// - [tooSmall]: 계산기 대신 창을 키워 달라는 안내를 띄웠는지
  static void layout({
    required ScreenArrangement chosen,
    required ScreenArrangement drawn,
    required bool tooSmall,
    required Size window,
    required Iterable<DisplayFeature> features,
    required bool foldableDevice,
  }) {
    if (!enabled) return;
    final line =
        '배치: ${drawn.name}'
        '${drawn == chosen ? '' : ' (고른 배치 ${chosen.name})'}'
        '${tooSmall ? ' 안내' : ''}'
        ' — 창 ${_size(window)}, 화면 특징 [${features.map(_feature).join(', ')}], '
        '폴더블=$foldableDevice';
    if (line == _lastLayout) return;
    _lastLayout = line;
    final now = _clock();
    _write('$line @${_since(now)}');
    if (_watchFrameTimings) _watchFrames(now);
  }

  static void _watchFrames(int now) {
    _windows.add((now - frameMarginMicros, now + frameWatchMicros));
    if (_windows.length > maxFrameWindows) _windows.removeAt(0);
    if (_timingsAdded) return;
    SchedulerBinding.instance.addTimingsCallback(onFrameTimings);
    _timingsAdded = true;
  }

  static void _stopWatchingFrames() {
    _windows.clear();
    if (_timingsAdded) {
      SchedulerBinding.instance.removeTimingsCallback(onFrameTimings);
      _timingsAdded = false;
    }
  }

  /// 엔진이 보낸 프레임 시각 — 어느 감시 구간(배치가 바뀌기 [frameMarginMicros] 전 ~ 바뀐 뒤 [frameWatchMicros])에든
  /// 빌드를 시작한 프레임만 남긴다.
  @visibleForTesting
  static void onFrameTimings(List<FrameTiming> timings) {
    if (!enabled || _windows.isEmpty) return;
    for (final t in timings) {
      final buildStart = t.timestampInMicroseconds(FramePhase.buildStart);
      if (!_windows.any((w) => w.$1 <= buildStart && buildStart <= w.$2)) {
        continue;
      }
      _write(
        '프레임 #${t.frameNumber}: 빌드 @${_since(buildStart)} ~ '
        '래스터 끝 @${_since(t.timestampInMicroseconds(FramePhase.rasterFinish))}',
      );
    }
  }

  /// [enable]부터 [micros]까지 (ms, 소수 첫째 자리)
  static String _since(int micros) =>
      '${((micros - _origin) / 1000).toStringAsFixed(1)}ms';

  static String _feature(DisplayFeature f) =>
      '${f.type.name} ${f.state.name} ${_rect(f.bounds)}';

  static String _size(Size s) => '${_n(s.width)}x${_n(s.height)}';

  static String _rect(Rect r) =>
      '${_n(r.left)},${_n(r.top)}-${_n(r.right)},${_n(r.bottom)}';

  /// dp 값을 소수 첫째 자리까지 (정수면 소수점 없이)
  static String _n(double v) {
    final rounded = (v * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(1);
  }
}

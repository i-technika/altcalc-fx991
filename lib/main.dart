import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoTheme;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/layout/form_factor.dart';
import 'core/layout/layout_log.dart';
import 'core/theme/calc_theme.dart';
import 'core/theme/font_licenses.dart';
import 'core/theme/high_text_contrast.dart';
import 'presentation/l10n/device_locale_scope.dart';
import 'presentation/providers/device_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/calculator_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  // 시작 판정·방향 요청·화면 배치 진단 로그 (#158, `adb logcat -s AltCalc flutter`)
  LayoutLog.enableForBuild();
  // 방향 요청과 설정 저장소 열기를 함께 진행한다. 손잡이 설정이 첫 화면부터 반영되도록 둘 다 기다린다 (#24).
  // Android "고대비 텍스트" 첫 값도 함께 기다려 첫 화면부터 맞는 팔레트로 그린다 (#95).
  final (_, settings, _) = await (
    FormFactor.queryFoldableDevice().then((startup) async {
      LayoutLog.foldableQuery(startup);
      // 창 배치 첫 값에 접힘선이 있었으면 그 정보가 화면 정보로 올 때까지 첫 화면을 미룬다 (#158) — 미루지 않으면
      // 펼친 내부 화면의 첫 프레임이 위아래 배치였다가 접힘선 기준 배치로 바뀐다.
      if (startup.fold == true) {
        await DeviceOrientationLock.waitForFoldFeature();
      }
      return DeviceOrientationLock.instance.start(
        foldableDevice: startup.foldable,
      );
    }),
    openSettingsStorage(),
    SystemHighTextContrast.instance.start(),
  ).wait;
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(settings),
        foldableDeviceProvider.overrideWithValue(
          DeviceOrientationLock.instance.foldableDevice,
        ),
      ],
      child: const AltCalcApp(),
    ),
  );
  unawaited(
    WidgetsBinding.instance.waitUntilFirstFrameRasterized.then(
      (_) => LayoutLog.firstFrame(),
    ),
  );
}

/// 기기 종류([FormFactor.deviceKindOf])와 물리 화면 크기에 맞게 화면 방향을 고정한다 (#24, 폴더블은 #25).
/// 정책은 [FormFactor.orientationPolicyOf]이다.
/// - 폰·폴더블 커버 화면: 세로 — 가로 화면에서는 키패드가 쓸 수 없을 만큼 작아진다.
///   (iPhone은 Info.plist에서도 세로만 허용해 실행 첫 프레임부터 세로로 뜬다.)
/// - 태블릿: 가로 — LCD와 키패드를 좌우로 나눠 보여 준다. 단 Android 16 이상·iPad에서는 지켜지지 않는다
///   ([FormFactor] 참조). 그래서 화면 배치는 방향이 아니라 창 크기로 정한다(`CalculatorScreen`).
/// - 폴더블 내부 화면: 네 방향 모두 — 배치가 접힘선 방향을 따른다.
///
/// 폴더블은 시작 시 판정한다([FormFactor.queryFoldableDevice]). 시작 시 판정이 놓친 폴더블과
/// 접기·펼치기(물리 화면이 커버 ↔ 내부로 바뀜)에 대비해, 화면 정보가 바뀔 때(`didChangeMetrics`, 접히는
/// 부분 정보 도착 등) 정책을 다시 판정해 바뀌었을 때만 다시 요청한다. 방향 요청이 실패해도 앱은 뜬다(기록만 하고, 다음 화면 정보 변화 때 다시 시도).
/// 요청은 한 번에 하나씩 차례로 보내고, 성공한 요청만 기록한다 — 겹친 요청이 실패해도 기록이 어긋나지 않는다.
///
/// ## 폴더블 기억 (#70)
/// 시작 시 판정이 놓친 폴더블(접은 커버 화면에서 시작 등)을 화면 정보로 알아보면 그 뒤로 폴더블로 기억한다([foldableDevice]).
/// - 접히는 부분(fold·hinge)이 한 번이라도 보고됨
/// - 물리 화면이 비율이 다른 화면으로 바뀜([FormFactor.isOtherScreen]) — 커버 ↔ 내부 화면. 접힘 정보보다 먼저 와서,
///   처음 펼칠 때도 접힘 정보가 오기 전 프레임부터 폴더블로 판정한다.
///
/// 기억한 값은 방향 정책과 화면 배치(`foldableDeviceProvider` → `FormFactor.arrangementOf`)가 함께 쓴다 — 펼친 뒤
/// 접힘 정보가 오기 전 몇 프레임 동안 태블릿(가로)으로 요청해 화면이 돌았다가 돌아오거나, 좌우 분할로 그렸다가
/// 위아래로 바뀌는 깜빡임을 막는다. 화면 정보 변화를 받은 그 프레임 안에 바뀐다(앞 방향 요청을 기다리지 않는다).
/// 앱을 다시 켜면 시작 시 판정부터 다시 한다 — 저장하지 않는 것은 Android 자동 백업이 설정을 다른 기기로 옮기기 때문이다.
class DeviceOrientationLock with WidgetsBindingObserver {
  DeviceOrientationLock._();

  /// 앱 전체에서 하나만 쓴다
  static final DeviceOrientationLock instance = DeviceOrientationLock._();

  OrientationPolicy? _applied;
  final ValueNotifier<bool> _foldableDevice = ValueNotifier(false);

  /// 마지막으로 본 실제 물리 화면 크기 (dp, 플랫폼이 알려 주지 않으면 갱신하지 않는다) — [FormFactor.isOtherScreen] 비교용
  Size? _lastDisplay;

  /// 처리 중인 마지막 요청 (없으면 `null`). 다음 요청은 이것이 끝난 뒤 판정·전송한다.
  /// 비어 있을 때 미리 만든 Future를 두지 않는다 — Future는 만들어진 Zone에 묶이므로, 호출한 쪽 Zone에서
  /// 이어지게 한다(테스트의 가짜 비동기 Zone 포함).
  Future<void>? _pending;
  bool _observing = false;

  /// 마지막으로 요청에 성공한 방향 정책 (아직 없으면 `null`)
  @visibleForTesting
  OrientationPolicy? get appliedPolicy => _applied;

  /// 폴더블 기기 여부 — 시작 시 판정([start]의 `foldableDevice`)이거나, 그 뒤 화면 정보로 알아본 값(위 "폴더블 기억").
  /// 한 번 true가 되면 [stop] 전까지 false로 돌아가지 않는다.
  ValueListenable<bool> get foldableDevice => _foldableDevice;

  /// 지금 화면의 방향 정책으로 방향을 요청하고, 이후 화면 정보 변화를 관찰한다. 여러 번 불러도 관찰은 한 번이다.
  /// [foldableDevice]는 앱 시작 시 판정한 폴더블 기기 여부다([FormFactor.queryFoldableDevice]).
  Future<void> start({bool foldableDevice = false}) {
    if (foldableDevice) _foldableDevice.value = true;
    _observeScreen();
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    return _apply();
  }

  /// 관찰을 멈추고 요청 기록을 지운다 (테스트용).
  @visibleForTesting
  void stop() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
    _applied = null;
    _foldableDevice.value = false;
    _lastDisplay = null;
    _pending = null;
  }

  /// 현재 화면의 방향 정책. 화면(view)이 없으면 폰(세로)으로 본다.
  OrientationPolicy currentPolicy() => _currentDecision().policy;

  /// 방향 정책과 그 근거(기기 종류·물리 화면 크기 — 진단 로그용, #158). 화면이 없으면 크기 0의 폰이다.
  ({OrientationPolicy policy, DeviceKind kind, Size display})
  _currentDecision() {
    final view = _view;
    if (view == null) {
      return (
        policy: OrientationPolicy.portrait,
        kind: DeviceKind.phone,
        display: Size.zero,
      );
    }
    final displaySize = FormFactor.displaySizeOf(view);
    final kind = FormFactor.deviceKindOf(
      displaySize,
      view.displayFeatures,
      foldableDevice: _foldableDevice.value,
    );
    return (
      policy: FormFactor.orientationPolicyOf(kind, displaySize),
      kind: kind,
      display: displaySize,
    );
  }

  /// 접힘 정보를 기다리는 최대 시간 (#158). Flutter 엔진도 같은 출처(Jetpack WindowManager)를 따로 구독해 화면 정보로
  /// 보낸다. 두 구독 중 어느 쪽이 먼저 붙는지는 보장되지 않는다. Pixel Fold 에뮬레이터에서는 Android 판정이 첫 값을
  /// 받은 뒤 0~15ms 안에 왔다(7번). 오지 않으면 그냥 시작한다 — 그때는 위아래 배치가 먼저 보일 수 있다.
  ///
  /// 최악의 시작 지연(시작 화면이 남는 시간)은 [FormFactor.foldableQueryTimeout](Android 판정 응답) + 이 시간이다.
  static const Duration foldFeatureWait = Duration(milliseconds: 300);

  /// 화면 정보([FlutterView.displayFeatures])에 접히는 부분이 올 때까지(최대 [timeout]) 기다린다 (#158).
  /// 이미 있으면 바로 끝난다. 앱 시작(`main()`)이 Android 판정의 `fold`가 참일 때 첫 화면을 띄우기 전에 부른다.
  /// 접히는 부분이 아닌 화면 특징(화면 구멍 등)만 오면 계속 기다린다. 기다린 시간 로그는 실제 시계로 잰다(테스트의 가짜
  /// 시간과 다르다).
  static Future<void> waitForFoldFeature({
    Duration timeout = foldFeatureWait,
  }) async {
    bool hasFold() {
      final view = _view;
      return view != null && FormFactor.hasFoldOrHinge(view.displayFeatures);
    }

    final watch = Stopwatch()..start();
    if (hasFold()) {
      LayoutLog.foldFeatureWait(arrived: true, waited: watch.elapsed);
      return;
    }
    final arrived = Completer<bool>();
    final observer = _MetricsObserver(() {
      if (hasFold() && !arrived.isCompleted) arrived.complete(true);
    });
    WidgetsBinding.instance.addObserver(observer);
    try {
      final ok = await arrived.future.timeout(timeout, onTimeout: () => false);
      LayoutLog.foldFeatureWait(arrived: ok, waited: watch.elapsed);
    } finally {
      WidgetsBinding.instance.removeObserver(observer);
    }
  }

  static FlutterView? get _view {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    return dispatcher.implicitView ?? dispatcher.views.firstOrNull;
  }

  /// 지금 화면 정보로 폴더블 여부를 갱신한다 (위 "폴더블 기억").
  void _observeScreen() {
    final view = _view;
    if (view == null) return;
    final display = FormFactor.reportedDisplaySizeOf(view);
    final previous = _lastDisplay;
    if (display != null) _lastDisplay = display;
    if (_foldableDevice.value) return;
    if (FormFactor.hasFoldOrHinge(view.displayFeatures)) {
      _foldableDevice.value = true;
      LayoutLog.foldableRemembered('접힘 정보');
    } else if (previous != null &&
        display != null &&
        FormFactor.isOtherScreen(previous, display)) {
      _foldableDevice.value = true;
      LayoutLog.foldableRemembered('물리 화면 변경', from: previous, to: display);
    }
  }

  /// 앞 요청이 끝난 뒤 지금 정책으로 요청한다. 실패해도 오류를 내보내지 않는다.
  Future<void> _apply() {
    final previous = _pending;
    final next = previous == null
        ? _applyNow()
        : previous.then((_) => _applyNow());
    _pending = next;
    next.whenComplete(() {
      if (identical(_pending, next)) _pending = null;
    });
    return next;
  }

  Future<void> _applyNow() async {
    final (:policy, :kind, :display) = _currentDecision();
    if (policy == _applied) return;
    try {
      await SystemChrome.setPreferredOrientations(
        FormFactor.preferredOrientationsOf(policy),
      );
      _applied = policy;
      LayoutLog.orientationRequest(policy, kind: kind, display: display);
    } catch (error) {
      // 기록하지 않으므로 다음 화면 정보 변화 때 다시 시도한다.
      debugPrint('화면 방향 요청 실패: $error');
      LayoutLog.orientationRequest(
        policy,
        kind: kind,
        display: display,
        error: error,
      );
    }
  }

  @override
  void didChangeMetrics() {
    // 폴더블 여부는 앞 방향 요청을 기다리지 않고 바로 갱신한다 — 화면 배치가 이 프레임에 쓴다.
    _observeScreen();
    unawaited(_apply());
  }
}

/// 화면 정보가 바뀔 때마다 [onChange]를 부른다 ([DeviceOrientationLock.waitForFoldFeature]용).
class _MetricsObserver with WidgetsBindingObserver {
  final VoidCallback onChange;

  _MetricsObserver(this.onChange);

  @override
  void didChangeMetrics() => onChange();
}

/// 앱 루트. 상태 관리를 위해 [ProviderScope] 아래에 둔다.
///
/// [home]으로 첫 화면을 바꿔 끼울 수 있다 — 테스트·개발 도구가 앱과 같은 테마·로캘 범위에서 자기 화면을 띄울 때 쓴다.
/// [frameBuilder]로 앱 화면(루트 Navigator)을 바깥에서 감싸 배치할 수 있다 — 개발용 미리보기가 루트 Navigator를
/// 기기 틀 안에 두어, 화면이 띄우는 대화상자·Overlay가 실제 앱과 같은 구조로 그 틀 안에 뜨게 할 때 쓴다 (#72).
class AltCalcApp extends StatelessWidget {
  /// 첫 화면 (기본: [CalculatorScreen])
  final Widget home;

  /// Android "고대비 텍스트" 켜짐 여부 (#95, [HighTextContrastScope]로 앱 전체에 알린다).
  /// `null`이면 [SystemHighTextContrast.instance] — 테스트가 값을 바꿔 끼울 때만 넘긴다.
  final ValueListenable<bool>? highTextContrast;

  /// 앱 화면(루트 Navigator, [MaterialApp.builder]의 child — 대비 설정에 맞춘 테마로 감싼 것, [_ScreenTheme])을 감싸는
  /// 도구용 틀. `null`이면 그대로 띄운다.
  /// 실제 앱은 쓰지 않는다.
  final Widget Function(BuildContext context, Widget screen)? frameBuilder;

  const AltCalcApp({
    super.key,
    this.home = const CalculatorScreen(),
    this.frameBuilder,
    this.highTextContrast,
  });

  @override
  Widget build(BuildContext context) {
    // 고대비 판정은 [CalcPalette.of] 하나로 한다 (#97). 앱 바깥쪽(View 바로 아래)에서 고른 테마를 MaterialApp에 주고,
    // 화면(루트 Navigator) 바로 위에서 가장 가까운 MediaQuery로 한 번 더 고른다 — 개발용 미리보기처럼 틀 안에서
    // 고대비를 바꾸는 곳에서도 대화상자(와 MaterialApp이 테마로 정하는 텍스트 선택 색 등, #107 [_ScreenTheme])가 따라가게
    // 하려는 것이다. 실제 앱에서는 두 곳이 같은 MediaQuery·고대비 텍스트 값을 보므로
    // 같은 테마이고, 둘 다 같은 시간 동안 전환 애니메이션을 한다(둘 다 기본 시간·곡선 — MaterialApp의 테마 애니메이션
    // 설정(`themeAnimationStyle` 등)을 바꾸면 [_ScreenTheme]의 [AnimatedTheme]도 같이 바꾼다). 앱은 플랫폼 밝기와 관계없이 항상 어두운 테마라
    // MaterialApp의 다른 테마 칸(darkTheme·highContrastTheme 등)은 쓰지 않는다.
    // Android "고대비 텍스트"(#95)도 고대비 판정에 들어가므로, 그 범위를 MaterialApp 바깥에 두어 두 곳의 테마
    // 선택이 모두 그 값을 보게 한다.
    return HighTextContrastScope(
      notifier: highTextContrast ?? SystemHighTextContrast.instance,
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'AltCalc fx-991',
          debugShowCheckedModeBanner: false,
          theme: CalcPalette.of(context).materialTheme,
          builder: (context, child) {
            final screen = _ScreenTheme(
              child: child ?? const SizedBox.shrink(),
            );
            // 스크린리더 문구가 기기 언어 변경을 따라가도록 기기 로캘을 알린다 (#20)
            return DeviceLocaleScope(
              child: frameBuilder?.call(context, screen) ?? screen,
            );
          },
          home: home,
        ),
      ),
    );
  }
}

/// 화면(루트 Navigator) 바로 위의 테마 (#97, #107).
///
/// 가장 가까운 MediaQuery로 고른 테마([CalcPalette.of])를 [AnimatedTheme]으로 주고, [MaterialApp]이 자기 테마
/// (`MaterialApp.theme`)로 정해 두는 앱 수준 요소도 이 테마로 다시 정한다. 안쪽에 겹친 [Theme]만으로는 이 둘이 바뀌지 않는다.
/// - 텍스트 선택·커서 기본 색([DefaultSelectionStyle]): MaterialApp은 테마의 `textSelectionTheme`이 비어 있으면
///   primary 40%·primary로 정하고, [Theme]은 `textSelectionTheme`에 값이 있을 때만 바꾼다. MaterialApp처럼 목표 테마로
///   바로 정하고, 40%도 MaterialApp(`withOpacity`)과 같게 8비트 알파로 만든다.
/// - Cupertino 테마([CupertinoTheme]): [Theme]은 위에 Cupertino 테마가 이미 있으면 그것을 물려받는다 — MaterialApp 쪽
///   [Theme]이 바깥 테마로 만든 것이다. 여기서는 바깥 [Theme]처럼 전환 중인 테마로 만든다.
///   [CupertinoTheme]은 아래에 Cupertino 아이콘 테마(primary 색)를 씌우므로, [Theme]이 Cupertino 테마 안쪽에서 하듯
///   Material 아이콘 테마([ThemeData.iconTheme])를 다시 씌운다 — 빼면 색을 정하지 않은 아이콘이 primary 색이 된다.
///
/// 실제 앱에서는 바깥 테마와 같은 테마라 화면이 보는 값이 바뀌지 않는다(전환 중 포함, `test/widget/material_theme_test.dart`).
/// 개발용 미리보기처럼 틀 안에서 고대비를 바꾸면, 틀 안 화면이 호스트(기기) 쪽이 아니라 틀의 테마를 따르게 한다.
class _ScreenTheme extends StatelessWidget {
  final Widget child;

  const _ScreenTheme({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = CalcPalette.of(context).materialTheme;
    final selection = theme.textSelectionTheme;
    final primary = theme.colorScheme.primary;
    return AnimatedTheme(
      data: theme,
      child: DefaultSelectionStyle(
        selectionColor:
            selection.selectionColor ??
            primary.withAlpha((255.0 * 0.40).round()),
        cursorColor: selection.cursorColor ?? primary,
        child: Builder(
          builder: (context) {
            final animated = Theme.of(context);
            return CupertinoTheme(
              data: MaterialBasedCupertinoThemeData(materialTheme: animated),
              child: IconTheme(data: animated.iconTheme, child: child),
            );
          },
        ),
      ),
    );
  }
}

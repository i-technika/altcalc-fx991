import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/layout/form_factor.dart';
import 'core/theme/calc_theme.dart';
import 'core/theme/font_licenses.dart';
import 'presentation/l10n/device_locale_scope.dart';
import 'presentation/providers/device_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/calculator_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  // 방향 요청과 설정 저장소 열기를 함께 진행한다. 손잡이 설정이 첫 화면부터 반영되도록 둘 다 기다린다 (#24).
  final (foldable, settings) = await (
    FormFactor.queryHingeSensor().then((hinge) async {
      await DeviceOrientationLock.instance.start(hasHingeSensor: hinge);
      return hinge;
    }),
    openSettingsStorage(),
  ).wait;
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(settings),
        foldableDeviceProvider.overrideWithValue(foldable),
      ],
      child: const AltCalcApp(),
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
/// 폴더블은 시작 시 힌지 센서로 판정한다([FormFactor.queryHingeSensor]). 힌지 센서를 알리지 않는 폴더블과
/// 접기·펼치기(물리 화면이 커버 ↔ 내부로 바뀜)에 대비해, 화면 정보가 바뀔 때(`didChangeMetrics`, 접히는
/// 부분 정보 도착 등) 정책을 다시 판정해 바뀌었을 때만 다시 요청한다. 방향 요청이 실패해도 앱은 뜬다(기록만 하고, 다음 화면 정보 변화 때 다시 시도).
/// 요청은 한 번에 하나씩 차례로 보내고, 성공한 요청만 기록한다 — 겹친 요청이 실패해도 기록이 어긋나지 않는다.
class DeviceOrientationLock with WidgetsBindingObserver {
  DeviceOrientationLock._();

  /// 앱 전체에서 하나만 쓴다
  static final DeviceOrientationLock instance = DeviceOrientationLock._();

  OrientationPolicy? _applied;
  bool _hasHingeSensor = false;

  /// 처리 중인 마지막 요청 (없으면 `null`). 다음 요청은 이것이 끝난 뒤 판정·전송한다.
  /// 비어 있을 때 미리 만든 Future를 두지 않는다 — Future는 만들어진 Zone에 묶이므로, 호출한 쪽 Zone에서
  /// 이어지게 한다(테스트의 가짜 비동기 Zone 포함).
  Future<void>? _pending;
  bool _observing = false;

  /// 마지막으로 요청에 성공한 방향 정책 (아직 없으면 `null`)
  @visibleForTesting
  OrientationPolicy? get appliedPolicy => _applied;

  /// 지금 화면의 방향 정책으로 방향을 요청하고, 이후 화면 정보 변화를 관찰한다. 여러 번 불러도 관찰은 한 번이다.
  Future<void> start({bool hasHingeSensor = false}) {
    _hasHingeSensor = hasHingeSensor;
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
    _hasHingeSensor = false;
    _pending = null;
  }

  /// 현재 화면의 방향 정책. 화면(view)이 없으면 폰(세로)으로 본다.
  OrientationPolicy currentPolicy() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final view = dispatcher.implicitView ?? dispatcher.views.firstOrNull;
    if (view == null) return OrientationPolicy.portrait;
    final displaySize = FormFactor.displaySizeOf(view);
    final kind = FormFactor.deviceKindOf(
      displaySize,
      view.displayFeatures,
      hasHingeSensor: _hasHingeSensor,
    );
    return FormFactor.orientationPolicyOf(kind, displaySize);
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
    final policy = currentPolicy();
    if (policy == _applied) return;
    try {
      await SystemChrome.setPreferredOrientations(
        FormFactor.preferredOrientationsOf(policy),
      );
      _applied = policy;
    } catch (error) {
      // 기록하지 않으므로 다음 화면 정보 변화 때 다시 시도한다.
      debugPrint('화면 방향 요청 실패: $error');
    }
  }

  @override
  void didChangeMetrics() => unawaited(_apply());
}

/// 앱 루트. 상태 관리를 위해 [ProviderScope] 아래에 둔다.
///
/// [home]으로 첫 화면을 바꿔 끼울 수 있다 — 테스트·개발 도구가 앱과 같은 테마·로캘 범위에서 자기 화면을 띄울 때 쓴다.
/// [frameBuilder]로 앱 화면(루트 Navigator)을 바깥에서 감싸 배치할 수 있다 — 개발용 미리보기가 루트 Navigator를
/// 기기 틀 안에 두어, 화면이 띄우는 대화상자·Overlay가 실제 앱과 같은 구조로 그 틀 안에 뜨게 할 때 쓴다 (#72).
class AltCalcApp extends StatelessWidget {
  /// 첫 화면 (기본: [CalculatorScreen])
  final Widget home;

  /// 앱 화면(루트 Navigator, [MaterialApp.builder]의 child — 대비 설정에 맞춘 [Theme]로 감싼 것)을 감싸는
  /// 도구용 틀. `null`이면 그대로 띄운다.
  /// 실제 앱은 쓰지 않는다.
  final Widget Function(BuildContext context, Widget screen)? frameBuilder;

  const AltCalcApp({
    super.key,
    this.home = const CalculatorScreen(),
    this.frameBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AltCalc fx-991',
      debugShowCheckedModeBanner: false,
      // 플랫폼 밝기와 관계없이 같은 어두운 테마를 쓰고, 기기 고대비 설정에서는 고대비 테마로 바꾼다 (#97).
      // MaterialApp은 밝기(어두운 모드 여부)·고대비 조합마다 다른 칸을 보므로 네 칸을 모두 채운다.
      theme: CalcPalette.standard.materialTheme,
      darkTheme: CalcPalette.standard.materialTheme,
      highContrastTheme: CalcPalette.highContrast.materialTheme,
      highContrastDarkTheme: CalcPalette.highContrast.materialTheme,
      // 스크린리더 문구가 기기 언어 변경을 따라가도록 기기 로캘을 알린다 (#20)
      builder: (context, child) {
        final navigator = child ?? const SizedBox.shrink();
        // MaterialApp은 View의 고대비 설정만 보므로, 화면(루트 Navigator) 바로 위에서 가장 가까운 MediaQuery로
        // 테마를 다시 고른다 — 개발용 미리보기처럼 틀 안에서 고대비를 바꾸는 곳에서도 대화상자·툴팁이 따라간다.
        // 실제 앱에서는 MaterialApp이 고른 테마와 같다 (#97).
        final screen = Builder(
          builder: (context) => Theme(
            data: CalcPalette.of(context).materialTheme,
            child: navigator,
          ),
        );
        return DeviceLocaleScope(
          child: frameBuilder?.call(context, screen) ?? screen,
        );
      },
      home: home,
    );
  }
}

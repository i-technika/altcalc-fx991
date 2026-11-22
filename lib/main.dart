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

/// 기기 종류([FormFactor.deviceKindOf])에 맞게 화면 방향을 고정한다 (#24).
/// - 폰·폴더블: 세로 — 가로 화면에서는 키패드가 쓸 수 없을 만큼 작아진다.
///   (iPhone은 Info.plist에서도 세로만 허용해 실행 첫 프레임부터 세로로 뜬다.)
/// - 태블릿: 가로 — LCD와 키패드를 좌우로 나눠 보여 준다. 단 Android 16 이상·iPad에서는 지켜지지 않는다
///   ([FormFactor] 참조). 그래서 화면 배치는 방향이 아니라 창 크기로 정한다(`CalculatorScreen`).
///
/// 폴더블은 시작 시 힌지 센서로 판정한다([FormFactor.queryHingeSensor]). 힌지 센서를 알리지 않는 폴더블에
/// 대비해, 화면 정보가 바뀔 때(`didChangeMetrics`, 접히는 부분 정보 도착 등) 기기 종류를 다시 판정해
/// 바뀌었을 때만 다시 요청한다. 방향 요청이 실패해도 앱은 뜬다(기록만 하고, 다음 화면 정보 변화 때 다시 시도).
class DeviceOrientationLock with WidgetsBindingObserver {
  DeviceOrientationLock._();

  /// 앱 전체에서 하나만 쓴다
  static final DeviceOrientationLock instance = DeviceOrientationLock._();

  DeviceKind? _applied;
  bool _hasHingeSensor = false;
  bool _observing = false;

  /// 마지막으로 요청에 성공한 기기 종류 (아직 없으면 `null`)
  @visibleForTesting
  DeviceKind? get appliedKind => _applied;

  /// 지금 기기 종류로 방향을 요청하고, 이후 화면 정보 변화를 관찰한다. 여러 번 불러도 관찰은 한 번이다.
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
  }

  /// 현재 기기 종류. 화면(view)이 없으면 폰으로 본다.
  DeviceKind currentKind() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final view = dispatcher.implicitView ?? dispatcher.views.firstOrNull;
    if (view == null) return DeviceKind.phone;
    return FormFactor.deviceKindOf(
      FormFactor.displaySizeOf(view),
      view.displayFeatures,
      hasHingeSensor: _hasHingeSensor,
    );
  }

  Future<void> _apply() async {
    final kind = currentKind();
    if (kind == _applied) return;
    final previous = _applied;
    _applied = kind;
    try {
      await SystemChrome.setPreferredOrientations(
        FormFactor.preferredOrientationsFor(kind),
      );
    } catch (error) {
      // 실패하면 다음 화면 정보 변화 때 다시 시도한다.
      if (_applied == kind) _applied = previous;
      debugPrint('화면 방향 요청 실패: $error');
    }
  }

  @override
  void didChangeMetrics() => unawaited(_apply());
}

/// 앱 루트. 상태 관리를 위해 [ProviderScope] 아래에 둔다.
///
/// [home]으로 첫 화면을 바꿔 끼울 수 있다 — 테스트·개발 도구가 앱과 같은 테마·로캘 범위에서 자기 화면을 띄울 때 쓴다.
class AltCalcApp extends StatelessWidget {
  /// 첫 화면 (기본: [CalculatorScreen])
  final Widget home;

  const AltCalcApp({super.key, this.home = const CalculatorScreen()});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AltCalc fx-991',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: CalcTheme.bodyBackground,
      ),
      // 스크린리더 문구가 기기 언어 변경을 따라가도록 기기 로캘을 알린다 (#20)
      builder: (context, child) =>
          DeviceLocaleScope(child: child ?? const SizedBox.shrink()),
      home: home,
    );
  }
}

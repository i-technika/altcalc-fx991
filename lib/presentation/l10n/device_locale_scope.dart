import 'package:material_ui/material_ui.dart';

/// 기기(플랫폼) 로캘을 하위 위젯에 알리고, 실행 중 기기 언어가 바뀌면 의존하는 위젯을 다시 빌드한다 (#20).
///
/// 앱(`MaterialApp`)은 `supportedLocales`를 지정하지 않아 `Localizations` 로캘이 항상 en_US이고,
/// 기기 언어가 바뀌어도 알리지 않는다. 스크린리더 문구(`CalcSemanticStrings.of`)는 이 위젯으로
/// 기기 로캘을 얻는다. 앱 루트(`MaterialApp.builder`)에 한 번 둔다.
///
/// 기기 언어 변경 때만 다시 빌드하므로 "키 입력으로 키패드는 다시 빌드되지 않는다" 계약과 충돌하지 않는다.
class DeviceLocaleScope extends StatefulWidget {
  final Widget child;

  const DeviceLocaleScope({super.key, required this.child});

  /// 가장 가까운 [DeviceLocaleScope]의 기기 로캘. 없으면 `null` (호출자가 플랫폼 값을 직접 읽는다).
  static Locale? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_DeviceLocaleInherited>()
      ?.locale;

  /// 기기 로캘. 범위 안이면 기기 언어가 바뀔 때 다시 빌드되고, 범위 밖(위젯 단독 테스트 등)이면
  /// 플랫폼 로캘을 직접 읽는다.
  static Locale of(BuildContext context) =>
      maybeOf(context) ??
      (View.maybeOf(context)?.platformDispatcher ??
              WidgetsBinding.instance.platformDispatcher)
          .locale;

  @override
  State<DeviceLocaleScope> createState() => _DeviceLocaleScopeState();
}

class _DeviceLocaleScopeState extends State<DeviceLocaleScope>
    with WidgetsBindingObserver {
  late Locale _locale = WidgetsBinding.instance.platformDispatcher.locale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    if (locale != _locale) setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) =>
      _DeviceLocaleInherited(locale: _locale, child: widget.child);
}

class _DeviceLocaleInherited extends InheritedWidget {
  final Locale locale;

  const _DeviceLocaleInherited({required this.locale, required super.child});

  @override
  bool updateShouldNotify(_DeviceLocaleInherited oldWidget) =>
      locale != oldWidget.locale;
}

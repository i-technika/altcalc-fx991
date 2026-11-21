import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/calc_theme.dart';
import 'core/theme/font_licenses.dart';
import 'presentation/l10n/device_locale_scope.dart';
import 'presentation/screens/calculator_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  await lockPortraitOrientation();
  runApp(const ProviderScope(child: AltCalcApp()));
}

/// 폰 화면을 세로로 고정한다. 가로 화면에서는 키패드가 쓸 수 없을 만큼 작아지기 때문이다.
/// (iPhone은 Info.plist에서도 세로만 허용해 실행 첫 프레임부터 세로로 뜬다.)
///
/// 방향 고정이 항상 지켜지지는 않는다 — 분할 화면·팝업 창처럼 창 자체가 낮아지는 경우,
/// Android 16(targetSdk 36) 이상에서 짧은 변 600dp 이상 화면(태블릿·폴더블 내부)은 방향 고정을
/// 무시하고, iPad는 멀티태스킹을 지원하는 동안 무시한다.
/// TODO(#24): 대화면은 방향 고정 없이 창 크기에 따라 LCD/키패드 좌우 분할로 대응한다.
Future<void> lockPortraitOrientation() =>
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);

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

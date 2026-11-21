import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/calc_theme.dart';
import 'presentation/screens/calculator_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
class AltCalcApp extends StatelessWidget {
  const AltCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AltCalc fx-991',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: CalcTheme.bodyBackground,
      ),
      home: const CalculatorScreen(),
    );
  }
}

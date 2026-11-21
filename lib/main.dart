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

/// 화면을 세로로 고정한다. 가로 화면에서는 키패드가 쓸 수 없을 만큼 작아지기 때문이다.
///
/// TODO(#24): 태블릿은 가로 고정 + LCD/키패드 좌우 분할로 바꾼다.
/// (iPad는 멀티태스킹을 지원하는 동안 방향 고정이 적용되지 않는다 — #24에서 방침 결정)
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

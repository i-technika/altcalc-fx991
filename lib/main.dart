import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/calc_theme.dart';
import 'presentation/screens/calculator_screen.dart';

void main() {
  runApp(const ProviderScope(child: AltCalcApp()));
}

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

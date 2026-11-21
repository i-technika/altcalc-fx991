// 개발용 키패드·화면 미리보기 실행기 (#21).
//
// 실제 앱 화면([CalculatorScreen])을 기기 크기 틀 안에 띄우고, 키 입력 로그를 옆에 보여준다.
// 키패드 배열을 따로 구현하지 않고 앱과 같은 위젯·상태(provider)를 그대로 쓰므로 앱과 어긋나지 않는다.
//
// 실행: flutter run -d chrome -t preview/key_preview_main.dart  (VS Code: "Key Preview (Chrome)")
//
// 릴리스 빌드에 포함되지 않는다 — 앱 진입점은 lib/main.dart이고, lib/의 어떤 파일도 이 파일을
// import하지 않는다(test/widget/key_preview_test.dart가 검증).
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/calc_state.dart';
import 'package:itechnika_altcalc_fx991/presentation/l10n/device_locale_scope.dart';
import 'package:itechnika_altcalc_fx991/presentation/providers/calc_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const ProviderScope(child: KeyPreviewApp()));

/// 미리보기 화면 크기 프리셋 (논리 픽셀, dp).
///
/// 대표 기기의 화면 크기를 근사한 값이다. [padding]은 상태 표시줄·홈 표시줄 등 시스템 인셋이다.
@immutable
class PreviewDevice {
  /// 표시 이름
  final String name;

  /// 화면 크기 (dp)
  final Size size;

  /// 시스템 인셋 (dp) — `MediaQuery.padding`/`viewPadding`으로 전달한다
  final EdgeInsets padding;

  const PreviewDevice(this.name, this.size, {this.padding = EdgeInsets.zero});

  /// 칩에 표시할 이름 (예: `일반 폰 390×844`)
  String get label =>
      '$name ${size.width.toStringAsFixed(0)}×${size.height.toStringAsFixed(0)}';
}

/// 미리보기 프리셋 목록. 첫 항목이 기본값이다.
const List<PreviewDevice> previewDevices = [
  PreviewDevice(
    '일반 폰',
    Size(390, 844),
    padding: EdgeInsets.only(top: 47, bottom: 34),
  ),
  PreviewDevice('소형 폰', Size(360, 640), padding: EdgeInsets.only(top: 24)),
  PreviewDevice(
    '대형 폰',
    Size(430, 932),
    padding: EdgeInsets.only(top: 59, bottom: 34),
  ),
  PreviewDevice(
    '폴더블 커버',
    Size(344, 882),
    padding: EdgeInsets.only(top: 24, bottom: 24),
  ),
  // 대화면 좌우 분할은 #24·#25, 짧은 창 대응은 #38에서 다룬다 — 여기서는 현재 배치를 확인만 한다.
  PreviewDevice('폴더블 내부', Size(690, 829), padding: EdgeInsets.only(top: 24)),
  PreviewDevice('태블릿 세로', Size(800, 1280), padding: EdgeInsets.only(top: 24)),
  PreviewDevice('분할 화면(짧은 창)', Size(390, 420)),
];

/// 미리보기 시스템 글자 배율 선택지 (Android 최대 200%)
const List<double> previewTextScales = [1.0, 1.3, 2.0];

/// 입력 로그 최대 보관 개수 (오래된 것부터 버린다)
const int previewLogCapacity = 500;

/// 입력 로그 한 항목. [number]는 초기화 이후 몇 번째 입력인지(1부터)이다.
typedef PreviewLogEntry = ({int number, KeyInput input});

/// 입력 로그 한 줄 문구 (예: `SOLVE  ← SHIFT + CALC`, `◀ (반복)`)
String describePreviewInput(KeyInput input) {
  final key = keyDefOf(input.id).mainLabel;
  return switch (input.layer) {
    KeyLayer.main => input.isRepeat ? '${input.label} (반복)' : input.label,
    KeyLayer.shift => '${input.label}  ← SHIFT + $key',
    KeyLayer.alpha => '${input.label}  ← ALPHA + $key',
  };
}

/// 미리보기 앱 루트. 앱([AltCalcApp])과 같은 테마·로캘 범위를 쓴다.
class KeyPreviewApp extends StatelessWidget {
  const KeyPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AltCalc 개발용 미리보기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: CalcTheme.bodyBackground,
      ),
      builder: (context, child) =>
          DeviceLocaleScope(child: child ?? const SizedBox.shrink()),
      home: const KeyPreviewScreen(),
    );
  }
}

/// 왼쪽 조작 패널(기기·글자 배율·입력 로그) + 오른쪽 기기 틀 속 실제 계산기 화면.
class KeyPreviewScreen extends ConsumerStatefulWidget {
  const KeyPreviewScreen({super.key});

  /// 조작 패널 폭 (dp)
  static const double panelWidth = 280;

  @override
  ConsumerState<KeyPreviewScreen> createState() => _KeyPreviewScreenState();
}

class _KeyPreviewScreenState extends ConsumerState<KeyPreviewScreen> {
  PreviewDevice _device = previewDevices.first;
  double _textScale = previewTextScales.first;
  final List<PreviewLogEntry> _log = [];
  int _inputTotal = 0;

  /// 상태를 처음으로 되돌리고 로그를 비운다.
  void _reset() {
    ref.invalidate(calcProvider);
    setState(() {
      _log.clear();
      _inputTotal = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 입력 수가 늘 때마다(반복 입력 포함) 마지막 입력을 기록한다.
    ref.listen(calcProvider.select((s) => (s.inputCount, s.lastInput)), (
      previous,
      next,
    ) {
      final (count, input) = next;
      if (input == null || count == previous?.$1) return;
      setState(() {
        _log.add((number: ++_inputTotal, input: input));
        if (_log.length > previewLogCapacity) _log.removeAt(0);
      });
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: KeyPreviewScreen.panelWidth,
              child: _ControlPanel(
                device: _device,
                textScale: _textScale,
                log: _log,
                onDeviceChanged: (d) => setState(() => _device = d),
                onTextScaleChanged: (s) => setState(() => _textScale = s),
                onReset: _reset,
              ),
            ),
            Expanded(
              child: _DeviceFrame(device: _device, textScale: _textScale),
            ),
          ],
        ),
      ),
    );
  }
}

/// 선택한 기기 크기로 [CalculatorScreen]을 그린다. 창보다 크면 비율을 유지해 축소한다.
///
/// 화면 크기·인셋·글자 배율은 `MediaQuery`로 전달해, 화면이 실제 기기에서처럼 배치를 산출하게 한다.
class _DeviceFrame extends StatelessWidget {
  final PreviewDevice device;
  final double textScale;

  const _DeviceFrame({required this.device, required this.textScale});

  /// 기기 틀 둘레 여백 (dp)
  static const double _margin = 16;

  /// 축소 비율 표시 줄 높이 (dp)
  static const double _captionHeight = 24;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = device.size;
        final availableWidth = constraints.maxWidth - _margin * 2;
        final availableHeight =
            constraints.maxHeight - _margin * 2 - _captionHeight;
        final scale = math.max(
          0.0,
          math.min(
            1.0,
            math.min(
              availableWidth / size.width,
              availableHeight / size.height,
            ),
          ),
        );

        return Padding(
          padding: const EdgeInsets.all(_margin),
          child: Column(
            children: [
              SizedBox(
                height: _captionHeight,
                child: Text(
                  '${device.label} · 글자 ${(textScale * 100).round()}% · '
                  '표시 배율 ${(scale * 100).round()}%',
                  key: const ValueKey('preview-frame-caption'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Expanded(
                child: Center(
                  child: scale <= 0
                      ? const SizedBox.shrink()
                      : DecoratedBox(
                          position: DecorationPosition.foreground,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24),
                          ),
                          child: SizedBox(
                            width: size.width * scale,
                            height: size.height * scale,
                            child: FittedBox(
                              child: SizedBox.fromSize(
                                key: const ValueKey('preview-device-screen'),
                                size: size,
                                child: MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                    size: size,
                                    padding: device.padding,
                                    viewPadding: device.padding,
                                    viewInsets: EdgeInsets.zero,
                                    systemGestureInsets: EdgeInsets.zero,
                                    textScaler: TextScaler.linear(textScale),
                                  ),
                                  child: const CalculatorScreen(),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 기기·글자 배율 선택, 초기화 버튼, 입력 로그.
class _ControlPanel extends StatelessWidget {
  final PreviewDevice device;
  final double textScale;
  final List<PreviewLogEntry> log;
  final ValueChanged<PreviewDevice> onDeviceChanged;
  final ValueChanged<double> onTextScaleChanged;
  final VoidCallback onReset;

  const _ControlPanel({
    required this.device,
    required this.textScale,
    required this.log,
    required this.onDeviceChanged,
    required this.onTextScaleChanged,
    required this.onReset,
  });

  static const TextStyle _heading = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CalcTheme.adSlotBackground,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('기기 크기', style: _heading),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (i, d) in previewDevices.indexed)
                  ChoiceChip(
                    key: ValueKey('preview-device-$i'),
                    label: Text(d.label, style: const TextStyle(fontSize: 11)),
                    selected: d == device,
                    onSelected: (_) => onDeviceChanged(d),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('시스템 글자 배율', style: _heading),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final s in previewTextScales)
                  ChoiceChip(
                    key: ValueKey('preview-text-scale-$s'),
                    label: Text('${(s * 100).round()}%'),
                    selected: s == textScale,
                    onSelected: (_) => onTextScaleChanged(s),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('입력 로그 (${log.length})', style: _heading)),
                TextButton(
                  key: const ValueKey('preview-reset'),
                  onPressed: onReset,
                  child: const Text('초기화'),
                ),
              ],
            ),
            Expanded(child: _InputLogView(log: log)),
          ],
        ),
      ),
    );
  }
}

/// 입력 로그. 최근 입력이 맨 위에 온다. SHIFT/ALPHA 층은 각인 색으로 구분한다.
class _InputLogView extends StatelessWidget {
  final List<PreviewLogEntry> log;

  const _InputLogView({required this.log});

  static Color _colorOf(KeyLayer layer) => switch (layer) {
    KeyLayer.main => Colors.white,
    KeyLayer.shift => CalcTheme.shiftLabel,
    KeyLayer.alpha => CalcTheme.alphaLabel,
  };

  @override
  Widget build(BuildContext context) {
    if (log.isEmpty) {
      return const Align(
        alignment: Alignment.topLeft,
        child: Text(
          '키를 누르면 여기에 기록됩니다.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('preview-log'),
      itemCount: log.length,
      itemBuilder: (context, i) {
        final (:number, :input) = log[log.length - 1 - i];
        return Text(
          '$number. ${describePreviewInput(input)}',
          style: TextStyle(
            color: _colorOf(input.layer),
            fontFamily: CalcTheme.monoFontFamily,
            fontSize: 12,
          ),
        );
      },
    );
  }
}

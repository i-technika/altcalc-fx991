// 개발용 키패드·화면 미리보기 실행기 (#21).
//
// 실제 앱 화면([CalculatorScreen])을 기기 크기 틀 안에 띄우고, 키 입력 로그를 옆에 보여준다.
// 키패드 배열을 따로 구현하지 않고 앱과 같은 루트([AltCalcApp])·위젯·상태(provider)를 그대로 쓴다.
//
// 실행: flutter run -d chrome -t preview/key_preview_main.dart  (VS Code: "Key Preview (Chrome)")
//
// 앱 릴리스 빌드에 포함되지 않는다 — 앱 진입점은 lib/main.dart이고 lib/에서 이 파일로 가는 import가 없으며
// pubspec 에셋에도 preview/가 없다(test/widget/key_preview_test.dart가 검증).
//
// TODO(#18): M6의 광고·인앱결제 플러그인은 웹 구현이 없으므로, 미리보기에서는 광고 슬롯을 빈 슬롯으로
// 덮어쓸 수 있게(provider 주입 등) 연결 구조를 정한다. CI가 이 파일을 웹으로 빌드한다(Sub-issue Linux CI).
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itechnika_altcalc_fx991/core/constants/key_definitions.dart';
import 'package:itechnika_altcalc_fx991/core/theme/calc_theme.dart';
import 'package:itechnika_altcalc_fx991/domain/models/calc_state.dart';
import 'package:itechnika_altcalc_fx991/main.dart' show AltCalcApp;
import 'package:itechnika_altcalc_fx991/presentation/providers/calc_provider.dart';
import 'package:itechnika_altcalc_fx991/presentation/screens/calculator_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() =>
    runApp(const ProviderScope(child: AltCalcApp(home: KeyPreviewScreen())));

/// 미리보기 화면 크기 프리셋 (논리 픽셀, dp).
///
/// 대표 기기의 화면 크기를 근사한 값이다. [padding]은 시스템 인셋이다 — 상태 표시줄(위),
/// 홈 표시줄·내비게이션 바·작업 표시줄(아래). Android 15 이상은 edge-to-edge가 강제되어
/// 내비게이션 바 높이(3버튼 48dp, 제스처 약 24dp)가 아래 인셋으로 들어온다.
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
  // iPhone 14·13 (상태 표시줄 47, 홈 표시줄 34)
  PreviewDevice(
    '일반 폰',
    Size(390, 844),
    padding: EdgeInsets.only(top: 47, bottom: 34),
  ),
  // 소형 Android, 3버튼 내비게이션 (키패드가 가장 압박받는 경우)
  PreviewDevice(
    '소형 폰',
    Size(360, 640),
    padding: EdgeInsets.only(top: 24, bottom: 48),
  ),
  // iPhone 15 Pro Max
  PreviewDevice(
    '대형 폰',
    Size(430, 932),
    padding: EdgeInsets.only(top: 59, bottom: 34),
  ),
  // Galaxy Z Fold5 커버, 제스처 내비게이션
  PreviewDevice(
    '폴더블 커버',
    Size(344, 882),
    padding: EdgeInsets.only(top: 24, bottom: 24),
  ),
  // 대화면 좌우 분할은 #24·#25, 짧은 창 대응은 #38에서 다룬다 — 여기서는 현재 배치를 확인만 한다.
  // Galaxy Z Fold5 내부 (힌지 displayFeatures는 흉내 내지 않는다)
  PreviewDevice(
    '폴더블 내부',
    Size(690, 829),
    padding: EdgeInsets.only(top: 24, bottom: 24),
  ),
  // 10인치급 Android 태블릿, 작업 표시줄 48dp
  PreviewDevice(
    '태블릿 세로',
    Size(800, 1280),
    padding: EdgeInsets.only(top: 24, bottom: 48),
  ),
  // Android 16 대화면은 방향 고정을 무시하므로 가로 화면도 확인 대상이다 (lib/main.dart 참조)
  PreviewDevice(
    '태블릿 가로',
    Size(1280, 800),
    padding: EdgeInsets.only(top: 24, bottom: 48),
  ),
  // 분할 화면의 위쪽 창 (상태 표시줄만 걸친다)
  PreviewDevice('분할 화면 위', Size(390, 420), padding: EdgeInsets.only(top: 24)),
];

/// 기본 시스템 글자 배율
const double previewDefaultTextScale = 1.0;

/// 미리보기 시스템 글자 배율 선택지 (Android 최소 85% ~ 최대 200%, 선형 근사).
///
/// 키패드·LCD는 [CalcTheme.keyMaxTextScaleFactor]·[CalcTheme.lcdMaxTextScaleFactor](130%)에서 배율을
/// 자르므로, 200%는 그 잘림이 지켜지는지 확인하는 용도다. Android 14 이상의 비선형 배율은 흉내 내지 않는다.
const List<double> previewTextScales = [0.85, 1.0, 1.3, 2.0];

/// 기기 틀 둘레 여백 (dp)
const double previewFrameMargin = 16;

/// 기기 틀 위 캡션(기기·배율 표시) 줄 높이 (dp)
const double previewFrameCaptionHeight = 24;

/// 입력 로그 기본 최대 보관 줄 수 (오래된 것부터 버린다)
const int previewLogCapacity = 500;

/// 미리보기가 구독하는 상태 조각: (모디파이어 대기, 입력 수, 마지막 입력)
typedef PreviewWatch = (KeyModifier, int, KeyInput?);

PreviewWatch _watchOf(CalcState s) => (s.modifier, s.inputCount, s.lastInput);

/// 입력 로그 한 줄. 기능 입력이면 [number](초기화 이후 몇 번째 입력, 1부터)와 [layer]가 있고,
/// 모디파이어 대기 변화면 둘 다 `null`이다.
typedef PreviewLogEntry = ({int? number, String text, KeyLayer? layer});

/// 기능 입력 문구 (예: `SOLVE  ← SHIFT + CALC`, `◄ (반복)`)
String describePreviewInput(KeyInput input) {
  final key = keyDefOf(input.id).mainLabel;
  return switch (input.layer) {
    KeyLayer.main => input.isRepeat ? '${input.label} (반복)' : input.label,
    KeyLayer.shift => '${input.label}  ← SHIFT + $key',
    KeyLayer.alpha => '${input.label}  ← ALPHA + $key',
  };
}

/// 입력 없이 모디파이어 대기만 바뀐 경우의 문구. 바뀌지 않았으면 `null`.
/// (예: `[SHIFT 대기]`, SHIFT → ALPHA는 `[ALPHA 대기]`, 기능 없는 층의 키·같은 키 다시 누름은 `[SHIFT 해제]`)
String? describePreviewModifierChange(KeyModifier before, KeyModifier after) {
  String name(KeyModifier m) => m == KeyModifier.shift ? 'SHIFT' : 'ALPHA';
  if (before == after) return null;
  if (after != KeyModifier.none) return '[${name(after)} 대기]';
  return '[${name(before)} 해제]';
}

/// 조작 패널(기기·글자 배율·입력 로그) + 기기 틀 속 실제 계산기 화면.
/// 넓은 창은 좌우, 좁은 창([narrowWidth] 미만)은 위아래로 배치한다.
class KeyPreviewScreen extends ConsumerStatefulWidget {
  /// 입력 로그 최대 보관 줄 수
  final int logCapacity;

  const KeyPreviewScreen({super.key, this.logCapacity = previewLogCapacity})
    : assert(logCapacity > 0, 'logCapacity는 양수여야 한다');

  /// 좌우 배치에서 조작 패널 폭 (dp)
  static const double panelWidth = 280;

  /// 이 폭보다 좁은 창은 위아래로 배치한다 (dp)
  static const double narrowWidth = 640;

  @override
  ConsumerState<KeyPreviewScreen> createState() => _KeyPreviewScreenState();
}

class _KeyPreviewScreenState extends ConsumerState<KeyPreviewScreen> {
  PreviewDevice _device = previewDevices.first;
  double _textScale = previewDefaultTextScale;
  final List<PreviewLogEntry> _log = [];
  int _inputTotal = 0;
  bool _trimmed = false;

  @override
  void didUpdateWidget(KeyPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logCapacity < oldWidget.logCapacity) _trimLog();
  }

  /// 보관 줄 수를 넘는 오래된 줄을 버린다.
  void _trimLog() {
    final excess = _log.length - widget.logCapacity;
    if (excess <= 0) return;
    _log.removeRange(0, excess);
    _trimmed = true;
  }

  /// 상태를 처음으로 되돌리고 로그를 비운다.
  void _reset() {
    // invalidate 직후 read하면 provider가 즉시 다시 만들어지고 리스너가 그 자리에서(동기) 불린다.
    // 그래서 처음 상태로 돌아가는 알림(예: SHIFT 대기 → 해제)은 아래에서 로그를 비우기 전에 들어왔다가
    // 함께 지워진다. read를 빼면 그 알림이 다음 프레임에 와서 빈 로그에 남는다(테스트가 검증).
    ref.invalidate(calcProvider);
    ref.read(calcProvider);
    setState(() {
      _log.clear();
      _inputTotal = 0;
      _trimmed = false;
    });
  }

  void _onChanged(PreviewWatch? previous, PreviewWatch next) {
    if (previous == null) return;
    final (before, countBefore, _) = previous;
    final (after, count, input) = next;
    final PreviewLogEntry entry;
    if (count != countBefore) {
      // 기능 입력 (반복 입력 포함). 모디파이어 해제는 입력의 층 표기로 드러난다.
      if (input == null) return;
      entry = (
        number: ++_inputTotal,
        text: describePreviewInput(input),
        layer: input.layer,
      );
    } else {
      final text = describePreviewModifierChange(before, after);
      if (text == null) return;
      entry = (number: null, text: text, layer: null);
    }
    setState(() {
      _log.add(entry);
      _trimLog();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(calcProvider.select(_watchOf), _onChanged);

    final panel = _ControlPanel(
      device: _device,
      textScale: _textScale,
      log: _log,
      inputTotal: _inputTotal,
      trimmed: _trimmed,
      onDeviceChanged: (d) => setState(() => _device = d),
      onTextScaleChanged: (s) => setState(() => _textScale = s),
      onReset: _reset,
    );
    final frame = _DeviceFrame(device: _device, textScale: _textScale);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < KeyPreviewScreen.narrowWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: frame),
                  Expanded(flex: 2, child: panel),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: KeyPreviewScreen.panelWidth, child: panel),
                Expanded(child: frame),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 선택한 기기 크기로 [CalculatorScreen]을 그린다. 창보다 크면 비율을 유지해 축소한다.
///
/// 화면 크기·인셋·글자 배율은 `MediaQuery`로 전달해 화면이 실제 기기에서처럼 배치를 산출하게 한다.
/// 실제 기기와 다르게 남는 값:
/// - `devicePixelRatio`·`displayFeatures`(폴더블 힌지)·플랫폼(스크린리더 알림 경로)은 호스트(브라우저) 값이다.
/// - `systemGestureInsets`는 **반드시 0**이다. `CalcKeyButton`의 시스템 제스처 영역 판정은 전역 터치 좌표를
///   `MediaQuery.sizeOf`와 비교하는데, 미리보기에서는 화면이 패널 폭만큼 밀리고 축소되어 좌표계가 맞지 않는다.
class _DeviceFrame extends StatelessWidget {
  final PreviewDevice device;
  final double textScale;

  const _DeviceFrame({required this.device, required this.textScale});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = device.size;
        final availableWidth = constraints.maxWidth - previewFrameMargin * 2;
        final availableHeight =
            constraints.maxHeight -
            previewFrameMargin * 2 -
            previewFrameCaptionHeight;
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

        // 여백·캡션조차 들어가지 않는 창: 안내 문구만 그린다.
        if (scale <= 0) {
          return const Center(
            child: Text(
              '창이 너무 작아 기기 화면을 표시할 수 없습니다.',
              key: ValueKey('preview-frame-too-small'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(previewFrameMargin),
          child: Column(
            children: [
              SizedBox(
                height: previewFrameCaptionHeight,
                child: Text(
                  '${device.label} · 글자 ${(textScale * 100).round()}% · '
                  '표시 배율 ${(scale * 100).round()}%',
                  key: const ValueKey('preview-frame-caption'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Expanded(
                child: Center(
                  child: DecoratedBox(
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
///
/// 설정 영역을 작게 두고 입력 로그가 남은 높이를 모두 쓴다 — 키를 누르는 동안 로그가 보여야 하기 때문이다.
/// 패널이 [_scrollAllBelowHeight]보다 낮을 때만 설정과 로그를 한꺼번에 스크롤한다(오버플로 방지).
class _ControlPanel extends StatelessWidget {
  final PreviewDevice device;
  final double textScale;
  final List<PreviewLogEntry> log;
  final int inputTotal;
  final bool trimmed;
  final ValueChanged<PreviewDevice> onDeviceChanged;
  final ValueChanged<double> onTextScaleChanged;
  final VoidCallback onReset;

  const _ControlPanel({
    required this.device,
    required this.textScale,
    required this.log,
    required this.inputTotal,
    required this.trimmed,
    required this.onDeviceChanged,
    required this.onTextScaleChanged,
    required this.onReset,
  });

  /// 이보다 낮은 패널은 전체를 스크롤한다 (dp)
  static const double _scrollAllBelowHeight = 240;

  /// 패널 안쪽 여백 (dp)
  static const double _padding = 12;

  /// 패널 배경 (미리보기 전용)
  static const Color _background = Color(0xFF1E1E1E);

  static const TextStyle _label = TextStyle(
    color: Colors.white70,
    fontSize: 12,
  );

  static const TextStyle _heading = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle _logStyle = TextStyle(
    fontFamily: CalcTheme.monoFontFamily,
    fontFamilyFallback: CalcTheme.monoFontFallback,
    fontSize: 12,
  );

  static Color _colorOf(KeyLayer? layer) => switch (layer) {
    null => Colors.white54,
    KeyLayer.main => Colors.white,
    KeyLayer.shift => CalcTheme.shiftLabel,
    KeyLayer.alpha => CalcTheme.alphaLabel,
  };

  Widget _settings() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('기기 크기', style: _label),
      DropdownButton<int>(
        key: const ValueKey('preview-device-select'),
        isExpanded: true,
        value: previewDevices.indexOf(device),
        items: [
          for (final (i, d) in previewDevices.indexed)
            DropdownMenuItem(
              value: i,
              child: Text(
                d.label,
                key: ValueKey('preview-device-$i'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (i) {
          if (i != null) onDeviceChanged(previewDevices[i]);
        },
      ),
      const SizedBox(height: 8),
      const Text('시스템 글자 배율', style: _label),
      const SizedBox(height: 4),
      SegmentedButton<double>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          for (final s in previewTextScales)
            ButtonSegment(
              value: s,
              label: Text(
                '${(s * 100).round()}%',
                key: ValueKey('preview-text-scale-$s'),
                maxLines: 1,
              ),
            ),
        ],
        selected: {textScale},
        onSelectionChanged: (v) => onTextScaleChanged(v.first),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: Text(
              '입력 로그 · 입력 $inputTotal회'
              '${trimmed ? ' (최근 ${log.length}줄만 표시)' : ''}',
              key: const ValueKey('preview-log-header'),
              style: _heading,
            ),
          ),
          TextButton(
            key: const ValueKey('preview-reset'),
            onPressed: onReset,
            child: const Text('초기화'),
          ),
        ],
      ),
    ],
  );

  /// 입력 로그 (최근 줄이 맨 위). 화면에 보이는 줄만 만든다(지연 생성).
  Widget _logSliver() => log.isEmpty
      ? const SliverToBoxAdapter(
          child: Text(
            '키를 누르면 여기에 최근 순으로 기록됩니다.',
            key: ValueKey('preview-log-empty'),
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        )
      : SliverList.builder(
          key: const ValueKey('preview-log'),
          itemCount: log.length,
          itemBuilder: (context, i) {
            final (:number, :text, :layer) = log[log.length - 1 - i];
            return Text(
              number == null ? text : '$number. $text',
              style: _logStyle.copyWith(color: _colorOf(layer)),
            );
          },
        );

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('preview-panel'),
      color: _background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < _scrollAllBelowHeight) {
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(_padding),
                  sliver: SliverToBoxAdapter(child: _settings()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    _padding,
                    0,
                    _padding,
                    _padding,
                  ),
                  sliver: _logSliver(),
                ),
              ],
            );
          }
          return Padding(
            padding: const EdgeInsets.all(_padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _settings(),
                Expanded(child: CustomScrollView(slivers: [_logSliver()])),
              ],
            ),
          );
        },
      ),
    );
  }
}

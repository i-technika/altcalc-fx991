import 'package:material_ui/material_ui.dart';

import '../../domain/models/handedness.dart';
import 'device_locale_scope.dart';

/// 앱 설정 화면 문구 (#24). 언어 선택은 스크린리더 문구(`CalcSemanticStrings`)와 같다 —
/// 기기 로캘이 한국어면 [KoSettingsStrings], 그 밖에는 [EnSettingsStrings].
/// 앱 전체 다국어(ARB) 도입 시 함께 옮긴다 — TODO(#48).
abstract class SettingsStrings {
  const SettingsStrings();

  /// 등록된 모든 언어 구현 (불변식 테스트가 모두 검사한다)
  static const List<SettingsStrings> all = [
    KoSettingsStrings(),
    EnSettingsStrings(),
  ];

  /// [locale]에 맞는 문구. 한국어가 아니면 영어.
  static SettingsStrings forLocale(Locale locale) =>
      switch (locale.languageCode) {
        'ko' => const KoSettingsStrings(),
        _ => const EnSettingsStrings(),
      };

  /// 기기 로캘에 맞는 문구
  static SettingsStrings of(BuildContext context) =>
      forLocale(DeviceLocaleScope.of(context));

  /// 설정 버튼 이름 (툴팁·스크린리더)
  String get settingsButton;

  /// 키패드 위치(손잡이) 선택 대화상자 제목
  String get handednessTitle;

  /// 키패드 위치 설정이 적용되는 화면 안내 (#41) — 설정 버튼이 폰에도 보이므로, 폰 화면에서는 달라지는 것이
  /// 없다는 것을 대화상자에서 알린다.
  String get handednessNote;

  /// 손잡이 선택지 이름
  String handedness(Handedness value);

  /// 손잡이 선택지 설명 (키패드가 어느 쪽에 오는지)
  String handednessDetail(Handedness value);

  /// 대화상자 닫기 버튼
  String get close;
}

/// 한국어 설정 문구
class KoSettingsStrings extends SettingsStrings {
  const KoSettingsStrings();

  @override
  String get settingsButton => '설정';

  @override
  String get handednessTitle => '키패드 위치';

  @override
  String get handednessNote => '태블릿 가로 화면과 펼친 폴더블에 적용됩니다. 폰 화면에서는 달라지지 않습니다.';

  @override
  String handedness(Handedness value) => switch (value) {
    Handedness.right => '오른손잡이',
    Handedness.left => '왼손잡이',
  };

  @override
  String handednessDetail(Handedness value) => switch (value) {
    Handedness.right => '키패드를 오른쪽에 둡니다',
    Handedness.left => '키패드를 왼쪽에 둡니다',
  };

  @override
  String get close => '닫기';
}

/// 영어 설정 문구
class EnSettingsStrings extends SettingsStrings {
  const EnSettingsStrings();

  @override
  String get settingsButton => 'Settings';

  @override
  String get handednessTitle => 'Keypad position';

  @override
  String get handednessNote =>
      'Applies to tablets in landscape and unfolded foldables. '
      'Nothing changes on a phone screen.';

  @override
  String handedness(Handedness value) => switch (value) {
    Handedness.right => 'Right-handed',
    Handedness.left => 'Left-handed',
  };

  @override
  String handednessDetail(Handedness value) => switch (value) {
    Handedness.right => 'Keypad on the right',
    Handedness.left => 'Keypad on the left',
  };

  @override
  String get close => 'Close';
}

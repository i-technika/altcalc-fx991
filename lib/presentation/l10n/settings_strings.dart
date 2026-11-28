import 'package:material_ui/material_ui.dart';

import '../../domain/models/handedness.dart';
import 'device_locale_scope.dart';

/// 앱 설정 화면 문구 (#24)와 계산기 화면 안내 문구(#38). 언어 선택은 스크린리더 문구(`CalcSemanticStrings`)와 같다 —
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

  /// 키패드 위치(손잡이) 선택 대화상자 제목
  String get handednessTitle;

  /// 지금 화면에서는 키패드 위치가 바뀌지 않는다는 안내 (#41) — 설정(ON 키, #190)은 폰에서도 열리므로 손잡이를 골라도
  /// 키패드가 그대로인 이유를 알린다. 위아래 배치(키패드 가운데)와, 실물 배열 키패드가 아래 패널 폭 전체를 쓰는 가로
  /// 접힘선 기준 배치(Flip 내부, #143)에서 보인다. 기기 종류가 아니라 숫자 키를 한쪽 가장자리에 두는지로 말한다: 같은
  /// 폴더블도 펼친 방향에 따라 배치가 다르다. 적용되는 화면의 예는 가로형(#142 — 숫자부가 손 쪽으로 옮겨
  /// 간다. LCD는 #284부터 본체 폭 전체라 그대로다)이다. "키패드 위치" 대신 "키 배치"로 말한다(#142 R1 — 숫자부만 옮겨 가는 넓은 배열이 있다).
  /// 선택지 설명("숫자 키를 왼쪽에 둡니다")은 손잡이가 적용되는 모든 배치에서 맞다 — 가로 접힘선의 넓은 배열도 #143부터
  /// 숫자부가 손잡이를 따른다(그 전에는 블록 폭 상한에 걸린 넓은 테이블톱에서 키패드만 옮겨 가고 숫자부는 오른쪽에 남았다).
  String get handednessNote;

  /// 손잡이 선택지 이름
  String handedness(Handedness value);

  /// 손잡이 선택지 설명 (숫자 키가 어느 쪽에 오는지 — 가로형·가로 접힘선의 넓은 배열은 숫자부, 책 자세는 손 쪽 패널의
  /// 키패드 전체가 그쪽이다)
  String handednessDetail(Handedness value);

  /// 대화상자 닫기 버튼
  String get close;

  /// 창이 너무 작아 키패드를 표시하지 않는다는 안내 (#38) — 계산기 대신 띄운다. 창을 키우면 돌아온다는 것을 알린다.
  String get windowTooSmall;
}

/// 한국어 설정 문구
class KoSettingsStrings extends SettingsStrings {
  const KoSettingsStrings();

  @override
  String get handednessTitle => '키패드 위치';

  @override
  String get handednessNote =>
      '지금 화면에서는 손잡이를 바꿔도 키 배치가 바뀌지 않습니다. '
      '가로로 넓은 화면 등에서 숫자 키를 고른 손 쪽으로 옮깁니다.';

  @override
  String handedness(Handedness value) => switch (value) {
    Handedness.right => '오른손잡이',
    Handedness.left => '왼손잡이',
  };

  @override
  String handednessDetail(Handedness value) => switch (value) {
    Handedness.right => '숫자 키를 오른쪽에 둡니다',
    Handedness.left => '숫자 키를 왼쪽에 둡니다',
  };

  @override
  String get close => '닫기';

  @override
  String get windowTooSmall => '창이 너무 작아 키패드를 표시할 수 없습니다.\n창을 키워 주세요.';
}

/// 영어 설정 문구
class EnSettingsStrings extends SettingsStrings {
  const EnSettingsStrings();

  @override
  String get handednessTitle => 'Keypad position';

  @override
  String get handednessNote =>
      'Changing this does not move the keys on this screen. '
      'On wide screens and similar layouts, '
      'the number keys move to the side you choose.';

  @override
  String handedness(Handedness value) => switch (value) {
    Handedness.right => 'Right-handed',
    Handedness.left => 'Left-handed',
  };

  @override
  String handednessDetail(Handedness value) => switch (value) {
    Handedness.right => 'Number keys on the right',
    Handedness.left => 'Number keys on the left',
  };

  @override
  String get close => 'Close';

  @override
  String get windowTooSmall =>
      'The window is too small for the keypad.\nMake the window larger.';
}

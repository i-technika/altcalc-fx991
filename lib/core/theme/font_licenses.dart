import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'calc_theme.dart';

/// 번들 글꼴(`assets/fonts/`)의 SIL OFL 1.1 라이선스 전문 에셋 경로 (패밀리 → 에셋).
///
/// OFL은 글꼴을 배포할 때 라이선스 전문을 함께 제공하도록 요구한다. 앱 시작 시
/// [registerFontLicenses]로 [LicenseRegistry]에 등록해 라이선스 화면(`showLicensePage`)에 표시한다.
const Map<String, String> bundledFontLicenseAssets = {
  CalcTheme.monoFontFamily: 'assets/fonts/NotoSansMono-OFL.txt',
  CalcTheme.mathFontFamily: 'assets/fonts/NotoSansMath-OFL.txt',
};

/// 번들 글꼴 라이선스를 [LicenseRegistry]에 등록한다. 앱 시작 시 한 번 호출한다.
///
/// 라이선스 전문은 라이선스 화면을 열 때 지연 로드된다.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: family, value: asset)
        in bundledFontLicenseAssets.entries) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(asset));
    }
  });
}

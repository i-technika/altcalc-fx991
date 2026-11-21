import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'calc_theme.dart';

/// 번들 글꼴(`assets/fonts/`)의 SIL OFL 1.1 라이선스 전문 에셋 경로 (패밀리 → 에셋).
///
/// OFL은 글꼴을 배포할 때 라이선스 전문을 함께 제공하도록 요구한다. 앱 시작 시
/// [registerFontLicenses]로 [LicenseRegistry]에 등록한다. 라이선스 화면(`showLicensePage`)이 이를 표시한다.
const Map<String, String> bundledFontLicenseAssets = {
  CalcTheme.monoFontFamily: 'assets/fonts/NotoSansMono-OFL.txt',
  CalcTheme.mathFontFamily: 'assets/fonts/NotoSansMath-OFL.txt',
};

bool _registered = false;

/// 번들 글꼴 라이선스를 [LicenseRegistry]에 등록한다. 앱 시작 시 호출한다.
///
/// - 여러 번 호출해도 한 번만 등록한다(라이선스 화면에 중복 표시 방지).
/// - 라이선스 전문은 라이선스 화면을 열 때 지연 로드된다. 에셋 하나를 읽지 못해도 나머지는 표시되도록
///   글꼴별로 오류를 격리하고 [FlutterError.reportError]로 보고한다.
/// - 앱에는 아직 라이선스 화면 진입점(`showLicensePage`)이 없다. 설정·정보 화면에서 연결한다.
void registerFontLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: family, value: asset)
        in bundledFontLicenseAssets.entries) {
      final String text;
      try {
        text = await rootBundle.loadString(asset);
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'font_licenses',
            context: ErrorDescription('글꼴 라이선스 로드 실패: $asset'),
          ),
        );
        continue;
      }
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });
}

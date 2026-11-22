import 'package:material_ui/material_ui.dart';

/// 화면 단위 대화상자를 띄운다 — [context]가 속한 화면의 **가장 가까운 Navigator**에 (#72).
///
/// 앱 코드는 대화상자를 `showDialog` 대신 이 함수로 띄운다(`test/unit/screen_dialog_usage_test.dart`가
/// `lib/`의 직접 호출을 막는다). `showDialog`는 기본값이 루트 Navigator(`useRootNavigator: true`)라서:
/// - 실제 앱: Navigator가 하나뿐이라 결과가 같다.
/// - 화면을 흉내 내는 곳(개발용 미리보기의 기기 틀): 기기 화면 안에 자기 Navigator를 두므로, 이 함수로 띄운
///   대화상자만 기기 틀 안에 그 기기의 MediaQuery(크기·인셋·글자 배율)로 뜬다. 루트에 띄우면 미리보기 창
///   전체를 덮는다.
///
/// 앞으로 화면마다 Navigator를 두는 배치(창 분할 등)가 생기면 대화상자도 그 화면 안에 뜬다 — 화면 단위
/// 대화상자는 그 화면에 속한다는 뜻으로 의도한 동작이다. 앱 전체를 덮어야 하는 대화상자가 필요해지면
/// 이 파일에 별도 함수를 두고 이유를 적는다.
Future<T?> showScreenDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  useRootNavigator: false,
  barrierDismissible: barrierDismissible,
  builder: builder,
);

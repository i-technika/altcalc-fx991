/// 키패드를 주로 쓰는 손 (#24) — 숫자 키를 화면 어느 쪽에 둘지 정한다.
///
/// - 가로형 배치(#142)·가로 접힘선의 넓은 배열(#143): 숫자부를 이 손 쪽에, 함수부를 반대쪽에 둔다. LCD는 본체 폭 전체라
///   손잡이와 무관하다(#284 — 전에는 활성 LCD가 숫자부 위, 계산 기록이 함수부 위였다).
/// - 폴더블 내부 화면의 접힘선 기준 배치(#25): 키패드를 이 손 쪽 절반에 둔다.
/// 위아래 배치(폰 세로 화면 등)에는 영향이 없다.
enum Handedness {
  /// 오른손잡이 (기본) — 숫자 키(키패드) 오른쪽
  right('right'),

  /// 왼손잡이 — 숫자 키(키패드) 왼쪽
  left('left');

  /// 저장 값. 열거형 이름을 바꿔도 저장된 설정이 깨지지 않도록 이름과 따로 둔다.
  final String storageValue;

  const Handedness(this.storageValue);

  /// 기본값 (저장된 값이 없거나 알 수 없는 값일 때)
  static const Handedness fallback = Handedness.right;

  /// 저장 값을 읽는다. `null`이거나 알 수 없는 값이면 [fallback].
  static Handedness fromStorage(String? value) =>
      values.firstWhere((h) => h.storageValue == value, orElse: () => fallback);

  /// 숫자 키(키패드)가 화면 오른쪽에 오는지
  bool get keypadOnRight => this == Handedness.right;
}

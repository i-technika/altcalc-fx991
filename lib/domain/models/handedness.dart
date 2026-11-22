/// 키패드를 주로 쓰는 손 — 좌우 분할 배치에서 키패드를 어느 쪽에 둘지 정한다 (#24).
///
/// 위아래 배치(폰 세로 화면 등)에는 영향이 없다. 폴더블 내부 화면 분할(#25)도 같은 설정을 쓴다.
enum Handedness {
  /// 오른손잡이 (기본) — 키패드 오른쪽, LCD 왼쪽
  right('right'),

  /// 왼손잡이 — 키패드 왼쪽, LCD 오른쪽
  left('left');

  /// 저장 값. 열거형 이름을 바꿔도 저장된 설정이 깨지지 않도록 이름과 따로 둔다.
  final String storageValue;

  const Handedness(this.storageValue);

  /// 기본값 (저장된 값이 없거나 알 수 없는 값일 때)
  static const Handedness fallback = Handedness.right;

  /// 저장 값을 읽는다. `null`이거나 알 수 없는 값이면 [fallback].
  static Handedness fromStorage(String? value) =>
      values.firstWhere((h) => h.storageValue == value, orElse: () => fallback);

  /// 키패드가 화면 오른쪽에 오는지
  bool get keypadOnRight => this == Handedness.right;
}

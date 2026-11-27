import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 스크린리더 읽기 순서 도구 (테스트 공용).

/// 의미 트리를 읽는 순서(`DebugSemanticsDumpOrder.traversalOrder`)대로 훑은 노드 id 목록 — 뿌리부터 깊이 우선.
List<int> semanticsTraversalOrder(WidgetTester tester) {
  final order = <int>[];
  void visit(SemanticsNode node) {
    order.add(node.id);
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      visit(child);
    }
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return order;
}

/// [order]([semanticsTraversalOrder])에서 [finder]가 찾은 위젯의 의미 노드 위치. 없으면 테스트를 실패시킨다.
int semanticsIndexIn(WidgetTester tester, List<int> order, Finder finder) {
  final i = order.indexOf(tester.getSemantics(finder).id);
  expect(i, isNonNegative, reason: '$finder');
  return i;
}

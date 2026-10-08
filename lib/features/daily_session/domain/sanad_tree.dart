// شجرة الإسناد التفاعلية: تُدمج الأسانيد في شجرة واحدة تبدأ بالنبي ﷺ ثم
// الصحابي فالتابعي وصولاً إلى المصنفين، ويُحسب لكل عقدة موضعها للرسم.

import 'package:flutter/foundation.dart';

import '../../hadith/data/models/models.dart';

/// عقدة في الشجرة.
class SanadTreeNode {
  SanadTreeNode({
    required this.narratorId,
    required this.depth,
    required this.nameAsWritten,
  });

  /// الراوي.
  final String narratorId;

  /// العمق (النبي ﷺ عند الصفر).
  final int depth;

  /// الاسم كما ورد في أول إسناد مر به.
  final String? nameAsWritten;

  /// صيغ الأداء التي تحمّل بها عن أبيه في الشجرة.
  final List<String> terms = <String>[];

  /// الأسانيد المارة به.
  final List<String> chainIds = <String>[];

  /// الأبناء.
  final List<SanadTreeNode> children = <SanadTreeNode>[];

  /// الموضع الأفقي بوحدة الأعمدة.
  double slot = 0;
}

/// حافة بين عقدتين.
@immutable
class SanadTreeEdge {
  const SanadTreeEdge({required this.parent, required this.child});

  /// الأب.
  final SanadTreeNode parent;

  /// الابن.
  final SanadTreeNode child;
}

/// الشجرة مع تخطيطها.
@immutable
class SanadTree {
  const SanadTree._({
    required this.roots,
    required this.nodes,
    required this.edges,
    required this.columns,
    required this.depth,
  });

  /// يبني الشجرة من الأسانيد المرتبة من النبي ﷺ إلى المصنف.
  factory SanadTree.build(List<SanadChain> chains) {
    final List<SanadTreeNode> roots = <SanadTreeNode>[];
    for (final SanadChain chain in chains) {
      List<SanadTreeNode> level = roots;
      SanadTreeNode? parent;
      for (int i = 0; i < chain.links.length; i++) {
        final SanadLink link = chain.links[i];
        SanadTreeNode? node;
        for (final SanadTreeNode candidate in level) {
          if (candidate.narratorId == link.narratorId) {
            node = candidate;
            break;
          }
        }
        if (node == null) {
          node = SanadTreeNode(
            narratorId: link.narratorId,
            depth: i,
            nameAsWritten: link.nameAsWritten,
          );
          level.add(node);
        }
        if (!node.chainIds.contains(chain.id)) {
          node.chainIds.add(chain.id);
        }
        final String? term = link.term;
        if (parent != null && term != null && term.isNotEmpty && !node.terms.contains(term)) {
          node.terms.add(term);
        }
        parent = node;
        level = node.children;
      }
    }

    final List<SanadTreeNode> nodes = <SanadTreeNode>[];
    final List<SanadTreeEdge> edges = <SanadTreeEdge>[];
    int nextLeaf = 0;
    int maxDepth = 0;
    void place(SanadTreeNode node) {
      nodes.add(node);
      if (node.depth > maxDepth) {
        maxDepth = node.depth;
      }
      if (node.children.isEmpty) {
        node.slot = nextLeaf.toDouble();
        nextLeaf++;
        return;
      }
      for (final SanadTreeNode child in node.children) {
        edges.add(SanadTreeEdge(parent: node, child: child));
        place(child);
      }
      node.slot = (node.children.first.slot + node.children.last.slot) / 2;
    }

    for (final SanadTreeNode root in roots) {
      place(root);
    }
    return SanadTree._(
      roots: List<SanadTreeNode>.unmodifiable(roots),
      nodes: List<SanadTreeNode>.unmodifiable(nodes),
      edges: List<SanadTreeEdge>.unmodifiable(edges),
      columns: nextLeaf == 0 ? 1 : nextLeaf,
      depth: maxDepth + 1,
    );
  }

  /// الجذور (النبي ﷺ عادة).
  final List<SanadTreeNode> roots;

  /// كل العقد.
  final List<SanadTreeNode> nodes;

  /// الحواف.
  final List<SanadTreeEdge> edges;

  /// عدد الأعمدة (الأوراق).
  final int columns;

  /// عدد الطبقات.
  final int depth;
}

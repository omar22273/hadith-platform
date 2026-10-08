// شجرة الإسناد التفاعلية: رسم يربط النبي ﷺ بالصحابي فالتابعي وصولاً إلى
// المصنفين، مع صيغ الأداء على الحواف. تُكبّر وتُحرّك باللمس، والعقدة تفتح الترجمة.

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_sheet.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../hadith/data/models/models.dart';
import '../../../hadith/domain/hadith_bundle.dart';
import '../../domain/sanad_tree.dart';
import 'narrator_card.dart';

/// عرض الشجرة.
class SanadTreeView extends StatelessWidget {
  const SanadTreeView({super.key, required this.bundle});

  /// الفهارس والحديث.
  final HadithBundle bundle;

  static const double _nodeWidth = 132;
  static const double _nodeHeight = 74;
  static const double _columnGap = 14;
  static const double _rowGap = 58;
  static const double _padding = 24;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final SanadTree tree = SanadTree.build(bundle.hadith.scholar.chains);
    final double width = _padding * 2 + tree.columns * (_nodeWidth + _columnGap) - _columnGap;
    final double height = _padding * 2 + tree.depth * (_nodeHeight + _rowGap) - _rowGap;

    Offset topCenter(SanadTreeNode node) {
      final double ltrX = _padding + node.slot * (_nodeWidth + _columnGap) + _nodeWidth / 2;
      final double x = width - ltrX;
      final double y = _padding + node.depth * (_nodeHeight + _rowGap);
      return Offset(x, y);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              for (final SanadChain chain in bundle.hadith.scholar.chains)
                SoftChip(
                  icon: chain.isWordingChain ? Icons.format_quote_rounded : Icons.account_tree_rounded,
                  label: '${bundle.sourceTitle(chain.source.sourceId)} ${arabicDigits(chain.source.hadithNumber)}'
                      '${chain.isWordingChain ? ' · سياق اللفظ' : ''}',
                  background: chain.isWordingChain ? palette.amberSoft : null,
                  foreground: chain.isWordingChain ? palette.amberText : null,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'حرّك الشجرة وكبّرها بإصبعين، والمس الراوي لترجمته.',
            style: text.labelSmall?.copyWith(color: palette.inkSoft),
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            constrained: false,
            minScale: 0.5,
            maxScale: 2.5,
            boundaryMargin: const EdgeInsets.all(120),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _EdgesPainter(
                        tree: tree,
                        topCenter: topCenter,
                        nodeHeight: _nodeHeight,
                        line: palette.amber.withValues(alpha: 0.55),
                        termColor: palette.amberText,
                        termBackground: palette.paper,
                      ),
                    ),
                  ),
                  for (final SanadTreeNode node in tree.nodes)
                    Positioned(
                      left: topCenter(node).dx - _nodeWidth / 2,
                      top: topCenter(node).dy,
                      width: _nodeWidth,
                      height: _nodeHeight,
                      child: _NodeCard(node: node, bundle: bundle),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.node, required this.bundle});

  final SanadTreeNode node;
  final HadithBundle bundle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final NarratorProfile? narrator = bundle.narrators.byId(node.narratorId);
    final NarratorCategory category = narrator?.category ?? NarratorCategory.narrator;
    final String name = narrator?.displayName ?? node.nameAsWritten ?? node.narratorId;
    final String role = category == NarratorCategory.narrator
        ? (narrator?.tabaqa?.text ?? 'راوٍ')
        : narratorCategoryLabel(category);
    final bool compiler = category == NarratorCategory.compiler;
    final bool prophet = category == NarratorCategory.prophet;
    return SmoothSurface(
      color: compiler
          ? palette.ink
          : prophet
              ? palette.amberSoft
              : palette.surface,
      borderColor: prophet || category == NarratorCategory.companion ? palette.amber : palette.line,
      radius: AppShapes.radiusSmall,
      elevated: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      semanticLabel: '$name، $role',
      onTap: narrator == null
          ? null
          : () => showSmoothSheet<void>(
                context: context,
                builder: (BuildContext sheetContext) => NarratorCard(narrator: narrator, bundle: bundle),
              ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.labelLarge?.copyWith(
              color: compiler ? palette.paper : palette.ink,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          Text(
            role,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(
              color: compiler ? palette.amberSoft : palette.inkSoft,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _EdgesPainter extends CustomPainter {
  _EdgesPainter({
    required this.tree,
    required this.topCenter,
    required this.nodeHeight,
    required this.line,
    required this.termColor,
    required this.termBackground,
  });

  final SanadTree tree;
  final Offset Function(SanadTreeNode node) topCenter;
  final double nodeHeight;
  final Color line;
  final Color termColor;
  final Color termBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final SanadTreeEdge edge in tree.edges) {
      final Offset parentTop = topCenter(edge.parent);
      final Offset from = Offset(parentTop.dx, parentTop.dy + nodeHeight);
      final Offset to = topCenter(edge.child);
      final double midY = (from.dy + to.dy) / 2;
      final Path path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(from.dx, midY, to.dx, midY, to.dx, to.dy);
      canvas.drawPath(path, stroke);
      final List<String> terms = edge.child.terms;
      if (terms.isEmpty) {
        continue;
      }
      final TextPainter label = TextPainter(
        text: TextSpan(
          text: terms.join(' / '),
          style: AppTypography.athar(color: termColor, fontSize: 14).copyWith(height: 1.2),
        ),
        textDirection: TextDirection.rtl,
        maxLines: 1,
      )..layout(maxWidth: 160);
      final Offset labelCenter = Offset((from.dx + to.dx) / 2, midY);
      final Rect box = Rect.fromCenter(
        center: labelCenter,
        width: label.width + 10,
        height: label.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(8)),
        Paint()..color = termBackground,
      );
      label.paint(canvas, Offset(box.left + 5, box.top + 2));
      label.dispose();
    }
  }

  @override
  bool shouldRepaint(_EdgesPainter oldDelegate) {
    return oldDelegate.tree != tree || oldDelegate.line != line || oldDelegate.termColor != termColor;
  }
}

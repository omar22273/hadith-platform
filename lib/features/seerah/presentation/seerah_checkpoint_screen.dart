// واحة الاستذكار: خمس محطات مخلوطة يسحبها المستخدم إلى ترتيبها الزمني. عند
// الخطأ تُلوَّن المواضع الخاطئة ويُعاد المحاولة، وعند الصواب يُتاح المتابعة.
// يمكن تخطيها دون أن يعلق المستخدم.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/text/arabic_digits.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/app_shapes.dart';
import '../../../core/ui/smooth_surface.dart';
import '../data/models/seerah_station.dart';
import '../domain/seerah_checkpoint.dart';

/// شاشة الواحة. تُغلق بـ true عند الحل وبـ false عند التخطي.
class SeerahCheckpointScreen extends StatefulWidget {
  const SeerahCheckpointScreen({super.key, required this.checkpoint});

  /// الواحة.
  final SeerahCheckpoint checkpoint;

  @override
  State<SeerahCheckpointScreen> createState() => _SeerahCheckpointScreenState();
}

class _SeerahCheckpointScreenState extends State<SeerahCheckpointScreen> {
  late final List<SeerahStationModel> _order = List<SeerahStationModel>.of(widget.checkpoint.shuffled);
  List<bool>? _result;
  bool _solved = false;
  int _attempts = 0;

  void _reorder(int oldIndex, int newIndex) {
    if (_solved) {
      return;
    }
    setState(() {
      // onReorderItem يسلّم newIndex معدّلاً بعد إزالة العنصر من موضعه القديم.
      final SeerahStationModel moved = _order.removeAt(oldIndex);
      _order.insert(newIndex, moved);
      _result = null;
    });
  }

  void _check() {
    final List<bool> result = widget.checkpoint.evaluate(_order);
    final bool solved = result.every((bool ok) => ok);
    setState(() {
      _result = result;
      _solved = solved;
      _attempts += 1;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('واحة الاستذكار', style: AppTypography.heritageTitle(color: palette.ink, fontSize: 22)),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Text(
              'اسحب الأحداث الخمسة الأخيرة لترتبها زمنياً، الأقدم في الأعلى، ثم اضغط «تحقق».',
              style: text.bodyMedium?.copyWith(color: palette.inkSoft, height: 1.7),
            ),
          ),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              buildDefaultDragHandles: false,
              onReorderItem: _reorder,
              proxyDecorator: (Widget child, int index, Animation<double> animation) =>
                  Material(color: Colors.transparent, elevation: 6, child: child),
              children: <Widget>[
                for (int i = 0; i < _order.length; i++)
                  Padding(
                    key: ValueKey<String>(_order[i].id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CheckpointTile(
                      position: i,
                      station: _order[i],
                      correct: _result?[i],
                      locked: _solved,
                    ),
                  ),
              ],
            ),
          ),
          if (_solved)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'أحسنت؛ هذا هو الترتيب الزمني الصحيح.',
                style: text.titleSmall?.copyWith(color: palette.emeraldText, fontWeight: FontWeight.w700),
              ),
            )
          else if (_result != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'بعض المواضع تحتاج إلى مراجعة (بالأحمر). حرّكها وحاول مجدداً.'
                '${_attempts >= 3 ? ' يمكنك الاستعانة بشريط الزمن في الخريطة.' : ''}',
                style: text.bodyMedium?.copyWith(color: palette.amberText, height: 1.6),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: <Widget>[
                  if (!_solved)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('تخطي الواحة'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _solved ? () => Navigator.of(context).pop(true) : _check,
                    icon: Icon(_solved ? Icons.arrow_back_rounded : Icons.fact_check_rounded),
                    label: Text(_solved ? 'تابع الرحلة' : 'تحقق'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckpointTile extends StatelessWidget {
  const _CheckpointTile({
    required this.position,
    required this.station,
    required this.correct,
    required this.locked,
  });

  final int position;
  final SeerahStationModel station;
  final bool? correct;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final Color border = correct == null
        ? palette.line
        : (correct! ? palette.emerald : palette.amberDeep);
    final Color fill = correct == null
        ? palette.surface
        : (correct! ? palette.emeraldSoft : palette.amberSoft);
    return SmoothSurface(
      color: fill,
      borderColor: border,
      borderWidth: correct == null ? 1 : 2,
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Text(
            arabicDigits(position + 1),
            style: text.titleLarge?.copyWith(color: palette.amberText, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  station.title,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.5),
                ),
                Text(
                  station.place.name,
                  style: text.labelSmall?.copyWith(color: palette.inkSoft),
                ),
              ],
            ),
          ),
          if (correct != null)
            Icon(
              correct! ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: correct! ? palette.emeraldText : palette.amberDeep,
            ),
          if (!locked)
            ReorderableDragStartListener(
              index: position,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.drag_indicator_rounded, color: palette.locked),
              ),
            ),
        ],
      ),
    );
  }
}

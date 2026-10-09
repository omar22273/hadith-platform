// شريط الزمن: محطات السيرة بترتيبها، مجمّعة تحت حقبها الثلاث. يتبع الشريط
// المحطة المختارة فيبقيها في مجال الرؤية.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../data/models/seerah_station.dart';
import 'seerah_labels.dart';

/// شريط الزمن.
class SeerahTimeline extends StatefulWidget {
  const SeerahTimeline({
    super.key,
    required this.stations,
    required this.selectedIndex,
    required this.visited,
    required this.onSelect,
  });

  /// المحطات بترتيبها الزمني.
  final List<SeerahStationModel> stations;

  /// المحطة المختارة.
  final int selectedIndex;

  /// المحطات المكتملة مشاهدها.
  final Set<String> visited;

  /// اختيار محطة بترتيبها.
  final ValueChanged<int> onSelect;

  @override
  State<SeerahTimeline> createState() => _SeerahTimelineState();
}

class _SeerahTimelineState extends State<SeerahTimeline> {
  late List<GlobalKey> _keys = _makeKeys();

  List<GlobalKey> _makeKeys() {
    return List<GlobalKey>.generate(widget.stations.length, (int index) => GlobalKey());
  }

  @override
  void didUpdateWidget(SeerahTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stations.length != widget.stations.length) {
      _keys = _makeKeys();
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _reveal(widget.selectedIndex);
    }
  }

  void _reveal(int index) {
    WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
      if (!mounted || index < 0 || index >= _keys.length) {
        return;
      }
      final BuildContext? itemContext = _keys[index].currentContext;
      if (itemContext == null) {
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          itemContext,
          alignment: 0.5,
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = <Widget>[];
    for (int i = 0; i < widget.stations.length; i++) {
      final SeerahStationModel station = widget.stations[i];
      if (i == 0 || widget.stations[i - 1].epoch != station.epoch) {
        items.add(_EpochMarker(epoch: station.epoch));
      }
      items.add(
        _StationChip(
          key: _keys[i],
          station: station,
          selected: i == widget.selectedIndex,
          visited: widget.visited.contains(station.id),
          onTap: () => widget.onSelect(i),
        ),
      );
    }
    return SizedBox(
      height: 112,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items,
        ),
      ),
    );
  }
}

class _EpochMarker extends StatelessWidget {
  const _EpochMarker({required this.epoch});

  final SeerahEpoch epoch;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8, top: 8, bottom: 8),
      child: Semantics(
        header: true,
        child: RotatedBox(
          quarterTurns: 3,
          child: Center(
            child: Text(
              epochLabel(epoch),
              style: text.labelSmall?.copyWith(
                color: palette.amberText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StationChip extends StatelessWidget {
  const _StationChip({
    super.key,
    required this.station,
    required this.selected,
    required this.visited,
    required this.onTap,
  });

  final SeerahStationModel station;
  final bool selected;
  final bool visited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 10, top: 6, bottom: 6),
      child: Semantics(
        button: true,
        selected: selected,
        label: 'المحطة ${arabicDigits(station.order)}: ${station.title}${visited ? '، مكتملة' : ''}',
        child: ExcludeSemantics(
          child: Material(
            color: selected ? palette.amberSoft : palette.surface,
            shape: AppShapes.rounded(
              AppShapes.radiusMedium,
              side: BorderSide(
                color: selected ? palette.amber : palette.line,
                width: selected ? 1.6 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 148,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            arabicDigits(station.order),
                            style: text.labelLarge?.copyWith(
                              color: palette.amberText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (visited) Icon(Icons.verified_rounded, size: 16, color: palette.emeraldText),
                        ],
                      ),
                      Expanded(
                        child: Text(
                          station.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: palette.ink,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

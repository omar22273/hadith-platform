// بوابة مدخل البيانات المحلية السرية (AdminExportScreen): نموذج إضافة حديث أو
// تعديله، ونموذج إضافة مشهد سيرة، وزر «توليد وتصدير JSON» يولد مصفوفة معيارية
// متحققاً منها ذهاباً وإياباً، مع نسخ فوري إلى الحافظة.
//
// تُفتح بخمس نقرات متتالية على رقم الإصدار في الإعدادات. لا ترسل اللوحة شيئاً
// إلى أي خادم؛ كل ما فيها يبقى على الجهاز حتى ينسخه المحرر.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text/arabic_digits.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/app_shapes.dart';
import '../../../core/ui/smooth_surface.dart';
import '../../hadith/application/hadith_providers.dart';
import '../../hadith/data/models/models.dart';
import '../../hadith/domain/hadith_bundle.dart';
import '../../seerah/application/seerah_providers.dart';
import '../../seerah/data/models/seerah_station.dart';
import '../../seerah/presentation/widgets/seerah_labels.dart';
import '../application/admin_controller.dart';
import '../data/models/hadith_draft.dart';
import '../domain/admin_drafts.dart';

/// اللوحة.
class AdminExportScreen extends StatelessWidget {
  const AdminExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة الإدخال المحلية'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(icon: Icon(Icons.menu_book_rounded), text: 'حديث'),
              Tab(icon: Icon(Icons.map_rounded), text: 'مشهد سيرة'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _HadithTab(),
            _SeerahTab(),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ hadith

class _HadithTab extends ConsumerStatefulWidget {
  const _HadithTab();

  @override
  ConsumerState<_HadithTab> createState() => _HadithTabState();
}

class _GharibControllers {
  _GharibControllers({String word = '', String meaning = ''})
      : word = TextEditingController(text: word),
        meaning = TextEditingController(text: meaning);

  final TextEditingController word;
  final TextEditingController meaning;

  void dispose() {
    word.dispose();
    meaning.dispose();
  }
}

class _HadithTabState extends ConsumerState<_HadithTab> with AutomaticKeepAliveClientMixin<_HadithTab> {
  final TextEditingController _number = TextEditingController();
  final TextEditingController _matn = TextEditingController();
  final TextEditingController _narrator = TextEditingController();
  final TextEditingController _benefits = TextEditingController();
  final List<_GharibControllers> _gharib = <_GharibControllers>[_GharibControllers()];
  List<String> _errors = const <String>[];
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _number.dispose();
    _matn.dispose();
    _narrator.dispose();
    _benefits.dispose();
    for (final _GharibControllers row in _gharib) {
      row.dispose();
    }
    super.dispose();
  }

  HadithDraftForm get _form {
    return HadithDraftForm(
      number: _number.text,
      matn: _matn.text,
      topNarrator: _narrator.text,
      gharib: <GharibRow>[
        for (final _GharibControllers row in _gharib) GharibRow(word: row.word.text, meaning: row.meaning.text),
      ],
      benefits: _benefits.text,
    );
  }

  void _fill(HadithDraftForm form) {
    _number.text = form.number;
    _matn.text = form.matn;
    _narrator.text = form.topNarrator;
    _benefits.text = form.benefits;
    for (final _GharibControllers row in _gharib) {
      row.dispose();
    }
    _gharib
      ..clear()
      ..addAll(<_GharibControllers>[
        for (final GharibRow row in form.gharib) _GharibControllers(word: row.word, meaning: row.meaning),
      ]);
    if (_gharib.isEmpty) {
      _gharib.add(_GharibControllers());
    }
  }

  Future<void> _loadExisting(String hadithId) async {
    setState(() => _loading = true);
    try {
      final HadithBundle bundle = await ref.read(hadithBundleProvider(hadithId).future);
      if (!mounted) {
        return;
      }
      setState(() {
        _fill(HadithDraftForm.fromBundle(bundle));
        _errors = const <String>[];
      });
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر تحميل الحديث: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _add() {
    final HadithDraftForm form = _form;
    final List<String> errors = form.validate();
    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      return;
    }
    ref.read(adminControllerProvider.notifier).addHadith(form.toDraft());
    setState(() {
      _fill(HadithDraftForm.blank);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('أُضيفت المسودة إلى الدفعة.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final AdminState admin = ref.watch(adminControllerProvider);
    final List<CurriculumItem> items = ref.watch(curriculumProvider).value?.items ?? const <CurriculumItem>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        _Section(
          title: 'نموذج إضافة/تعديل حديث',
          icon: Icons.edit_note_rounded,
          children: <Widget>[
            if (items.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'تحميل حديث موجود للتعديل'),
                items: <DropdownMenuItem<String>>[
                  for (final CurriculumItem item in items)
                    DropdownMenuItem<String>(
                      value: item.hadithId,
                      child: Text('${arabicDigits(item.number)}. ${item.title}'),
                    ),
                ],
                onChanged: _loading
                    ? null
                    : (String? id) {
                        if (id != null) {
                          _loadExisting(id);
                        }
                      },
              ),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            TextField(
              controller: _number,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'رقم الحديث في الأربعين', hintText: 'مثل 3'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _matn,
              minLines: 4,
              maxLines: 10,
              style: AppTypography.matnOf(context, color: palette.ink, fontSize: 20),
              decoration: const InputDecoration(
                labelText: 'المتن المشكول',
                hintText: 'يُلصق كما في الطبعة المحققة بضبطه كاملاً',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _narrator,
              decoration: const InputDecoration(labelText: 'الراوي الأعلى', hintText: 'الصحابي راوي الحديث'),
            ),
            const SizedBox(height: 16),
            Text('المفردات وغريب الألفاظ', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (int i = 0; i < _gharib.length; i++) ...<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _gharib[i].word,
                      decoration: InputDecoration(labelText: 'اللفظة ${arabicDigits(i + 1)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _gharib[i].meaning,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'البيان'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'حذف السطر',
                    onPressed: _gharib.length == 1
                        ? null
                        : () => setState(() {
                              _gharib.removeAt(i).dispose();
                            }),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _gharib.add(_GharibControllers())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('لفظة أخرى'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _benefits,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'الفوائد السلوكية',
                hintText: 'فائدة في كل سطر',
                alignLabelWithHint: true,
              ),
            ),
            _Errors(errors: _errors),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('إضافة إلى الدفعة'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'دفعة الأحاديث (${arabicDigits(admin.hadithDrafts.length)})',
          icon: Icons.inventory_2_outlined,
          children: <Widget>[
            if (admin.hadithDrafts.isEmpty)
              Text('لم تُضف مسودات بعد.', style: text.bodySmall?.copyWith(color: palette.inkSoft)),
            for (final HadithDraft draft in admin.hadithDrafts)
              _QueuedTile(
                title: '${arabicDigits(draft.number)}. ${draft.topNarrator}',
                subtitle: '${arabicDigits(draft.gharib.length)} لفظة · ${arabicDigits(draft.behavioralBenefits.length)} فائدة',
                onRemove: () => ref.read(adminControllerProvider.notifier).removeHadith(draft.number),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _ExportPanel(
          enabled: admin.hadithDrafts.isNotEmpty,
          json: admin.hadithJson,
          count: admin.hadithDrafts.length,
          onGenerate: () => ref.read(adminControllerProvider.notifier).exportHadiths(),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ seerah

class _SeerahTab extends ConsumerStatefulWidget {
  const _SeerahTab();

  @override
  ConsumerState<_SeerahTab> createState() => _SeerahTabState();
}

class _SeerahTabState extends ConsumerState<_SeerahTab> with AutomaticKeepAliveClientMixin<_SeerahTab> {
  final TextEditingController _id = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _timeLabel = TextEditingController();
  final TextEditingController _scene = TextEditingController();
  final TextEditingController _challenge = TextEditingController();
  final TextEditingController _decision = TextEditingController();
  final TextEditingController _locator = TextEditingController();
  final Map<SeerahScene, TextEditingController> _quotes = <SeerahScene, TextEditingController>{
    for (final SeerahScene scene in SeerahScene.values) scene: TextEditingController(),
  };
  SeerahEpoch _epoch = SeerahEpoch.meccan;
  int _placeIndex = 0;
  String _sourceId = 'sira_ibn_hisham';
  List<String> _errors = const <String>[];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _id,
      _title,
      _timeLabel,
      _scene,
      _challenge,
      _decision,
      _locator,
      ..._quotes.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  SeerahDraftForm get _form {
    return SeerahDraftForm(
      id: _id.text,
      title: _title.text,
      epoch: _epoch,
      placeIndex: _placeIndex,
      timeLabel: _timeLabel.text,
      scene: _scene.text,
      challenge: _challenge.text,
      decision: _decision.text,
      sourceId: _sourceId,
      locator: _locator.text,
      quotes: <SeerahScene, String>{
        for (final MapEntry<SeerahScene, TextEditingController> entry in _quotes.entries) entry.key: entry.value.text,
      },
    );
  }

  void _clear() {
    for (final TextEditingController controller in <TextEditingController>[
      _id,
      _title,
      _timeLabel,
      _scene,
      _challenge,
      _decision,
      _locator,
      ..._quotes.values,
    ]) {
      controller.clear();
    }
  }

  void _add() {
    final SeerahDraftForm form = _form;
    final List<String> errors = form.validate();
    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      return;
    }
    final int existing = ref.read(seerahDatasetProvider).value?.stations.length ?? 0;
    final int queued = ref.read(adminControllerProvider).seerahDrafts.length;
    ref.read(adminControllerProvider.notifier).addSeerah(form.toStation(order: existing + queued + 1));
    final List<SeerahScene> missing = form.missingScenes;
    setState(_clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          missing.isEmpty
              ? 'أُضيفت المحطة إلى الدفعة.'
              : 'أُضيفت المحطة، وينقصها شاهد: ${missing.map(sceneTitle).join('، ')}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final AdminState admin = ref.watch(adminControllerProvider);
    final List<SourceWork> sources = ref.watch(sourceCatalogProvider).value?.sources ?? const <SourceWork>[];
    final bool sourceKnown = sources.any((SourceWork source) => source.id == _sourceId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        _Section(
          title: 'نموذج إضافة مشهد سيرة',
          icon: Icons.add_location_alt_outlined,
          children: <Widget>[
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'المحطة', hintText: 'مثل: بيعة العقبة الثانية'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _id,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'المعرّف اللاتيني', hintText: 'aqaba_second_pledge'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SeerahEpoch>(
              initialValue: _epoch,
              decoration: const InputDecoration(labelText: 'الحقبة'),
              items: <DropdownMenuItem<SeerahEpoch>>[
                for (final SeerahEpoch epoch in SeerahEpoch.values)
                  DropdownMenuItem<SeerahEpoch>(value: epoch, child: Text(epochLabel(epoch))),
              ],
              onChanged: (SeerahEpoch? value) {
                if (value != null) {
                  setState(() => _epoch = value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _placeIndex,
              decoration: const InputDecoration(labelText: 'الموضع (إحداثيات تقريبية)'),
              items: <DropdownMenuItem<int>>[
                for (int i = 0; i < seerahPlacePresets.length; i++)
                  DropdownMenuItem<int>(value: i, child: Text(seerahPlacePresets[i].name)),
              ],
              onChanged: (int? value) {
                if (value != null) {
                  setState(() => _placeIndex = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timeLabel,
              decoration: const InputDecoration(labelText: 'وسم زمني (اختياري، من الشواهد)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _scene,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'المشهد', alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _challenge,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'المأزق', alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _decision,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'المخرج النبوي', alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            Text('المصدر', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (sources.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: sourceKnown ? _sourceId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الكتاب'),
                items: <DropdownMenuItem<String>>[
                  for (final SourceWork source in sources)
                    DropdownMenuItem<String>(
                      value: source.id,
                      child: Text(source.title, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _sourceId = value);
                  }
                },
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _locator,
              decoration: const InputDecoration(labelText: 'الموضع في المصدر', hintText: 'ج1 ص317 أو رقم الحديث'),
            ),
            const SizedBox(height: 12),
            for (final SeerahScene scene in SeerahScene.values) ...<Widget>[
              TextField(
                controller: _quotes[scene],
                minLines: 2,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'نص الشاهد: ${sceneTitle(scene)}',
                  hintText: 'منقول من المصدر بنصه',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'لا تظهر المحطة في التطبيق حتى يكون لكل مشهد من المشاهد الثلاثة شاهده المنقول بنصه.',
              style: text.labelSmall?.copyWith(color: palette.inkSoft),
            ),
            _Errors(errors: _errors),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('إضافة إلى الدفعة'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'دفعة المشاهد (${arabicDigits(admin.seerahDrafts.length)})',
          icon: Icons.inventory_2_outlined,
          children: <Widget>[
            if (admin.seerahDrafts.isEmpty)
              Text('لم تُضف محطات بعد.', style: text.bodySmall?.copyWith(color: palette.inkSoft)),
            for (final SeerahStationModel station in admin.seerahDrafts)
              _QueuedTile(
                title: '${arabicDigits(station.order)}. ${station.title}',
                subtitle: '${epochLabel(station.epoch)} · ${station.place.name} · ${arabicDigits(station.evidence.length)} شاهد',
                onRemove: () => ref.read(adminControllerProvider.notifier).removeSeerah(station.id),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _ExportPanel(
          enabled: admin.seerahDrafts.isNotEmpty,
          json: admin.seerahJson,
          count: admin.seerahDrafts.length,
          onGenerate: () => ref.read(adminControllerProvider.notifier).exportSeerah(),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ shared

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SmoothSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: palette.amberText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.heritageTitle(color: palette.ink, fontSize: 21),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Errors extends StatelessWidget {
  const _Errors({required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) {
      return const SizedBox.shrink();
    }
    final AppPalette palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SmoothSurface(
        color: palette.amberSoft,
        borderColor: palette.amber.withValues(alpha: 0.5),
        radius: AppShapes.radiusSmall,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final String error in errors)
              Text(
                '• $error',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.ink, height: 1.7),
              ),
          ],
        ),
      ),
    );
  }
}

class _QueuedTile extends StatelessWidget {
  const _QueuedTile({required this.title, required this.subtitle, required this.onRemove});

  final String title;
  final String subtitle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SmoothSurface(
        color: palette.surfaceMuted,
        radius: AppShapes.radiusSmall,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(subtitle, style: text.labelSmall?.copyWith(color: palette.inkSoft)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'حذف من الدفعة',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportPanel extends StatelessWidget {
  const _ExportPanel({
    required this.enabled,
    required this.json,
    required this.count,
    required this.onGenerate,
  });

  final bool enabled;
  final String? json;
  final int count;
  final String? Function() onGenerate;

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نُسخ JSON إلى الحافظة.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String? value = json;
    return SmoothSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FilledButton.icon(
            onPressed: enabled
                ? () {
                    final String? generated = onGenerate();
                    if (generated == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('لم يجتز JSON المولد التحقق؛ راجع المدخلات.')),
                      );
                    }
                  }
                : null,
            icon: const Icon(Icons.data_object_rounded),
            label: const Text('توليد وتصدير JSON'),
          ),
          if (value != null) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Icon(Icons.verified_rounded, size: 18, color: palette.emeraldText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'JSON صالح ومطابق للمخطط · ${arabicDigits(count)} عنصر',
                    style: text.labelMedium?.copyWith(color: palette.emeraldText, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _copy(context, value),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('نسخ'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 360),
                decoration: ShapeDecoration(
                  color: palette.surfaceMuted,
                  shape: AppShapes.rounded(AppShapes.radiusSmall, side: BorderSide(color: palette.line)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.5,
                      color: palette.ink,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

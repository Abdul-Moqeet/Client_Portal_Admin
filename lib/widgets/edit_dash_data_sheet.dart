import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_widget.dart';
import '../theme/colors.dart';
import 'shared_components.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  EDIT DASHBOARD DATA SHEET
// ═══════════════════════════════════════════════════════════════════════════

class EditDashDataSheet extends StatefulWidget {
  const EditDashDataSheet({super.key, required this.dashboardWidget});
  final DashboardWidget dashboardWidget;

  @override
  State<EditDashDataSheet> createState() => _EditDashDataSheetState();
}

class _EditDashDataSheetState extends State<EditDashDataSheet> {
  bool _isSaving = false;

  // Metrics controllers
  List<TextEditingController> _metricTitles = [];
  List<TextEditingController> _metricValues = [];

  // Text list items controllers
  List<TextEditingController> _textListItems = [];

  // Global progress
  double _globalProgress = 0.0;

  // Subtitle
  final _subtitleCtrl = TextEditingController();

  // Trailing text
  final _trailingTextCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final data = widget.dashboardWidget.data;

    // Load metrics
    final metrics = (data['metrics'] as List?) ?? [];
    for (final m in metrics) {
      _metricTitles.add(TextEditingController(text: m['title']?.toString() ?? ''));
      _metricValues.add(TextEditingController(text: m['value']?.toString() ?? ''));
    }
    if (_metricTitles.isEmpty) {
      _metricTitles.add(TextEditingController());
      _metricValues.add(TextEditingController());
    }

    // Load text_list_items
    final textItems = (data['text_list_items'] as List?) ?? [];
    for (final item in textItems) {
      _textListItems.add(TextEditingController(text: item?.toString() ?? ''));
    }

    // Load global_progress
    final gp = data['global_progress'];
    if (gp is num) {
      _globalProgress = gp.toDouble().clamp(0.0, 1.0);
    }

    // Load subtitle
    _subtitleCtrl.text = data['subtitle']?.toString() ?? '';

    // Load trailing_text
    _trailingTextCtrl.text = data['trailing_text']?.toString() ?? '';
  }

  @override
  void dispose() {
    for (final c in [..._metricTitles, ..._metricValues, ..._textListItems]) {
      c.dispose();
    }
    _subtitleCtrl.dispose();
    _trailingTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final category = widget.dashboardWidget.category;

      // Build metrics array
      final metrics = <Map<String, dynamic>>[];
      for (int i = 0; i < _metricTitles.length; i++) {
        final title = _metricTitles[i].text.trim();
        final value = _metricValues[i].text.trim();
        if (title.isNotEmpty || value.isNotEmpty) {
          metrics.add({'title': title, 'value': value});
        }
      }

      // Start building data map
      final newData = <String, dynamic>{'metrics': metrics};

      // Add category-specific fields
      if (category == DashboardCategory.pipelineProgress) {
        newData['global_progress'] = _globalProgress;
        newData['text_list_items'] = _textListItems
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      } else if (category == DashboardCategory.coreVitalsRadar) {
        newData['subtitle'] = _subtitleCtrl.text.trim();
      } else if (category == DashboardCategory.userSentiment) {
        newData['subtitle'] = _subtitleCtrl.text.trim();
        newData['text_list_items'] = _textListItems
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      } else if (category == DashboardCategory.appStoreStatus) {
        newData['trailing_text'] = _trailingTextCtrl.text.trim();
      }

      // Preserve existing history key if it exists
      final existingData = widget.dashboardWidget.data;
      if (existingData.containsKey('history')) {
        newData['history'] = existingData['history'];
      }

      await Supabase.instance.client
          .from('widgets_data')
          .update({
            'data': newData,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.dashboardWidget.id);

      final updated = widget.dashboardWidget.copyWith(data: newData);
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      debugPrint('Edit dash data failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.dashboardWidget;
    final category = w.category;
    final categoryColor = category?.color ?? AppColors.accent;

    return SheetContainer(
      title: 'Edit Data',
      subtitle: w.title,
      icon: category?.icon ?? Icons.edit_rounded,
      iconColor: categoryColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metrics section
          Row(children: [
            const SheetLabel('METRICS'),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _metricTitles.add(TextEditingController());
                _metricValues.add(TextEditingController());
              }),
              child: const Icon(Icons.add_circle_rounded,
                  color: AppColors.accent, size: 20),
            ),
          ]),
          const SizedBox(height: 8),
          ...List.generate(
            _metricTitles.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: SheetField(
                        controller: _metricTitles[i],
                        hint: 'Title',
                        icon: Icons.label_outline_rounded)),
                const SizedBox(width: 8),
                Expanded(
                    flex: 2,
                    child: SheetField(
                        controller: _metricValues[i],
                        hint: 'Value',
                        icon: Icons.numbers_rounded)),
                if (_metricTitles.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _metricTitles[i].dispose();
                        _metricValues[i].dispose();
                        _metricTitles.removeAt(i);
                        _metricValues.removeAt(i);
                      }),
                      child: const Icon(Icons.remove_circle_rounded,
                          color: AppColors.danger, size: 20),
                    ),
                  ),
              ]),
            ),
          ),

          // Category-specific fields
          ..._buildCategoryFields(category),

          const SizedBox(height: 28),
          _isSaving
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent))
              : SheetButton(
                  label: 'Save Changes',
                  color: categoryColor,
                  onTap: _save),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryFields(DashboardCategory? category) {
    if (category == null) return [];

    switch (category) {
      case DashboardCategory.pipelineProgress:
        return [
          const SizedBox(height: 20),
          SheetLabel('PROGRESS (${(_globalProgress * 100).toInt()}%)'),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: DashboardCategory.pipelineProgress.color,
              inactiveTrackColor: AppColors.border,
              thumbColor: DashboardCategory.pipelineProgress.color,
              overlayColor:
                  DashboardCategory.pipelineProgress.color.withOpacity(0.2),
            ),
            child: Slider(
              value: _globalProgress,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              onChanged: (v) => setState(() => _globalProgress = v),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const SheetLabel('TEXT LIST ITEMS'),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _textListItems.add(TextEditingController());
              }),
              child: const Icon(Icons.add_circle_rounded,
                  color: AppColors.accent, size: 20),
            ),
          ]),
          const SizedBox(height: 8),
          ...List.generate(
            _textListItems.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                    child: SheetField(
                        controller: _textListItems[i],
                        hint: 'Item ${i + 1}',
                        icon: Icons.short_text_rounded)),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _textListItems[i].dispose();
                      _textListItems.removeAt(i);
                    }),
                    child: const Icon(Icons.remove_circle_rounded,
                        color: AppColors.danger, size: 20),
                  ),
                ),
              ]),
            ),
          ),
        ];

      case DashboardCategory.coreVitalsRadar:
        return [
          const SizedBox(height: 20),
          const SheetLabel('SUBTITLE'),
          const SizedBox(height: 8),
          SheetField(
              controller: _subtitleCtrl,
              hint: 'e.g. Last 30 days',
              icon: Icons.subtitles_rounded),
        ];

      case DashboardCategory.userSentiment:
        return [
          const SizedBox(height: 20),
          const SheetLabel('SUBTITLE'),
          const SizedBox(height: 8),
          SheetField(
              controller: _subtitleCtrl,
              hint: 'e.g. User feedback summary',
              icon: Icons.subtitles_rounded),
          const SizedBox(height: 16),
          Row(children: [
            const SheetLabel('TEXT LIST ITEMS'),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _textListItems.add(TextEditingController());
              }),
              child: const Icon(Icons.add_circle_rounded,
                  color: AppColors.accent, size: 20),
            ),
          ]),
          const SizedBox(height: 8),
          ...List.generate(
            _textListItems.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                    child: SheetField(
                        controller: _textListItems[i],
                        hint: 'Item ${i + 1}',
                        icon: Icons.short_text_rounded)),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _textListItems[i].dispose();
                      _textListItems.removeAt(i);
                    }),
                    child: const Icon(Icons.remove_circle_rounded,
                        color: AppColors.danger, size: 20),
                  ),
                ),
              ]),
            ),
          ),
        ];

      case DashboardCategory.appStoreStatus:
        return [
          const SizedBox(height: 20),
          const SheetLabel('TRAILING TEXT'),
          const SizedBox(height: 8),
          SheetField(
              controller: _trailingTextCtrl,
              hint: 'e.g. v2.1.0 - Released',
              icon: Icons.text_fields_rounded),
        ];

      case DashboardCategory.versionMilestones:
        return [];
    }
  }
}

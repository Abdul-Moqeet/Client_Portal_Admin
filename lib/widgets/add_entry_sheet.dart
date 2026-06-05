import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_widget.dart';
import '../theme/colors.dart';
import 'shared_components.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  ADD ENTRY SHEET
// ═══════════════════════════════════════════════════════════════════════════

class AddEntrySheet extends StatefulWidget {
  const AddEntrySheet({super.key, required this.dashboardWidget});
  final DashboardWidget dashboardWidget;

  @override
  State<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<AddEntrySheet> {
  bool _isSaving = false;

  final _dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10));

  // KPI
  final _kpiValueCtrl = TextEditingController();
  final _kpiChangeCtrl = TextEditingController();
  final _kpiPrefixCtrl = TextEditingController();
  bool _kpiTrendUp = true;

  // Chart
  final _chartLabelsCtrl =
      TextEditingController(text: 'Mon,Tue,Wed,Thu,Fri,Sat,Sun');
  final _chartValuesCtrl = TextEditingController();

  // Info chart
  final List<TextEditingController> _infoNames = [TextEditingController()];
  final List<TextEditingController> _infoValues = [TextEditingController()];

  // Leaderboard
  final List<TextEditingController> _lbNames = [TextEditingController()];
  final List<TextEditingController> _lbScores = [TextEditingController()];

  // Dashboard widget entry fields
  final List<TextEditingController> _dashMetricTitles = [TextEditingController()];
  final List<TextEditingController> _dashMetricValues = [TextEditingController()];
  final List<TextEditingController> _dashTextListItems = [];
  final _dashGlobalProgressCtrl = TextEditingController(text: '0.0');

  @override
  void dispose() {
    _dateCtrl.dispose();
    _kpiValueCtrl.dispose();
    _kpiChangeCtrl.dispose();
    _kpiPrefixCtrl.dispose();
    _chartLabelsCtrl.dispose();
    _chartValuesCtrl.dispose();
    for (final c in [
      ..._infoNames,
      ..._infoValues,
      ..._lbNames,
      ..._lbScores,
      ..._dashMetricTitles,
      ..._dashMetricValues,
      ..._dashTextListItems,
    ]) {
      c.dispose();
    }
    _dashGlobalProgressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final date = _dateCtrl.text.trim();
    if (date.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      dynamic entry;

      if (widget.dashboardWidget.isDashWidget) {
        // Build dashboard entry
        final metrics = <Map<String, dynamic>>[];
        for (int i = 0; i < _dashMetricTitles.length; i++) {
          final title = _dashMetricTitles[i].text.trim();
          final value = _dashMetricValues[i].text.trim();
          if (title.isNotEmpty || value.isNotEmpty) {
            metrics.add({'title': title, 'value': value});
          }
        }
        entry = <String, dynamic>{'metrics': metrics};

        final category = widget.dashboardWidget.category;
        if (category == DashboardCategory.pipelineProgress) {
          entry['global_progress'] =
              double.tryParse(_dashGlobalProgressCtrl.text.trim()) ?? 0.0;
          entry['text_list_items'] = _dashTextListItems
              .map((c) => c.text.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } else {
        switch (widget.dashboardWidget.type) {
          case WidgetType.kpi:
            entry = {
              'trend': _kpiTrendUp ? 'up' : 'down',
              'value': num.tryParse(_kpiValueCtrl.text.trim()) ?? 0,
              'change': num.tryParse(_kpiChangeCtrl.text.trim()) ?? 0,
              if (_kpiPrefixCtrl.text.trim().isNotEmpty)
                'prefix': _kpiPrefixCtrl.text.trim(),
            };

          case WidgetType.chart:
            entry = {
              'labels': _chartLabelsCtrl.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList(),
              'values': _chartValuesCtrl.text
                  .split(',')
                  .map((s) => num.tryParse(s.trim()) ?? 0)
                  .toList(),
            };

          case WidgetType.infoChart:
            entry = List.generate(
              _infoNames.length,
              (i) => {
                'name': _infoNames[i].text.trim(),
                'value': num.tryParse(_infoValues[i].text.trim()) ?? 0,
              },
            );

          case WidgetType.leaderBoard:
            final leaders = List.generate(
              _lbNames.length,
              (i) => {
                'name': _lbNames[i].text.trim(),
                'score': num.tryParse(_lbScores[i].text.trim()) ?? 0,
              },
            )..sort(
                (a, b) => (b['score'] as num).compareTo(a['score'] as num));
            entry = {'leaders': leaders};
        }
      }

      final newHistory =
          Map<String, dynamic>.from(widget.dashboardWidget.history)
            ..[date] = entry;
      final updatedData = {
        ...Map<String, dynamic>.from(widget.dashboardWidget.data),
        'history': newHistory,
      };

      await Supabase.instance.client
          .from('widgets_data')
          .update({
            'data': updatedData,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.dashboardWidget.id);

      final updated = DashboardWidget(
        id: widget.dashboardWidget.id,
        type: widget.dashboardWidget.type,
        title: widget.dashboardWidget.title,
        data: updatedData,
        history: newHistory,
        colspan: widget.dashboardWidget.colspan,
        position: widget.dashboardWidget.position,
      );

      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      debugPrint('Save entry failed: $e');
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
    return SheetContainer(
      title: 'Add Entry',
      subtitle: w.title,
      icon: w.type.icon,
      iconColor: w.type.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetLabel('Date'),
          const SizedBox(height: 8),
          SheetField(
              controller: _dateCtrl,
              hint: 'YYYY-MM-DD',
              icon: Icons.calendar_today_rounded),
          const SizedBox(height: 20),
          ..._buildTypeFields(w.type),
          const SizedBox(height: 28),
          _isSaving
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent))
              : SheetButton(
                  label: 'Save Entry', color: w.type.color, onTap: _save),
        ],
      ),
    );
  }

  List<Widget> _buildTypeFields(WidgetType type) {
    // Dashboard widget entry fields
    if (widget.dashboardWidget.isDashWidget) {
      return _buildDashEntryFields();
    }

    switch (type) {
      case WidgetType.kpi:
        return [
          const SheetLabel('Value'),
          const SizedBox(height: 8),
          SheetField(
              controller: _kpiValueCtrl,
              hint: 'e.g. 1250',
              icon: Icons.numbers_rounded,
              keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetLabel('Change %'),
                  const SizedBox(height: 8),
                  SheetField(
                      controller: _kpiChangeCtrl,
                      hint: 'e.g. 3.5',
                      icon: Icons.percent_rounded,
                      keyboardType: TextInputType.number),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetLabel('Prefix (opt.)'),
                  const SizedBox(height: 8),
                  SheetField(
                      controller: _kpiPrefixCtrl,
                      hint: r'e.g. $',
                      icon: Icons.attach_money_rounded),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          const SheetLabel('Trend'),
          const SizedBox(height: 8),
          Row(children: [
            TrendButton(
                label: 'Up',
                selected: _kpiTrendUp,
                color: AppColors.success,
                onTap: () => setState(() => _kpiTrendUp = true)),
            const SizedBox(width: 10),
            TrendButton(
                label: 'Down',
                selected: !_kpiTrendUp,
                color: AppColors.danger,
                onTap: () => setState(() => _kpiTrendUp = false)),
          ]),
        ];

      case WidgetType.chart:
        return [
          const SheetLabel('Labels (comma-separated)'),
          const SizedBox(height: 8),
          SheetField(
              controller: _chartLabelsCtrl,
              hint: 'Mon,Tue,Wed...',
              icon: Icons.label_rounded),
          const SizedBox(height: 16),
          const SheetLabel('Values (comma-separated)'),
          const SizedBox(height: 8),
          SheetField(
              controller: _chartValuesCtrl,
              hint: '90,160,120...',
              icon: Icons.show_chart_rounded,
              keyboardType: TextInputType.text),
        ];

      case WidgetType.infoChart:
        return [
          Row(children: [
            const SheetLabel('Segments'),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _infoNames.add(TextEditingController());
                _infoValues.add(TextEditingController());
              }),
              child: const Icon(Icons.add_circle_rounded,
                  color: AppColors.accent, size: 20),
            ),
          ]),
          const SizedBox(height: 8),
          ...List.generate(
            _infoNames.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: SheetField(
                        controller: _infoNames[i],
                        hint: 'Name',
                        icon: Icons.label_outline_rounded)),
                const SizedBox(width: 8),
                Expanded(
                    flex: 2,
                    child: SheetField(
                        controller: _infoValues[i],
                        hint: 'Value',
                        icon: Icons.numbers_rounded,
                        keyboardType: TextInputType.number)),
                if (_infoNames.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _infoNames[i].dispose();
                        _infoValues[i].dispose();
                        _infoNames.removeAt(i);
                        _infoValues.removeAt(i);
                      }),
                      child: const Icon(Icons.remove_circle_rounded,
                          color: AppColors.danger, size: 20),
                    ),
                  ),
              ]),
            ),
          ),
        ];

      case WidgetType.leaderBoard:
        return [
          Row(children: [
            const SheetLabel('Leaders'),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _lbNames.add(TextEditingController());
                _lbScores.add(TextEditingController());
              }),
              child: const Icon(Icons.add_circle_rounded,
                  color: AppColors.accent, size: 20),
            ),
          ]),
          const SizedBox(height: 8),
          ...List.generate(
            _lbNames.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(
                  width: 28,
                  child: Text('#${i + 1}',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Expanded(
                    flex: 3,
                    child: SheetField(
                        controller: _lbNames[i],
                        hint: 'Player name',
                        icon: Icons.person_outline_rounded)),
                const SizedBox(width: 8),
                Expanded(
                    flex: 2,
                    child: SheetField(
                        controller: _lbScores[i],
                        hint: 'Score',
                        icon: Icons.scoreboard_rounded,
                        keyboardType: TextInputType.number)),
                if (_lbNames.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _lbNames[i].dispose();
                        _lbScores[i].dispose();
                        _lbNames.removeAt(i);
                        _lbScores.removeAt(i);
                      }),
                      child: const Icon(Icons.remove_circle_rounded,
                          color: AppColors.danger, size: 20),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Leaders are auto-sorted by score on save.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ];
    }
  }

  List<Widget> _buildDashEntryFields() {
    final category = widget.dashboardWidget.category;
    return [
      Row(children: [
        const SheetLabel('Metrics'),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() {
            _dashMetricTitles.add(TextEditingController());
            _dashMetricValues.add(TextEditingController());
          }),
          child: const Icon(Icons.add_circle_rounded,
              color: AppColors.accent, size: 20),
        ),
      ]),
      const SizedBox(height: 8),
      ...List.generate(
        _dashMetricTitles.length,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(
                flex: 3,
                child: SheetField(
                    controller: _dashMetricTitles[i],
                    hint: 'Title',
                    icon: Icons.label_outline_rounded)),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: SheetField(
                    controller: _dashMetricValues[i],
                    hint: 'Value',
                    icon: Icons.numbers_rounded)),
            if (_dashMetricTitles.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _dashMetricTitles[i].dispose();
                    _dashMetricValues[i].dispose();
                    _dashMetricTitles.removeAt(i);
                    _dashMetricValues.removeAt(i);
                  }),
                  child: const Icon(Icons.remove_circle_rounded,
                      color: AppColors.danger, size: 20),
                ),
              ),
          ]),
        ),
      ),
      if (category == DashboardCategory.pipelineProgress) ...[
        const SizedBox(height: 16),
        const SheetLabel('Global Progress (0.0 - 1.0)'),
        const SizedBox(height: 8),
        SheetField(
            controller: _dashGlobalProgressCtrl,
            hint: '0.0 - 1.0',
            icon: Icons.linear_scale_rounded,
            keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        Row(children: [
          const SheetLabel('Text List Items'),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() {
              _dashTextListItems.add(TextEditingController());
            }),
            child: const Icon(Icons.add_circle_rounded,
                color: AppColors.accent, size: 20),
          ),
        ]),
        const SizedBox(height: 8),
        ...List.generate(
          _dashTextListItems.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                  child: SheetField(
                      controller: _dashTextListItems[i],
                      hint: 'Item ${i + 1}',
                      icon: Icons.short_text_rounded)),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _dashTextListItems[i].dispose();
                    _dashTextListItems.removeAt(i);
                  }),
                  child: const Icon(Icons.remove_circle_rounded,
                      color: AppColors.danger, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ],
    ];
  }
}

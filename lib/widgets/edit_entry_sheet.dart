import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_widget.dart';
import '../theme/colors.dart';
import 'shared_components.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  EDIT ENTRY SHEET - View, edit, and delete existing history entries
// ═══════════════════════════════════════════════════════════════════════════

class EditEntrySheet extends StatefulWidget {
  const EditEntrySheet({super.key, required this.dashboardWidget});
  final DashboardWidget dashboardWidget;

  @override
  State<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<EditEntrySheet> {
  late Map<String, dynamic> _history;
  bool _isSaving = false;
  String? _editingDate;

  // Controllers for editing
  final _dateCtrl = TextEditingController();

  // KPI
  final _kpiValueCtrl = TextEditingController();
  String _kpiVariant = 'trend';
  String _kpiTrend = 'up';
  final _kpiUnitCtrl = TextEditingController();
  final _kpiItemCtrl = TextEditingController();
  final _kpiPurchasesCtrl = TextEditingController();
  final _kpiLowCtrl = TextEditingController();
  final _kpiCriticalCtrl = TextEditingController();
  final _kpiResolvedCtrl = TextEditingController();

  // Chart
  final _chartLabelsCtrl = TextEditingController();
  final _chartValuesCtrl = TextEditingController();

  // Info chart
  List<TextEditingController> _infoNames = [];
  List<TextEditingController> _infoValues = [];

  // Leaderboard
  List<TextEditingController> _lbNames = [];
  List<TextEditingController> _lbScores = [];

  // Dashboard widget entry fields
  List<TextEditingController> _dashMetricTitles = [];
  List<TextEditingController> _dashMetricValues = [];
  List<TextEditingController> _dashTextListItems = [];
  final _dashGlobalProgressCtrl = TextEditingController();
  final _dashSubtitleCtrl = TextEditingController();
  final _dashTrailingTextCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _history = Map<String, dynamic>.from(widget.dashboardWidget.history);
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _kpiValueCtrl.dispose();
    _kpiUnitCtrl.dispose();
    _kpiItemCtrl.dispose();
    _kpiPurchasesCtrl.dispose();
    _kpiLowCtrl.dispose();
    _kpiCriticalCtrl.dispose();
    _kpiResolvedCtrl.dispose();
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
    _dashSubtitleCtrl.dispose();
    _dashTrailingTextCtrl.dispose();
    super.dispose();
  }

  void _startEditing(String date) {
    final entry = _history[date];
    setState(() {
      _editingDate = date;
      _dateCtrl.text = date;
    });

    // Dashboard widget entries
    if (widget.dashboardWidget.isDashWidget) {
      // Dispose old dashboard controllers
      for (final c in [..._dashMetricTitles, ..._dashMetricValues, ..._dashTextListItems]) {
        c.dispose();
      }
      _dashMetricTitles = [];
      _dashMetricValues = [];
      _dashTextListItems = [];

      if (entry is Map) {
        final metrics = (entry['metrics'] as List?) ?? [];
        for (final m in metrics) {
          _dashMetricTitles
              .add(TextEditingController(text: m['title']?.toString() ?? ''));
          _dashMetricValues
              .add(TextEditingController(text: m['value']?.toString() ?? ''));
        }

        final textItems = (entry['text_list_items'] as List?) ?? [];
        for (final item in textItems) {
          _dashTextListItems
              .add(TextEditingController(text: item?.toString() ?? ''));
        }

        _dashGlobalProgressCtrl.text =
            entry['global_progress']?.toString() ?? '0.0';

        _dashSubtitleCtrl.text = entry['subtitle']?.toString() ?? '';
        _dashTrailingTextCtrl.text = entry['trailing_text']?.toString() ?? '';
      }

      if (_dashMetricTitles.isEmpty) {
        _dashMetricTitles.add(TextEditingController());
        _dashMetricValues.add(TextEditingController());
      }
      return;
    }

    switch (widget.dashboardWidget.type) {
      case WidgetType.kpi:
        if (entry is Map) {
          _kpiValueCtrl.text = entry['value']?.toString() ?? '';
          // Detect variant from entry keys
          if (entry.containsKey('trend')) {
            _kpiVariant = 'trend';
            _kpiTrend = entry['trend']?.toString() ?? 'up';
          } else if (entry.containsKey('unit')) {
            _kpiVariant = 'unit';
            _kpiUnitCtrl.text = entry['unit']?.toString() ?? '';
          } else if (entry.containsKey('item')) {
            _kpiVariant = 'item';
            _kpiItemCtrl.text = entry['item']?.toString() ?? '';
            _kpiPurchasesCtrl.text = entry['purchases']?.toString() ?? '0';
          } else if (entry.containsKey('low') ||
              entry.containsKey('critical') ||
              entry.containsKey('resolved')) {
            _kpiVariant = 'tickets';
            _kpiLowCtrl.text = entry['low']?.toString() ?? '0';
            _kpiCriticalCtrl.text = entry['critical']?.toString() ?? '0';
            _kpiResolvedCtrl.text = entry['resolved']?.toString() ?? '0';
          } else {
            _kpiVariant = 'none';
          }
        }
      case WidgetType.chart:
        if (entry is Map) {
          _chartLabelsCtrl.text =
              (entry['labels'] as List?)?.join(',') ?? '';
          _chartValuesCtrl.text =
              (entry['values'] as List?)?.join(',') ?? '';
        }
      case WidgetType.infoChart:
        // Dispose old controllers
        for (final c in [..._infoNames, ..._infoValues]) {
          c.dispose();
        }
        if (entry is List) {
          _infoNames = entry
              .map((e) => TextEditingController(text: e['name']?.toString() ?? ''))
              .toList();
          _infoValues = entry
              .map((e) => TextEditingController(text: e['value']?.toString() ?? ''))
              .toList();
        } else {
          _infoNames = [TextEditingController()];
          _infoValues = [TextEditingController()];
        }
      case WidgetType.leaderBoard:
        // Dispose old controllers
        for (final c in [..._lbNames, ..._lbScores]) {
          c.dispose();
        }
        if (entry is Map && entry['leaders'] is List) {
          final leaders = entry['leaders'] as List;
          _lbNames = leaders
              .map((e) => TextEditingController(text: e['name']?.toString() ?? ''))
              .toList();
          _lbScores = leaders
              .map((e) => TextEditingController(text: e['score']?.toString() ?? ''))
              .toList();
        } else {
          _lbNames = [TextEditingController()];
          _lbScores = [TextEditingController()];
        }
    }
  }

  void _cancelEditing() {
    setState(() => _editingDate = null);
  }

  Future<void> _deleteEntry(String date) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Entry',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Delete entry for $date?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _history.remove(date);
      if (_editingDate == date) _editingDate = null;
    });
    await _persistHistory();
  }

  Future<void> _saveEditedEntry() async {
    if (_editingDate == null) return;
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
        } else if (category == DashboardCategory.userSentiment) {
          entry['subtitle'] = _dashSubtitleCtrl.text.trim();
          entry['text_list_items'] = _dashTextListItems
              .map((c) => c.text.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        } else if (category == DashboardCategory.coreVitalsRadar) {
          entry['subtitle'] = _dashSubtitleCtrl.text.trim();
        } else if (category == DashboardCategory.appStoreStatus) {
          entry['trailing_text'] = _dashTrailingTextCtrl.text.trim();
        }
      } else {
        switch (widget.dashboardWidget.type) {
          case WidgetType.kpi:
            final rawValue = _kpiValueCtrl.text.trim();
            final numValue = num.tryParse(rawValue);
            switch (_kpiVariant) {
              case 'trend':
                entry = {
                  'value': numValue ?? rawValue,
                  'trend': _kpiTrend,
                };
              case 'unit':
                entry = {
                  'value': numValue ?? rawValue,
                  'unit': _kpiUnitCtrl.text.trim(),
                };
              case 'item':
                entry = {
                  'value': numValue ?? rawValue,
                  'item': _kpiItemCtrl.text.trim(),
                  'purchases':
                      num.tryParse(_kpiPurchasesCtrl.text.trim()) ?? 0,
                };
              case 'tickets':
                entry = {
                  'value': numValue ?? rawValue,
                  'low': num.tryParse(_kpiLowCtrl.text.trim()) ?? 0,
                  'critical':
                      num.tryParse(_kpiCriticalCtrl.text.trim()) ?? 0,
                  'resolved':
                      num.tryParse(_kpiResolvedCtrl.text.trim()) ?? 0,
                };
              default:
                entry = {'value': numValue ?? rawValue};
            }
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

      final newDate = _dateCtrl.text.trim();
      // If date changed, remove old key
      if (newDate != _editingDate) {
        _history.remove(_editingDate);
      }
      _history[newDate] = entry;

      await _persistHistory();
      setState(() => _editingDate = null);
    } catch (e) {
      debugPrint('Edit entry failed: $e');
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

  Future<void> _persistHistory() async {
    final updatedData = {
      ...Map<String, dynamic>.from(widget.dashboardWidget.data),
      'history': _history,
    };

    await Supabase.instance.client
        .from('widgets_data')
        .update({
          'data': updatedData,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', widget.dashboardWidget.id);
  }

  String _summarise(dynamic value) => summariseEntry(value);

  @override
  Widget build(BuildContext context) {
    final w = widget.dashboardWidget;
    final sortedKeys = _history.keys.toList()..sort((a, b) => b.compareTo(a));

    return SheetContainer(
      title: 'Edit Entries',
      subtitle: '${w.title} - ${sortedKeys.length} entries',
      icon: Icons.edit_note_rounded,
      iconColor: w.type.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_editingDate != null) ...[
            _buildEditForm(),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
          ],
          if (sortedKeys.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No entries yet',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...sortedKeys.map((date) => _buildEntryTile(date)),
          const SizedBox(height: 16),
          SheetButton(
            label: 'Done',
            onTap: () {
              final updated = widget.dashboardWidget.copyWith(
                history: _history,
                data: {
                  ...Map<String, dynamic>.from(widget.dashboardWidget.data),
                  'history': _history,
                },
              );
              Navigator.pop(context, updated);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEntryTile(String date) {
    final isEditing = _editingDate == date;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isEditing
            ? AppColors.accent.withOpacity(0.1)
            : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditing ? AppColors.accent.withOpacity(0.4) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace')),
                const SizedBox(height: 2),
                Text(
                  _summarise(_history[date]),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _startEditing(date),
            icon: const Icon(Icons.edit_rounded,
                size: 16, color: AppColors.accent),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            onPressed: () => _deleteEntry(date),
            icon: const Icon(Icons.delete_rounded,
                size: 16, color: AppColors.danger),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_rounded,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Editing: $_editingDate',
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: _cancelEditing,
                child: const Icon(Icons.close_rounded,
                    color: AppColors.textSecondary, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SheetLabel('Date'),
          const SizedBox(height: 6),
          SheetField(
              controller: _dateCtrl,
              hint: 'YYYY-MM-DD',
              icon: Icons.calendar_today_rounded),
          const SizedBox(height: 12),
          ..._buildEditFields(),
          const SizedBox(height: 16),
          _isSaving
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent))
              : SheetButton(
                  label: 'Save Changes',
                  color: AppColors.accent,
                  onTap: _saveEditedEntry),
        ],
      ),
    );
  }

  List<Widget> _buildEditFields() {
    // Dashboard widget edit fields
    if (widget.dashboardWidget.isDashWidget) {
      return _buildDashEditFields();
    }

    switch (widget.dashboardWidget.type) {
      case WidgetType.kpi:
        return [
          const SheetLabel('Value'),
          const SizedBox(height: 6),
          SheetField(
              controller: _kpiValueCtrl,
              hint: 'e.g. 168.04',
              icon: Icons.numbers_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 10),
          const SheetLabel('KPI Variant'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildVariantChip('Trend', 'trend'),
              _buildVariantChip('Unit', 'unit'),
              _buildVariantChip('Item', 'item'),
              _buildVariantChip('Tickets', 'tickets'),
              _buildVariantChip('None', 'none'),
            ],
          ),
          const SizedBox(height: 10),
          ..._buildKpiVariantFields(),
        ];
      case WidgetType.chart:
        return [
          const SheetLabel('Labels'),
          const SizedBox(height: 6),
          SheetField(
              controller: _chartLabelsCtrl,
              hint: 'Mon,Tue,Wed...',
              icon: Icons.label_rounded),
          const SizedBox(height: 10),
          const SheetLabel('Values'),
          const SizedBox(height: 6),
          SheetField(
              controller: _chartValuesCtrl,
              hint: '90,160,120...',
              icon: Icons.show_chart_rounded),
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
                  color: AppColors.accent, size: 18),
            ),
          ]),
          const SizedBox(height: 6),
          ...List.generate(
            _infoNames.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: SheetField(
                        controller: _infoNames[i],
                        hint: 'Name',
                        icon: Icons.label_outline_rounded)),
                const SizedBox(width: 6),
                Expanded(
                    flex: 2,
                    child: SheetField(
                        controller: _infoValues[i],
                        hint: 'Value',
                        icon: Icons.numbers_rounded,
                        keyboardType: TextInputType.number)),
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
                  color: AppColors.accent, size: 18),
            ),
          ]),
          const SizedBox(height: 6),
          ...List.generate(
            _lbNames.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: SheetField(
                        controller: _lbNames[i],
                        hint: 'Name',
                        icon: Icons.person_outline_rounded)),
                const SizedBox(width: 6),
                Expanded(
                    flex: 2,
                    child: SheetField(
                        controller: _lbScores[i],
                        hint: 'Score',
                        icon: Icons.scoreboard_rounded,
                        keyboardType: TextInputType.number)),
              ]),
            ),
          ),
        ];
    }
  }

  Widget _buildVariantChip(String label, String variant) {
    final selected = _kpiVariant == variant;
    return GestureDetector(
      onTap: () => setState(() => _kpiVariant = variant),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withOpacity(0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent.withOpacity(0.5) : AppColors.border,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppColors.accent : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  List<Widget> _buildKpiVariantFields() {
    switch (_kpiVariant) {
      case 'trend':
        return [
          const SheetLabel('Trend'),
          const SizedBox(height: 6),
          Row(children: [
            TrendButton(
                label: 'Up',
                selected: _kpiTrend == 'up',
                color: AppColors.success,
                onTap: () => setState(() => _kpiTrend = 'up')),
            const SizedBox(width: 10),
            TrendButton(
                label: 'Down',
                selected: _kpiTrend == 'down',
                color: AppColors.danger,
                onTap: () => setState(() => _kpiTrend = 'down')),
            const SizedBox(width: 10),
            TrendButton(
                label: 'Stable',
                selected: _kpiTrend == 'stable',
                color: AppColors.textSecondary,
                onTap: () => setState(() => _kpiTrend = 'stable')),
          ]),
        ];
      case 'unit':
        return [
          const SheetLabel('Unit'),
          const SizedBox(height: 6),
          SheetField(
              controller: _kpiUnitCtrl,
              hint: 'e.g. mins, hrs, %',
              icon: Icons.straighten_rounded),
        ];
      case 'item':
        return [
          const SheetLabel('Item'),
          const SizedBox(height: 6),
          SheetField(
              controller: _kpiItemCtrl,
              hint: 'e.g. Monthly Subscription',
              icon: Icons.shopping_bag_rounded),
          const SizedBox(height: 8),
          const SheetLabel('Purchases'),
          const SizedBox(height: 6),
          SheetField(
              controller: _kpiPurchasesCtrl,
              hint: 'e.g. 3',
              icon: Icons.shopping_cart_rounded,
              keyboardType: TextInputType.number),
        ];
      case 'tickets':
        return [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetLabel('Low'),
                  const SizedBox(height: 6),
                  SheetField(
                      controller: _kpiLowCtrl,
                      hint: '0',
                      icon: Icons.arrow_downward_rounded,
                      keyboardType: TextInputType.number),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetLabel('Critical'),
                  const SizedBox(height: 6),
                  SheetField(
                      controller: _kpiCriticalCtrl,
                      hint: '0',
                      icon: Icons.warning_rounded,
                      keyboardType: TextInputType.number),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetLabel('Resolved'),
                  const SizedBox(height: 6),
                  SheetField(
                      controller: _kpiResolvedCtrl,
                      hint: '0',
                      icon: Icons.check_circle_rounded,
                      keyboardType: TextInputType.number),
                ],
              ),
            ),
          ]),
        ];
      default:
        return [];
    }
  }

  List<Widget> _buildDashEditFields() {
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
              color: AppColors.accent, size: 18),
        ),
      ]),
      const SizedBox(height: 6),
      ...List.generate(
        _dashMetricTitles.length,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(
                flex: 3,
                child: SheetField(
                    controller: _dashMetricTitles[i],
                    hint: 'Title',
                    icon: Icons.label_outline_rounded)),
            const SizedBox(width: 6),
            Expanded(
                flex: 2,
                child: SheetField(
                    controller: _dashMetricValues[i],
                    hint: 'Value',
                    icon: Icons.numbers_rounded)),
            if (_dashMetricTitles.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _dashMetricTitles[i].dispose();
                    _dashMetricValues[i].dispose();
                    _dashMetricTitles.removeAt(i);
                    _dashMetricValues.removeAt(i);
                  }),
                  child: const Icon(Icons.remove_circle_rounded,
                      color: AppColors.danger, size: 18),
                ),
              ),
          ]),
        ),
      ),
      if (category == DashboardCategory.pipelineProgress) ...[
        const SizedBox(height: 10),
        const SheetLabel('Global Progress (0.0 - 1.0)'),
        const SizedBox(height: 6),
        SheetField(
            controller: _dashGlobalProgressCtrl,
            hint: '0.0 - 1.0',
            icon: Icons.linear_scale_rounded,
            keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        Row(children: [
          const SheetLabel('Text List Items'),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() {
              _dashTextListItems.add(TextEditingController());
            }),
            child: const Icon(Icons.add_circle_rounded,
                color: AppColors.accent, size: 18),
          ),
        ]),
        const SizedBox(height: 6),
        ...List.generate(
          _dashTextListItems.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(
                  child: SheetField(
                      controller: _dashTextListItems[i],
                      hint: 'Item ${i + 1}',
                      icon: Icons.short_text_rounded)),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _dashTextListItems[i].dispose();
                    _dashTextListItems.removeAt(i);
                  }),
                  child: const Icon(Icons.remove_circle_rounded,
                      color: AppColors.danger, size: 18),
                ),
              ),
            ]),
          ),
        ),
      ],
      if (category == DashboardCategory.userSentiment) ...[
        const SizedBox(height: 10),
        const SheetLabel('Subtitle'),
        const SizedBox(height: 6),
        SheetField(
            controller: _dashSubtitleCtrl,
            hint: 'e.g. User feedback summary',
            icon: Icons.subtitles_rounded),
        const SizedBox(height: 10),
        Row(children: [
          const SheetLabel('Text List Items'),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() {
              _dashTextListItems.add(TextEditingController());
            }),
            child: const Icon(Icons.add_circle_rounded,
                color: AppColors.accent, size: 18),
          ),
        ]),
        const SizedBox(height: 6),
        ...List.generate(
          _dashTextListItems.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(
                  child: SheetField(
                      controller: _dashTextListItems[i],
                      hint: 'Item ${i + 1}',
                      icon: Icons.short_text_rounded)),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _dashTextListItems[i].dispose();
                    _dashTextListItems.removeAt(i);
                  }),
                  child: const Icon(Icons.remove_circle_rounded,
                      color: AppColors.danger, size: 18),
                ),
              ),
            ]),
          ),
        ),
      ],
      if (category == DashboardCategory.coreVitalsRadar) ...[
        const SizedBox(height: 10),
        const SheetLabel('Subtitle'),
        const SizedBox(height: 6),
        SheetField(
            controller: _dashSubtitleCtrl,
            hint: 'e.g. Last 30 days',
            icon: Icons.subtitles_rounded),
      ],
      if (category == DashboardCategory.appStoreStatus) ...[
        const SizedBox(height: 10),
        const SheetLabel('Trailing Text'),
        const SizedBox(height: 6),
        SheetField(
            controller: _dashTrailingTextCtrl,
            hint: 'e.g. v2.1.0 - Released',
            icon: Icons.text_fields_rounded),
      ],
    ];
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  MODELS
// ═══════════════════════════════════════════════════════════════════════════

enum WidgetType {
  kpi,
  chart,
  infoChart,
  leaderBoard;

  String get label => switch (this) {
        WidgetType.kpi => 'KPI',
        WidgetType.chart => 'Chart',
        WidgetType.infoChart => 'Info Chart',
        WidgetType.leaderBoard => 'Leaderboard',
      };

  String get apiKey => switch (this) {
        WidgetType.kpi => 'kpi',
        WidgetType.chart => 'chart',
        WidgetType.infoChart => 'info_chart',
        WidgetType.leaderBoard => 'leader_board',
      };

  IconData get icon => switch (this) {
        WidgetType.kpi => Icons.speed_rounded,
        WidgetType.chart => Icons.bar_chart_rounded,
        WidgetType.infoChart => Icons.donut_large_rounded,
        WidgetType.leaderBoard => Icons.emoji_events_rounded,
      };

  Color get color => switch (this) {
        WidgetType.kpi => const Color(0xFF06D6A0),
        WidgetType.chart => const Color(0xFF118AB2),
        WidgetType.infoChart => const Color(0xFFFFD166),
        WidgetType.leaderBoard => const Color(0xFFEF476F),
      };

  static WidgetType fromKey(String key) => switch (key) {
        'kpi' => WidgetType.kpi,
        'chart' => WidgetType.chart,
        'info_chart' => WidgetType.infoChart,
        'leader_board' => WidgetType.leaderBoard,
        _ => WidgetType.kpi,
      };
}

class DashboardWidget {
  DashboardWidget({
    required this.id,
    required this.type,
    required this.title,
    required this.history,
    required this.data,
    this.colspan,
    this.position = 0,
  });

  final String id;
  final WidgetType type;
  final String title;
  final Map<String, dynamic> history;
  final Map<String, dynamic> data; // full data column, needed for merging
  final int? colspan;
  final int position;

  int get entryCount => history.length;

  String get latestDate {
    if (history.isEmpty) return '—';
    final sorted = history.keys.toList()..sort();
    return sorted.last;
  }

  factory DashboardWidget.fromJson(Map<String, dynamic> json) {
    // ✅ FIX 1: use json['id'] — the widget's own DB uuid.
    // The old code used Supabase.instance.client.auth.currentUser?.id here,
    // which stamped every widget with the same user-auth id. That made it
    // impossible to tell widgets apart, so _openAddEntry could never find the
    // right index, and the Supabase update hit the wrong (or all) rows.
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return DashboardWidget(
      id: json['id']?.toString() ?? '',          // ← widget uuid, not user id
      type: WidgetType.fromKey(json['widget_type'] ?? ''),
      title: json['title'] ?? 'Untitled',
      data: data,                                // ← store full data map
      history: data['history'] as Map<String, dynamic>? ?? {},
      colspan: json['colspan'] as int?,
      position: json['position'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'widget_type': type.apiKey,
        'title': title,
        'data': {'history': history},
        'colspan': colspan,
        'position': position,
      };
}

// ═══════════════════════════════════════════════════════════════════════════
//  COLOUR TOKENS
// ═══════════════════════════════════════════════════════════════════════════

class _C {
  static const bg = Color(0xFF0A0C10);
  static const surface = Color(0xFF13161E);
  static const card = Color(0xFF1A1E2A);
  static const border = Color(0xFF252A38);
  static const accent = Color(0xFFFFD166);
  static const textPrimary = Color(0xFFF0F2FA);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF3D4358);
  static const danger = Color(0xFFEF476F);
  static const success = Color(0xFF06D6A0);
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN ADMIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class WidgetAdminScreen extends StatefulWidget {
  const WidgetAdminScreen({super.key, required this.initialWidgets});
  final List<Map<String, dynamic>> initialWidgets;

  @override
  State<WidgetAdminScreen> createState() => _WidgetAdminScreenState();
}

class _WidgetAdminScreenState extends State<WidgetAdminScreen>
    with SingleTickerProviderStateMixin {
  late List<DashboardWidget> _widgets;
  WidgetType? _filterType;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _widgets = widget.initialWidgets
        .map(DashboardWidget.fromJson)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<DashboardWidget> get _filtered => _filterType == null
      ? _widgets
      : _widgets.where((w) => w.type == _filterType).toList();

  void _openCreate() async {
    final result = await showModalBottomSheet<DashboardWidget>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateWidgetSheet(),
    );
    if (result != null) setState(() => _widgets.add(result));
  }

  void _openAddEntry(DashboardWidget w) async {
    final updated = await showModalBottomSheet<DashboardWidget>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEntrySheet(widget: w),
    );
    if (updated != null) {
      setState(() {
        // Now works correctly — ids are real widget uuids
        final idx = _widgets.indexWhere((x) => x.id == updated.id);
        if (idx != -1) _widgets[idx] = updated;
      });
    }
  }

  void _deleteWidget(String id) {
    setState(() => _widgets.removeWhere((w) => w.id == id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Widget deleted'),
        backgroundColor: _C.card,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
            label: 'Undo', textColor: _C.accent, onPressed: () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildStats(),
            _buildFilterRow(),
            const SizedBox(height: 4),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _WidgetCard(
                        key: ValueKey(filtered[i].id),
                        widget_: filtered[i],
                        index: i,
                        onAddEntry: () => _openAddEntry(filtered[i]),
                        onDelete: () => _deleteWidget(filtered[i].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.only(right: 8, top: 2),
                      decoration: const BoxDecoration(
                          color: _C.success, shape: BoxShape.circle),
                    ),
                    const Text('ADMIN CONSOLE',
                        style: TextStyle(
                            color: _C.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2)),
                  ]),
                  const SizedBox(height: 6),
                  const Text('Widget Manager',
                      style: TextStyle(
                          color: _C.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8)),
                ],
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.tune_rounded,
                  color: _C.textSecondary, size: 22),
            ),
          ],
        ),
      );

  Widget _buildStats() {
    final counts = <WidgetType, int>{};
    for (final w in _widgets) {
      counts[w.type] = (counts[w.type] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _MiniStat(
                label: 'Total',
                value: _widgets.length.toString(),
                color: _C.accent),
            const SizedBox(width: 8),
            ...WidgetType.values.map((t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _MiniStat(
                      label: t.label,
                      value: (counts[t] ?? 0).toString(),
                      color: t.color),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                icon: Icons.apps_rounded,
                selected: _filterType == null,
                color: _C.accent,
                onTap: () => setState(() => _filterType = null),
              ),
              const SizedBox(width: 8),
              ...WidgetType.values.map((t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: t.label,
                      icon: t.icon,
                      selected: _filterType == t,
                      color: t.color,
                      onTap: () => setState(
                          () => _filterType = _filterType == t ? null : t),
                    ),
                  )),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.widgets_outlined, size: 52, color: _C.textMuted),
            const SizedBox(height: 12),
            const Text('No widgets',
                style: TextStyle(color: _C.textSecondary, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Tap + to create one',
                style: TextStyle(color: _C.textMuted, fontSize: 13)),
          ],
        ),
      );

  Widget _buildFab() => FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: _C.accent,
        foregroundColor: _C.bg,
        elevation: 0,
        label: const Text('New Widget',
            style: TextStyle(fontWeight: FontWeight.w700)),
        icon: const Icon(Icons.add_rounded),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
//  WIDGET CARD
// ═══════════════════════════════════════════════════════════════════════════

class _WidgetCard extends StatefulWidget {
  const _WidgetCard({
    super.key,
    required this.widget_,
    required this.index,
    required this.onAddEntry,
    required this.onDelete,
  });
  final DashboardWidget widget_;
  final int index;
  final VoidCallback onAddEntry;
  final VoidCallback onDelete;

  @override
  State<_WidgetCard> createState() => _WidgetCardState();
}

class _WidgetCardState extends State<_WidgetCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    final curved =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween(begin: 30.0, end: 0.0).animate(curved);
    _fade = Tween(begin: 0.0, end: 1.0).animate(curved);
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmtDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month - 1]} ${d.day}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.widget_;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _slide.value),
        child: Opacity(opacity: _fade.value, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: w.type.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(w.type.icon, color: w.type.color, size: 14),
                          const SizedBox(width: 6),
                          Text(w.type.label,
                              style: TextStyle(
                                  color: w.type.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(w.title,
                          style: const TextStyle(
                              color: _C.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                    ),
                    PopupMenuButton<String>(
                      color: const Color(0xFF252A38),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'add',
                          child: Row(children: [
                            Icon(Icons.add_circle_outline_rounded,
                                size: 16, color: _C.accent),
                            SizedBox(width: 10),
                            Text('Add Entry',
                                style: TextStyle(color: _C.textPrimary)),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 16, color: _C.danger),
                            SizedBox(width: 10),
                            Text('Delete',
                                style: TextStyle(color: _C.danger)),
                          ]),
                        ),
                      ],
                      onSelected: (v) {
                        if (v == 'add') widget.onAddEntry();
                        if (v == 'delete') widget.onDelete();
                      },
                      child: const Icon(Icons.more_vert_rounded,
                          color: _C.textSecondary, size: 20),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _C.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    _MetaChip(
                      icon: Icons.history_rounded,
                      label: '${w.entryCount} entries',
                      color: _C.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    _MetaChip(
                      icon: Icons.calendar_today_rounded,
                      label: 'Latest: ${_fmtDate(w.latestDate)}',
                      color: _C.textSecondary,
                    ),
                    if (w.colspan != null) ...[
                      const SizedBox(width: 8),
                      _MetaChip(
                        icon: Icons.grid_view_rounded,
                        label: 'Colspan ${w.colspan}',
                        color: w.type.color,
                      ),
                    ],
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onAddEntry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: w.type.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded,
                                color: w.type.color, size: 14),
                            const SizedBox(width: 4),
                            Text('Add Entry',
                                style: TextStyle(
                                    color: w.type.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (w.history.isNotEmpty) _HistoryPreview(widget_: w),
            ],
          ),
        ),
      ),
    );
  }
}

// ── History preview strip ─────────────────────────────────────────────────

class _HistoryPreview extends StatelessWidget {
  const _HistoryPreview({required this.widget_});
  final DashboardWidget widget_;

  String _summarise(dynamic value) {
    if (value is Map) {
      final m = Map<String, dynamic>.from(value);
      if (m.containsKey('value')) {
        final prefix = m['prefix'] ?? '';
        final trend = m['trend'] == 'up' ? '▲' : '▼';
        return '$prefix${m['value']}  $trend ${m['change'] ?? ''}%';
      }
      if (m.containsKey('values')) {
        return 'Values: ${(m['values'] as List?)?.join(', ') ?? ''}';
      }
      if (m.containsKey('leaders')) {
        final leaders = m['leaders'] as List? ?? [];
        return leaders.take(2).map((l) => '${l['name']} ${l['score']}').join(' · ');
      }
    }
    if (value is List) {
      return value.take(3).map((v) => '${v['name']}: ${v['value']}').join(' · ');
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = widget_.history.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final preview = sorted.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: _C.bg.withOpacity(0.5),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Column(
        children: preview.asMap().entries.map((e) {
          final i = e.key;
          final entry = e.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text(entry.key,
                        style: const TextStyle(
                            color: _C.textSecondary,
                            fontSize: 11,
                            fontFamily: 'monospace')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _summarise(entry.value),
                        style: const TextStyle(
                            color: _C.textPrimary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < preview.length - 1)
                Divider(height: 1, indent: 16, color: _C.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CREATE WIDGET SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _CreateWidgetSheet extends StatefulWidget {
  const _CreateWidgetSheet();

  @override
  State<_CreateWidgetSheet> createState() => _CreateWidgetSheetState();
}

class _CreateWidgetSheetState extends State<_CreateWidgetSheet> {
  WidgetType _type = WidgetType.kpi;
  final _titleCtrl = TextEditingController();
  final _colspanCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _colspanCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final userId =
          Supabase.instance.client.auth.currentUser?.id ?? '';
      final response = await Supabase.instance.client
          .from('widgets_data')
          .insert({
            'user_id': userId,
            'widget_type': _type.apiKey,
            'title': _titleCtrl.text.trim(),
            'data': {'history': {}},
            'colspan': int.tryParse(_colspanCtrl.text),
            'position': 99,
          })
          .select()
          .single();

      final newWidget = DashboardWidget.fromJson(response);
      if (mounted) Navigator.pop(context, newWidget);
    } catch (e) {
      debugPrint('Create widget failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to create: $e'),
          backgroundColor: _C.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'New Widget',
      subtitle: 'Choose type and fill in details',
      icon: Icons.add_box_rounded,
      iconColor: _C.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetLabel('Widget Type'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 3,
            children: WidgetType.values
                .map((t) => _TypeTile(
                      type: t,
                      selected: _type == t,
                      onTap: () => setState(() => _type = t),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          const _SheetLabel('Title'),
          const SizedBox(height: 8),
          _SheetField(
              controller: _titleCtrl,
              hint: 'e.g. Active Users',
              icon: Icons.title_rounded),
          const SizedBox(height: 16),
          const _SheetLabel('Colspan (optional)'),
          const SizedBox(height: 8),
          _SheetField(
              controller: _colspanCtrl,
              hint: '1 or 2',
              icon: Icons.grid_view_rounded,
              keyboardType: TextInputType.number),
          const SizedBox(height: 28),
          _isSaving
              ? const Center(
                  child: CircularProgressIndicator(color: _C.accent))
              : _SheetButton(label: 'Create Widget', onTap: _create),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ADD ENTRY SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _AddEntrySheet extends StatefulWidget {
  const _AddEntrySheet({required this.widget});
  final DashboardWidget widget;

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  // ✅ FIX 3: declared INSIDE the state class, not at file/class level
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

  @override
  void dispose() {
    _dateCtrl.dispose();
    _kpiValueCtrl.dispose();
    _kpiChangeCtrl.dispose();
    _kpiPrefixCtrl.dispose();
    _chartLabelsCtrl.dispose();
    _chartValuesCtrl.dispose();
    for (final c in [
      ..._infoNames, ..._infoValues, ..._lbNames, ..._lbScores
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final date = _dateCtrl.text.trim();
    if (date.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      dynamic entry;
      switch (widget.widget.type) {
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
          )..sort((a, b) =>
              (b['score'] as num).compareTo(a['score'] as num));
          entry = {'leaders': leaders};
      }

      final newHistory =
          Map<String, dynamic>.from(widget.widget.history)..[date] = entry;
      final updatedData = {
        ...Map<String, dynamic>.from(widget.widget.data),
        'history': newHistory,
      };

      // ✅ FIX 2: filter by the widget's own uuid, NOT user_id.
      // Old code: .eq('user_id', userId) → overwrote every widget for this user.
      // New code: .eq('id', widget.widget.id) → updates only this one widget.
      await Supabase.instance.client
          .from('widgets_data')
          .update({
            'data': updatedData,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.widget.id); // ← widget uuid, not user_id

      final updated = DashboardWidget(
        id: widget.widget.id,
        type: widget.widget.type,
        title: widget.widget.title,
        data: updatedData,
        history: newHistory,
        colspan: widget.widget.colspan,
        position: widget.widget.position,
      );

      if (mounted) Navigator.pop(context, updated);
    } catch (e, st) {
      debugPrint('Save entry failed: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: _C.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.widget;
    return _Sheet(
      title: 'Add Entry',
      subtitle: w.title,
      icon: w.type.icon,
      iconColor: w.type.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetLabel('Date'),
          const SizedBox(height: 8),
          _SheetField(
              controller: _dateCtrl,
              hint: 'YYYY-MM-DD',
              icon: Icons.calendar_today_rounded),
          const SizedBox(height: 20),
          ..._buildTypeFields(w.type),
          const SizedBox(height: 28),
          _isSaving
              ? const Center(
                  child: CircularProgressIndicator(color: _C.accent))
              : _SheetButton(
                  label: 'Save Entry',
                  color: w.type.color,
                  onTap: _save),
        ],
      ),
    );
  }

  List<Widget> _buildTypeFields(WidgetType type) {
    switch (type) {
      case WidgetType.kpi:
        return [
          const _SheetLabel('Value'),
          const SizedBox(height: 8),
          _SheetField(
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
                  const _SheetLabel('Change %'),
                  const SizedBox(height: 8),
                  _SheetField(
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
                  const _SheetLabel('Prefix (opt.)'),
                  const SizedBox(height: 8),
                  _SheetField(
                      controller: _kpiPrefixCtrl,
                      hint: r'e.g. $',
                      icon: Icons.attach_money_rounded),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          const _SheetLabel('Trend'),
          const SizedBox(height: 8),
          Row(children: [
            _TrendButton(
                label: '▲ Up',
                selected: _kpiTrendUp,
                color: _C.success,
                onTap: () => setState(() => _kpiTrendUp = true)),
            const SizedBox(width: 10),
            _TrendButton(
                label: '▼ Down',
                selected: !_kpiTrendUp,
                color: _C.danger,
                onTap: () => setState(() => _kpiTrendUp = false)),
          ]),
        ];

      case WidgetType.chart:
        return [
          const _SheetLabel('Labels (comma-separated)'),
          const SizedBox(height: 8),
          _SheetField(
              controller: _chartLabelsCtrl,
              hint: 'Mon,Tue,Wed...',
              icon: Icons.label_rounded),
          const SizedBox(height: 16),
          const _SheetLabel('Values (comma-separated)'),
          const SizedBox(height: 8),
          _SheetField(
              controller: _chartValuesCtrl,
              hint: '90,160,120...',
              icon: Icons.show_chart_rounded,
              keyboardType: TextInputType.text),
        ];

      case WidgetType.infoChart:
        return [
          Row(children: [
            const _SheetLabel('Segments'),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _infoNames.add(TextEditingController());
                _infoValues.add(TextEditingController());
              }),
              child: const Icon(Icons.add_circle_rounded,
                  color: _C.accent, size: 20),
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
                    child: _SheetField(
                        controller: _infoNames[i],
                        hint: 'Name',
                        icon: Icons.label_outline_rounded)),
                const SizedBox(width: 8),
                Expanded(
                    flex: 2,
                    child: _SheetField(
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
                          color: _C.danger, size: 20),
                    ),
                  ),
              ]),
            ),
          ),
        ];

      case WidgetType.leaderBoard:
        return [
          Row(children: [
            const _SheetLabel('Leaders'),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _lbNames.add(TextEditingController());
                _lbScores.add(TextEditingController());
              }),
              child: const Icon(Icons.add_circle_rounded,
                  color: _C.accent, size: 20),
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
                          color: _C.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Expanded(
                    flex: 3,
                    child: _SheetField(
                        controller: _lbNames[i],
                        hint: 'Player name',
                        icon: Icons.person_outline_rounded)),
                const SizedBox(width: 8),
                Expanded(
                    flex: 2,
                    child: _SheetField(
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
                          color: _C.danger, size: 20),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Leaders are auto-sorted by score on save.',
              style: TextStyle(color: _C.textSecondary, fontSize: 11)),
        ];
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED SHEET SHELL
// ═══════════════════════════════════════════════════════════════════════════

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.child,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: _C.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: _C.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: _C.textSecondary, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded,
                      color: _C.textSecondary, size: 22),
                ),
              ],
            ),
          ),
          Divider(height: 24, color: _C.border.withOpacity(0.6)),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20,
                  MediaQuery.of(context).viewInsets.bottom + 24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  REUSABLE SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: _C.textSecondary, fontSize: 11)),
          ],
        ),
      );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : _C.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? color.withOpacity(0.5) : _C.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected ? color : _C.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: selected ? color : _C.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      );
}

class _TypeTile extends StatelessWidget {
  const _TypeTile(
      {required this.type, required this.selected, required this.onTap});
  final WidgetType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? type.color.withOpacity(0.15) : _C.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? type.color : _C.border,
                width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(type.icon,
                  color: selected ? type.color : _C.textSecondary,
                  size: 16),
              const SizedBox(width: 8),
              Text(type.label,
                  style: TextStyle(
                      color: selected ? type.color : _C.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: _C.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      );
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: _C.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: _C.textMuted, fontSize: 14),
          prefixIcon: Icon(icon, color: _C.textSecondary, size: 18),
          filled: true,
          fillColor: _C.card,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: _C.accent, width: 1.5)),
        ),
      );
}

class _SheetButton extends StatelessWidget {
  const _SheetButton(
      {required this.label, required this.onTap, this.color = _C.accent});
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: _C.bg,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      );
}

class _TrendButton extends StatelessWidget {
  const _TrendButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.15) : _C.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? color : _C.border,
                  width: selected ? 1.5 : 1),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: selected ? color : _C.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
        ),
      );
}


// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// // ═══════════════════════════════════════════════════════════════════════════
// //  MODELS
// // ═══════════════════════════════════════════════════════════════════════════

// enum WidgetType {
//   kpi,
//   chart,
//   infoChart,
//   leaderBoard,
//   // ── ADDED EXECUTIVE SCHEMAS TO UNIFIED ENGINE ──
//   appStoreStatus,
//   userSentiment,
//   coreVitalsRadar,
//   pipelineProgress,
//   versionMilestones;

//   String get label => switch (this) {
//         WidgetType.kpi => 'KPI',
//         WidgetType.chart => 'Chart',
//         WidgetType.infoChart => 'Info Chart',
//         WidgetType.leaderBoard => 'Leaderboard',
//         WidgetType.appStoreStatus => 'App Store Status',
//         WidgetType.userSentiment => 'User Sentiment',
//         WidgetType.coreVitalsRadar => 'Core Vitals Radar',
//         WidgetType.pipelineProgress => 'Pipeline Progress',
//         WidgetType.versionMilestones => 'Version Milestones',
//       };

//   String get apiKey => switch (this) {
//         WidgetType.kpi => 'kpi',
//         WidgetType.chart => 'chart',
//         WidgetType.infoChart => 'info_chart',
//         WidgetType.leaderBoard => 'leader_board',
//         WidgetType.appStoreStatus => 'app_store_status',
//         WidgetType.userSentiment => 'user_sentiment',
//         WidgetType.coreVitalsRadar => 'core_vitals_radar',
//         WidgetType.pipelineProgress => 'pipeline_progress',
//         WidgetType.versionMilestones => 'version_milestones',
//       };

//   IconData get icon => switch (this) {
//         WidgetType.kpi => Icons.speed_rounded,
//         WidgetType.chart => Icons.bar_chart_rounded,
//         WidgetType.infoChart => Icons.donut_large_rounded,
//         WidgetType.leaderBoard => Icons.emoji_events_rounded,
//         WidgetType.appStoreStatus => Icons.apps_outage_rounded,
//         WidgetType.userSentiment => Icons.mood_rounded,
//         WidgetType.coreVitalsRadar => Icons.radar_rounded,
//         WidgetType.pipelineProgress => Icons.trending_up_rounded,
//         WidgetType.versionMilestones => Icons.flag_rounded,
//       };

//   Color get color => switch (this) {
//         WidgetType.kpi => const Color(0xFF06D6A0),
//         WidgetType.chart => const Color(0xFF118AB2),
//         WidgetType.infoChart => const Color(0xFFFFD166),
//         WidgetType.leaderBoard => const Color(0xFFEF476F),
//         WidgetType.appStoreStatus => const Color(0xFF06D6A0),
//         WidgetType.userSentiment => const Color(0xFF118AB2),
//         WidgetType.coreVitalsRadar => const Color(0xFFFFD166),
//         WidgetType.pipelineProgress => const Color(0xFF6366F1),
//         WidgetType.versionMilestones => const Color(0xFFEF476F),
//       };

//   bool get isOperationalLayout => 
//       this == WidgetType.appStoreStatus ||
//       this == WidgetType.userSentiment ||
//       this == WidgetType.coreVitalsRadar ||
//       this == WidgetType.pipelineProgress ||
//       this == WidgetType.versionMilestones;

//   static WidgetType fromKey(String key) => switch (key) {
//         'kpi' => WidgetType.kpi,
//         'chart' => WidgetType.chart,
//         'info_chart' => WidgetType.infoChart,
//         'leader_board' => WidgetType.leaderBoard,
//         'app_store_status' => WidgetType.appStoreStatus,
//         'user_sentiment' => WidgetType.userSentiment,
//         'core_vitals_radar' => WidgetType.coreVitalsRadar,
//         'pipeline_progress' => WidgetType.pipelineProgress,
//         'version_milestones' => WidgetType.versionMilestones,
//         _ => WidgetType.kpi,
//       };
// }

// class DashboardWidget {
//   DashboardWidget({
//     required this.id,
//     required this.type,
//     required this.title,
//     required this.history,
//     required this.data,
//     this.colspan,
//     this.position = 0,
//   });

//   final String id;
//   final WidgetType type;
//   final String title;
//   final Map<String, dynamic> history;
//   final Map<String, dynamic> data; 
//   final int? colspan;
//   final int position;

//   int get entryCount => history.length;

//   String get latestDate {
//     if (history.isEmpty) return '—';
//     final sorted = history.keys.toList()..sort();
//     return sorted.last;
//   }

//   factory DashboardWidget.fromJson(Map<String, dynamic> json) {
//     final data = json['data'] as Map<String, dynamic>? ?? {};
//     return DashboardWidget(
//       id: json['id']?.toString() ?? '',          
//       type: WidgetType.fromKey(json['category'] ?? json['widget_type'] ?? ''),
//       title: json['title'] ?? 'Untitled',
//       data: data,                                
//       history: data['history'] as Map<String, dynamic>? ?? {},
//       colspan: json['colspan'] as int?,
//       position: json['position'] as int? ?? 0,
//     );
//   }

//   Map<String, dynamic> toJson() => {
//         'id': id,
//         'widget_type': type.apiKey,
//         'category': type.apiKey,
//         'title': title,
//         'data': {'history': history},
//         'colspan': colspan,
//         'position': position,
//       };
// }

// // ═══════════════════════════════════════════════════════════════════════════
// //  COLOUR TOKENS
// // ═══════════════════════════════════════════════════════════════════════════

// class _C {
//   static const bg = Color(0xFF0A0C10);
//   static const surface = Color(0xFF13161E);
//   static const card = Color(0xFF1A1E2A);
//   static const border = Color(0xFF252A38);
//   static const accent = Color(0xFFFFD166);
//   static const textPrimary = Color(0xFFF0F2FA);
//   static const textSecondary = Color(0xFF6B7280);
//   static const textMuted = Color(0xFF3D4358);
//   static const danger = Color(0xFFEF476F);
//   static const success = Color(0xFF06D6A0);
// }

// // ═══════════════════════════════════════════════════════════════════════════
// //  MAIN ADMIN SCREEN
// // ═══════════════════════════════════════════════════════════════════════════

// class WidgetAdminScreen extends StatefulWidget {
//   const WidgetAdminScreen({super.key, required this.initialWidgets});
//   final List<Map<String, dynamic>> initialWidgets;

//   @override
//   State<WidgetAdminScreen> createState() => _WidgetAdminScreenState();
// }

// class _WidgetAdminScreenState extends State<WidgetAdminScreen>
//     with SingleTickerProviderStateMixin {
//   late List<DashboardWidget> _widgets;
//   WidgetType? _filterType;
//   late AnimationController _ctrl;

//   @override
//   void initState() {
//     super.initState();
//     _widgets = widget.initialWidgets
//         .map(DashboardWidget.fromJson)
//         .toList()
//       ..sort((a, b) => a.position.compareTo(b.position));
//     _ctrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 500))
//       ..forward();
//   }

//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }

//   List<DashboardWidget> get _filtered => _filterType == null
//       ? _widgets
//       : _widgets.where((w) => w.type == _filterType).toList();

//   void _openCreate() async {
//     final result = await showModalBottomSheet<DashboardWidget>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => const _CreateWidgetSheet(),
//     );
//     if (result != null) setState(() => _widgets.add(result));
//   }

//   void _openAddEntry(DashboardWidget w) async {
//     final updated = await showModalBottomSheet<DashboardWidget>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => _AddEntrySheet(widget: w),
//     );
//     if (updated != null) {
//       setState(() {
//         final idx = _widgets.indexWhere((x) => x.id == updated.id);
//         if (idx != -1) _widgets[idx] = updated;
//       });
//     }
//   }

//   void _deleteWidget(String id) {
//     setState(() => _widgets.removeWhere((w) => w.id == id));
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: const Text('Widget deleted'),
//         backgroundColor: _C.card,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final filtered = _filtered;
//     return Scaffold(
//       backgroundColor: _C.bg,
//       body: SafeArea(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildHeader(),
//             _buildStats(),
//             _buildFilterRow(),
//             const SizedBox(height: 4),
//             Expanded(
//               child: filtered.isEmpty
//                   ? _buildEmpty()
//                   : ListView.builder(
//                       padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
//                       itemCount: filtered.length,
//                       itemBuilder: (ctx, i) => _WidgetCard(
//                         key: ValueKey(filtered[i].id),
//                         widget_: filtered[i],
//                         index: i,
//                         onAddEntry: () => _openAddEntry(filtered[i]),
//                         onDelete: () => _deleteWidget(filtered[i].id),
//                       ),
//                     ),
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: _buildFab(),
//     );
//   }

//   Widget _buildHeader() => Padding(
//         padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(children: [
//               Container(
//                 width: 6, height: 6,
//                 margin: const EdgeInsets.only(right: 8, top: 2),
//                 decoration: const BoxDecoration(
//                     color: _C.success, shape: BoxShape.circle),
//               ),
//               const Text('ADMIN CONSOLE',
//                   style: TextStyle(
//                       color: _C.textSecondary,
//                       fontSize: 10,
//                       fontWeight: FontWeight.w700,
//                       letterSpacing: 2)),
//             ]),
//             const SizedBox(height: 6),
//             const Text('Widget Manager',
//                 style: TextStyle(
//                     color: _C.textPrimary,
//                     fontSize: 26,
//                     fontWeight: FontWeight.w800,
//                     letterSpacing: -0.8)),
//           ],
//         ),
//       );

//   Widget _buildStats() {
//     final counts = <WidgetType, int>{};
//     for (final w in _widgets) {
//       counts[w.type] = (counts[w.type] ?? 0) + 1;
//     }
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: Row(
//           children: [
//             _MiniStat(
//                 label: 'Total',
//                 value: _widgets.length.toString(),
//                 color: _C.accent),
//             const SizedBox(width: 8),
//             ...WidgetType.values.map((t) => Padding(
//                   padding: const EdgeInsets.only(right: 8),
//                   child: _MiniStat(
//                       label: t.label,
//                       value: (counts[t] ?? 0).toString(),
//                       color: t.color),
//                 )),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildFilterRow() => Padding(
//         padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
//         child: SingleChildScrollView(
//           scrollDirection: Axis.horizontal,
//           child: Row(
//             children: [
//               _FilterChip(
//                 label: 'All',
//                 icon: Icons.apps_rounded,
//                 selected: _filterType == null,
//                 color: _C.accent,
//                 onTap: () => setState(() => _filterType = null),
//               ),
//               const SizedBox(width: 8),
//               ...WidgetType.values.map((t) => Padding(
//                     padding: const EdgeInsets.only(right: 8),
//                     child: _FilterChip(
//                       label: t.label,
//                       icon: t.icon,
//                       selected: _filterType == t,
//                       color: t.color,
//                       onTap: () => setState(
//                           () => _filterType = _filterType == t ? null : t),
//                     ),
//                   )),
//             ],
//           ),
//         ),
//       );

//   Widget _buildEmpty() => Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.widgets_outlined, size: 52, color: _C.textMuted),
//             const SizedBox(height: 12),
//             const Text('No widgets found',
//                 style: TextStyle(color: _C.textSecondary, fontSize: 16)),
//           ],
//         ),
//       );

//   Widget _buildFab() => FloatingActionButton.extended(
//         onPressed: _openCreate,
//         backgroundColor: _C.accent,
//         foregroundColor: _C.bg,
//         elevation: 0,
//         label: const Text('New Widget',
//             style: TextStyle(fontWeight: FontWeight.w700)),
//         icon: const Icon(Icons.add_rounded),
//       );
// }

// // ═══════════════════════════════════════════════════════════════════════════
// //  WIDGET CARD LAYOUT
// // ═══════════════════════════════════════════════════════════════════════════

// class _WidgetCard extends StatefulWidget {
//   const _WidgetCard({
//     super.key,
//     required this.widget_,
//     required this.index,
//     required this.onAddEntry,
//     required this.onDelete,
//   });
//   final DashboardWidget widget_;
//   final int index;
//   final VoidCallback onAddEntry;
//   final VoidCallback onDelete;

//   @override
//   State<_WidgetCard> createState() => _WidgetCardState();
// }

// class _WidgetCardState extends State<_WidgetCard>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _ctrl;
//   late Animation<double> _slide;
//   late Animation<double> _fade;

//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 400));
//     final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
//     _slide = Tween(begin: 30.0, end: 0.0).animate(curved);
//     _fade = Tween(begin: 0.0, end: 1.0).animate(curved);
//     Future.delayed(Duration(milliseconds: widget.index * 60), () {
//       if (mounted) _ctrl.forward();
//     });
//   }

//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }

//   String _fmtDate(String raw) {
//     try {
//       final d = DateTime.parse(raw);
//       const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
//       return '${m[d.month - 1]} ${d.day}';
//     } catch (_) {
//       return raw;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final w = widget.widget_;
//     return AnimatedBuilder(
//       animation: _ctrl,
//       builder: (_, child) => Transform.translate(
//         offset: Offset(0, _slide.value),
//         child: Opacity(opacity: _fade.value, child: child),
//       ),
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 12),
//         decoration: BoxDecoration(
//           color: _C.card,
//           borderRadius: BorderRadius.circular(18),
//           border: Border.all(color: _C.border),
//         ),
//         child: Column(
//           children: [
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
//               child: Row(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                     decoration: BoxDecoration(
//                       color: w.type.color.withOpacity(0.12),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(w.type.icon, color: w.type.color, size: 14),
//                         const SizedBox(width: 6),
//                         Text(w.type.label,
//                             style: TextStyle(
//                                 color: w.type.color,
//                                 fontSize: 11,
//                                 fontWeight: FontWeight.w700)),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: Text(w.title,
//                         style: const TextStyle(
//                             color: _C.textPrimary,
//                             fontSize: 15,
//                             fontWeight: FontWeight.w700),
//                         overflow: TextOverflow.ellipsis),
//                   ),
//                   PopupMenuButton<String>(
//                     color: const Color(0xFF252A38),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                     itemBuilder: (_) => [
//                       const PopupMenuItem(
//                         value: 'add',
//                         child: Row(children: [
//                           Icon(Icons.add_circle_outline_rounded, size: 16, color: _C.accent),
//                           SizedBox(width: 10),
//                           Text('Add Entry', style: TextStyle(color: _C.textPrimary)),
//                         ]),
//                       ),
//                       const PopupMenuItem(
//                         value: 'delete',
//                         child: Row(children: [
//                           Icon(Icons.delete_outline_rounded, size: 16, color: _C.danger),
//                           SizedBox(width: 10),
//                           Text('Delete', style: TextStyle(color: _C.danger)),
//                         ]),
//                       ),
//                     ],
//                     onSelected: (v) {
//                       if (v == 'add') widget.onAddEntry();
//                       if (v == 'delete') widget.onDelete();
//                     },
//                     child: const Icon(Icons.more_vert_rounded, color: _C.textSecondary, size: 20),
//                   ),
//                 ],
//               ),
//             ),
//             Divider(height: 1, color: _C.border),
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
//               child: Row(
//                 children: [
//                   _MetaChip(icon: Icons.history_rounded, label: '${w.entryCount} entries', color: _C.textSecondary),
//                   const SizedBox(width: 8),
//                   _MetaChip(icon: Icons.calendar_today_rounded, label: 'Latest: ${_fmtDate(w.latestDate)}', color: _C.textSecondary),
//                   const Spacer(),
//                   GestureDetector(
//                     onTap: widget.onAddEntry,
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                       decoration: BoxDecoration(
//                         color: w.type.color.withOpacity(0.12),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(Icons.add_rounded, color: w.type.color, size: 14),
//                           const SizedBox(width: 4),
//                           Text('Add Entry', style: TextStyle(color: w.type.color, fontSize: 12, fontWeight: FontWeight.w600)),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             if (w.history.isNotEmpty) _HistoryPreview(widget_: w),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ── HISTORY PREVIEW STRIP ──────────────────────────────────────────────────

// class _HistoryPreview extends StatelessWidget {
//   const _HistoryPreview({required this.widget_});
//   final DashboardWidget widget_;

//   String _summarise(dynamic value) {
//     if (value is Map) {
//       final m = Map<String, dynamic>.from(value);
//       if (m.containsKey('metrics')) {
//         final metricsList = m['metrics'] as List?;
//         return metricsList?.map((item) => "${item['title']}: ${item['value']}").join(' · ') ?? '';
//       }
//       if (m.containsKey('value')) {
//         final prefix = m['prefix'] ?? '';
//         final trend = m['trend'] == 'up' ? '▲' : '▼';
//         return '$prefix${m['value']}  $trend ${m['change'] ?? ''}%';
//       }
//       if (m.containsKey('values')) return 'Values: ${(m['values'] as List?)?.join(', ') ?? ''}';
//       if (m.containsKey('leaders')) {
//         final leaders = m['leaders'] as List? ?? [];
//         return leaders.take(2).map((l) => '${l['name']} ${l['score']}').join(' · ');
//       }
//     }
//     return value.toString();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final sorted = widget_.history.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
//     final preview = sorted.take(3).toList();

//     return Container(
//       decoration: BoxDecoration(
//         color: _C.bg.withOpacity(0.5),
//         borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
//       ),
//       child: Column(
//         children: preview.asMap().entries.map((e) {
//           final i = e.key;
//           final entry = e.value;
//           return Column(
//             children: [
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                 child: Row(
//                   children: [
//                     Text(entry.key, style: const TextStyle(color: _C.textSecondary, fontSize: 11, fontFamily: 'monospace')),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Text(
//                         _summarise(entry.value),
//                         style: const TextStyle(color: _C.textPrimary, fontSize: 12),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               if (i < preview.length - 1) Divider(height: 1, indent: 16, color: _C.border),
//             ],
//           );
//         }).toList(),
//       ),
//     );
//   }
// }

// // ═══════════════════════════════════════════════════════════════════════════
// //  CREATE NEW WIDGET SHEET
// // ═══════════════════════════════════════════════════════════════════════════

// class _CreateWidgetSheet extends StatefulWidget {
//   const _CreateWidgetSheet();

//   @override
//   State<_CreateWidgetSheet> createState() => _CreateWidgetSheetState();
// }

// class _CreateWidgetSheetState extends State<_CreateWidgetSheet> {
//   WidgetType _type = WidgetType.kpi;
//   final _titleCtrl = TextEditingController();
//   final _colspanCtrl = TextEditingController();
//   bool _isSaving = false;

//   @override
//   void dispose() {
//     _titleCtrl.dispose();
//     _colspanCtrl.dispose();
//     super.dispose();
//   }

//   Future<void> _create() async {
//     if (_titleCtrl.text.trim().isEmpty) return;
//     setState(() => _isSaving = true);
//     try {
//       final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      
//       // Auto-assign positions cleanly based on max current value
//       final maxPositionResponse = await Supabase.instance.client
//           .from('widgets_data')
//           .select('position')
//           .order('position', ascending: false)
//           .limit(1)
//           .maybeSingle();

//       int currentMaxPosition = maxPositionResponse != null ? (maxPositionResponse['position'] as int) : 0;

//       final response = await Supabase.instance.client
//           .from('widgets_data')
//           .insert({
//             'user_id': userId,
//             'widget_type': _type.apiKey,
//             'category': _type.apiKey,
//             'title': _titleCtrl.text.trim(),
//             'is_dash_widget': _type.isOperationalLayout ? true : false,
//             'data': {'history': {}},
//             'colspan': int.tryParse(_colspanCtrl.text) ?? 1,
//             'position': currentMaxPosition + 1,
//           })
//           .select()
//           .single();

//       final newWidget = DashboardWidget.fromJson(response);
//       if (mounted) Navigator.pop(context, newWidget);
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create: $e'), backgroundColor: _C.danger));
//       }
//     } finally {
//       if (mounted) setState(() => _isSaving = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return _Sheet(
//       title: 'New Widget Template',
//       subtitle: 'Select configuration type blueprint',
//       icon: Icons.add_box_rounded,
//       iconColor: _C.accent,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const _SheetLabel('Config Engine Archetype'),
//           const SizedBox(height: 10),
//           SizedBox(
//             height: 220,
//             child: GridView.count(
//               crossAxisCount: 2,
//               crossAxisSpacing: 8,
//               mainAxisSpacing: 8,
//               childAspectRatio: 2.8,
//               children: WidgetType.values
//                   .map((t) => _TypeTile(
//                         type: t,
//                         selected: _type == t,
//                         onTap: () => setState(() => _type = t),
//                       ))
//                   .toList(),
//             ),
//           ),
//           const SizedBox(height: 16),
//           const _SheetLabel('Title'),
//           const SizedBox(height: 8),
//           _SheetField(controller: _titleCtrl, hint: 'e.g. Core System Performance', icon: Icons.title_rounded),
//           const SizedBox(height: 16),
//           _isSaving ? const Center(child: CircularProgressIndicator(color: _C.accent)) : _SheetButton(label: 'Build Widget Row', onTap: _create),
//         ],
//       ),
//     );
//   }
// }

// // ═══════════════════════════════════════════════════════════════════════════
// //  ADD HISTORICAL ENTRY SHEET (INTEGRATED PAYLOAD MODIFIER)
// // ═══════════════════════════════════════════════════════════════════════════

// class _AddEntrySheet extends StatefulWidget {
//   const _AddEntrySheet({required this.widget});
//   final DashboardWidget widget;

//   @override
//   State<_AddEntrySheet> createState() => _AddEntrySheetState();
// }

// class _AddEntrySheetState extends State<_AddEntrySheet> {
//   bool _isSaving = false;
//   final _dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));

//   // Legacy Fields
//   final _kpiValueCtrl = TextEditingController();
//   final _kpiChangeCtrl = TextEditingController();
//   final _kpiPrefixCtrl = TextEditingController();
//   bool _kpiTrendUp = true;
//   final _chartLabelsCtrl = TextEditingController(text: 'Mon,Tue,Wed,Thu,Fri,Sat,Sun');
//   final _chartValuesCtrl = TextEditingController();

//   // Integrated Operational Sub-fields (Metrics & Lists arrays)
//   final _trailingTextCtrl = TextEditingController();
//   final _subtitleCtrl = TextEditingController();
//   final _progressCtrl = TextEditingController();
//   final List<TextEditingController> _metricTitles = [TextEditingController(), TextEditingController()];
//   final List<TextEditingController> _metricValues = [TextEditingController(), TextEditingController()];
//   final List<TextEditingController> _textItems = [TextEditingController(), TextEditingController()];

//   @override
//   void dispose() {
//     _dateCtrl.dispose(); _kpiValueCtrl.dispose(); _kpiChangeCtrl.dispose(); _kpiPrefixCtrl.dispose();
//     _chartLabelsCtrl.dispose(); _chartValuesCtrl.dispose(); _trailingTextCtrl.dispose(); _subtitleCtrl.dispose(); _progressCtrl.dispose();
//     for (var c in [..._metricTitles, ..._metricValues, ..._textItems]) { c.dispose(); }
//     super.dispose();
//   }

//   Future<void> _save() async {
//     final date = _dateCtrl.text.trim();
//     if (date.isEmpty) return;
//     setState(() => _isSaving = true);

//     try {
//       dynamic entry;

//       if (widget.widget.type.isOperationalLayout) {
//         // Build the modern operational array configurations
//         final List<Map<String, String>> metrics = [];
//         for (int i = 0; i < _metricTitles.length; i++) {
//           if (_metricTitles[i].text.isNotEmpty) {
//             metrics.add({
//               'title': _metricTitles[i].text.trim(),
//               'value': _metricValues[i].text.trim(),
//             });
//           }
//         }
//         final listItems = _textItems.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

//         entry = {
//           if (_subtitleCtrl.text.isNotEmpty) 'subtitle': _subtitleCtrl.text.trim(),
//           if (_trailingTextCtrl.text.isNotEmpty) 'trailing_text': _trailingTextCtrl.text.trim(),
//           if (_progressCtrl.text.isNotEmpty) 'global_progress': double.tryParse(_progressCtrl.text),
//           'metrics': metrics,
//           'text_list_items': listItems,
//         };
//       } else {
//         // Fall back gracefully to legacy formatting rules
//         switch (widget.widget.type) {
//           case WidgetType.kpi:
//             entry = {
//               'trend': _kpiTrendUp ? 'up' : 'down',
//               'value': num.tryParse(_kpiValueCtrl.text.trim()) ?? 0,
//               'change': num.tryParse(_kpiChangeCtrl.text.trim()) ?? 0,
//               if (_kpiPrefixCtrl.text.trim().isNotEmpty) 'prefix': _kpiPrefixCtrl.text.trim(),
//             };
//             break;
//           case WidgetType.chart:
//             entry = {
//               'labels': _chartLabelsCtrl.text.split(',').map((s) => s.trim()).toList(),
//               'values': _chartValuesCtrl.text.split(',').map((s) => num.tryParse(s.trim()) ?? 0).toList(),
//             };
//             break;
//           default:
//             entry = {'value': _kpiValueCtrl.text.trim()};
//         }
//       }

//       final newHistory = Map<String, dynamic>.from(widget.widget.history)..[date] = entry;
      
//       // Keep root variables in data synchronized for easier frontend parsing checks
//       final Map<String, dynamic> updatedData = {
//         ...Map<String, dynamic>.from(widget.widget.data),
//         'history': newHistory,
//         if (widget.widget.type.isOperationalLayout) ...entry,
//       };

//       await Supabase.instance.client
//           .from('widgets_data')
//           .update({
//             'data': updatedData, 
//             'updated_at': DateTime.now().toIso8601String()
//           })
//           .eq('id', widget.widget.id);

//       final updated = DashboardWidget(
//         id: widget.widget.id,
//         type: widget.widget.type,
//         title: widget.widget.title,
//         data: updatedData,
//         history: newHistory,
//         colspan: widget.widget.colspan,
//         position: widget.widget.position,
//       );

//       if (mounted) Navigator.pop(context, updated);
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to commit parameters: $e'), backgroundColor: _C.danger));
//       }
//     } finally {
//       if (mounted) setState(() => _isSaving = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final w = widget.widget;
//     return _Sheet(
//       title: 'Append Data Metrics',
//       subtitle: w.title,
//       icon: w.type.icon,
//       iconColor: w.type.color,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const _SheetLabel('Log Entry Date'),
//           const SizedBox(height: 8),
//           _SheetField(controller: _dateCtrl, hint: 'YYYY-MM-DD', icon: Icons.calendar_today_rounded),
//           const SizedBox(height: 16),
//           ..._buildDynamicFormFields(w.type),
//           const SizedBox(height: 24),
//           _isSaving 
//               ? const Center(child: CircularProgressIndicator(color: _C.accent)) 
//               : _SheetButton(label: 'Save Dynamic Entry', color: w.type.color, onTap: _save),
//         ],
//       ),
//     );
//   }

//   List<Widget> _buildDynamicFormFields(WidgetType type) {
//     if (type.isOperationalLayout) {
//       return [
//         if (type == WidgetType.appStoreStatus) ...[
//           const _SheetLabel('Trailing Action Alert Label'),
//           const SizedBox(height: 6),
//           _SheetField(controller: _trailingTextCtrl, hint: 'e.g. Active Now', icon: Icons.label_important_rounded),
//           const SizedBox(height: 12),
//         ],
//         if (type == WidgetType.coreVitalsRadar) ...[
//           const _SheetLabel('Subheading Context Info'),
//           const SizedBox(height: 6),
//           _SheetField(controller: _subtitleCtrl, hint: 'e.g. High level performance indicators', icon: Icons.subtitles_rounded),
//           const SizedBox(height: 12),
//         ],
//         if (type == WidgetType.pipelineProgress) ...[
//           const _SheetLabel('Progress Float Percentage (0.0 to 1.0)'),
//           const SizedBox(height: 6),
//           _SheetField(controller: _progressCtrl, hint: 'e.g. 0.75', icon: Icons.hourglass_top_rounded),
//           const SizedBox(height: 12),
//         ],
//         const _SheetLabel('Data Pairs (Row Metrics)'),
//         const SizedBox(height: 6),
//         Row(children: [
//           Expanded(child: _SheetField(controller: _metricTitles[0], hint: 'Label 1 (e.g. iOS)', icon: Icons.tag)),
//           const SizedBox(width: 8),
//           Expanded(child: _SheetField(controller: _metricValues[0], hint: 'Value 1 (e.g. Live)', icon: Icons.assessment)),
//         ]),
//         const SizedBox(height: 8),
//         Row(children: [
//           Expanded(child: _SheetField(controller: _metricTitles[1], hint: 'Label 2', icon: Icons.tag)),
//           const SizedBox(width: 8),
//           Expanded(child: _SheetField(controller: _metricValues[1], hint: 'Value 2', icon: Icons.assessment)),
//         ]),
//         const SizedBox(height: 12),
//         const _SheetLabel('Text Bullet Lists (Optional Log Rows)'),
//         const SizedBox(height: 6),
//         _SheetField(controller: _textItems[0], hint: 'Roadmap/Feedback description line 1', icon: Icons.list_alt_rounded),
//         const SizedBox(height: 8),
//         _SheetField(controller: _textItems[1], hint: 'Roadmap/Feedback description line 2', icon: Icons.list_alt_rounded),
//       ];
//     }

//     // Default Legacy Layout Forms Fallback
//     if (type == WidgetType.kpi) {
//       return [
//         const _SheetLabel('Core Static Value Number'),
//         const SizedBox(height: 6),
//         _SheetField(controller: _kpiValueCtrl, hint: 'e.g. 4.9', icon: Icons.pin),
//       ];
//     }
//     return [
//       const _SheetLabel('Comma-Separated Grid Values'),
//       const SizedBox(height: 6),
//       _SheetField(controller: _chartValuesCtrl, hint: '10, 20, 30, 40', icon: Icons.multiline_chart),
//     ];
//   }
// }

// // ═══════════════════════════════════════════════════════════════════════════
// //  REUSABLE CORE UI COMPONENTS (SHALLOW WRAPPERS)
// // ═══════════════════════════════════════════════════════════════════════════

// class _Sheet extends StatelessWidget {
//   const _Sheet({required this.title, required this.subtitle, required this.icon, required this.iconColor, required this.child});
//   final String title, subtitle; final IconData icon; final Color iconColor; final Widget child;
//   @override
//   Widget build(BuildContext context) => Container(
//         padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
//         decoration: const BoxDecoration(color: _C.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
//         child: SingleChildScrollView(
//           child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
//             Row(children: [
//               Icon(icon, color: iconColor, size: 22),
//               const SizedBox(width: 10),
//               Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                 Text(title, style: const TextStyle(color: _C.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
//                 Text(subtitle, style: const TextStyle(color: _C.textSecondary, fontSize: 12)),
//               ])
//             ]),
//             const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: _C.border)),
//             child
//           ]),
//         ),
//       );
// }

// class _SheetLabel extends StatelessWidget {
//   const _SheetLabel(this.text); final String text;
//   @override
//   Widget build(BuildContext context) => Text(text, style: const TextStyle(color: _C.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5));
// }

// class _SheetField extends StatelessWidget {
//   const _SheetField({required this.controller, required this.hint, required this.icon, this.keyboardType});
//   final TextEditingController controller; final String hint; final IconData icon; final TextInputType? keyboardType;
//   @override
//   Widget build(BuildContext context) => TextField(
//         controller: controller, keyboardType: keyboardType,
//         style: const TextStyle(color: _C.textPrimary, fontSize: 14),
//         decoration: InputDecoration(
//           prefixIcon: Icon(icon, color: _C.textMuted, size: 16), hintText: hint,
//           hintStyle: const TextStyle(color: _C.textMuted), filled: true, fillColor: _C.card,
//           enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _C.border), borderRadius: BorderRadius.circular(12)),
//           focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _C.accent), borderRadius: BorderRadius.circular(12)),
//           contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//         ),
//       );
// }

// class _SheetButton extends StatelessWidget {
//   const _SheetButton({required this.label, this.color = _C.accent, required this.onTap});
//   final String label; final Color color; final VoidCallback onTap;
//   @override
//   Widget build(BuildContext context) => SizedBox(
//         width: double.infinity,
//         child: ElevatedButton(
//           onPressed: onTap,
//           style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
//           child: Text(label, style: TextStyle(color: color == _C.accent ? _C.bg : _C.textPrimary, fontWeight: FontWeight.bold)),
//         ),
//       );
// }

// class _TypeTile extends StatelessWidget {
//   const _TypeTile({required this.type, required this.selected, required this.onTap});
//   final WidgetType type; final bool selected; final VoidCallback onTap;
//   @override
//   Widget build(BuildContext context) => InkWell(
//         onTap: onTap, borderRadius: BorderRadius.circular(12),
//         child: Container(
//           padding: const EdgeInsets.all(8),
//           decoration: BoxDecoration(color: selected ? type.color.withOpacity(0.15) : _C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? type.color : _C.border, width: 1.5)),
//           child: Row(children: [
//             Icon(type.icon, color: type.color, size: 18),
//             const SizedBox(width: 8),
//             Expanded(child: Text(type.label, style: TextStyle(color: selected ? _C.textPrimary : _C.textSecondary, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
//           ]),
//         ),
//       );
// }

// class _MiniStat extends StatelessWidget {
//   const _MiniStat({required this.label, required this.value, required this.color});
//   final String label, value; final Color color;
//   @override
//   Widget build(BuildContext context) => Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         decoration: BoxDecoration(color: _C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
//         child: Row(children: [
//           Text(label, style: const TextStyle(color: _C.textSecondary, fontSize: 12)),
//           const SizedBox(width: 8),
//           Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
//         ]),
//       );
// }

// class _FilterChip extends StatelessWidget {
//   const _FilterChip({required this.label, required this.icon, required this.selected, required this.color, required this.onTap});
//   final String label; final IconData icon; final bool selected; final Color color; final VoidCallback onTap;
//   @override
//   Widget build(BuildContext context) => InkWell(
//         onTap: onTap, borderRadius: BorderRadius.circular(20),
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           decoration: BoxDecoration(color: selected ? color.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? color : _C.border)),
//           child: Row(children: [
//             Icon(icon, color: selected ? color : _C.textSecondary, size: 14),
//             const SizedBox(width: 6),
//             Text(label, style: TextStyle(color: selected ? _C.textPrimary : _C.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
//           ]),
//         ),
//       );
// }

// class _MetaChip extends StatelessWidget {
//   const _MetaChip({required this.icon, required this.label, required Color color}) : _color = color; final IconData icon; final String label; final Color _color;
//   @override
//   Widget build(BuildContext context) => Row(children: [Icon(icon, color: _color, size: 12), const SizedBox(width: 4), Text(label, style: TextStyle(color: _color, fontSize: 11))]);
// }
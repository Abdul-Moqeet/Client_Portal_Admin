import 'package:flutter/material.dart';

import '../models/dashboard_widget.dart';
import '../theme/colors.dart';
import 'shared_components.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  WIDGET CARD
// ═══════════════════════════════════════════════════════════════════════════

class WidgetCard extends StatefulWidget {
  const WidgetCard({
    super.key,
    required this.widget_,
    required this.index,
    required this.onAddEntry,
    required this.onEditEntries,
    required this.onEditWidget,
    required this.onDelete,
  });
  final DashboardWidget widget_;
  final int index;
  final VoidCallback onAddEntry;
  final VoidCallback onEditEntries;
  final VoidCallback onEditWidget;
  final VoidCallback onDelete;

  @override
  State<WidgetCard> createState() => _WidgetCardState();
}

class _WidgetCardState extends State<WidgetCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
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
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${m[d.month - 1]} ${d.day}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.widget_;
    final isDash = w.isDashWidget;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _slide.value),
        child: Opacity(opacity: _fade.value, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
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
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                    ),
                    PopupMenuButton<String>(
                      color: const Color(0xFF252A38),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (_) => isDash
                          ? _buildDashMenuItems()
                          : _buildHistoryMenuItems(),
                      onSelected: (v) {
                        if (v == 'add' || v == 'edit_data') {
                          widget.onAddEntry();
                        }
                        if (v == 'edit_entries') widget.onEditEntries();
                        if (v == 'edit_widget') widget.onEditWidget();
                        if (v == 'delete') widget.onDelete();
                      },
                      child: const Icon(Icons.more_vert_rounded,
                          color: AppColors.textSecondary, size: 20),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    if (isDash && w.category != null) ...[
                      MetaChip(
                        icon: w.category!.icon,
                        label: w.category!.label,
                        color: w.category!.color,
                      ),
                      const SizedBox(width: 8),
                    ],
                    MetaChip(
                      icon: isDash
                          ? Icons.analytics_rounded
                          : Icons.history_rounded,
                      label: isDash
                          ? '${w.metrics.length} metrics'
                          : '${w.entryCount} entries',
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    if (!isDash)
                      MetaChip(
                        icon: Icons.calendar_today_rounded,
                        label: 'Latest: ${_fmtDate(w.latestDate)}',
                        color: AppColors.textSecondary,
                      ),
                    if (w.colspan != null) ...[
                      const SizedBox(width: 8),
                      MetaChip(
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
                            Icon(
                                isDash
                                    ? Icons.edit_rounded
                                    : Icons.add_rounded,
                                color: w.type.color,
                                size: 14),
                            const SizedBox(width: 4),
                            Text(isDash ? 'Edit Data' : 'Add Entry',
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
              if (isDash && w.metrics.isNotEmpty)
                _MetricsPreview(widget_: w)
              else if (!isDash && w.history.isNotEmpty)
                _HistoryPreview(widget_: w),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildHistoryMenuItems() {
    return [
      const PopupMenuItem(
        value: 'add',
        child: Row(children: [
          Icon(Icons.add_circle_outline_rounded,
              size: 16, color: AppColors.accent),
          SizedBox(width: 10),
          Text('Add Entry',
              style: TextStyle(color: AppColors.textPrimary)),
        ]),
      ),
      const PopupMenuItem(
        value: 'edit_entries',
        child: Row(children: [
          Icon(Icons.edit_note_rounded,
              size: 16, color: AppColors.textSecondary),
          SizedBox(width: 10),
          Text('Edit Entries',
              style: TextStyle(color: AppColors.textPrimary)),
        ]),
      ),
      const PopupMenuItem(
        value: 'edit_widget',
        child: Row(children: [
          Icon(Icons.settings_rounded,
              size: 16, color: AppColors.textSecondary),
          SizedBox(width: 10),
          Text('Edit Widget',
              style: TextStyle(color: AppColors.textPrimary)),
        ]),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: Row(children: [
          Icon(Icons.delete_outline_rounded,
              size: 16, color: AppColors.danger),
          SizedBox(width: 10),
          Text('Delete', style: TextStyle(color: AppColors.danger)),
        ]),
      ),
    ];
  }

  List<PopupMenuEntry<String>> _buildDashMenuItems() {
    final w = widget.widget_;
    return [
      const PopupMenuItem(
        value: 'edit_data',
        child: Row(children: [
          Icon(Icons.edit_rounded,
              size: 16, color: AppColors.accent),
          SizedBox(width: 10),
          Text('Edit Data',
              style: TextStyle(color: AppColors.textPrimary)),
        ]),
      ),
      if (w.history.isNotEmpty)
        const PopupMenuItem(
          value: 'edit_entries',
          child: Row(children: [
            Icon(Icons.edit_note_rounded,
                size: 16, color: AppColors.textSecondary),
            SizedBox(width: 10),
            Text('Edit History',
                style: TextStyle(color: AppColors.textPrimary)),
          ]),
        ),
      const PopupMenuItem(
        value: 'edit_widget',
        child: Row(children: [
          Icon(Icons.settings_rounded,
              size: 16, color: AppColors.textSecondary),
          SizedBox(width: 10),
          Text('Edit Widget',
              style: TextStyle(color: AppColors.textPrimary)),
        ]),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: Row(children: [
          Icon(Icons.delete_outline_rounded,
              size: 16, color: AppColors.danger),
          SizedBox(width: 10),
          Text('Delete', style: TextStyle(color: AppColors.danger)),
        ]),
      ),
    ];
  }
}

// ── Metrics preview for dashboard widgets ─────────────────────────────────

class _MetricsPreview extends StatelessWidget {
  const _MetricsPreview({required this.widget_});
  final DashboardWidget widget_;

  @override
  Widget build(BuildContext context) {
    final preview = widget_.metrics.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg.withOpacity(0.5),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Column(
        children: preview.asMap().entries.map((e) {
          final i = e.key;
          final metric = e.value;
          final title = metric['title']?.toString() ?? '';
          final value = metric['value']?.toString() ?? '';
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      value,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (i < preview.length - 1)
                const Divider(height: 1, indent: 16, color: AppColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── History preview strip ─────────────────────────────────────────────────

class _HistoryPreview extends StatelessWidget {
  const _HistoryPreview({required this.widget_});
  final DashboardWidget widget_;

  String _summarise(dynamic value) => summariseEntry(value);

  @override
  Widget build(BuildContext context) {
    final sorted = widget_.history.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final preview = sorted.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg.withOpacity(0.5),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text(entry.key,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontFamily: 'monospace')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _summarise(entry.value),
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < preview.length - 1)
                const Divider(height: 1, indent: 16, color: AppColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

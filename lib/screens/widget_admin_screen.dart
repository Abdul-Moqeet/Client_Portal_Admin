import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_widget.dart';
import '../theme/colors.dart';
import '../widgets/add_entry_sheet.dart';
import '../widgets/create_widget_sheet.dart';
import '../widgets/edit_entry_sheet.dart';
import '../widgets/edit_widget_sheet.dart';
import '../widgets/shared_components.dart';
import '../widgets/widget_card.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  WIDGET ADMIN SCREEN (refactored)
// ═══════════════════════════════════════════════════════════════════════════

enum SortMode { position, type, title, latestDate }

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
  SortMode _sortMode = SortMode.position;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _reorderMode = false;
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
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DashboardWidget> get _filtered {
    var list = _widgets.toList();

    // Apply type filter
    if (_filterType != null) {
      list = list.where((w) => w.type == _filterType).toList();
    }

    // Apply search
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((w) => w.title.toLowerCase().contains(_searchQuery))
          .toList();
    }

    // Apply sort
    switch (_sortMode) {
      case SortMode.position:
        list.sort((a, b) => a.position.compareTo(b.position));
      case SortMode.type:
        list.sort((a, b) => a.type.label.compareTo(b.type.label));
      case SortMode.title:
        list.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case SortMode.latestDate:
        list.sort((a, b) => b.latestDate.compareTo(a.latestDate));
    }
    return list;
  }

  void _openCreate() async {
    final result = await showModalBottomSheet<DashboardWidget>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateWidgetSheet(),
    );
    if (result != null) setState(() => _widgets.add(result));
  }

  void _openAddEntry(DashboardWidget w) async {
    final updated = await showModalBottomSheet<DashboardWidget>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEntrySheet(dashboardWidget: w),
    );
    if (updated != null) {
      setState(() {
        final idx = _widgets.indexWhere((x) => x.id == updated.id);
        if (idx != -1) _widgets[idx] = updated;
      });
    }
  }

  void _openEditEntries(DashboardWidget w) async {
    final updated = await showModalBottomSheet<DashboardWidget>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditEntrySheet(dashboardWidget: w),
    );
    if (updated != null) {
      setState(() {
        final idx = _widgets.indexWhere((x) => x.id == updated.id);
        if (idx != -1) _widgets[idx] = updated;
      });
    }
  }

  void _openEditWidget(DashboardWidget w) async {
    final updated = await showModalBottomSheet<DashboardWidget>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditWidgetSheet(dashboardWidget: w),
    );
    if (updated != null) {
      setState(() {
        final idx = _widgets.indexWhere((x) => x.id == updated.id);
        if (idx != -1) _widgets[idx] = updated;
      });
    }
  }

  void _deleteWidget(DashboardWidget widget_) async {
    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Widget',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${widget_.title}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
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

    // Store for undo
    final deletedWidget = widget_;
    final deletedIndex = _widgets.indexOf(widget_);

    setState(() => _widgets.removeWhere((w) => w.id == widget_.id));

    if (!mounted) return;
    final snackBar = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Widget deleted'),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.accent,
          onPressed: () {
            setState(() {
              if (deletedIndex >= 0 && deletedIndex <= _widgets.length) {
                _widgets.insert(deletedIndex, deletedWidget);
              } else {
                _widgets.add(deletedWidget);
              }
            });
          },
        ),
      ),
    );

    // Wait for snackbar - if not undone, delete from DB
    snackBar.closed.then((reason) async {
      if (reason != SnackBarClosedReason.action) {
        try {
          await Supabase.instance.client
              .from('widgets_data')
              .delete()
              .eq('id', widget_.id);
        } catch (e) {
          debugPrint('Failed to delete from Supabase: $e');
        }
      }
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _widgets.removeAt(oldIndex);
      _widgets.insert(newIndex, item);
    });
    _persistPositions();
  }

  Future<void> _persistPositions() async {
    for (int i = 0; i < _widgets.length; i++) {
      final w = _widgets[i];
      _widgets[i] = w.copyWith(position: i);
    }
    try {
      for (final w in _widgets) {
        await Supabase.instance.client
            .from('widgets_data')
            .update({'position': w.position}).eq('id', w.id);
      }
    } catch (e) {
      debugPrint('Failed to persist positions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Widget Manager',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => setState(() => _reorderMode = !_reorderMode),
            icon: Icon(
              _reorderMode ? Icons.check_rounded : Icons.reorder_rounded,
              color: _reorderMode ? AppColors.accent : AppColors.textSecondary,
              size: 22,
            ),
            tooltip: _reorderMode ? 'Done reordering' : 'Reorder',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            _buildStats(),
            _buildFilterAndSort(),
            const SizedBox(height: 4),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmpty()
                  : _reorderMode
                      ? _buildReorderableList(filtered)
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) => WidgetCard(
                            key: ValueKey(filtered[i].id),
                            widget_: filtered[i],
                            index: i,
                            onAddEntry: () => _openAddEntry(filtered[i]),
                            onEditEntries: () =>
                                _openEditEntries(filtered[i]),
                            onEditWidget: () =>
                                _openEditWidget(filtered[i]),
                            onDelete: () => _deleteWidget(filtered[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search widgets by title...',
            hintStyle:
                const TextStyle(color: AppColors.textMuted, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.textSecondary, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () => _searchCtrl.clear(),
                    child: const Icon(Icons.clear_rounded,
                        color: AppColors.textSecondary, size: 18),
                  )
                : null,
            filled: true,
            fillColor: AppColors.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.accent, width: 1.5)),
          ),
        ),
      );

  Widget _buildStats() {
    final counts = <WidgetType, int>{};
    for (final w in _widgets) {
      counts[w.type] = (counts[w.type] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            MiniStat(
                label: 'Total',
                value: _widgets.length.toString(),
                color: AppColors.accent),
            const SizedBox(width: 8),
            ...WidgetType.values.map((t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: MiniStat(
                      label: t.label,
                      value: (counts[t] ?? 0).toString(),
                      color: t.color),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAndSort() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChipWidget(
                    label: 'All',
                    icon: Icons.apps_rounded,
                    selected: _filterType == null,
                    color: AppColors.accent,
                    onTap: () => setState(() => _filterType = null),
                  ),
                  const SizedBox(width: 8),
                  ...WidgetType.values.map((t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChipWidget(
                          label: t.label,
                          icon: t.icon,
                          selected: _filterType == t,
                          color: t.color,
                          onTap: () => setState(() =>
                              _filterType = _filterType == t ? null : t),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Sort: ',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                  _buildSortChip('Position', SortMode.position),
                  const SizedBox(width: 6),
                  _buildSortChip('Type', SortMode.type),
                  const SizedBox(width: 6),
                  _buildSortChip('Title', SortMode.title),
                  const SizedBox(width: 6),
                  _buildSortChip('Latest', SortMode.latestDate),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildSortChip(String label, SortMode mode) {
    final selected = _sortMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _sortMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withOpacity(0.15)
              : AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.accent.withOpacity(0.5)
                : AppColors.border,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color:
                    selected ? AppColors.accent : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildReorderableList(List<DashboardWidget> items) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: items.length,
      onReorder: _onReorder,
      itemBuilder: (ctx, i) => Container(
        key: ValueKey(items[i].id),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.drag_handle_rounded,
                color: AppColors.textMuted, size: 20),
            const SizedBox(width: 12),
            Icon(items[i].type.icon, color: items[i].type.color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(items[i].title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
            Text('#${i + 1}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.widgets_outlined, size: 52, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No widgets match "$_searchQuery"'
                  : 'No widgets',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Tap + to create one',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );

  Widget _buildFab() => FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bg,
        elevation: 0,
        label: const Text('New Widget',
            style: TextStyle(fontWeight: FontWeight.w700)),
        icon: const Icon(Icons.add_rounded),
      );
}

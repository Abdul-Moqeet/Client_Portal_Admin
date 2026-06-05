import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_widget.dart';
import '../theme/colors.dart';
import 'shared_components.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  EDIT WIDGET METADATA SHEET
// ═══════════════════════════════════════════════════════════════════════════

class EditWidgetSheet extends StatefulWidget {
  const EditWidgetSheet({super.key, required this.dashboardWidget});
  final DashboardWidget dashboardWidget;

  @override
  State<EditWidgetSheet> createState() => _EditWidgetSheetState();
}

class _EditWidgetSheetState extends State<EditWidgetSheet> {
  late WidgetType _type;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _colspanCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.dashboardWidget.type;
    _titleCtrl = TextEditingController(text: widget.dashboardWidget.title);
    _colspanCtrl = TextEditingController(
        text: widget.dashboardWidget.colspan?.toString() ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _colspanCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('widgets_data')
          .update({
            'widget_type': _type.apiKey,
            'title': _titleCtrl.text.trim(),
            'colspan': int.tryParse(_colspanCtrl.text),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.dashboardWidget.id);

      final updated = widget.dashboardWidget.copyWith(
        type: _type,
        title: _titleCtrl.text.trim(),
        colspan: int.tryParse(_colspanCtrl.text),
      );

      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      debugPrint('Edit widget failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update: $e'),
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
    return SheetContainer(
      title: 'Edit Widget',
      subtitle: 'Update widget properties',
      icon: Icons.edit_rounded,
      iconColor: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetLabel('Widget Type'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 3,
            children: WidgetType.values
                .map((t) => TypeTile(
                      type: t,
                      selected: _type == t,
                      onTap: () => setState(() => _type = t),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          const SheetLabel('Title'),
          const SizedBox(height: 8),
          SheetField(
              controller: _titleCtrl,
              hint: 'e.g. Active Users',
              icon: Icons.title_rounded),
          const SizedBox(height: 16),
          const SheetLabel('Colspan (optional)'),
          const SizedBox(height: 8),
          SheetField(
              controller: _colspanCtrl,
              hint: '1 or 2',
              icon: Icons.grid_view_rounded,
              keyboardType: TextInputType.number),
          const SizedBox(height: 28),
          _isSaving
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent))
              : SheetButton(label: 'Save Changes', onTap: _save),
        ],
      ),
    );
  }
}

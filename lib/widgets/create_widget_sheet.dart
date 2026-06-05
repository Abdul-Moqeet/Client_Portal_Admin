import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_widget.dart';
import '../theme/colors.dart';
import 'shared_components.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  CREATE WIDGET SHEET
// ═══════════════════════════════════════════════════════════════════════════

class CreateWidgetSheet extends StatefulWidget {
  const CreateWidgetSheet({super.key});

  @override
  State<CreateWidgetSheet> createState() => _CreateWidgetSheetState();
}

class _CreateWidgetSheetState extends State<CreateWidgetSheet> {
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
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

      // Fetch organisation_id so the new widget shows up on reload
      final userRow = await Supabase.instance.client
          .from('users')
          .select('organisation_id')
          .eq('id', userId)
          .single();
      final organisationId = userRow['organisation_id'];

      final response = await Supabase.instance.client
          .from('widgets_data')
          .insert({
            'user_id': userId,
            'organisation_id': organisationId,
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
      title: 'New Widget',
      subtitle: 'Choose type and fill in details',
      icon: Icons.add_box_rounded,
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
              : SheetButton(label: 'Create Widget', onTap: _create),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_widget.dart';
import '../theme/colors.dart';
import 'shared_components.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  CREATE DASHBOARD WIDGET SHEET
// ═══════════════════════════════════════════════════════════════════════════

class CreateDashWidgetSheet extends StatefulWidget {
  const CreateDashWidgetSheet({super.key});

  @override
  State<CreateDashWidgetSheet> createState() => _CreateDashWidgetSheetState();
}

class _CreateDashWidgetSheetState extends State<CreateDashWidgetSheet> {
  DashboardCategory _selectedCategory = DashboardCategory.values.first;
  final _titleCtrl = TextEditingController();
  final _colspanCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _colspanCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildInitialData(DashboardCategory category) {
    switch (category) {
      case DashboardCategory.pipelineProgress:
        return {
          'metrics': [],
          'global_progress': 0.0,
          'text_list_items': [],
        };
      case DashboardCategory.coreVitalsRadar:
        return {
          'metrics': [],
          'subtitle': '',
        };
      case DashboardCategory.userSentiment:
        return {
          'metrics': [],
          'text_list_items': [],
          'subtitle': '',
        };
      case DashboardCategory.appStoreStatus:
        return {
          'metrics': [],
          'trailing_text': '',
        };
      case DashboardCategory.versionMilestones:
        return {
          'metrics': [],
        };
    }
  }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

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
            'widget_type': 'kpi',
            'title': _titleCtrl.text.trim(),
            'data': _buildInitialData(_selectedCategory),
            'colspan': int.tryParse(_colspanCtrl.text),
            'position': 99,
            'is_dash_widget': true,
            'category': _selectedCategory.apiKey,
          })
          .select()
          .single();

      final newWidget = DashboardWidget.fromJson(response);
      if (mounted) Navigator.pop(context, newWidget);
    } catch (e) {
      debugPrint('Create dashboard widget failed: $e');
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
      title: 'New Dashboard Widget',
      subtitle: 'Choose a category and fill in details',
      icon: Icons.dashboard_rounded,
      iconColor: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetLabel('CATEGORY'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 3,
            children: DashboardCategory.values
                .map((c) => CategoryTile(
                      category: c,
                      selected: _selectedCategory == c,
                      onTap: () => setState(() => _selectedCategory = c),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          const SheetLabel('TITLE'),
          const SizedBox(height: 8),
          SheetField(
              controller: _titleCtrl,
              hint: 'e.g. Pipeline Status',
              icon: Icons.title_rounded),
          const SizedBox(height: 16),
          const SheetLabel('COLSPAN (OPTIONAL)'),
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

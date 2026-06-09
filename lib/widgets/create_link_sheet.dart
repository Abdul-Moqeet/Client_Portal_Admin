import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/external_link.dart';
import '../theme/colors.dart';
import 'shared_components.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  CREATE LINK SHEET
// ═══════════════════════════════════════════════════════════════════════════

class CreateLinkSheet extends StatefulWidget {
  const CreateLinkSheet({super.key});

  @override
  State<CreateLinkSheet> createState() => _CreateLinkSheetState();
}

class _CreateLinkSheetState extends State<CreateLinkSheet> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  String _iconName = 'link';
  bool _isSaving = false;

  static const String _organisationId = 'd69eb82e-f92c-4c70-ac5d-329926b40423';

  static const List<String> _iconOptions = [
    'link',
    'chat',
    'document',
    'web',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _urlCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final response = await Supabase.instance.client
          .from('external_links')
          .insert({
            'title': _titleCtrl.text.trim(),
            'url': _urlCtrl.text.trim(),
            'icon_name': _iconName,
            'organisation_id': _organisationId,
            'position': 0,
          })
          .select()
          .single();

      final newLink = ExternalLink.fromJson(Map<String, dynamic>.from(response));
      if (mounted) Navigator.pop(context, newLink);
    } catch (e) {
      debugPrint('Create link failed: $e');
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
      title: 'New Link',
      subtitle: 'Add an external link',
      icon: Icons.link_rounded,
      iconColor: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetLabel('TITLE'),
          const SizedBox(height: 8),
          SheetField(
            controller: _titleCtrl,
            hint: 'e.g. Notion, Google Chat',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 16),
          const SheetLabel('URL'),
          const SizedBox(height: 8),
          SheetField(
            controller: _urlCtrl,
            hint: 'https://notion.so/...',
            icon: Icons.link_rounded,
          ),
          const SizedBox(height: 16),
          const SheetLabel('ICON'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _iconName,
                isExpanded: true,
                dropdownColor: AppColors.card,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                items: _iconOptions.map((icon) {
                  return DropdownMenuItem(
                    value: icon,
                    child: Text(icon),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _iconName = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 28),
          _isSaving
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent))
              : SheetButton(label: 'Create Link', onTap: _save),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/alert_action.dart';
import '../theme/colors.dart';
import 'shared_components.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  EDIT ALERT SHEET
// ═══════════════════════════════════════════════════════════════════════════

class EditAlertSheet extends StatefulWidget {
  const EditAlertSheet({super.key, required this.alert});
  final AlertAction alert;

  @override
  State<EditAlertSheet> createState() => _EditAlertSheetState();
}

class _EditAlertSheetState extends State<EditAlertSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _actionLabelCtrl;
  late String _iconName;
  late bool _hasAction;
  bool _isSaving = false;

  static const List<String> _iconOptions = [
    'warning',
    'info',
    'security',
    'error',
    'update',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.alert.title);
    _descCtrl = TextEditingController(text: widget.alert.description);
    _colorCtrl = TextEditingController(text: widget.alert.iconColor);
    _actionLabelCtrl =
        TextEditingController(text: widget.alert.actionLabel ?? '');
    _iconName = widget.alert.iconName;
    _hasAction = widget.alert.hasAction;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _colorCtrl.dispose();
    _actionLabelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final response = await Supabase.instance.client
          .from('alerts_actions')
          .update({
            'title': _titleCtrl.text.trim(),
            'description': _descCtrl.text.trim(),
            'icon_name': _iconName,
            'icon_color': _colorCtrl.text.trim(),
            'has_action': _hasAction,
            'action_label': _hasAction ? _actionLabelCtrl.text.trim() : null,
          })
          .eq('id', widget.alert.id)
          .select()
          .single();

      final updated = AlertAction.fromJson(Map<String, dynamic>.from(response));
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      debugPrint('Update alert failed: $e');
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
      title: 'Edit Alert',
      subtitle: 'Update alert details',
      icon: Icons.edit_rounded,
      iconColor: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetLabel('TITLE'),
          const SizedBox(height: 8),
          SheetField(
            controller: _titleCtrl,
            hint: 'e.g. Certificate Expiring',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 16),
          const SheetLabel('DESCRIPTION'),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Describe the alert...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              filled: true,
              fillColor: AppColors.card,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                value: _iconOptions.contains(_iconName) ? _iconName : 'info',
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
          const SizedBox(height: 16),
          const SheetLabel('ICON COLOR (HEX)'),
          const SizedBox(height: 8),
          SheetField(
            controller: _colorCtrl,
            hint: '#FFC107',
            icon: Icons.palette_outlined,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SheetLabel('HAS ACTION BUTTON'),
              Switch(
                value: _hasAction,
                activeColor: AppColors.accent,
                onChanged: (val) => setState(() => _hasAction = val),
              ),
            ],
          ),
          if (_hasAction) ...[
            const SizedBox(height: 8),
            const SheetLabel('ACTION LABEL'),
            const SizedBox(height: 8),
            SheetField(
              controller: _actionLabelCtrl,
              hint: 'e.g. Resolve',
              icon: Icons.touch_app_outlined,
            ),
          ],
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

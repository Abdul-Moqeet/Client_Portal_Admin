import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/alert_action.dart';
import '../theme/colors.dart';
import '../widgets/create_alert_sheet.dart';
import '../widgets/edit_alert_sheet.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  ALERTS ADMIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class AlertsAdminScreen extends StatefulWidget {
  const AlertsAdminScreen({super.key});

  @override
  State<AlertsAdminScreen> createState() => _AlertsAdminScreenState();
}

class _AlertsAdminScreenState extends State<AlertsAdminScreen> {
  List<AlertAction> _alerts = [];
  bool _isLoading = true;
  String? _error;

  static const String _organisationId = 'd69eb82e-f92c-4c70-ac5d-329926b40423';

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client
          .from('alerts_actions')
          .select()
          .eq('organisation_id', _organisationId)
          .order('position', ascending: true);

      setState(() {
        _alerts = (response as List)
            .map((json) => AlertAction.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      debugPrint('Error loading alerts: $e');
    }
  }

  void _openCreateSheet() async {
    final result = await showModalBottomSheet<AlertAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateAlertSheet(),
    );
    if (result != null) {
      setState(() => _alerts.add(result));
    }
  }

  void _openEditSheet(AlertAction alert) async {
    final result = await showModalBottomSheet<AlertAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditAlertSheet(alert: alert),
    );
    if (result != null) {
      setState(() {
        final idx = _alerts.indexWhere((a) => a.id == result.id);
        if (idx != -1) _alerts[idx] = result;
      });
    }
  }

  void _deleteAlert(AlertAction alert) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Alert',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${alert.title}"?',
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

    setState(() => _alerts.removeWhere((a) => a.id == alert.id));

    try {
      await Supabase.instance.client
          .from('alerts_actions')
          .delete()
          .eq('id', alert.id);
    } catch (e) {
      debugPrint('Failed to delete alert: $e');
      if (mounted) {
        setState(() => _alerts.add(alert));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete alert. It has been restored.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  IconData _iconFromName(String name) {
    switch (name) {
      case 'warning':
        return Icons.warning_outlined;
      case 'info':
        return Icons.info_outline;
      case 'security':
        return Icons.gpp_maybe_outlined;
      case 'error':
        return Icons.error_outline;
      case 'update':
        return Icons.system_update_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorFromHex(String hex) {
    try {
      final hexCode = hex.replaceAll('#', '');
      return Color(int.parse('FF$hexCode', radix: 16));
    } catch (_) {
      return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Alerts Manager',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _loadAlerts,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? _buildError()
              : _alerts.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bg,
        elevation: 0,
        label: const Text('New Alert',
            style: TextStyle(fontWeight: FontWeight.w700)),
        icon: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              const Text('Failed to load alerts',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_error ?? '',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadAlerts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 52, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('No alerts configured',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Tap + to create one',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      );

  Widget _buildList() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _alerts.length,
        itemBuilder: (ctx, i) {
          final alert = _alerts[i];
          final iconColor = _colorFromHex(alert.iconColor);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconFromName(alert.iconName),
                      color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.title,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(alert.description,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (alert.hasAction && alert.actionLabel != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(alert.actionLabel!,
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => _openEditSheet(alert),
                      child: const Icon(Icons.edit_outlined,
                          color: AppColors.textSecondary, size: 18),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _deleteAlert(alert),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
}

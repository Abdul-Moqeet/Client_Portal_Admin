import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/external_link.dart';
import '../theme/colors.dart';
import '../widgets/create_link_sheet.dart';
import '../widgets/edit_link_sheet.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  LINKS ADMIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class LinksAdminScreen extends StatefulWidget {
  const LinksAdminScreen({super.key});

  @override
  State<LinksAdminScreen> createState() => _LinksAdminScreenState();
}

class _LinksAdminScreenState extends State<LinksAdminScreen> {
  List<ExternalLink> _links = [];
  bool _isLoading = true;
  String? _error;

  static const String _organisationId = 'd69eb82e-f92c-4c70-ac5d-329926b40423';

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client
          .from('external_links')
          .select()
          .eq('organisation_id', _organisationId)
          .order('position', ascending: true);

      setState(() {
        _links = (response as List)
            .map((json) => ExternalLink.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      debugPrint('Error loading links: $e');
    }
  }

  void _openCreateSheet() async {
    final result = await showModalBottomSheet<ExternalLink>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateLinkSheet(),
    );
    if (result != null) {
      setState(() => _links.add(result));
    }
  }

  void _openEditSheet(ExternalLink link) async {
    final result = await showModalBottomSheet<ExternalLink>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditLinkSheet(link: link),
    );
    if (result != null) {
      setState(() {
        final idx = _links.indexWhere((l) => l.id == result.id);
        if (idx != -1) _links[idx] = result;
      });
    }
  }

  void _deleteLink(ExternalLink link) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Link',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${link.title}"?',
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

    setState(() => _links.removeWhere((l) => l.id == link.id));

    try {
      await Supabase.instance.client
          .from('external_links')
          .delete()
          .eq('id', link.id);
    } catch (e) {
      debugPrint('Failed to delete link: $e');
      if (mounted) {
        setState(() => _links.add(link));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete link. It has been restored.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  IconData _iconFromName(String? name) {
    switch (name) {
      case 'link':
        return Icons.link_rounded;
      case 'chat':
        return Icons.chat_rounded;
      case 'document':
        return Icons.description_rounded;
      case 'web':
        return Icons.language_rounded;
      default:
        return Icons.link_rounded;
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
        title: const Text('External Links Manager',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _loadLinks,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? _buildError()
              : _links.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bg,
        elevation: 0,
        label: const Text('New Link',
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
              const Text('Failed to load links',
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
                onPressed: _loadLinks,
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
            Icon(Icons.link_off_rounded,
                size: 52, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('No external links configured',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Tap + to create one',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      );

  Widget _buildList() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _links.length,
        itemBuilder: (ctx, i) {
          final link = _links[i];
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
                    color: AppColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconFromName(link.iconName),
                      color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(link.title,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(link.url,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => _openEditSheet(link),
                      child: const Icon(Icons.edit_outlined,
                          color: AppColors.textSecondary, size: 18),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _deleteLink(link),
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

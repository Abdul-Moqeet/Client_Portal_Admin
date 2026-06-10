import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  TICKET DETAIL ADMIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class TicketDetailAdminScreen extends StatefulWidget {
  const TicketDetailAdminScreen({super.key, required this.ticket});

  final Map<String, dynamic> ticket;

  @override
  State<TicketDetailAdminScreen> createState() =>
      _TicketDetailAdminScreenState();
}

class _TicketDetailAdminScreenState extends State<TicketDetailAdminScreen> {
  final TextEditingController _replyController = TextEditingController();
  bool _isSending = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _messages = [];

  String get _ticketId =>
      (widget.ticket['id'] ?? widget.ticket['ticket_id'] ?? '').toString();

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('ticket_messages')
          .select()
          .eq('ticket_id', _ticketId)
          .order('created_at', ascending: true);

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading messages: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply() async {
    if (_replyController.text.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      await Supabase.instance.client.from('ticket_messages').insert({
        'message': _replyController.text.trim(),
        'created_by': _currentUserId,
        'ticket_id': _ticketId,
      });
      _replyController.clear();
      await _loadMessages();
    } catch (e) {
      debugPrint('Error sending reply: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Color _priorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return AppColors.danger;
      case 'medium':
        return AppColors.accent;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'open':
        return AppColors.success;
      case 'in_progress':
      case 'in progress':
        return AppColors.accent;
      case 'closed':
      case 'resolved':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priority = (widget.ticket['priority'] ?? '').toString();
    final status = (widget.ticket['status'] ?? '').toString();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.ticket['title'] ?? 'Ticket Detail',
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _loadMessages,
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
          ),
        ],
      ),
      body: Column(
        children: [
          // Ticket header
          _buildTicketHeader(priority, status),

          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.accent))
                : _buildMessagesList(),
          ),

          // Reply input
          _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildTicketHeader(String priority, String status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.ticket['title'] ?? 'Untitled',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.ticket['subject'] ?? '',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _priorityColor(priority).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Priority: ${priority.isNotEmpty ? priority : 'N/A'}',
                  style: TextStyle(
                      color: _priorityColor(priority),
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Status: ${status.isNotEmpty ? status : 'N/A'}',
                  style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    // Build the full message list: initial ticket message + thread messages
    final allMessages = <Map<String, dynamic>>[];

    // Add the initial ticket message as the first bubble
    final initialMessage = widget.ticket['message'];
    if (initialMessage != null &&
        initialMessage.toString().trim().isNotEmpty) {
      allMessages.add({
        'message': initialMessage,
        'created_by': widget.ticket['created_by'] ?? '',
        'created_at': widget.ticket['created_at'],
      });
    }

    // Add all ticket_messages
    allMessages.addAll(_messages);

    if (allMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('No messages yet',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allMessages.length,
      itemBuilder: (ctx, i) {
        final msg = allMessages[i];
        final isAdmin =
            (msg['created_by'] ?? '').toString() == _currentUserId;
        return _MessageBubble(
          message: (msg['message'] ?? '').toString(),
          isAdmin: isAdmin,
          createdAt: msg['created_at'],
        );
      },
    );
  }

  Widget _buildReplyInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Type a reply...',
                hintStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 14),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendReply(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isSending ? null : _sendReply,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.bg,
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: AppColors.bg, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  MESSAGE BUBBLE WIDGET
// ─────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isAdmin,
    this.createdAt,
  });

  final String message;
  final bool isAdmin;
  final String? createdAt;

  @override
  Widget build(BuildContext context) {
    final formattedTime = createdAt != null
        ? DateFormat('MMM d, h:mm a')
            .format(DateTime.parse(createdAt!).toLocal())
        : '';

    // Admin messages: blue, aligned right; User messages: green, aligned left
    final bgColor = isAdmin
        ? const Color(0xFF3B82F6).withOpacity(0.15)
        : const Color(0xFF06D6A0).withOpacity(0.15);
    final alignment =
        isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleAlignment =
        isAdmin ? Alignment.centerRight : Alignment.centerLeft;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Align(
            alignment: bubbleAlignment,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${isAdmin ? 'Admin' : 'User'} ${formattedTime.isNotEmpty ? '- $formattedTime' : ''}',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

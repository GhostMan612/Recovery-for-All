// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
//
// lib/widgets/tutorial_chatbot_dialog.dart
//
// Full-app tutorial chatbot dialog with recovery pet avatar.

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/recovery_pet_service.dart';
import '../services/tutorial_chatbot_service.dart';
import '../widgets/avatar_visual_layer.dart';

class TutorialChatbotDialog extends StatefulWidget {
  final RecoveryPet pet;
  final TutorialChatbotService chatbotService;
  final VoidCallback? onClose;

  const TutorialChatbotDialog({
    super.key,
    required this.pet,
    required this.chatbotService,
    this.onClose,
  });

  @override
  State<TutorialChatbotDialog> createState() => _TutorialChatbotDialogState();
}

class _TutorialChatbotDialogState extends State<TutorialChatbotDialog> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _displayMessages = [];

  StreamSubscription? _messagesSub;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messagesSub = widget.chatbotService.messagesStream.listen((messages) {
      if (mounted) {
        setState(() {
          _displayMessages.clear();
          _displayMessages.addAll(messages.map((m) => _ChatMessage(
            text: m.text,
            isUser: m.isUser,
            timestamp: m.timestamp,
          )));
        });
        _scrollToBottom();
      }
    });
    widget.chatbotService.initialize();
    _inputFocus.requestFocus();
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    await widget.chatbotService.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            AvatarVisualLayer(
              pet: widget.pet,
              size: 36,
              showAura: true,
              compact: true,
            ),
            const SizedBox(width: 10),
            const Text('Tutorial Guide', style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.white70),
            tooltip: 'Clear chat',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text('Clear chat?', style: TextStyle(color: Colors.white)),
                  content: const Text('This will delete all chat history.', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await widget.chatbotService.clearHistory();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => widget.onClose?.call(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _displayMessages.length,
              itemBuilder: (context, index) {
                final msg = _displayMessages[_displayMessages.length - 1 - index];
                return _ChatBubble(message: msg);
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  AvatarVisualLayer(
                    pet: widget.pet,
                    size: 28,
                    showAura: false,
                    compact: true,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Guide is typing...',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocus,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Ask about meetings, journal, pet, constellations...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Color(0xFF1E293B),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.accent),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: message.isUser ? AppColors.accent : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomLeft: message.isUser ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: message.isUser ? const Radius.circular(4) : const Radius.circular(16),
            ),
            border: message.isUser ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.black : Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: message.isUser ? Colors.black54 : AppColors.textDim,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
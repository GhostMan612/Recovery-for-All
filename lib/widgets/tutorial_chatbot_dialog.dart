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
  final bool _isTyping = false;

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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Row(
          children: [
            AvatarVisualLayer(
              pet: widget.pet,
              size: 36,
              showAura: true,
              compact: true,
            ),
            const SizedBox(width: 10),
            Text('Tutorial Guide', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.clear_all, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            tooltip: 'Clear chat',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                  title: Text('Clear chat?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  content: Text('This will delete all chat history.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
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
            tooltip: 'Close tutorial',
            icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            // Fall back to popping the route so the control can never be a
            // no-op, even if a future caller forgets to pass onClose.
            onPressed: () {
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
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
                  Text(
                    'Guide is typing...',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
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
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Ask about meetings, journal, pet, constellations...',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainer,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Send message',
                  icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
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
            color: message.isUser ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomLeft: message.isUser ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: message.isUser ? const Radius.circular(4) : const Radius.circular(16),
            ),
            border: message.isUser ? null : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                  color: message.isUser ? Colors.black54 : Theme.of(context).colorScheme.outline,
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

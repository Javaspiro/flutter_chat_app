import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ChatPage extends StatefulWidget {
  final String senderId;
  final String senderName;
  final String? receiverId;
  final String receiverName;
  final String receiverPhone;
  final String receiverNormalizedPhone;
  final bool hasAppAccount;

  const ChatPage({
    super.key,
    required this.senderId,
    required this.senderName,
    this.receiverId,
    required this.receiverName,
    required this.receiverPhone,
    required this.receiverNormalizedPhone,
    required this.hasAppAccount,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final DatabaseReference _messagesRef = FirebaseDatabase.instance.ref().child("messages");
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref().child("users");
  final DatabaseReference _recentChatsRef = FirebaseDatabase.instance.ref().child("recent_chats");
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  StreamSubscription? _messagesSubscription;
  bool _isSending = false;
  String? _actualReceiverId;
  bool _isRegisteredUser = false;
  // Receiver status
  bool _receiverOnline = false;
  String _receiverLastSeen = '';
  StreamSubscription? _receiverStatusSubscription;
  // AI Suggestions
  bool _isLoadingSuggestions = false;
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  // Animation Controllers
  late AnimationController _typingAnimationController;
  late AnimationController _suggestionsAnimationController;
  late AnimationController _messageAnimationController;
  late Animation<double> _suggestionsSlideAnimation;
  late Animation<double> _suggestionsFadeAnimation;
  late Animation<Offset> _messageSlideAnimation;
  // Typing indicator
  bool _isReceiverTyping = false;
  Timer? _typingTimer;
  // Gemma API Configuration
  static const String gemmaApiKey = 'AIzaSyAIIUOl8SRwjpx4sUEfjE0Oo0dPHZ6mo7c';
  static const String gemmaApiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemma-3-27b-it:generateContent';

  // Theme and Background State
  String _chatTheme = 'light'; // light, dark, system
  String _chatBackground = 'default'; // default, plain, image
  Color? _customBackgroundColor;
  String? _customBackgroundImage;
  File? _selectedBackgroundImage;

  // Message status tracking
  Timer? _statusUpdateTimer;
  Map<String, Timer> _messageStatusTimers = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeChat();
    _loadUserPreferences();
    _startStatusUpdateTimer();
  }

  void _startStatusUpdateTimer() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isRegisteredUser && mounted) {
        _updateMessageStatuses();
      }
    });
  }

  Future<void> _updateMessageStatuses() async {
    if (!_isRegisteredUser || _actualReceiverId == null || _messages.isEmpty) return;

    try {
      for (var message in _messages) {
        if (message["senderId"] == widget.senderId) {
          // My messages - check if delivered or read
          if (message["status"] == "sent") {
            // Check if receiver is online - mark as delivered
            if (_receiverOnline) {
              await _messagesRef
                  .child(_chatId)
                  .child(message["id"])
                  .update({"status": "delivered"});
            }
          }
        } else {
          // Messages from receiver - mark as read if not already
          if (message["status"] != "read") {
            await _messagesRef
                .child(_chatId)
                .child(message["id"])
                .update({"status": "read"});
          }
        }
      }
    } catch (e) {
      print("Error updating message statuses: $e");
    }
  }

  Future<void> _markMessageAsRead(String messageId) async {
    try {
      await _messagesRef
          .child(_chatId)
          .child(messageId)
          .update({"status": "read"});
    } catch (e) {
      print("Error marking message as read: $e");
    }
  }

  Future<void> _markMessageAsDelivered(String messageId) async {
    try {
      await _messagesRef
          .child(_chatId)
          .child(messageId)
          .update({"status": "delivered"});
    } catch (e) {
      print("Error marking message as delivered: $e");
    }
  }

  Future<void> _loadUserPreferences() async {
    try {
      final snapshot = await _usersRef.child(widget.senderId).child('chat_preferences').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _chatTheme = data['theme'] ?? 'light';
          _chatBackground = data['background'] ?? 'default';
          _customBackgroundColor = data['backgroundColor'] != null
              ? Color(data['backgroundColor'])
              : null;
          _customBackgroundImage = data['backgroundImage'];
        });
      }
    } catch (e) {
      print("Error loading preferences: $e");
    }
  }

  Future<void> _saveUserPreferences() async {
    try {
      await _usersRef.child(widget.senderId).child('chat_preferences').set({
        'theme': _chatTheme,
        'background': _chatBackground,
        'backgroundColor': _customBackgroundColor?.value,
        'backgroundImage': _customBackgroundImage,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      print("Error saving preferences: $e");
    }
  }

  void _initializeAnimations() {
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _suggestionsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _suggestionsSlideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _suggestionsAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _suggestionsFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _suggestionsAnimationController,
        curve: Curves.easeIn,
      ),
    );
    _messageAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _messageSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _messageAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _initializeChat() async {
    await _resolveReceiverId();
    _setupMessagesListener();
    if (_isRegisteredUser) {
      _setupReceiverStatusListener();
      _updateUserOnlineStatus(true);
    }
    _messageAnimationController.forward();
  }

  Future<void> _resolveReceiverId() async {
    if (widget.hasAppAccount && widget.receiverId != null) {
      setState(() {
        _actualReceiverId = widget.receiverId;
        _isRegisteredUser = true;
      });
    } else {
      try {
        final snapshot = await _usersRef.get();
        if (snapshot.exists) {
          final Map users = snapshot.value as Map;
          String? foundUserId;
          users.forEach((uid, userData) {
            final userMap = Map<String, dynamic>.from(userData);
            final userPhone = _normalizePhoneNumber(userMap['phone'] ?? '');
            if (userPhone == widget.receiverNormalizedPhone && uid != widget.senderId) {
              foundUserId = uid;
            }
          });
          if (foundUserId != null) {
            setState(() {
              _actualReceiverId = foundUserId;
              _isRegisteredUser = true;
            });
          } else {
            setState(() {
              _actualReceiverId = 'contact_${widget.receiverNormalizedPhone}';
              _isRegisteredUser = false;
            });
          }
        }
      } catch (e) {
        print("Error checking if contact is registered: $e");
        setState(() {
          _actualReceiverId = 'contact_${widget.receiverNormalizedPhone}';
          _isRegisteredUser = false;
        });
      }
    }
  }

  void _setupReceiverStatusListener() {
    if (_actualReceiverId == null) return;
    _receiverStatusSubscription = _usersRef.child(_actualReceiverId!).onValue.listen((event) {
      if (event.snapshot.exists) {
        final userData = Map<String, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          _receiverOnline = userData['isOnline'] ?? false;
          final lastSeen = userData['lastSeen'];
          if (lastSeen != null) {
            if (lastSeen is int) {
              final date = DateTime.fromMillisecondsSinceEpoch(lastSeen);
              _receiverLastSeen = _formatLastSeen(date);
            } else {
              _receiverLastSeen = '';
            }
          } else {
            _receiverLastSeen = '';
          }
        });

        // When receiver comes online, update sent messages to delivered
        if (_receiverOnline) {
          _updateSentMessagesToDelivered();
        }
      }
    });
  }

  Future<void> _updateSentMessagesToDelivered() async {
    try {
      for (var message in _messages) {
        if (message["senderId"] == widget.senderId && message["status"] == "sent") {
          await _messagesRef
              .child(_chatId)
              .child(message["id"])
              .update({"status": "delivered"});
        }
      }
    } catch (e) {
      print("Error updating messages to delivered: $e");
    }
  }

  String _formatLastSeen(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _normalizePhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('91') && cleaned.length > 10) {
      cleaned = cleaned.substring(2);
    }
    if (cleaned.length > 10) {
      cleaned = cleaned.substring(cleaned.length - 10);
    }
    return cleaned;
  }

  String get _chatId {
    if (_actualReceiverId == null) return '';
    if (!_isRegisteredUser) {
      return 'contact_${widget.senderId}_${widget.receiverNormalizedPhone}';
    } else {
      List<String> ids = [widget.senderId, _actualReceiverId!];
      ids.sort();
      return ids.join('_');
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _receiverStatusSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    _suggestionsAnimationController.dispose();
    _messageAnimationController.dispose();
    _typingTimer?.cancel();
    _statusUpdateTimer?.cancel();

    // Cancel all message status timers
    for (var timer in _messageStatusTimers.values) {
      timer.cancel();
    }
    _messageStatusTimers.clear();

    if (_isRegisteredUser) {
      _updateUserOnlineStatus(false);
    }
    super.dispose();
  }

  void _updateUserOnlineStatus(bool isOnline) async {
    try {
      final userRef = FirebaseDatabase.instance.ref().child("users").child(widget.senderId);
      Map<String, dynamic> updateData = {
        "isOnline": isOnline,
      };
      if (!isOnline) {
        updateData["lastSeen"] = ServerValue.timestamp;
      }
      await userRef.update(updateData);
    } catch (e) {
      print("Error updating online status: $e");
    }
  }

  void _setupMessagesListener() {
    if (_chatId.isEmpty) return;
    _messagesSubscription = _messagesRef
        .child(_chatId)
        .orderByChild("timestamp")
        .onValue
        .listen((event) {
      final Map<String, dynamic> messagesMap = {};
      if (event.snapshot.value != null) {
        messagesMap.addAll(Map<String, dynamic>.from(event.snapshot.value as Map));
      }
      List<Map<String, dynamic>> loadedMessages = [];
      messagesMap.forEach((key, value) {
        loadedMessages.add({
          "id": key,
          ...Map<String, dynamic>.from(value),
        });
      });
      loadedMessages.sort((a, b) {
        final aTime = a["timestamp"] ?? 0;
        final bTime = b["timestamp"] ?? 0;
        return aTime.compareTo(bTime);
      });
      if (mounted) {
        setState(() {
          _messages = loadedMessages;
          _isLoading = false;
        });
        _scrollToBottom();
        if (_isRegisteredUser) {
          _markMessagesAsRead();
        }
      }
    }, onError: (error) {
      print("Error loading messages: $error");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _markMessagesAsRead() async {
    try {
      for (var message in _messages) {
        if (message["senderId"] != widget.senderId && message["status"] != "read") {
          await _messagesRef.child(_chatId).child(message["id"]).update({"status": "read"});
        }
      }
    } catch (e) {
      print("Error marking messages as read: $e");
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: animated ? const Duration(milliseconds: 300) : Duration.zero,
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getRecentConversationContext() {
    if (_messages.isEmpty) return "No previous messages. Start a new conversation.";
    // Focus on last message for reply
    final lastMessage = _messages.last;
    final recentMessages = _messages.length > 3 ? _messages.sublist(_messages.length - 3) : _messages;
    String context = "Recent conversation (last few messages):\n";
    for (var msg in recentMessages) {
      String sender = msg["senderId"] == widget.senderId ? "Me" : "Other";
      context += "$sender: ${msg['content']}\n";
    }
    context += "\nThe last message from the other person is: ${lastMessage['content']}";
    return context;
  }

  Future<void> _generateAISuggestions() async {
    if (_messages.isEmpty) {
      setState(() {
        _suggestions = [
          "Hello! How are you? 👋",
          "Hi, nice to meet you! 😊",
          "Hey, what's up? ✨"
        ];
        _showSuggestions = true;
        _suggestionsAnimationController.forward(from: 0.0);
      });
      return;
    }
    setState(() {
      _isLoadingSuggestions = true;
      _showSuggestions = true;
      _suggestionsAnimationController.forward(from: 0.0);
    });
    try {
      String conversationContext = _getRecentConversationContext();
      String prompt = """
First, analyze the primary language used in the recent conversation (detect if it's primarily Tamil, English, Hindi, or a mix like Tanglish). 

Then, based on that detected language, suggest exactly 3 short, natural, and contextually suitable replies to the last message from the other person. All 3 suggestions must be in the same detected primary language (or the mix if Tanglish). 

Keep each reply friendly, relevant to the context, under 60 characters, and suitable as a direct response to the last message. Do not mix languages across suggestions.

$conversationContext

Detected language: [Your detection here]

My 3 suggested replies in that language (numbered 1-3, just the replies):
      """;
      final response = await http.post(
        Uri.parse('$gemmaApiUrl?key=$gemmaApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 200,
            'topK': 40,
            'topP': 0.95,
          }
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String aiResponse = data['candidates'][0]['content']['parts'][0]['text'] ?? '';
        List<String> suggestions = _parseAISuggestions(aiResponse);
        setState(() {
          _suggestions = suggestions;
          _isLoadingSuggestions = false;
        });
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print("Error generating suggestions: $e");
      setState(() {
        _suggestions = _getFallbackSuggestions();
        _isLoadingSuggestions = false;
      });
    }
  }

  List<String> _parseAISuggestions(String aiResponse) {
    List<String> suggestions = [];
    RegExp regex = RegExp(r'\d+\.\s*(.+?)(?=\d+\.|$)', dotAll: true);
    Iterable<Match> matches = regex.allMatches(aiResponse);
    if (matches.isNotEmpty) {
      for (var match in matches) {
        String suggestion = match.group(1)?.trim() ?? '';
        if (suggestion.isNotEmpty) {
          suggestions.add(suggestion);
        }
      }
    }
    if (suggestions.isEmpty) {
      suggestions = aiResponse
          .split('\n')
          .where((line) => line.trim().isNotEmpty && !line.contains('1.') && !line.contains('2.') && !line.contains('3.'))
          .map((line) => line.trim())
          .toList();
    }
    while (suggestions.length < 3) {
      suggestions.addAll(_getFallbackSuggestions());
    }
    return suggestions.take(3).toList();
  }

  List<String> _getFallbackSuggestions() {
    return [
      "Okay 👍",
      "Sounds good! 😊",
      "Let me think about it... 🤔",
      "சரி (Sari) 👍",
      "ठीक है (Theek hai) 👌",
      "அப்படியா? (Appadiya?) 🤔",
      "Nice! ✨",
      "I understand 💭",
      "Will get back to you 📝"
    ]..shuffle();
  }

  void _toggleSuggestions() {
    if (!_showSuggestions) {
      _generateAISuggestions();
    } else {
      _suggestionsAnimationController.reverse().then((_) {
        setState(() {
          _showSuggestions = false;
        });
      });
    }
  }

  void _useSuggestion(String suggestion) {
    _messageController.text = suggestion;
    _suggestionsAnimationController.reverse().then((_) {
      setState(() {
        _showSuggestions = false;
      });
    });
    _simulateTyping();
  }

  void _simulateTyping() {
    setState(() => _isReceiverTyping = true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isReceiverTyping = false);
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending || _actualReceiverId == null) return;
    setState(() {
      _isSending = true;
    });
    try {
      final messageContent = _messageController.text.trim();
      final messageData = {
        "senderId": widget.senderId,
        "senderName": widget.senderName,
        "receiverId": _actualReceiverId,
        "receiverName": widget.receiverName,
        "receiverPhone": widget.receiverPhone,
        "content": messageContent,
        "status": "sent",
        "type": "text",
        "isRegisteredUser": _isRegisteredUser,
      };
      final newMessageRef = _messagesRef.child(_chatId).push();
      await newMessageRef.set({
        ...messageData,
        "timestamp": ServerValue.timestamp,
      });

      // If receiver is online, mark as delivered immediately
      if (_receiverOnline) {
        Future.delayed(const Duration(seconds: 1), () {
          _markMessageAsDelivered(newMessageRef.key!);
        });
      }

      await _updateRecentChats(messageContent);
      _messageController.clear();
      setState(() {
        _isSending = false;
      });
      if (_showSuggestions) {
        _suggestionsAnimationController.reverse().then((_) {
          setState(() {
            _showSuggestions = false;
          });
        });
      }
    } catch (e) {
      print("Error sending message: $e");
      setState(() {
        _isSending = false;
      });
      if (mounted) {
        _showAnimatedSnackBar(context, "Failed to send message", isError: true);
      }
    }
  }

  Future<void> _updateRecentChats(String lastMessage) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      Map<String, dynamic> senderData = {
        "userId": _actualReceiverId,
        "name": widget.receiverName,
        "phone": widget.receiverPhone,
        "normalizedPhone": widget.receiverNormalizedPhone,
        "lastMessage": lastMessage,
        "lastMessageTime": now,
        "unreadCount": 0,
        "isRegisteredUser": _isRegisteredUser,
      };
      await _recentChatsRef
          .child(widget.senderId)
          .child(_actualReceiverId!)
          .set(senderData);
      if (_isRegisteredUser) {
        final receiverRef = _recentChatsRef
            .child(_actualReceiverId!)
            .child(widget.senderId);
        final snapshot = await receiverRef.get();
        int unreadCount = 1;
        if (snapshot.exists) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          unreadCount = (data["unreadCount"] ?? 0) + 1;
        }
        Map<String, dynamic> receiverData = {
          "userId": widget.senderId,
          "name": widget.senderName,
          "phone": widget.receiverPhone,
          "normalizedPhone": _normalizePhoneNumber(widget.receiverPhone),
          "lastMessage": lastMessage,
          "lastMessageTime": now,
          "unreadCount": unreadCount,
          "isRegisteredUser": true,
        };
        await receiverRef.set(receiverData);
      }
    } catch (e) {
      print("Error updating recent chats: $e");
    }
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    if (message["senderId"] != widget.senderId) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildAnimatedOptionTile(
              icon: Icons.delete,
              color: Colors.red,
              title: 'Delete Message',
              subtitle: 'Remove this message',
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message["id"]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 300),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: color.withOpacity(0.05),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(subtitle),
              onTap: onTap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _messagesRef.child(_chatId).child(messageId).remove();
      if (mounted) {
        _showAnimatedSnackBar(context, 'Message deleted');
      }
    } catch (e) {
      print("Error deleting message: $e");
      if (mounted) {
        _showAnimatedSnackBar(context, 'Error deleting message', isError: true);
      }
    }
  }

  void _showAnimatedSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  String _formatMessageTime(dynamic timestamp) {
    if (timestamp == null) return "";
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      if (now.difference(date).inDays > 0) {
        return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.day}/${date.month}";
      } else {
        return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
      }
    } catch (e) {
      return "";
    }
  }

  Widget _buildStatusIcon(String status, Color color) {
    switch (status) {
      case 'sent':
        return Icon(Icons.check, size: 12, color: color.withOpacity(0.7));
      case 'delivered':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 12, color: color.withOpacity(0.7)),
            Icon(Icons.check, size: 12, color: color.withOpacity(0.7)),
          ],
        );
      case 'read':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, size: 12, color: Colors.blue),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _getContactStatus() {
    if (_actualReceiverId == null) return "Loading...";
    if (_isRegisteredUser) {
      return _receiverOnline ? "Online" : (_receiverLastSeen.isNotEmpty ? "Last seen $_receiverLastSeen" : "Offline");
    }
    return "Contact";
  }

  void _showThemeOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.palette, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            const Text('Chat Theme'),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption('light', Icons.wb_sunny, 'Light', Colors.amber),
            const Divider(height: 1),
            _buildThemeOption('dark', Icons.nightlight_round, 'Dark', Colors.indigo),
            const Divider(height: 1),
            _buildThemeOption('system', Icons.settings, 'System', Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String value, IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {
        setState(() {
          _chatTheme = value;
        });
        _saveUserPreferences();
        Navigator.pop(context);
        _showAnimatedSnackBar(context, 'Theme set to $label');
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            if (_chatTheme == value)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  void _showBackgroundOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.image, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            const Text('Chat Background'),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBackgroundOption('default', Icons.gradient, 'Default Gradient'),
            const Divider(height: 1),
            _buildBackgroundOption('plain', Icons.color_lens, 'Plain Color'),
            const Divider(height: 1),
            _buildBackgroundOption('image', Icons.wallpaper, 'Custom Image'),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundOption(String value, IconData icon, String label) {
    final isSelected = _chatBackground == value;
    return InkWell(
      onTap: () async {
        setState(() {
          _chatBackground = value;
        });
        if (value == 'plain') {
          _showColorPickerDialog();
        } else if (value == 'image') {
          await _pickBackgroundImage();
        } else {
          _saveUserPreferences();
          Navigator.pop(context);
          _showAnimatedSnackBar(context, 'Background set to $label');
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBackgroundImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedBackgroundImage = File(image.path);
          _customBackgroundImage = image.path;
        });
        _saveUserPreferences();
        if (mounted) {
          Navigator.pop(context); // Close background options
          _showAnimatedSnackBar(context, 'Background image updated');
        }
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted) {
        _showAnimatedSnackBar(context, 'Failed to pick image', isError: true);
      }
    }
  }

  void _showColorPickerDialog() {
    List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Background Color'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: colors.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () {
                  setState(() {
                    _customBackgroundColor = colors[index];
                  });
                  _saveUserPreferences();
                  Navigator.pop(context); // Close color picker
                  Navigator.pop(context); // Close background options
                  _showAnimatedSnackBar(context, 'Background color updated');
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors[index],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors[index].withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Apply theme based on selection
    ThemeData chatThemeData;
    switch (_chatTheme) {
      case 'dark':
        chatThemeData = ThemeData.dark();
        break;
      case 'light':
      default:
        chatThemeData = ThemeData.light();
        break;
    }

    return Theme(
      data: chatThemeData,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: _actualReceiverId == null
            ? _buildLoadingScreen(colorScheme)
            : Stack(
          children: [
            // Background with custom options
            Container(
              decoration: BoxDecoration(
                gradient: _chatBackground == 'default'
                    ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primary.withOpacity(0.05),
                    colorScheme.surface,
                  ],
                )
                    : _chatBackground == 'plain' && _customBackgroundColor != null
                    ? LinearGradient(
                  colors: [
                    _customBackgroundColor!.withOpacity(0.1),
                    _customBackgroundColor!.withOpacity(0.05),
                  ],
                )
                    : _chatBackground == 'image' && _customBackgroundImage != null
                    ? null
                    : LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.05),
                    colorScheme.surface,
                  ],
                ),
                image: _chatBackground == 'image' && _customBackgroundImage != null
                    ? DecorationImage(
                  image: _selectedBackgroundImage != null
                      ? FileImage(_selectedBackgroundImage!)
                      : AssetImage(_customBackgroundImage!) as ImageProvider,
                  fit: BoxFit.cover,
                  opacity: 0.1,
                )
                    : null,
              ),
            ),
            // Main content
            Column(
              children: [
                _buildAnimatedAppBar(colorScheme),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingScreen(colorScheme)
                      : _messages.isEmpty
                      ? _buildEmptyChatScreen(colorScheme)
                      : _buildMessagesList(colorScheme),
                ),
                if (_showSuggestions)
                  _buildSuggestionsPanel(colorScheme),
                _buildMessageInput(colorScheme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedAppBar(ColorScheme colorScheme) {
    return SlideTransition(
      position: _messageSlideAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Hero(
                  tag: 'avatar_${widget.receiverName}',
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      (widget.receiverName.isNotEmpty ? widget.receiverName[0] : "?").toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.receiverName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isRegisteredUser ? (_receiverOnline ? Colors.green : Colors.grey) : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _getContactStatus(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isRegisteredUser) ...[
                  IconButton(
                    icon: const Icon(Icons.palette_outlined, color: Colors.white, size: 20),
                    onPressed: _showThemeOptions,
                  ),
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: Colors.white, size: 20),
                    onPressed: _showBackgroundOptions,
                  ),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _typingAnimationController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: 0.3 + (_typingAnimationController.value * 0.7),
                        child: const Icon(
                          Icons.circle,
                          color: Colors.white,
                          size: 8,
                        ),
                      );
                    },
                  ),
                ] else
                  IconButton(
                    icon: const Icon(Icons.palette_outlined, color: Colors.white, size: 20),
                    onPressed: _showThemeOptions,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder(
            duration: const Duration(seconds: 2),
            tween: Tween<double>(begin: 0.0, end: 2.0),
            builder: (context, double value, child) {
              return Transform.rotate(
                angle: value * 3.14159,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: SweepGradient(
                      colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.chat_bubble_outline, color: Colors.white),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            "Initializing chat...",
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatScreen(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder(
            duration: const Duration(seconds: 2),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: colorScheme.primary.withOpacity(0.5),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 800),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            builder: (context, double value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Column(
                    children: [
                      Text(
                        "No messages yet",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRegisteredUser
                            ? "Say hello to ${widget.receiverName} 👋"
                            : "Send a message to this contact 💬",
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ColorScheme colorScheme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message["senderId"] == widget.senderId;
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 30)),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, double value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(isMe ? 50 * (1 - value) : -50 * (1 - value), 0),
                child: _buildMessageBubble(message, isMe, colorScheme),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe, ColorScheme colorScheme) {
    final status = message["status"] ?? "sent";
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8,
          left: isMe ? 50 : 0,
          right: isMe ? 0 : 50,
        ),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) _buildAvatar(widget.receiverName, _isRegisteredUser, colorScheme),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? colorScheme.primary
                      : _isRegisteredUser
                      ? colorScheme.surfaceVariant
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isMe ? colorScheme.primary : colorScheme.surfaceVariant).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      message["content"] ?? "",
                      style: TextStyle(
                        color: isMe
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatMessageTime(message["timestamp"]),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? colorScheme.onPrimary.withOpacity(0.7)
                                : colorScheme.outline,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _buildStatusIcon(status, isMe ? colorScheme.onPrimary : colorScheme.outline),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isMe) _buildAvatar(widget.senderName, true, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, bool isRegistered, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: isRegistered
            ? colorScheme.primaryContainer
            : Colors.orange.withOpacity(0.3),
        child: Text(
          (name.isNotEmpty ? name[0] : "?").toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            color: isRegistered
                ? colorScheme.onPrimaryContainer
                : Colors.orange,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsPanel(ColorScheme colorScheme) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _suggestionsAnimationController,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(
        opacity: _suggestionsFadeAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, -4),
                blurRadius: 20,
                color: Colors.black.withOpacity(0.1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.auto_awesome, size: 16, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Smart Replies",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: colorScheme.outline),
                    onPressed: _toggleSuggestions,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _isLoadingSuggestions
                  ? _buildLoadingSuggestions(colorScheme)
                  : _buildSuggestionChips(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSuggestions(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _typingAnimationController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(
                          0.3 + (_typingAnimationController.value * 0.7),
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(width: 12),
            Text(
              "Generating suggestions...",
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChips(ColorScheme colorScheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _suggestions.map((suggestion) {
        return TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          curve: Curves.elasticOut,
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _useSuggestion(suggestion),
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withOpacity(0.1),
                          colorScheme.primary.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      suggestion,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildMessageInput(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 8,
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI Suggestion Button with animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.elasticOut,
            decoration: BoxDecoration(
              color: _showSuggestions
                  ? colorScheme.primary
                  : colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _showSuggestions ? Icons.close : Icons.auto_awesome,
                  key: ValueKey<bool>(_showSuggestions),
                  color: _showSuggestions
                      ? colorScheme.onPrimary
                      : colorScheme.primary,
                  size: 20,
                ),
              ),
              onPressed: _toggleSuggestions,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Text Field with animation
          Expanded(
            child: TweenAnimationBuilder(
              duration: const Duration(milliseconds: 200),
              tween: Tween<double>(begin: 0.95, end: 1.0),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: colorScheme.onSurface),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(color: colorScheme.outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (text) {
                        if (text.isNotEmpty) {
                          _simulateTyping();
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          // Send Button with animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.elasticOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withBlue(200),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: IconButton(
              icon: _isSending
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _isSending ? null : _sendMessage,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
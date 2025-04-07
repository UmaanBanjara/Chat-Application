import 'package:flutter/material.dart';
import 'package:flutter_application_1/data/models/chat_message_model.dart';
import 'package:flutter_application_1/data/service/service_locator.dart';
import 'package:flutter_application_1/logic/chat/chat_cubit.dart';
import 'package:flutter_application_1/logic/chat/chat_state.dart';
import 'package:flutter_application_1/presentation/widgets/loading_dots.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class ChatMessageScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatMessageScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatMessageScreen> createState() => _ChatMessageScreenState();
}

class _ChatMessageScreenState extends State<ChatMessageScreen> {
  final TextEditingController messageController = TextEditingController();
  final scrollController = ScrollController();
  final FocusNode focusNode = FocusNode(); // ✅ Added FocusNode
  late final ChatCubit chatCubit;

  bool isComposing = false;
  bool showemoji = false;
  List<ChatMessage> previousMessages = [];

  @override
  void initState() {
    super.initState();
    chatCubit = getIt<ChatCubit>();
    chatCubit.enterChat(widget.receiverId);
    messageController.addListener(onTextChanged);
    scrollController.addListener(onScroll);
  }

  @override
  void dispose() {
    messageController.dispose();
    chatCubit.leaveChat();
    scrollController.dispose();
    focusNode.dispose(); // ✅ Dispose focusNode
    super.dispose();
  }

  void onScroll() {
    if (scrollController.position.pixels <= 200) {
      chatCubit.loadmoremessages();
    }
  }

  void onTextChanged() {
    final composing = messageController.text.isNotEmpty;
    if (composing != isComposing) {
      setState(() {
        isComposing = composing;
      });
    }

    if (composing) {
      chatCubit.startTyping();
    }
  }

  Future<void> handleSendMessage() async {
    final messageText = messageController.text.trim();
    if (messageText.isEmpty) return;
    messageController.clear();
    setState(() {});
    await chatCubit.sendMessage(
      content: messageText,
      receiverId: widget.receiverId,
    );
  }

  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.minScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void hasNewMessages(List<ChatMessage> messages) {
    if (messages.length != previousMessages.length) {
      scrollToBottom();
      previousMessages = List.from(messages);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : 'N'),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.receiverName.isNotEmpty ? widget.receiverName : 'Unknown'),
                BlocBuilder<ChatCubit, ChatState>(
                  bloc: chatCubit,
                  builder: (context, state) {
                    if (state.isreceiverTyping) {
                      return const LoadingDots();
                    }
                    if (state.isreceiverOnline) {
                      return Text("Online", style: TextStyle(color: Colors.green));
                    }
                    if (state.receiverlaseseen != null) {
                      final lastSeen = state.receiverlaseseen!.toDate();
                      return Text(
                        "Last seen: ${lastSeen.hour % 12 == 0 ? 12 : lastSeen.hour % 12}:${lastSeen.minute.toString().padLeft(2, '0')} ${lastSeen.hour >= 12 ? 'PM' : 'AM'}",
                      );
                    }
                    return SizedBox();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      body: BlocConsumer<ChatCubit, ChatState>(
        bloc: chatCubit,
        listener: (context, state) => hasNewMessages(state.messages),
        builder: (context, state) {
          if (state.status == ChatStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == ChatStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.error ?? "Something went wrong"),
                  ElevatedButton(
                    onPressed: () => chatCubit.enterChat(widget.receiverId),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              if (state.amiblocked)
                Container(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    "You have been blocked by ${widget.receiverName}",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              Expanded(
                child: state.messages.isEmpty
                    ? Center(child: Text("No messages yet"))
                    : ListView.builder(
                        controller: scrollController,
                        reverse: true,
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final message = state.messages[index];
                          final isMe = message.senderId == chatCubit.currentUserId;
                          return MessageBubble(message: message, isMe: isMe);
                        },
                      ),
              ),
              if (!state.amiblocked && !state.isuserblocked)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            showemoji = !showemoji;
                            if (showemoji) {
                              focusNode.unfocus(); // ✅ Hide keyboard
                            } else {
                              focusNode.requestFocus(); // ✅ Show keyboard
                            }
                          });
                        },
                        icon: const Icon(Icons.emoji_emotions),
                      ),
                      Expanded(
                        child: TextField(
                          controller: messageController,
                          focusNode: focusNode, // ✅ Set the focus node
                          decoration: InputDecoration(
                            hintText: "Type a message",
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: isComposing ? handleSendMessage : null,
                        icon: Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              if (showemoji)
                Container(
                  height: 250,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: Text(
                      "🙂 Emoji keyboard placeholder",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 64 : 8,
          right: isMe ? 8 : 64,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).primaryColor
              : Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(color: isMe ? Colors.white : Colors.black),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm a').format(message.timestamp.toDate()),
                  style: TextStyle(color: isMe ? Colors.white : Colors.black),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color: message.status == MessageStatus.read ? Colors.red : Colors.white70,
                  )
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}

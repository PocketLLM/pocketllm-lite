import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/chat_app_bar.dart';
import 'widgets/chat_body.dart';
import 'widgets/chat_input.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const ChatAppBar(),
      body: Column(
        children: [
          const Expanded(child: ChatBody()),
          const ChatInput(),
        ],
      ),
    );
  }
}

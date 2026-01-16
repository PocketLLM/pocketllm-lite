import 'package:flutter/material.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_body.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: ChatAppBar(),
      body: ChatBodyContent(),
    );
  }
}

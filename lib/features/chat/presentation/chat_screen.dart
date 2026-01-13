import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers.dart';
import '../../../services/usage_limits_provider.dart';
import '../../../services/ad_service.dart';
import 'providers/chat_provider.dart';
import 'providers/models_provider.dart';
import 'providers/connection_status_provider.dart';

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
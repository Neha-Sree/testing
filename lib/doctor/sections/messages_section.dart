import 'package:flutter/material.dart';

import '../../chat_list_screen.dart';

class MessagesSection extends StatelessWidget {
  const MessagesSection({super.key, required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context) {
    return ChatListScreen(currentUserId: doctorId, currentUserType: 'doctor');
  }
}

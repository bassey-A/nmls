import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'user_service.dart';

// Data model for a conversation
class Conversation {
  final String id;
  final List<String> participants;
  final String lastMessage;

  Conversation({required this.id, required this.participants, required this.lastMessage});

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? 'No messages yet.',
    );
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Messages')),
      body: Consumer<UserService>(
        builder: (context, userService, child) {
          if (userService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userService.student == null) {
            return const Center(child: Text("Please log in to see messages."));
          }

          return StreamBuilder<QuerySnapshot>(
            // Query for conversations where the student's ID is in the 'participants' array
            stream: FirebaseFirestore.instance
                .collection('conversations')
                .where('participants', arrayContains: userService.student!.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("You have no messages."));
              }

              final conversations = snapshot.data!.docs.map((doc) => Conversation.fromFirestore(doc)).toList();

              return ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  // A simple display showing the participant count and last message
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${conversation.participants.length}')),
                      title: Text('Conversation with ${conversation.participants.length -1} others'),
                      subtitle: Text(conversation.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        // TODO: Navigate to a detailed chat view
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/colors.dart';
import '../services/firestore_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirestoreService _firestore = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: AppColors.textLight),
                  SizedBox(height: 16),
                  Text('No notifications', style: TextStyle(color: AppColors.textLight)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              final isRead = data['is_read'] ?? false;
              final title = data['title'] ?? '';
              final message = data['message'] ?? '';
              final createdAt = data['created_at'] as Timestamp?;
              final dateStr = createdAt != null
                  ? DateFormat('MMM dd, yyyy – hh:mm a').format(createdAt.toDate())
                  : '';

              return Card(
                color: isRead ? Colors.white : AppColors.primary.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead ? Colors.grey[300] : AppColors.primary,
                    child: Icon(
                      Icons.notifications,
                      color: isRead ? Colors.grey[600] : Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 10, color: AppColors.textLight),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isRead)
                        IconButton(
                          icon: const Icon(Icons.check, color: AppColors.primary),
                          onPressed: () => _markAsRead(id),
                          tooltip: 'Mark as read',
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteNotification(id),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                  onTap: () => _markAsRead(id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _markAsRead(String id) async {
    await _firestore.markNotificationAsRead(id);
  }

  Future<void> _markAllAsRead() async {
    await _firestore.markAllNotificationsAsRead();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _deleteNotification(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deleteNotification(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
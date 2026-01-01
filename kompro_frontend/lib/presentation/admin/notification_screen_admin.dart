import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/services/auth_service.dart';

class NotificationScreenAdmin extends StatefulWidget {
  final int userId;
  const NotificationScreenAdmin({super.key, required this.userId});

  @override
  State<NotificationScreenAdmin> createState() =>
      _NotificationScreenAdminState();
}

class _NotificationScreenAdminState extends State<NotificationScreenAdmin> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotif();
  }

  // Fetches all general notifications from the server
  Future<void> _fetchNotif() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _authService.getAllNotificationsGeneral();
      setState(() {
        _notifications = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Failed to load data: $e", Colors.red);
      }
    }
  }

  // Shows a confirmation dialog before deleting a notification
  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Delete Announcement?"),
            content: const Text("Deleted data cannot be recovered."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _handleDelete(id);
                },
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  // Handles the deletion logic by calling the API and refreshing the list
  Future<void> _handleDelete(int id) async {
    try {
      await _authService.deleteNotification(id);
      _showSnackBar("Announcement successfully deleted", Colors.orange);
      _fetchNotif();
    } catch (e) {
      _showSnackBar("Delete failed: $e", Colors.red);
    }
  }

  // Displays a dialog with input fields to create and broadcast a new notification
  void _showAddDialog() {
    final titleController = TextEditingController();
    final msgController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Text(
              "Create New Announcement",
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: "Title",
                    hintText: "e.g., System Maintenance",
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: msgController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Message",
                    hintText: "Announcement content...",
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () async {
                  if (titleController.text.isNotEmpty &&
                      msgController.text.isNotEmpty) {
                    await _authService.addNotificationGeneral(
                      titleController.text,
                      msgController.text,
                    );
                  }
                },
                child: const Text(
                  "Send to All",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  // Helper function to show snackbar messages
  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Manage Notifications",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _fetchNotif,
                child:
                    _notifications.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                          // Standard mobile horizontal padding (20)
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          itemCount: _notifications.length,
                          itemBuilder:
                              (context, index) =>
                                  _buildNotifCard(_notifications[index]),
                        ),
              ),
    );
  }

  // Builds the individual UI card for a notification entry
  Widget _buildNotifCard(Map<String, dynamic> data) {
    String timeLabel = "-";
    if (data['createdAt'] != null) {
      DateTime dt = DateTime.parse(data['createdAt']).toLocal();
      timeLabel = DateFormat('dd MMM yyyy, HH:mm').format(dt);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeLabel,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 22,
                ),
                onPressed: () => _confirmDelete(data['notificationId']),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data['title'] ?? "",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data['message'] ?? "",
            style: TextStyle(
              color: Colors.grey[700],
              height: 1.4,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Builds a placeholder UI when no notifications are available
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 80,
            color: Colors.grey[200],
          ),
          const SizedBox(height: 10),
          const Text(
            "No announcements yet",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

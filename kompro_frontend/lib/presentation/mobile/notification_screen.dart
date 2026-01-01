import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/services/auth_service.dart';

class UserNotificationScreen extends StatefulWidget {
  final int userId;
  const UserNotificationScreen({super.key, required this.userId});

  @override
  State<UserNotificationScreen> createState() => _UserNotificationScreenState();
}

class _UserNotificationScreenState extends State<UserNotificationScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotif();
  }

  // mengambil seluruh data pengumuman umum dari backend
  Future<void> _fetchNotif() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await _authService.getAllNotificationsGeneral();

      if (!mounted) return;

      setState(() {
        _notifications = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint("Error fetching notifications: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Information Center",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2196F3),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _fetchNotif,
                color: const Color(0xFF2196F3),
                child:
                    _notifications.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            return _buildNotificationCard(
                              _notifications[index],
                            );
                          },
                        ),
              ),
    );
  }

  // membangun kartu informasi notifikasi secara individu
  Widget _buildNotificationCard(Map<String, dynamic> data) {
    String formattedDate = "-";

    if (data['createdAt'] != null) {
      try {
        DateTime dt = DateTime.parse(data['createdAt']).toLocal();
        formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(dt);
      } catch (e) {
        formattedDate = data['createdAt'].toString();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.campaign_rounded, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    "ANNOUNCEMENT",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Text(
                formattedDate,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data['title'] ?? "Latest Information",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data['message'] ?? "No description provided.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // tampilan ketika data pengumuman kosong atau tidak ditemukan
  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 80,
                color: Colors.grey[200],
              ),
              const SizedBox(height: 16),
              const Text(
                "No new announcements",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

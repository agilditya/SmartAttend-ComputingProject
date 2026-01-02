import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/services/auth_service.dart';
import 'dashboard_screen.dart';

class HistoryScreen extends StatefulWidget {
  final int userId;

  const HistoryScreen({super.key, required this.userId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  Map<String, List<Map<String, String>>> _groupedHistory = {};

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  // Mengambil data riwayat kehadiran dan mengelompokkannya berdasarkan tanggal
  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final List<dynamic> rawData = await _authService.getAttendance(
        widget.userId,
      );

      // Cek mounted setelah await untuk menghindari error BuildContext
      if (!mounted) return;

      Map<String, List<Map<String, String>>> grouped = {};
      Map<String, Map<String, dynamic>> dailySessions = {};

      for (var record in rawData) {
        DateTime ts = DateTime.parse(record['timestamp']).toLocal();
        String dateKey = DateFormat('yyyy-MM-dd').format(ts);

        if (!dailySessions.containsKey(dateKey)) {
          dailySessions[dateKey] = {
            "date": ts,
            "checkIn": "--:--",
            "checkOut": "--:--",
            "checkInTime": null,
            "checkOutTime": null,
          };
        }

        String timeStr = DateFormat('HH:mm').format(ts);
        if (record['type'] == 'check-in') {
          dailySessions[dateKey]!['checkIn'] = timeStr;
          dailySessions[dateKey]!['checkInTime'] = ts;
        } else if (record['type'] == 'checkout') {
          dailySessions[dateKey]!['checkOut'] = timeStr;
          dailySessions[dateKey]!['checkOutTime'] = ts;
        }
      }

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final yesterdayStr = DateFormat(
        'yyyy-MM-dd',
      ).format(now.subtract(const Duration(days: 1)));

      dailySessions.forEach((key, value) {
        String groupLabel;
        if (key == todayStr) {
          groupLabel = "Today";
        } else if (key == yesterdayStr) {
          groupLabel = "Yesterday";
        } else {
          groupLabel = DateFormat('EEEE, d MMM yyyy').format(value['date']);
        }

        String duration = "-";
        if (value['checkInTime'] != null && value['checkOutTime'] != null) {
          Duration diff = (value['checkOutTime'] as DateTime).difference(
            value['checkInTime'] as DateTime,
          );
          int hours = diff.inHours;
          int minutes = diff.inMinutes.remainder(60);
          duration = "${hours}h ${minutes}m";
        } else if (value['checkInTime'] != null && key == todayStr) {
          duration = "On process";
        }

        if (!grouped.containsKey(groupLabel)) grouped[groupLabel] = [];
        grouped[groupLabel]!.add({
          "checkIn": value['checkIn'],
          "checkOut": value['checkOut'],
          "duration": duration,
        });
      });

      setState(() {
        _groupedHistory = grouped;
      });
    } catch (e) {
      debugPrint("Error History: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                        onRefresh: _fetchHistory,
                        child:
                            _groupedHistory.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    120,
                                  ),
                                  itemCount: _groupedHistory.length,
                                  itemBuilder: (context, index) {
                                    String key = _groupedHistory.keys.elementAt(
                                      index,
                                    );
                                    List<Map<String, String>> items =
                                        _groupedHistory[key]!;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionLabel(key),
                                        ...items.map(
                                          (item) => _buildHistoryCard(item),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    );
                                  },
                                ),
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // Widget bagian atas berisi judul layar riwayat
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFE3F2FD),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: const Center(
        child: Text(
          "History",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2196F3),
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  // Widget label teks untuk pengelompokan tanggal riwayat
  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10.0, left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // Widget kartu riwayat yang berisi jam masuk, keluar, dan durasi kerja
  Widget _buildHistoryCard(Map<String, String> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _rowItem("Check in", data['checkIn']!, true),
          const SizedBox(height: 12),
          _rowItem("Check out", data['checkOut']!, false),
          const Divider(height: 24, color: Color(0xFFF0F0F0)),
          _rowItem("Duration", data['duration']!, false, isDuration: true),
        ],
      ),
    );
  }

  // Widget baris item generik untuk menampilkan label dan nilai data
  Widget _rowItem(
    String label,
    String value,
    bool isFirst, {
    bool isDuration = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDuration ? const Color(0xFF2196F3) : Colors.black87,
          ),
        ),
      ],
    );
  }

  // Widget tampilan ketika data riwayat kosong
  Widget _buildEmptyState() {
    return const Center(
      child: Text("No history found", style: TextStyle(color: Colors.grey)),
    );
  }

  // Widget tombol aksi utama (Fingerprint) di tengah navigasi
  Widget _buildFab() {
    return SizedBox(
      height: 70,
      width: 70,
      child: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        backgroundColor: const Color(0xFF2196F3),
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.fingerprint, color: Colors.white, size: 32),
      ),
    );
  }

  // Widget navigasi bawah untuk berpindah antara Home dan History
  Widget _buildBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white.withValues(alpha: 0.95),
      elevation: 10,
      height: 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.home_rounded,
            label: "HOME",
            isSelected: false,
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardScreen(userId: widget.userId),
                ),
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 40),
          _buildNavItem(
            icon: Icons.history_rounded,
            label: "HISTORY",
            isSelected: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // Widget pembantu untuk membangun item menu navigasi bawah
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isSelected ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFF2196F3) : Colors.grey[600],
            size: 28,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color(0xFF2196F3) : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

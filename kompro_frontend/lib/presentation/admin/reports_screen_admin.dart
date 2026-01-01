import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/services/auth_service.dart';

class ReportsScreenAdmin extends StatefulWidget {
  const ReportsScreenAdmin({super.key});

  @override
  State<ReportsScreenAdmin> createState() => _ReportsScreenAdminState();
}

class _ReportsScreenAdminState extends State<ReportsScreenAdmin> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  List<dynamic> _users = [];
  List<dynamic> _allAttendance = [];
  List<Map<String, dynamic>> _reportData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Fungsi untuk mengambil data user dan seluruh data presensi dari server secara bersamaan
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _authService.getAllUsers(),
        _authService.getAllAttendance(),
      ]);

      _users = results[0];
      _allAttendance = results[1];

      _generateMonthlyReport();
    } catch (e) {
      debugPrint("Error loading reports: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fungsi untuk memfilter dan menghitung total hari hadir unik per user berdasarkan bulan yang dipilih
  void _generateMonthlyReport() {
    List<Map<String, dynamic>> tempReport = [];

    for (var user in _users) {
      if (user['role'].toString().toLowerCase() != 'user') continue;

      final int uId = user['userId'] ?? user['user_id'] ?? 0;

      final userAttendances = _allAttendance.where((record) {
        DateTime ts = DateTime.parse(record['timestamp']).toLocal();
        bool isSameMonth =
            ts.month == _selectedDate.month && ts.year == _selectedDate.year;
        bool isCheckIn = record['type'] == 'check-in';
        bool isWorkDay =
            ts.weekday >= DateTime.monday && ts.weekday <= DateTime.friday;

        return (record['user_id'] == uId || record['userId'] == uId) &&
            isSameMonth &&
            isCheckIn &&
            isWorkDay;
      });

      int totalUniqueDays =
          userAttendances
              .map(
                (e) => DateFormat(
                  'yyyy-MM-dd',
                ).format(DateTime.parse(e['timestamp'])),
              )
              .toSet()
              .length;

      tempReport.add({
        'name': user['name'] ?? 'Unknown',
        'nimNip': user['nimNip'] ?? user['nim_nip'] ?? '-',
        'total': totalUniqueDays,
      });
    }

    tempReport.sort((a, b) => b['total'].compareTo(a['total']));

    setState(() {
      _reportData = tempReport;
    });
  }

  // Fungsi untuk menampilkan bottom sheet guna memilih bulan dan tahun laporan
  void _showTimePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 400,
              child: Column(
                children: [
                  const Text(
                    "Select Period",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 10,
                      itemBuilder: (context, index) {
                        int year = DateTime.now().year - index;
                        bool isSelected = _selectedDate.year == year;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ChoiceChip(
                            label: Text(year.toString()),
                            selected: isSelected,
                            selectedColor: const Color(0xFF2196F3),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                            onSelected: (val) {
                              setModalState(() {
                                _selectedDate = DateTime(
                                  year,
                                  _selectedDate.month,
                                );
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.5,
                          ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        int month = index + 1;
                        bool isSelected = _selectedDate.month == month;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedDate = DateTime(
                                _selectedDate.year,
                                month,
                              );
                              _generateMonthlyReport();
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? const Color(0xFF2196F3)
                                      : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              DateFormat('MMM').format(DateTime(0, month)),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Attendance Reports",
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
      body: Column(
        children: [
          _buildHeaderSection(),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _reportData.isEmpty
                    ? _buildEmptyState()
                    : _buildReportList(),
          ),
        ],
      ),
    );
  }

  // Widget untuk menampilkan informasi periode laporan yang sedang aktif dan tombol kalender
  Widget _buildHeaderSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Report Period",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMMM yyyy').format(_selectedDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: _showTimePicker,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month, color: Color(0xFF2196F3)),
            ),
          ),
        ],
      ),
    );
  }

  // Widget untuk membangun daftar laporan presensi karyawan menggunakan ListView
  Widget _buildReportList() {
    return ListView.builder(
      itemCount: _reportData.length,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemBuilder: (context, index) {
        final item = _reportData[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE3F2FD),
                child: Text(
                  "${index + 1}",
                  style: const TextStyle(
                    color: Color(0xFF2196F3),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "ID: ${item['nimNip']}",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    "${item['total']}",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const Text(
                    "Days",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget untuk menampilkan tampilan kosong apabila tidak ada data presensi pada periode terpilih
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 10),
          const Text(
            "No attendance data for this period",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

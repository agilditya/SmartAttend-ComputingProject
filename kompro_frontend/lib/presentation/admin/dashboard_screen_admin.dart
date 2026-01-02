import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../data/services/auth_service.dart';
import '/presentation/admin/profile_screen_admin.dart';
import '/presentation/admin/notification_screen_admin.dart';
import '/presentation/admin/reports_screen_admin.dart';
import '/presentation/admin/settingarea_screen_admin.dart';

class AdminDashboardScreen extends StatefulWidget {
  final int userId;
  const AdminDashboardScreen({super.key, required this.userId});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  String _displayName = "Admin";
  String _currentDate = "";
  List<dynamic> _users = [];
  List<dynamic> _allAttendance = [];
  int _totalHadir = 0;
  int _totalUsersOnly = 0;

  @override
  void initState() {
    super.initState();
    _setupDate();
    _fetchAdminData();
  }

  // Fungsi untuk mengatur format tanggal dalam bahasa Indonesia
  Future<void> _setupDate() async {
    await initializeDateFormatting('id_ID', null);
    if (mounted) {
      setState(() {
        _currentDate = DateFormat(
          'EEEE, d MMM yyyy',
          'id_ID',
        ).format(DateTime.now());
      });
    }
  }

  // Fungsi untuk mengambil semua data yang diperlukan admin dari server secara paralel
  Future<void> _fetchAdminData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _authService.getAllUsers(),
        _authService.getAllAttendance(),
        _authService.getUserProfile(widget.userId),
      ]);

      if (mounted) {
        setState(() {
          _users = results[0] as List<dynamic>;
          _allAttendance = results[1] as List<dynamic>;
          final adminData = results[2] as Map<String, dynamic>;
          _displayName = adminData['name']?.toString() ?? "Admin";

          final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final onlyUsers =
              _users
                  .where((u) => u['role'].toString().toLowerCase() == 'user')
                  .toList();
          _totalUsersOnly = onlyUsers.length;

          final hadirSet =
              _allAttendance
                  .where((record) {
                    DateTime ts = DateTime.parse(record['timestamp']).toLocal();
                    final int rId = record['user_id'] ?? record['userId'];
                    bool isUserRole = onlyUsers.any(
                      (u) => (u['userId'] ?? u['user_id']) == rId,
                    );
                    return DateFormat('yyyy-MM-dd').format(ts) == today &&
                        record['type'] == 'check-in' &&
                        isUserRole;
                  })
                  .map((record) => record['user_id'] ?? record['userId'])
                  .toSet();

          _totalHadir = hadirSet.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Fetching Data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fungsi untuk mengecek apakah user tertentu sudah check-in hari ini
  bool _hasUserCheckedInToday(int targetId) {
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _allAttendance.any((a) {
      DateTime ts = DateTime.parse(a['timestamp']).toLocal();
      return (a['user_id'] == targetId || a['userId'] == targetId) &&
          DateFormat('yyyy-MM-dd').format(ts) == today &&
          a['type'] == 'check-in';
    });
  }

  // Fungsi untuk mendapatkan jam absen (check-in/out) user pada hari ini
  String _getUserTimeToday(int targetId, String type) {
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final record = _allAttendance.firstWhere((a) {
        DateTime ts = DateTime.parse(a['timestamp']).toLocal();
        return (a['user_id'] == targetId || a['userId'] == targetId) &&
            DateFormat('yyyy-MM-dd').format(ts) == today &&
            a['type'] == type;
      });
      return DateFormat(
        'HH:mm',
      ).format(DateTime.parse(record['timestamp']).toLocal());
    } catch (e) {
      return "--:--";
    }
  }

  // Fungsi untuk menampilkan dialog tambah user baru
  void _showAddUserDialog() {
    final name = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();
    final nim = TextEditingController();
    String role = "user";
    bool hidePass = true;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setST) => AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text(
                    "Create New User",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPopupField(
                            controller: name,
                            label: "Full Name",
                            icon: Icons.person_outline,
                          ),
                          _buildPopupField(
                            controller: email,
                            label: "Email Address",
                            icon: Icons.email_outlined,
                          ),
                          _buildPopupField(
                            controller: pass,
                            label: "Password",
                            icon: Icons.lock_outline,
                            isPassword: true,
                            isObscured: hidePass,
                            toggle: () => setST(() => hidePass = !hidePass),
                          ),
                          _buildPopupField(
                            controller: nim,
                            label: "NIM / NIP",
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 10),
                          _buildRoleDropdown(
                            role,
                            (v) => setST(() => role = v!),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _executeTask(
                          () => _authService.registerUser(
                            name: name.text,
                            email: email.text,
                            password: pass.text,
                            role: role,
                            nimNip: nim.text,
                          ),
                          "User Created",
                        );
                      },
                      child: const Text("Create"),
                    ),
                  ],
                ),
          ),
    );
  }

  // Fungsi untuk menampilkan dialog edit data user
  void _showEditUserDialog(Map<String, dynamic> user) {
    final name = TextEditingController(text: user['name']);
    final email = TextEditingController(
      text: user['usernameEmail'] ?? user['username_email'],
    );
    final nim = TextEditingController(text: user['nimNip'] ?? user['nim_nip']);
    final dummyPass = TextEditingController(text: "********");
    String role = (user['role'] ?? "user").toString().toLowerCase();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setST) => AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text(
                    "Edit Information",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPopupField(
                            controller: name,
                            label: "Full Name",
                            icon: Icons.person_outline,
                          ),
                          _buildPopupField(
                            controller: email,
                            label: "Email Address",
                            icon: Icons.email_outlined,
                          ),
                          _buildPopupField(
                            controller: nim,
                            label: "NIM / NIP",
                            icon: Icons.badge_outlined,
                          ),
                          _buildPopupField(
                            controller: dummyPass,
                            label: "Password (Locked)",
                            icon: Icons.lock_person_outlined,
                            readOnly: true,
                            isPassword: true,
                            isObscured: true,
                          ),
                          const SizedBox(height: 10),
                          _buildRoleDropdown(
                            role,
                            (v) => setST(() => role = v!),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _executeTask(
                          () => _authService.updateUser(
                            userId: user['userId'] ?? user['user_id'],
                            name: name.text,
                            email: email.text,
                            role: role,
                            nimNip: nim.text,
                          ),
                          "Update Success",
                        );
                      },
                      child: const Text("Save Changes"),
                    ),
                  ],
                ),
          ),
    );
  }

  // Helper widget untuk membuat field input di dalam dialog
  Widget _buildPopupField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isObscured = false,
    bool readOnly = false,
    VoidCallback? toggle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? isObscured : false,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue),
          filled: true,
          fillColor:
              readOnly ? Colors.grey[100] : Colors.blue.withValues(alpha: 0.05),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon:
              isPassword && !readOnly
                  ? IconButton(
                    icon: Icon(
                      isObscured ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: toggle,
                  )
                  : null,
        ),
      ),
    );
  }

  // Helper widget untuk dropdown pilihan role di dalam dialog
  Widget _buildRoleDropdown(String val, Function(String?) onCh) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        value: val,
        items: const [
          DropdownMenuItem(value: "user", child: Text("User")),
          DropdownMenuItem(value: "admin", child: Text("Admin")),
        ],
        onChanged: onCh,
        decoration: const InputDecoration(
          labelText: "Role",
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.admin_panel_settings_outlined,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  // Fungsi untuk menampilkan daftar lingkaran user dan admin (User Management)
  Widget _buildUserCircleList() {
    final usersList =
        _users
            .where((u) => u['role'].toString().toLowerCase() == 'user')
            .toList();
    final adminsList =
        _users
            .where((u) => u['role'].toString().toLowerCase() == 'admin')
            .toList();
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCircleItem(
            label: "Add New",
            icon: Icons.add,
            isButton: true,
            onTap: () => _showAddUserDialog(),
          ),
          ...usersList.map((user) {
            final int uId = user['userId'] ?? user['user_id'] ?? 0;
            return _buildCircleItem(
              label: user['name'].toString().split(' ')[0],
              icon: Icons.person,
              color:
                  _hasUserCheckedInToday(uId)
                      ? Colors.greenAccent[700]!
                      : Colors.redAccent[700]!,
              onTap: () => _showUserDetail(user),
            );
          }),
          if (adminsList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              child: VerticalDivider(color: Colors.grey[300], thickness: 2),
            ),
          ...adminsList.map(
            (admin) => _buildCircleItem(
              label: admin['name'].toString().split(' ')[0],
              icon: Icons.admin_panel_settings,
              color: Colors.blue[300]!,
              onTap: () => _showUserDetail(admin),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget untuk item lingkaran (user avatar/button)
  Widget _buildCircleItem({
    required String label,
    required IconData icon,
    bool isButton = false,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 15),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isButton ? const Color(0xFF2196F3) : Colors.white,
                border: Border.all(
                  color:
                      isButton
                          ? Colors.transparent
                          : (color ?? Colors.grey[300]!),
                  width: 3.5,
                ),
              ),
              child: Icon(
                icon,
                color: isButton ? Colors.white : Colors.grey[400],
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Fungsi untuk menampilkan header dashboard (Welcome & Profile)
  Widget _buildHeader() => Container(
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
            Text(
              "Welcome, $_displayName",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196F3),
              ),
            ),
            Text(
              _currentDate,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        InkWell(
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => ProfileScreenAdmin(userId: widget.userId),
                ),
              ),
          child: const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: Colors.blue),
          ),
        ),
      ],
    ),
  );

  // Fungsi untuk menampilkan ringkasan statistik (Present & Absent)
  Widget _buildStatsCard() => Row(
    children: [
      _buildStatBox(
        "Present Today",
        "$_totalHadir / $_totalUsersOnly",
        Colors.green,
      ),
      const SizedBox(width: 15),
      _buildStatBox(
        "Absent Today",
        "${_totalUsersOnly - _totalHadir}",
        Colors.red,
      ),
    ],
  );

  // Helper widget untuk kotak statistik
  Widget _buildStatBox(String l, String v, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            v,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: c,
            ),
          ),
          Text(l, style: TextStyle(color: c, fontSize: 12)),
        ],
      ),
    ),
  );

  // Fungsi untuk menampilkan grid menu aksi admin
  Widget _buildActionGrid() => Row(
    children: [
      _buildGridItem(
        "Announcement",
        Icons.notifications_none,
        Colors.orange,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => NotificationScreenAdmin(userId: widget.userId),
          ),
        ),
      ),
      const SizedBox(width: 20),
      _buildGridItem(
        "GPS Area",
        Icons.location_on_outlined,
        Colors.blue,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const SettingAreaScreenAdmin()),
        ),
      ),
      const SizedBox(width: 20),
      _buildGridItem(
        "Reports",
        Icons.description_outlined,
        Colors.purple,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const ReportsScreenAdmin()),
        ),
      ),
    ],
  );

  // Helper widget untuk item grid menu
  Widget _buildGridItem(String l, IconData i, Color c, VoidCallback? t) =>
      Expanded(
        child: InkWell(
          onTap: t ?? () {},
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(i, color: c, size: 30),
              ),
              const SizedBox(height: 8),
              Text(
                l,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );

  // Fungsi untuk menampilkan detail user dalam bentuk bottom sheet
  void _showUserDetail(Map<String, dynamic> user) {
    final int uId = user['userId'] ?? user['user_id'] ?? 0;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.person, size: 45, color: Colors.blue),
                ),
                const SizedBox(height: 15),
                Text(
                  user['name'] ?? "Unknown",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user['nimNip'] ?? user['nim_nip'] ?? "-",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const Divider(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTimeDisplay(
                      "Check-In",
                      _getUserTimeToday(uId, 'check-in'),
                      Colors.green,
                    ),
                    _buildTimeDisplay(
                      "Check-Out",
                      _getUserTimeToday(uId, 'checkout'),
                      Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 35),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmDeleteUser(user);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[50],
                          foregroundColor: Colors.red,
                        ),
                        child: const Text("Delete"),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditUserDialog(user);
                        },
                        child: const Text("Edit"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  // Helper widget untuk menampilkan teks waktu (Check-In/Out)
  Widget _buildTimeDisplay(String l, String t, Color c) => Column(
    children: [
      Text(l, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      const SizedBox(height: 5),
      Text(
        t,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c),
      ),
    ],
  );

  // Fungsi wrapper untuk mengeksekusi tugas async dengan loading state
  Future<void> _executeTask(Future<void> Function() t, String m) async {
    setState(() => _isLoading = true);
    try {
      await t();
      _showSnackBar(m, Colors.green);
      _fetchAdminData();
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
      setState(() => _isLoading = false);
    }
  }

  // Fungsi untuk menampilkan notifikasi snackbar di bawah layar
  void _showSnackBar(String m, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: c,
          behavior: SnackBarBehavior.floating,
        ),
      );

  // Fungsi untuk menampilkan konfirmasi sebelum menghapus user
  void _confirmDeleteUser(Map<String, dynamic> u) => showDialog(
    context: context,
    builder:
        (c) => AlertDialog(
          title: const Text("Delete User"),
          content: Text("Are you sure you want to remove ${u['name']}?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(c);
                _executeTask(
                  () => _authService.deleteUser(u['userId'] ?? u['user_id']),
                  "Deleted",
                );
              },
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _fetchAdminData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 25),
                        const Text(
                          "User Management",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildUserCircleList(),
                        const SizedBox(height: 30),
                        _buildStatsCard(),
                        const SizedBox(height: 30),
                        const Text(
                          "Admin Menu",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildActionGrid(),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../data/services/auth_service.dart';

class ProfileScreenAdmin extends StatefulWidget {
  final int userId;
  const ProfileScreenAdmin({super.key, required this.userId});

  @override
  State<ProfileScreenAdmin> createState() => _ProfileScreenAdminState();
}

class _ProfileScreenAdminState extends State<ProfileScreenAdmin> {
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  String _name = "-";
  String _nimNip = "-";
  String _role = "-";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Fungsi untuk mengambil data profil admin dari backend saat layar dimuat
  Future<void> _fetchUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _authService.getUserProfile(widget.userId);
      if (mounted) {
        setState(() {
          _name = data['name']?.toString() ?? "No Name";
          _nimNip = data['nim_nip']?.toString() ?? "-";
          _role = data['role']?.toString() ?? "admin";
        });
      }
    } catch (e) {
      debugPrint("Error Fetch Profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fungsi pembantu untuk menampilkan pesan SnackBar (feedback user)
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Fungsi untuk menampilkan dialog pop-up untuk mengganti password
  void _showChangePasswordDialog() {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();
    List<bool> obscureTextList = [true, true, true];

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  titlePadding: const EdgeInsets.only(top: 25),
                  title: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: Colors.blue,
                          size: 35,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "Change Password",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Update your security credentials",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 15),
                          _buildPwField(
                            controller: currentPwController,
                            label: "Current Password",
                            isObscured: obscureTextList[0],
                            toggle:
                                () => setDialogState(
                                  () =>
                                      obscureTextList[0] = !obscureTextList[0],
                                ),
                          ),
                          const SizedBox(height: 18),
                          _buildPwField(
                            controller: newPwController,
                            label: "New Password",
                            isObscured: obscureTextList[1],
                            toggle:
                                () => setDialogState(
                                  () =>
                                      obscureTextList[1] = !obscureTextList[1],
                                ),
                          ),
                          const SizedBox(height: 18),
                          _buildPwField(
                            controller: confirmPwController,
                            label: "Confirm New Password",
                            isObscured: obscureTextList[2],
                            toggle:
                                () => setDialogState(
                                  () =>
                                      obscureTextList[2] = !obscureTextList[2],
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
                  actions: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (newPwController.text !=
                                  confirmPwController.text) {
                                _showSnackBar(
                                  "Passwords do not match",
                                  Colors.red,
                                );
                                return;
                              }
                              if (currentPwController.text.isEmpty ||
                                  newPwController.text.isEmpty) {
                                _showSnackBar(
                                  "Fields cannot be empty",
                                  Colors.orange,
                                );
                                return;
                              }

                              Navigator.pop(context);
                              setState(() => _isLoading = true);
                              try {
                                final result = await _authService
                                    .updatePassword(
                                      userId: widget.userId,
                                      currentPassword: currentPwController.text,
                                      newPassword: newPwController.text,
                                    );
                                _showSnackBar(
                                  result['message']?.toString() ??
                                      "Password updated successfully",
                                  Colors.green,
                                );
                              } catch (e) {
                                _showSnackBar(
                                  e.toString().replaceAll("Exception: ", ""),
                                  Colors.red,
                                );
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Update",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          children: [
                            _buildProfileHeader(),
                            const SizedBox(height: 20),
                            _buildInfoSection(),
                            const SizedBox(height: 30),
                            _buildActionButtons(context),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  // Widget untuk bilah atas yang berisi judul layar dan tombol kembali
  Widget _buildTopBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 25),
      decoration: const BoxDecoration(
        color: Color(0xFFE3F2FD),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 10,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF2196F3),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Text(
            "Admin Profile",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2196F3),
            ),
          ),
        ],
      ),
    );
  }

  // Widget visual untuk bagian atas profil (header gradasi dan stack avatar)
  Widget _buildProfileHeader() {
    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                ),
              ),
            ),
          ),
          Positioned(bottom: 0, child: _buildAvatarCircle()),
        ],
      ),
    );
  }

  // Widget untuk lingkaran avatar profil
  Widget _buildAvatarCircle() {
    return Container(
      height: 100,
      width: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: const CircleAvatar(
        backgroundColor: Color(0xFFE3F2FD),
        child: Icon(Icons.person, color: Color(0xFF2196F3), size: 50),
      ),
    );
  }

  // Widget pembungkus untuk seluruh field informasi user
  Widget _buildInfoSection() {
    return Column(
      children: [
        _buildInfoField("Full Name", _name),
        const SizedBox(height: 20),
        _buildInfoField("NIM / NIP", _nimNip),
        const SizedBox(height: 20),
        _buildInfoField("User Role", _role.toUpperCase()),
      ],
    );
  }

  // Widget untuk menampilkan baris informasi (Label dan Nilai)
  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
          ],
        ),
        const Divider(color: Color(0xFFF0F0F0), thickness: 1.5),
      ],
    );
  }

  // Widget untuk tombol-tombol aksi (Change Password dan Logout)
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _buildButton(
          label: "Change Password",
          icon: Icons.vpn_key_outlined,
          onPressed: _showChangePasswordDialog,
          color: Colors.grey[100]!,
        ),
        const SizedBox(height: 16),
        _buildButton(
          label: "Logout Account",
          icon: Icons.logout_rounded,
          onPressed:
              () => Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false),
          color: const Color(0xFFFFEBEE),
          textColor: Colors.red[700],
        ),
      ],
    );
  }

  // Widget template tombol serbaguna untuk profil
  Widget _buildButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    Color? textColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor ?? Colors.black87,
          elevation: 0,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // Widget untuk input field password di dalam dialog
  Widget _buildPwField({
    required TextEditingController controller,
    required String label,
    required bool isObscured,
    required VoidCallback toggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscured,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            isObscured ? Icons.visibility_off : Icons.visibility,
            size: 20,
          ),
          onPressed: toggle,
        ),
      ),
    );
  }
}

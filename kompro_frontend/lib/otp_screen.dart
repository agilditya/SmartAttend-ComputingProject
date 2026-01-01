import 'package:flutter/material.dart';
import '../../data/services/auth_service.dart';
import '/presentation/admin/dashboard_screen_admin.dart';
import '/presentation/mobile/dashboard_screen.dart';

class OtpScreen extends StatefulWidget {
  final int userId;

  const OtpScreen({super.key, required this.userId});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // memvalidasi kode OTP dan menentukan arah navigasi berdasarkan peran user
  void _handleVerify() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        String typedOtp = _otpController.text.trim().toUpperCase();

        await _authService.verifyOtp(widget.userId, typedOtp);

        final userProfile = await _authService.getUserProfile(widget.userId);

        if (!mounted) return;

        final String role =
            (userProfile['role'] ?? 'user').toString().toLowerCase();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Welcome, ${userProfile['name']}!"),
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (role == 'admin') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => AdminDashboardScreen(userId: widget.userId),
            ),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(userId: widget.userId),
            ),
            (route) => false,
          );
        }
      } catch (e) {
        debugPrint("OTP_VERIFY_ERROR: $e");

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed: ${e.toString().replaceAll("Exception:", "")}",
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // mengirimkan ulang kode OTP baru ke alamat email user
  void _handleResend() async {
    try {
      await _authService.resendOtp(widget.userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("A new OTP code has been sent!"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed: ${e.toString()}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHeaderIcon(),
                    const SizedBox(height: 30),
                    _buildTitleSection(),
                    const SizedBox(height: 40),
                    _buildOtpInput(),
                    const SizedBox(height: 30),
                    _buildVerifyButton(),
                    const SizedBox(height: 24),
                    _buildFooterLinks(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Membuat widget ikon lingkaran gembok di bagian atas layar
  Widget _buildHeaderIcon() {
    return Container(
      height: 120,
      width: 120,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.lock_person_rounded,
        size: 60,
        color: Colors.blue,
      ),
    );
  }

  // Membuat bagian teks judul utama dan instruksi verifikasi
  Widget _buildTitleSection() {
    return const Column(
      children: [
        Text(
          "Two-Step Verification",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Enter the 6-digit code sent to your email",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ],
    );
  }

  // Membuat kolom input teks untuk kode OTP dengan format kapital dan jarak huruf
  Widget _buildOtpInput() {
    return TextFormField(
      controller: _otpController,
      keyboardType: TextInputType.text,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: 8.0,
      ),
      decoration: InputDecoration(
        hintText: "X X X X X X",
        hintStyle: const TextStyle(letterSpacing: 2.0, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
      ),
      validator: (val) => val!.isEmpty ? "Code required" : null,
    );
  }

  // Membuat tombol verifikasi dengan indikator loading saat proses async berjalan
  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleVerify,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child:
            _isLoading
                ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
                : const Text(
                  "Verify Code",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
      ),
    );
  }

  // Membuat kumpulan tombol tautan untuk kirim ulang OTP dan navigasi kembali ke login
  Widget _buildFooterLinks() {
    return Column(
      children: [
        TextButton.icon(
          onPressed: _isLoading ? null : _handleResend,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text("Resend Code"),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Back to Login",
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

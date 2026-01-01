import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/services/auth_service.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int userId;

  const DashboardScreen({super.key, required this.userId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  bool _isProcessingLocation = false;
  String _displayName = "Loading...";
  String _currentDate = "";
  String _checkInTime = "--:--";
  String _checkOutTime = "--:--";
  String _duration = "No data yet";
  String _notifTitle = "Loading...";
  String _notifBody = "";

  LatLng _officeLocation = const LatLng(-6.97321, 107.63014);
  double _officeRadius = 50.0;

  @override
  void initState() {
    super.initState();
    _setupDate();
    _fetchAllData();
  }

  // Mengatur format tanggal header ke dalam Bahasa Inggris
  Future<void> _setupDate() async {
    await initializeDateFormatting('en_US', null);
    if (mounted) {
      setState(() {
        _currentDate = DateFormat(
          'EEEE, d MMM yyyy',
          'en_US',
        ).format(DateTime.now());
      });
    }
  }

  // Mengambil seluruh data secara paralel dengan penanganan error
  Future<void> _fetchAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchUserProfile(),
        _fetchAttendance(),
        _fetchNotification(),
        _fetchOfficeConfig(),
      ]);
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Mengambil konfigurasi kantor dengan perbaikan parsing tipe data (Anti-Error)
  Future<void> _fetchOfficeConfig() async {
    try {
      final dynamic responseData = await _authService.getOfficeLocation();
      if (!mounted) return;

      Map<String, dynamic>? officeData;

      if (responseData is List && responseData.isNotEmpty) {
        officeData = responseData[0] as Map<String, dynamic>;
      } else if (responseData is Map<String, dynamic>) {
        officeData = responseData;
      }

      if (officeData != null) {
        setState(() {
          double lat =
              double.tryParse(officeData!['latitude'].toString()) ?? -6.97321;
          double lng =
              double.tryParse(officeData['longitude'].toString()) ?? 107.63014;
          _officeLocation = LatLng(lat, lng);
          _officeRadius =
              double.tryParse(officeData['radius'].toString()) ?? 50.0;
        });
        debugPrint(
          "Office Config Loaded: $_officeLocation dengan radius $_officeRadius",
        );
      } else {
        debugPrint("Office Config Error: Data kosong atau format salah");
      }
    } catch (e) {
      debugPrint("Office Config Error: $e");
    }
  }

  // Mengambil profil pengguna
  Future<void> _fetchUserProfile() async {
    try {
      final data = await _authService.getUserProfile(widget.userId);
      if (!mounted) return;
      setState(() => _displayName = data['name'] ?? "User");
    } catch (e) {
      debugPrint("Profile Error: $e");
    }
  }

  // Mengambil riwayat kehadiran hari ini
  Future<void> _fetchAttendance() async {
    try {
      final List<dynamic> data = await _authService.getAttendance(
        widget.userId,
      );
      if (!mounted) return;

      if (data.isNotEmpty) {
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        String cin = "--:--", cout = "--:--";

        for (var record in data) {
          DateTime dt = DateTime.parse(record['timestamp']).toLocal();
          if (DateFormat('yyyy-MM-dd').format(dt) == todayStr) {
            if (record['type'] == 'check-in') {
              cin = DateFormat('HH:mm').format(dt);
            } else if (record['type'] == 'checkout') {
              cout = DateFormat('HH:mm').format(dt);
            }
          }
        }

        setState(() {
          _checkInTime = cin;
          _checkOutTime = cout;
          _duration =
              (cin != "--:--" && cout == "--:--")
                  ? "In Progress"
                  : (cout != "--:--")
                  ? "Completed"
                  : "Not yet present";
        });
      }
    } catch (e) {
      debugPrint("Attendance Error: $e");
    }
  }

  // Mengambil notifikasi terbaru
  Future<void> _fetchNotification() async {
    try {
      final data = await _authService.getLatestNotification(widget.userId);
      if (!mounted) return;
      setState(() {
        _notifTitle = data['title'] ?? "No Announcement";
        _notifBody = data['message'] ?? "No new information today.";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notifTitle = "SmartAttend Info";
        _notifBody = "Have a great work! Keep your GPS active.";
      });
    }
  }

  // Menangani permintaan lokasi GPS
  Future<void> _handleAttendance() async {
    setState(() => _isProcessingLocation = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      if (!mounted) return;
      setState(() => _isProcessingLocation = false);
      _showConfirmationSheet(pos);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("GPS Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // Lembar konfirmasi kehadiran
  void _showConfirmationSheet(Position userPos) {
    LatLng userLatLng = LatLng(userPos.latitude, userPos.longitude);
    bool isCheckIn = (_checkInTime == "--:--");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isCheckIn ? "Confirm Check-In" : "Confirm Check-Out",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: userLatLng,
                        initialZoom: 17,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: _officeLocation,
                              radius: _officeRadius,
                              useRadiusInMeter: true,
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderColor: Colors.blue,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _officeLocation,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.blue,
                                size: 35,
                              ),
                            ),
                            Marker(
                              point: userLatLng,
                              child: const Icon(
                                Icons.person_pin_circle,
                                color: Colors.red,
                                size: 35,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _submitToBackend(userPos, isCheckIn),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCheckIn ? Colors.green : Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isCheckIn ? "CHECK-IN NOW" : "CHECK-OUT NOW",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // Mengirim data presensi ke backend
  Future<void> _submitToBackend(Position pos, bool isCheckIn) async {
    double dist = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      _officeLocation.latitude,
      _officeLocation.longitude,
    );

    if (dist > _officeRadius) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed: You are ${dist.round()}m away from office."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(context);
    setState(() => _isLoading = true);
    try {
      final res = await _authService.submitAttendance(
        userId: widget.userId,
        lat: pos.latitude,
        lng: pos.longitude,
        isCheckIn: isCheckIn,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']), backgroundColor: Colors.green),
      );
      _fetchAllData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll("Exception:", "")),
          backgroundColor: Colors.red,
        ),
      );
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
        child: RefreshIndicator(
          onRefresh: _fetchAllData,
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildAttendanceCard(),
                        const SizedBox(height: 20),
                        _buildNotificationSection(),
                        const SizedBox(height: 20),
                        _buildMapView(),
                      ],
                    ),
                  ),
        ),
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hi, $_displayName",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currentDate,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
          InkWell(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userId: widget.userId),
                  ),
                ),
            child: const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF2196F3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFE3F2FD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Text(
              "ATTENDANCE",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196F3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 20.0,
              horizontal: 24.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(child: _buildTimeColumn("Check In", _checkInTime)),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(child: _buildTimeColumn("Check Out", _checkOutTime)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              "Status: $_duration",
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(String label, String time) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2196F3),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Announcement",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              UserNotificationScreen(userId: widget.userId),
                    ),
                  ),
              child: const Row(
                children: [
                  Text("See All", style: TextStyle(fontSize: 12)),
                  Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
          ],
        ),
        InkWell(
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          UserNotificationScreen(userId: widget.userId),
                ),
              ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.campaign_rounded,
                  color: Colors.blue,
                  size: 30,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _notifTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _notifBody,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapView() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _officeLocation,
            initialZoom: 16.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _officeLocation,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    return SizedBox(
      height: 70,
      width: 70,
      child: FloatingActionButton(
        onPressed:
            _isLoading || _isProcessingLocation ? null : _handleAttendance,
        backgroundColor: const Color(0xFF2196F3),
        shape: const CircleBorder(),
        child:
            _isProcessingLocation
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.fingerprint, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      height: 70,
      elevation: 10,
      color: Colors.white.withValues(alpha: 0.95),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home_rounded, "HOME", 0),
          const SizedBox(width: 40),
          _buildNavItem(Icons.history_rounded, "HISTORY", 1),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    return InkWell(
      onTap: () {
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HistoryScreen(userId: widget.userId),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: index == 0 ? const Color(0xFF2196F3) : Colors.grey[600],
            size: 28,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: index == 0 ? const Color(0xFF2196F3) : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

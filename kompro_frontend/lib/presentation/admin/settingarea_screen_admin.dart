import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/services/auth_service.dart';

class SettingAreaScreenAdmin extends StatefulWidget {
  const SettingAreaScreenAdmin({super.key});

  @override
  State<SettingAreaScreenAdmin> createState() => _SettingAreaScreenAdminState();
}

class _SettingAreaScreenAdminState extends State<SettingAreaScreenAdmin> {
  final AuthService _authService = AuthService();
  final MapController _mapController = MapController();

  // Koordinat default (akan tertimpa saat data dari DB berhasil dimuat)
  LatLng _currentLocation = const LatLng(-6.97321, 107.63014);
  double _currentRadius = 100.0;
  bool _isLoading = true;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Memastikan pengambilan data dilakukan segera saat layar dibuka
    _loadCurrentOffice();
  }

  // Mengambil data lokasi kantor dari server dan menyinkronkan posisi peta
  Future<void> _loadCurrentOffice() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final List<dynamic> data = await _authService.getOfficeLocation();

      if (data.isNotEmpty) {
        final Map<String, dynamic> office = data[0] as Map<String, dynamic>;

        if (mounted) {
          setState(() {
            _currentLocation = LatLng(
              double.parse(office['latitude'].toString()),
              double.parse(office['longitude'].toString()),
            );
            _currentRadius = double.parse(office['radius'].toString());
            _nameController.text =
                office['locationName']?.toString() ?? "Main Office";
            _isLoading = false;
          });

          // Menggerakkan kamera peta ke koordinat hasil database
          // Gunakan delay kecil agar MapController sudah siap (mounted) di layar
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _mapController.move(_currentLocation, 16);
            }
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error load office: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Mengirim pembaruan data lokasi ke server dan memuat ulang state
  Future<void> _handleUpdate() async {
    setState(() => _isLoading = true);
    try {
      await _authService.addOfficeLocation(
        name: _nameController.text,
        lat: _currentLocation.latitude,
        lng: _currentLocation.longitude,
        radius: _currentRadius.toInt(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Office Location Updated Successfully!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Refresh data dari database setelah berhasil update
        _loadCurrentOffice();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update: ${e.toString()}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Set Office Location",
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Tombol refresh manual jika data tidak muncul
          IconButton(
            icon: const Icon(Icons.sync, color: Color(0xFF2196F3)),
            onPressed: _loadCurrentOffice,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildOfficeNameInput(),
                  _buildMapSection(),
                  _buildRadiusSettings(),
                ],
              ),
    );
  }

  // Widget input nama kantor dengan batas margin mobile (20px)
  Widget _buildOfficeNameInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextField(
        controller: _nameController,
        decoration: InputDecoration(
          labelText: "Office Name",
          prefixIcon: const Icon(Icons.business, color: Color(0xFF2196F3)),
          filled: true,
          fillColor: const Color(0xFFE3F2FD),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // Widget peta interaktif dengan penanganan tap untuk memindah pin
  Widget _buildMapSection() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation,
                  initialZoom: 16,
                  onTap: (_, point) {
                    setState(() {
                      _currentLocation = point;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.attendance.app',
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _currentLocation,
                        radius: _currentRadius,
                        useRadiusInMeter: true,
                        color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                        borderColor: const Color(0xFF2196F3),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation,
                        width: 80,
                        height: 80,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(top: 10, right: 10, child: _buildInstructionTag()),
            ],
          ),
        ),
      ),
    );
  }

  // Widget label kecil pemberitahuan cara penggunaan peta
  Widget _buildInstructionTag() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: const Text(
        "Tap map to move pin",
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Widget slider radius dan tombol simpan
  Widget _buildRadiusSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Attendance Radius",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "${_currentRadius.round()} meters",
                style: const TextStyle(
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: _currentRadius,
            min: 50,
            max: 300,
            divisions: 5,
            label: "${_currentRadius.round()}m",
            onChanged: (val) => setState(() => _currentRadius = val),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _handleUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "UPDATE OFFICE AREA",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

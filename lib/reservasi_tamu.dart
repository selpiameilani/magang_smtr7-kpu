import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database_helper.dart';
import '../home.dart';

class ReservasiTamuPage extends StatefulWidget {
  const ReservasiTamuPage({super.key});

  @override
  State<ReservasiTamuPage> createState() => _ReservasiTamuPageState();
}

class _ReservasiTamuPageState extends State<ReservasiTamuPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _asalController = TextEditingController();
  final TextEditingController _jumlahPengunjungController =
      TextEditingController();
  final TextEditingController _keperluanController = TextEditingController();
  final TextEditingController _nomorIdentitasController =
      TextEditingController();
  final TextEditingController _teleponController = TextEditingController();
  final TextEditingController _namaOperatorController = TextEditingController();

  String? _photoPath;
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  String? _selectedKeperluan;
  String? _selectedJenisKelamin;
  String? _selectedTujuan;
  String? _selectedIdentitas;

  final List<String> _keperluanOptions = [
    'Pelayanan Permohonan Informasi Publik',
    'Layanan Konsultasi Teknis',
    'Pelayanan Data Pemilih',
    'Autentifikasi Salinan Keputusan tentang Penetapan Perolehan Suara Sah Partai Politik dan Perolehan Kursi Partai Politik Tingkat Kabupaten',
    'Pelayanan Penggantian Antar Waktu Anggota DPRD Tingkat Kabupaten',
    'Layanan Dokumentasi dan Publikasi Hukum',
    'Pendidikan Pemilih melalui Pendidikan Kepemiluan',
    'Layanan Pengaduan Masyarakat',
    'Layanan Magang Perguruan Tinggi',
    'Lainnya',
  ];

  final List<String> _jenisKelaminOptions = ['Laki-laki', 'Perempuan'];

  final List<String> _tujuanOptions = [
    'Ketua KPU Kabupaten Sukabumi',
    'Sekretaris KPU Kabupaten Sukabumi',
    'Anggota KPU kabupaten Sukabumi - Divisi Perencanaan Data dan Informasi',
    'Anggota KPU Kabupaten Sukabumi - Divisi Teknis Penyelenggaraan',
    'Anggota KPU Kabupaten Sukabumi - Divisi Sosialisasi Pemilih, dan partisipasi Masyarakat',
    'Anggota KPU Kabupaten Sukabumi - Divisi Hukum dan Pengawasan',
    'SUB Bagian Keuangan Umum dan Logistik - Sekretariat Kabupaten Sukabumi',
    'SUB Bagian Teknis Penyelenggaraan Pemilu dan Hukum - Sekretariat Kabupaten Sukabumi',
    'SUB Bagian Data Perencanaan dan Informasi - Sekretariat Kabupaten Sukabumi',
    'SUB Bagian Partisipasi dan Hubungan Masyarat dan SDM - Sekretariat Kabupaten Sukabumi',
  ];

  final List<String> _identitasOptions = ['KTP', 'SIM', 'Pasport'];

  bool _showKeperluanTextField = false;
  bool _showNomorIdentitasField = false;

  @override
  void dispose() {
    _namaController.dispose();
    _asalController.dispose();
    _jumlahPengunjungController.dispose();
    _keperluanController.dispose();
    _nomorIdentitasController.dispose();
    _teleponController.dispose();
    _namaOperatorController.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    try {
      debugPrint('Meminta permission kamera...');

      // Skip permission request untuk Windows
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.camera.request();

        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Permission kamera ditolak. Silakan aktifkan di pengaturan.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      debugPrint('Membuka kamera...');
      if (!mounted) return;

      // PERBAIKAN: Tambahkan try-catch untuk availableCameras
      List<CameraDescription> cameras;
      try {
        cameras = await availableCameras();
      } catch (e) {
        debugPrint('Error getting cameras: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tidak dapat mengakses kamera: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak ada kamera yang tersedia di device ini'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      debugPrint('Jumlah kamera tersedia: ${cameras.length}');

      // Pilih kamera (prioritas front camera)
      CameraDescription selectedCamera = cameras.first;
      for (var camera in cameras) {
        debugPrint('Kamera: ${camera.name}, Arah: ${camera.lensDirection}');
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      debugPrint('Kamera dipilih: ${selectedCamera.name}');
      if (!mounted) return;

      final String? capturedImagePath = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(camera: selectedCamera),
        ),
      );

      if (capturedImagePath != null && mounted) {
        setState(() {
          _photoPath = capturedImagePath;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto berhasil diambil!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengakses kamera: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showQueuePopup(int nomorAntrian) async {
    final DateTime now = DateTime.now();
    final String currentTime =
        "${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}";

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  width: 320,
                  margin: const EdgeInsets.only(top: 100),
                  padding: const EdgeInsets.fromLTRB(30, 80, 30, 30),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B0000), Color(0xFF3D0000)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 40,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'MOHON TUNGGU',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Anda Sedang Dalam Antrian',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8800), Color(0xFFFF5500)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B00)
                                  .withValues(alpha: 0.7),
                              blurRadius: 30,
                              spreadRadius: 5,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            nomorAntrian.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              fontSize: 70,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 35),
                      Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8800), Color(0xFFFF6600)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B00)
                                  .withValues(alpha: 0.5),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                    builder: (context) => const HomePage()),
                              );
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.access_time,
                                      color: Color(0xFFFF6600),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    currentTime,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Text(
                                    'OK',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/penyu.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFD4A574),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.account_circle,
                              size: 120,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveData() async {
    // Validasi semua field terlebih dahulu
    List<String> errors = [];

    // Validasi text field
    if (_namaController.text.trim().isEmpty) {
      errors.add('Nama harus diisi');
    }
    if (_asalController.text.trim().isEmpty) {
      errors.add('Asal harus diisi');
    }
    if (_jumlahPengunjungController.text.trim().isEmpty) {
      errors.add('Jumlah Pengunjung harus diisi');
    } else if (!RegExp(r'^[0-9]+$')
        .hasMatch(_jumlahPengunjungController.text.trim())) {
      errors.add('Jumlah Pengunjung hanya boleh berisi angka');
    }
    if (_teleponController.text.trim().isEmpty) {
      errors.add('Telepon/HP harus diisi');
    } else if (!RegExp(r'^[0-9]+$').hasMatch(_teleponController.text.trim())) {
      errors.add('Telepon/HP hanya boleh berisi angka');
    }
    if (_namaOperatorController.text.trim().isEmpty) {
      errors.add('Nama Operator harus diisi');
    }

    // Validasi dropdown
    if (_selectedJenisKelamin == null) {
      errors.add('Jenis Kelamin harus dipilih');
    }
    if (_selectedTujuan == null) {
      errors.add('Tujuan harus dipilih');
    }
    if (_selectedKeperluan == null) {
      errors.add('Keperluan harus dipilih');
    }
    if (_selectedKeperluan == 'Lainnya' &&
        _keperluanController.text.trim().isEmpty) {
      errors.add('Keperluan lainnya harus diisi');
    }
    if (_selectedIdentitas == null) {
      errors.add('Identitas harus dipilih');
    }
    if (_selectedIdentitas != null &&
        _nomorIdentitasController.text.trim().isEmpty) {
      errors.add('Nomor Identitas harus diisi');
    }
    if (_selectedIdentitas != null &&
        _nomorIdentitasController.text.trim().isNotEmpty &&
        !RegExp(r'^[0-9]+$').hasMatch(_nomorIdentitasController.text.trim())) {
      errors.add('Nomor Identitas hanya boleh berisi angka');
    }

    if (_photoPath == null || _photoPath!.isEmpty) {
      // Hanya warning, tidak blocking
      debugPrint('⚠️ Warning: Foto tamu belum diambil');
    }

    // Jika ada error, tampilkan semua error
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.join('\n')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Jika semua validasi lolos, simpan data
    try {
      final String keperluan = _showKeperluanTextField
          ? _keperluanController.text.trim()
          : _selectedKeperluan ?? '';

      final DateTime now = DateTime.now();
      final String timeString =
          "${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}";

      HomePageState.addVisitor({
        'name': _namaController.text.trim(),
        'asal': _asalController.text.trim(),
        'time': timeString,
      });

      final Map<String, dynamic> tamuData = {
        'nama': _namaController.text.trim(),
        'jenis_kelamin': _selectedJenisKelamin ?? '',
        'tanggal_jam_visit': now.toIso8601String(), // PERBAIKAN: Format ISO
        'tanggal_jam_selesai': '', // Kosong untuk tamu baru
        'asal': _asalController.text.trim(),
        'jumlah_pengunjung': _jumlahPengunjungController.text.trim(),
        'tujuan': _selectedTujuan ?? '',
        'keperluan': keperluan,
        'identitas': _selectedIdentitas ?? '',
        'nomor_identitas': _nomorIdentitasController.text.trim(),
        'telepon': _teleponController.text.trim(),
        'nama_operator': _namaOperatorController.text.trim(),
        'photo_path': _photoPath ?? '', // Kosong jika tidak ada foto
        // Kolom baru untuk Firebase sync
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      await _databaseHelper.insertTamu(tamuData).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Database insert timeout');
        },
      );

      debugPrint('✅ Data saved successfully');

      if (mounted) {
        final int nomorAntrian = HomePageState.activeVisitors.length;
        await _showQueuePopup(nomorAntrian);
      }
    } catch (e) {
      debugPrint('Error saving data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error menyimpan data: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  Widget _buildFormField(String label, TextEditingController controller) {
    if (label == 'Jenis Kelamin') {
      return _buildDropdownField(label, _selectedJenisKelamin,
          _jenisKelaminOptions, 'Pilih Jenis Kelamin', (value) {
        setState(() => _selectedJenisKelamin = value);
      });
    }

    if (label == 'Tujuan') {
      return _buildDropdownField(
          label, _selectedTujuan, _tujuanOptions, 'Pilih Tujuan', (value) {
        setState(() => _selectedTujuan = value);
      });
    }

    if (label == 'Identitas') {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 160,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: const Color(0xFFE0E0E0), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedIdentitas,
                        isExpanded: true,
                        hint: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 15),
                            child: Text('Pilih Jenis Identitas',
                                style: TextStyle(fontSize: 15))),
                        icon: const Icon(Icons.arrow_drop_down, size: 28),
                        iconSize: 28,
                        elevation: 8,
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 15),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedIdentitas = newValue;
                            _showNomorIdentitasField = newValue != null;
                            if (newValue == null) {
                              _nomorIdentitasController.clear();
                            }
                          });
                        },
                        items: _identitasOptions
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                              value: value, child: Text(value));
                        }).toList(),
                      ),
                    ),
                  ),
                  if (_showNomorIdentitasField) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 45,
                      child: TextFormField(
                        controller: _nomorIdentitasController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Masukkan Nomor $_selectedIdentitas',
                          hintStyle: const TextStyle(fontSize: 15),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE0E0E0))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0), width: 1)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xFF660300), width: 2)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (label == 'Keperluan') {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 160,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: const Color(0xFFE0E0E0), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedKeperluan,
                        isExpanded: true,
                        hint: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 15),
                            child: Text('Pilih Keperluan',
                                style: TextStyle(fontSize: 15))),
                        icon: const Icon(Icons.arrow_drop_down, size: 28),
                        iconSize: 28,
                        elevation: 8,
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 15),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedKeperluan = newValue;
                            _showKeperluanTextField = newValue == 'Lainnya';
                            if (newValue != 'Lainnya') {
                              _keperluanController.text = newValue ?? '';
                            } else {
                              _keperluanController.clear();
                            }
                          });
                        },
                        items: _keperluanOptions
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1));
                        }).toList(),
                      ),
                    ),
                  ),
                  if (_showKeperluanTextField) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 45,
                      child: TextFormField(
                        controller: _keperluanController,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Masukkan keperluan lainnya',
                          hintStyle: const TextStyle(fontSize: 15),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE0E0E0))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0), width: 1)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xFF660300), width: 2)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
              width: 160,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white))),
          const SizedBox(width: 15),
          Expanded(
            child: SizedBox(
              height: 45,
              child: TextFormField(
                controller: controller,
                keyboardType:
                    label == 'Telepon/HP' || label == 'Jumlah Pengunjung'
                        ? TextInputType.number
                        : TextInputType.text,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFE0E0E0), width: 1)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFF660300), width: 2)),
                  errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.red, width: 2)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String? selectedValue,
      List<String> options, String hint, Function(String?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
              width: 160,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white))),
          const SizedBox(width: 15),
          Expanded(
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedValue,
                  isExpanded: true,
                  hint: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Text(hint, style: const TextStyle(fontSize: 15))),
                  icon: const Icon(Icons.arrow_drop_down, size: 28),
                  iconSize: 28,
                  elevation: 8,
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  onChanged: onChanged,
                  items: options.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value,
                            overflow: TextOverflow.ellipsis, maxLines: 1));
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0E0E0),
      body: Column(
        children: [
          // APP BAR
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF660300), Color(0xFF8B0000)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo_kpu.png',
                      width: 45,
                      height: 45,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.account_balance,
                            color: Colors.white, size: 24);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                const Text('Sistem Informasi Buku Tamu dan Pengamanan',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // SIDEBAR KIRI
                Container(
                  width: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D0D0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFBDBDBD)),
                              ),
                              child: const Icon(Icons.arrow_back,
                                  color: Color(0xFF660300), size: 24),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFFE0E0E0),
                    padding: const EdgeInsets.all(40),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // FORM DATA
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(35),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF660300), Color(0xFF8B0000)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Form Reservasi Tamu',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildFormField(
                                              'Nama', _namaController),
                                          _buildFormField('Jenis Kelamin',
                                              TextEditingController()),
                                          _buildFormField(
                                              'Asal', _asalController),
                                          _buildFormField('Jumlah Pengunjung',
                                              _jumlahPengunjungController),
                                          _buildFormField('Tujuan',
                                              TextEditingController()),
                                          _buildFormField('Keperluan',
                                              _keperluanController),
                                          _buildFormField('Identitas',
                                              TextEditingController()),
                                          _buildFormField(
                                              'Telepon/HP', _teleponController),
                                          _buildFormField('Nama Operator',
                                              _namaOperatorController),
                                          const SizedBox(height: 25),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 50,
                                            child: ElevatedButton(
                                              onPressed: _saveData,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFFE95007),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                elevation: 5,
                                              ),
                                              child: const Text('Submit',
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 1)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 30),
                        // FOTO TAMU
                        Container(
                          width: 380,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD0D0D0),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF660300),
                                      Color(0xFF8B0000)
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(15),
                                    topRight: Radius.circular(15),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.camera_alt,
                                        color: Colors.white, size: 24),
                                    SizedBox(width: 10),
                                    Text(
                                      'Foto Tamu',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFBDBDBD),
                                        width: 2),
                                  ),
                                  child: _photoPath != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Image.file(File(_photoPath!),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity),
                                        )
                                      : const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.person,
                                                size: 80,
                                                color: Color(0xFFBDBDBD)),
                                            SizedBox(height: 15),
                                            Text('Belum ada foto',
                                                style: TextStyle(
                                                    color: Color(0xFF9E9E9E),
                                                    fontSize: 16)),
                                          ],
                                        ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: _captureImage,
                                    icon: const Icon(Icons.camera_alt,
                                        color: Colors.white, size: 24),
                                    label: const Text('Ambil Foto',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE95007),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      elevation: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      debugPrint('Initializing camera: ${widget.camera.name}');

      _controller = CameraController(
        widget.camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        debugPrint('Camera initialized successfully');
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error menginisialisasi kamera: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      debugPrint('Error: Camera controller not initialized');
      return;
    }

    if (_controller!.value.isTakingPicture) {
      debugPrint('Camera is already taking a picture');
      return;
    }

    try {
      debugPrint('Taking picture...');

      final DatabaseHelper dbHelper = DatabaseHelper();
      final photoDir = await dbHelper.getPhotoStoragePath();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(photoDir, fileName);

      debugPrint('Photo will be saved to: $filePath');

      final XFile imageFile = await _controller!.takePicture();
      debugPrint('Picture taken, temporary path: ${imageFile.path}');

      await imageFile.saveTo(filePath);
      debugPrint('Picture saved to: $filePath');

      if (mounted) {
        Navigator.pop(context, filePath);
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengambil foto: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF660300),
        title: const Text('Ambil Foto Tamu',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 5,
      ),
      body: _isInitialized && _controller != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _takePicture,
                        icon: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 28),
                        label: const Text('Ambil Foto',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE95007),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 3),
                  SizedBox(height: 20),
                  Text('Menginisialisasi kamera...',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
    );
  }
}

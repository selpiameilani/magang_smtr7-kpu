import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'sertitu.dart';
import 'sertitu_banklapor.dart';

class SerTiTuAdminPage extends StatefulWidget {
  const SerTiTuAdminPage({super.key});

  @override
  State<SerTiTuAdminPage> createState() => _SerTiTuAdminPageState();
}

class _SerTiTuAdminPageState extends State<SerTiTuAdminPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const SerTiTuInputFormPage(),
    const SerTiTuPage(),
    const SerTiTuBankLaporPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF500000), // Dark Maroon
              Color(0xFF6B0000), // Maroon
              Color(0xFF500000), // Dark Maroon
            ],
          ),
        ),
        child: Column(
          children: [
            // Top Navigation Bar - Desktop Style
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Input Data - Kiri
                  _buildTabButton('Input', 0, Icons.edit_note),

                  // Serah Terima Tugas - Tengah
                  _buildTabButton('Serah Terima Tugas', 1, Icons.swap_horiz),

                  // Bank Laporan - Kanan
                  _buildTabButton('Bank Laporan', 2, Icons.assessment),
                ],
              ),
            ),
            // Page Content
            Expanded(
              child: _pages[_selectedIndex],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index, IconData icon) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF6B0000) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF6B0000) : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF6B0000) : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SerTiTuInputFormPage extends StatefulWidget {
  const SerTiTuInputFormPage({super.key});

  @override
  State<SerTiTuInputFormPage> createState() => _SerTiTuInputFormPageState();
}

class _SerTiTuInputFormPageState extends State<SerTiTuInputFormPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _waktuController = TextEditingController();
  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _laporanController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  String? _selectedReguPiket;
  final List<String> _reguPiketOptions = ['Regu 1', 'Regu 2', 'Regu 3'];

  String? _selectedNama;
  List<String> _namaOptions = [];

  @override
  void initState() {
    super.initState();
    _loadNamaPegawai();
  }

  Future<void> _loadNamaPegawai() async {
    try {
      final pegawaiList = await _databaseHelper.getAllPegawaiJagat();
      if (mounted) {
        setState(() {
          _namaOptions = pegawaiList.map((e) => e['nama'].toString()).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading nama pegawai: $e');
    }
  }

  @override
  void dispose() {
    _waktuController.dispose();
    _tanggalController.dispose();
    _laporanController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6B0000),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _waktuController.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6B0000),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _tanggalController.text =
            '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedReguPiket == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Regu Piket harus dipilih'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedNama == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama harus dipilih'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final DateTime now = DateTime.now();
      final Map<String, dynamic> inputData = {
        'regu_piket': _selectedReguPiket,
        'nama': _selectedNama,
        'waktu': _waktuController.text.trim(),
        'tanggal': _tanggalController.text.trim(),
        'laporan': _laporanController.text.trim(),
        'keterangan': _keteranganController.text.trim(),
        'tanggal_input': now.toString(),
      };

      await _databaseHelper.insertSerahTerima(inputData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _waktuController.clear();
        _tanggalController.clear();
        _laporanController.clear();
        _keteranganController.clear();
        setState(() {
          _selectedReguPiket = null;
          _selectedNama = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(50),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  spreadRadius: 0,
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Regu Piket
                    _buildLabel('Regu Piket'),
                    const SizedBox(height: 10),
                    _buildDropdown(
                      value: _selectedReguPiket,
                      hint: 'Pilih Regu Piket',
                      items: _reguPiketOptions,
                      onChanged: (value) {
                        setState(() {
                          _selectedReguPiket = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Hari/Tanggal
                    _buildLabel('Hari/Tanggal'),
                    const SizedBox(height: 10),
                    _buildTextFieldWithIcon(
                      _tanggalController,
                      'Pilih tanggal',
                      Icons.calendar_today_outlined,
                      onTap: _selectDate,
                      readOnly: true,
                    ),
                    const SizedBox(height: 24),

                    // Jam absen
                    _buildLabel('Jam'),
                    const SizedBox(height: 10),
                    _buildTextFieldWithIcon(
                      _waktuController,
                      'Pilih waktu',
                      Icons.access_time_outlined,
                      onTap: _selectTime,
                      readOnly: true,
                    ),
                    const SizedBox(height: 24),

                    // Nama - DROPDOWN
                    _buildLabel('Nama'),
                    const SizedBox(height: 10),
                    _namaOptions.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange[700]),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Belum ada data pegawai. Tambahkan pegawai di menu Pengaturan.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _buildDropdown(
                            value: _selectedNama,
                            hint: 'Pilih Nama',
                            items: _namaOptions,
                            onChanged: (value) {
                              setState(() {
                                _selectedNama = value;
                              });
                            },
                          ),
                    const SizedBox(height: 24),

                    // Keterangan
                    _buildLabel('Keterangan'),
                    const SizedBox(height: 10),
                    _buildTextField(_laporanController, 'Masukan Keterangan'),
                    const SizedBox(height: 24),

                    // Laporan
                    _buildLabel('Laporan'),
                    const SizedBox(height: 10),
                    _buildTextField(_keteranganController, 'Masukkan Laporan',
                        maxLines: 4),
                    const SizedBox(height: 36),

                    // Submit Button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF6B0000),
                            Color(0xFF500000),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF6B0000).withValues(alpha: 0.4),
                            spreadRadius: 0,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _saveData,
                          borderRadius: BorderRadius.circular(10),
                          child: const Center(
                            child: Text(
                              'SIMPAN DATA',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF2C2C2C),
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    bool required = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 0,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[500]),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: InputBorder.none,
        ),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Field ini harus diisi';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildTextFieldWithIcon(
    TextEditingController controller,
    String hint,
    IconData icon, {
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 0,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: Colors.grey[600], size: 22),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: InputBorder.none,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Field ini harus diisi';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 0,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: InputBorder.none,
        ),
        hint: Text(
          hint,
          style: TextStyle(color: Colors.grey[500]),
        ),
        icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700], size: 28),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SerTiTuPage extends StatefulWidget {
  const SerTiTuPage({super.key});

  @override
  State<SerTiTuPage> createState() => _SerTiTuPageState();
}

class _SerTiTuPageState extends State<SerTiTuPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _jamAbsensiController = TextEditingController();
  final TextEditingController _jabatanController =
      TextEditingController(text: 'Jagat Saksana');
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _laporanController = TextEditingController();
  final TextEditingController _tandaTanganController = TextEditingController();
  final TextEditingController _yangMenerimaController = TextEditingController();
  final TextEditingController _yangMenyerahkanController =
      TextEditingController();

  String? _selectedReguPiket;
  final List<String> _reguPiketOptions = ['Regu 1', 'Regu 2', 'Regu 3'];

  String? _selectedNama;
  List<String> _namaOptions = [];

  String? _selectedMengetahui;
  final List<String> _mengetahuiOptions = [
    'KASUBAG UMUM, KEUANGAN DAN LOGISTIK'
  ];

  String? _selectedNamaMengetahui;
  final List<String> _namaMengetahuiOptions = ['FAUZI NURDIN'];
  final String _nipMengetahui = '19780119 200912 1 002';

  bool _isGeneratingPDF = false;

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
    _tanggalController.dispose();
    _jamAbsensiController.dispose();
    _jabatanController.dispose();
    _keteranganController.dispose();
    _laporanController.dispose();
    _tandaTanganController.dispose();
    _yangMenerimaController.dispose();
    _yangMenyerahkanController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    String year = dateTime.year.toString();
    String month = dateTime.month.toString().padLeft(2, '0');
    String day = dateTime.day.toString().padLeft(2, '0');
    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String second = dateTime.second.toString().padLeft(2, '0');
    return '$year$month$day}_$hour$minute$second';
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
              primary: Color(0xFF660300),
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

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF660300),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _jamAbsensiController.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _exportToPDF() async {
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

    if (_selectedMengetahui == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mengetahui harus dipilih'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedNamaMengetahui == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama Mengetahui harus dipilih'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingPDF = true;
    });

    try {
      final DateTime now = DateTime.now();

      // Save to database
      final Map<String, dynamic> serahTerimaData = {
        'regu_piket': _selectedReguPiket,
        'tanggal': _tanggalController.text.trim(),
        'jam_absensi': _jamAbsensiController.text.trim(),
        'nama': _selectedNama,
        'jabatan': _jabatanController.text.trim(),
        'keterangan': _keteranganController.text.trim(),
        'laporan': _laporanController.text.trim(),
        'tanda_tangan': _tandaTanganController.text.trim(),
        'yang_menerima': _yangMenerimaController.text.trim(),
        'yang_menyerahkan': _yangMenyerahkanController.text.trim(),
        'mengetahui_jabatan': _selectedMengetahui,
        'mengetahui_nama': _selectedNamaMengetahui,
        'mengetahui_nip': _nipMengetahui,
        'tanggal_serah_terima': now.toString(),
      };
      await _databaseHelper.insertSerahTerima(serahTerimaData);

      // Create PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'BERITA ACARA SERAH TERIMA TUGAS',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'SEKRETARIAT KPU KABUPATEN SUKABUMI',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      pw.Container(
                        width: double.infinity,
                        height: 2,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 20),
                    ],
                  ),
                ),

                // Data
                _buildPDFRow('Regu Piket', _selectedReguPiket!),
                pw.SizedBox(height: 8),
                _buildPDFRow('Hari/Tanggal', _tanggalController.text.trim()),
                pw.SizedBox(height: 8),
                _buildPDFRow('Jam Absensi', _jamAbsensiController.text.trim()),
                pw.SizedBox(height: 8),
                _buildPDFRow('Nama', _selectedNama!),
                pw.SizedBox(height: 8),
                _buildPDFRow('Jabatan', _jabatanController.text.trim()),
                pw.SizedBox(height: 8),
                _buildPDFRow('Keterangan', _keteranganController.text.trim()),
                pw.SizedBox(height: 8),
                _buildPDFRow('Laporan Serah Terima Tugas',
                    _laporanController.text.trim()),
                pw.SizedBox(height: 8),
                _buildPDFRow(
                    'Tanda Tangan', _tandaTanganController.text.trim()),
                pw.SizedBox(height: 8),
                _buildPDFRow(
                    'Yang Menerima', _yangMenerimaController.text.trim()),
                pw.SizedBox(height: 8),
                _buildPDFRow(
                    'Yang Menyerahkan', _yangMenyerahkanController.text.trim()),

                pw.Spacer(),

                // Mengetahui
                pw.Center(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Mengetahui,',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.Text(
                        _selectedMengetahui!,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 60),
                      pw.Text(
                        _selectedNamaMengetahui!,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'NIP: $_nipMengetahui',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Get Downloads directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = await getDownloadsDirectory();
      }

      final fileName = 'Serah_Terima_${_formatDateTime(now)}.pdf';
      final filePath = '${directory?.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        setState(() {
          _isGeneratingPDF = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF berhasil diekspor ke: $filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );

        // Clear form
        _tanggalController.clear();
        _jamAbsensiController.clear();
        _jabatanController.text = 'Jagat Saksana';
        _keteranganController.clear();
        _laporanController.clear();
        _tandaTanganController.clear();
        _yangMenerimaController.clear();
        _yangMenyerahkanController.clear();
        setState(() {
          _selectedReguPiket = null;
          _selectedNama = null;
          _selectedMengetahui = null;
          _selectedNamaMengetahui = null;
        });
      }
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        setState(() {
          _isGeneratingPDF = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  pw.Widget _buildPDFRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 180,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(': ', style: const pw.TextStyle(fontSize: 11)),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF800020),
            Color(0xFF660300),
            Color(0xFF4A0000),
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 60),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            padding: const EdgeInsets.all(50),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  spreadRadius: 0,
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Regu Piket & Tanggal
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 30),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Hari/Tanggal'),
                            const SizedBox(height: 10),
                            _buildTextFieldWithIcon(
                              _tanggalController,
                              'Pilih tanggal',
                              Icons.calendar_today,
                              onTap: _selectDate,
                              readOnly: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Row 2: Jam Absensi & Nama
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Jam Absensi'),
                            const SizedBox(height: 10),
                            _buildTextFieldWithIcon(
                              _jamAbsensiController,
                              'Pilih waktu',
                              Icons.access_time,
                              onTap: _selectTime,
                              readOnly: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 30),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Nama'),
                            const SizedBox(height: 10),
                            _namaOptions.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.warning,
                                            color: Colors.orange[700], size: 18),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Belum ada data pegawai',
                                            style: TextStyle(fontSize: 12),
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
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Row 3: Jabatan (Full Width - Read Only)
                  _buildLabel('Jabatan'),
                  const SizedBox(height: 10),
                  _buildTextField(_jabatanController, 'Jabatan',
                      readOnly: true),
                  const SizedBox(height: 25),

                  // Row 4: Keterangan (Kecil - hanya untuk "Hadir")
                  _buildLabel('Keterangan'),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 250,
                    child: _buildTextField(_keteranganController, 'Hadir'),
                  ),
                  const SizedBox(height: 25),

                  // Row 5: Laporan Serah Terima Tugas (Besar - Full Width)
                  _buildLabel('Laporan Serah Terima Tugas'),
                  const SizedBox(height: 10),
                  _buildTextField(_laporanController,
                      'Masukkan laporan serah terima tugas secara detail...',
                      maxLines: 6),
                  const SizedBox(height: 25),

                  // Row 6: Tanda Tangan & Yang Menerima
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Tanda Tangan'),
                            const SizedBox(height: 10),
                            _buildTextField(_tandaTanganController,
                                'Nama untuk tanda tangan'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 30),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Yang Menerima'),
                            const SizedBox(height: 10),
                            _buildTextField(
                                _yangMenerimaController, 'Nama yang menerima'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Row 7: Yang Menyerahkan
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Yang Menyerahkan'),
                            const SizedBox(height: 10),
                            _buildTextField(_yangMenyerahkanController,
                                'Nama yang menyerahkan'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 30),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Row 8: Mengetahui - Jabatan & Nama
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Mengetahui (Jabatan)'),
                            const SizedBox(height: 10),
                            _buildDropdown(
                              value: _selectedMengetahui,
                              hint: 'Pilih jabatan',
                              items: _mengetahuiOptions,
                              onChanged: (value) {
                                setState(() {
                                  _selectedMengetahui = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 30),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Nama & NIP'),
                            const SizedBox(height: 10),
                            _buildDropdown(
                              value: _selectedNamaMengetahui,
                              hint: 'Pilih nama',
                              items: _namaMengetahuiOptions,
                              subtitle: 'NIP: $_nipMengetahui',
                              onChanged: (value) {
                                setState(() {
                                  _selectedNamaMengetahui = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 45),

                  // Export PDF Button
                  Center(
                    child: Container(
                      width: 300,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF800020),
                            Color(0xFF660300),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF660300).withValues(alpha: 0.3),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingPDF ? null : _exportToPDF,
                        icon: _isGeneratingPDF
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf,
                                size: 22, color: Colors.white),
                        label: Text(
                          _isGeneratingPDF ? 'Mengekspor PDF...' : 'Export PDF',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
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
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF333333),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? const Color(0xFFF5F5F5) : Colors.white,
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
        validator: (value) {
          if (!readOnly && (value == null || value.trim().isEmpty)) {
            return 'Field ini harus diisi';
          }
          return null;
        },
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
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          suffixIcon: Icon(icon, color: const Color(0xFF800020), size: 20),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    String? subtitle,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ButtonTheme(
        alignedDropdown: true,
        child: DropdownButtonHideUnderline(
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
            hint: Text(hint,
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF800020)),
            isExpanded: true,
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: subtitle != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      )
                    : Text(item, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
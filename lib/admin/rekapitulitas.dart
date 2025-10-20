import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class RekapitulitasPage extends StatefulWidget {
  const RekapitulitasPage({super.key});

  @override
  State<RekapitulitasPage> createState() => _RekapitulitasPageState();
}

class _RekapitulitasPageState extends State<RekapitulitasPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _completedVisitors = [];
  List<Map<String, dynamic>> _filteredVisitors = [];
  bool _isLoading = true;

  int? _selectedMonth;
  int? _selectedYear;
  final List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    _loadCompletedVisitors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompletedVisitors() async {
    setState(() => _isLoading = true);

    try {
      final visitors = await _databaseHelper.getCompletedTamu();
      Set<int> years = {};
      for (var visitor in visitors) {
        if (visitor['tanggal_jam_selesai'] != null) {
          try {
            DateTime dt = DateTime.parse(visitor['tanggal_jam_selesai']);
            years.add(dt.year);
          } catch (e) {
            debugPrint('Error parsing date: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _completedVisitors = visitors;
          _filteredVisitors = visitors;
          _availableYears.clear();
          _availableYears
              .addAll(years.toList()..sort((a, b) => b.compareTo(a)));
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading completed visitors: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterData() {
    setState(() {
      _filteredVisitors = _completedVisitors.where((visitor) {
        if (visitor['tanggal_jam_selesai'] == null) return false;
        try {
          DateTime dt = DateTime.parse(visitor['tanggal_jam_selesai']);
          bool matchMonth =
              _selectedMonth == null || dt.month == _selectedMonth;
          bool matchYear = _selectedYear == null || dt.year == _selectedYear;
          bool matchSearch = true;
          if (_searchController.text.isNotEmpty) {
            String searchText = _searchController.text.toLowerCase();
            matchSearch = (visitor['nama']
                        ?.toString()
                        .toLowerCase()
                        .contains(searchText) ??
                    false) ||
                (visitor['asal']
                        ?.toString()
                        .toLowerCase()
                        .contains(searchText) ??
                    false) ||
                (visitor['tujuan']
                        ?.toString()
                        .toLowerCase()
                        .contains(searchText) ??
                    false) ||
                (visitor['keperluan']
                        ?.toString()
                        .toLowerCase()
                        .contains(searchText) ??
                    false);
          }
          return matchMonth && matchYear && matchSearch;
        } catch (e) {
          return false;
        }
      }).toList();
    });
  }

  void _resetFilter() {
    setState(() {
      _selectedMonth = null;
      _selectedYear = null;
      _searchController.clear();
      _filteredVisitors = _completedVisitors;
    });
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}_${dateTime.hour.toString().padLeft(2, '0')}${dateTime.minute.toString().padLeft(2, '0')}${dateTime.second.toString().padLeft(2, '0')}';
  }

  String _formatDisplayDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return '-';
    try {
      DateTime dt = DateTime.parse(dateTimeStr);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _getPeriodText() {
    const monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    if (_selectedMonth != null && _selectedYear != null) {
      return '${monthNames[_selectedMonth! - 1]} $_selectedYear';
    } else if (_selectedMonth != null) {
      return monthNames[_selectedMonth! - 1];
    } else if (_selectedYear != null) {
      return _selectedYear.toString();
    }
    return 'Semua Periode';
  }

  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();
      final tableData = <Map<String, dynamic>>[];

      for (int i = 0; i < _filteredVisitors.length; i++) {
        final visitor = _filteredVisitors[i];
        String tanggalVisit =
            _formatDisplayDateTime(visitor['tanggal_jam_visit']);
        String tanggalSelesai =
            _formatDisplayDateTime(visitor['tanggal_jam_selesai']);

        String jk = '-';
        if (visitor['jenis_kelamin'] != null) {
          String jkFull = visitor['jenis_kelamin'].toString().toLowerCase();
          if (jkFull.contains('laki')) {
            jk = 'L';
          } else if (jkFull.contains('perempuan') ||
              jkFull.contains('wanita')) {
            jk = 'P';
          } else {
            jk = visitor['jenis_kelamin'].toString();
          }
        }

        pw.MemoryImage? photoImage;
        if (visitor['photo_path'] != null &&
            visitor['photo_path'].toString().isNotEmpty) {
          try {
            final file = File(visitor['photo_path']);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              photoImage = pw.MemoryImage(bytes);
            }
          } catch (e) {
            debugPrint('Error loading image: $e');
          }
        }

        tableData.add({
          'no': (i + 1).toString(),
          'nama': visitor['nama']?.toString() ?? '-',
          'jk': jk,
          'tanggal_visit': tanggalVisit,
          'tanggal_selesai': tanggalSelesai,
          'asal': visitor['asal']?.toString() ?? '-',
          'jumlah': visitor['jumlah_pengunjung']?.toString() ?? '-',
          'tujuan': visitor['tujuan']?.toString() ?? '-',
          'keperluan': visitor['keperluan']?.toString() ?? '-',
          'identitas': visitor['identitas']?.toString() ?? '-',
          'telepon': visitor['telepon']?.toString() ?? '-',
          'operator': visitor['nama_operator']?.toString() ?? '-',
          'photo': photoImage,
        });
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            return [
              pw.Center(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('DAFTAR REKAP TAMU',
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Text('SEMUA UNIT - SEKRETARIAT KPU KABUPATEN SUKABUMI',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Text('PERIODE: ${_getPeriodText()}',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 20),
                  ],
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30), // No
                  1: const pw.FixedColumnWidth(70), // Nama Tamu
                  2: const pw.FixedColumnWidth(25), // JK
                  3: const pw.FixedColumnWidth(85), // Tanggal Jam Visit
                  4: const pw.FixedColumnWidth(85), // Tanggal Jam Selesai
                  5: const pw.FixedColumnWidth(70), // Asal
                  6: const pw.FixedColumnWidth(40), // Jumlah pengunjung
                  7: const pw.FixedColumnWidth(60), // Tujuan
                  8: const pw.FixedColumnWidth(70), // Keperluan
                  9: const pw.FixedColumnWidth(60), // Identitas
                  10: const pw.FixedColumnWidth(65), // Telepon/HP
                  11: const pw.FixedColumnWidth(70), // Nama Operator
                  12: const pw.FixedColumnWidth(60), // Foto Tamu
                },
                children: [
                  pw.TableRow(
                    decoration:
                        pw.BoxDecoration(color: PdfColor.fromHex('#e8300e')),
                    children: [
                      _buildTableCell('No', isHeader: true),
                      _buildTableCell('Nama\nTamu', isHeader: true),
                      _buildTableCell('JK', isHeader: true),
                      _buildTableCell('Tanggal\nJam Visit', isHeader: true),
                      _buildTableCell('Tanggal\nJam\nSelesai', isHeader: true),
                      _buildTableCell('Asal', isHeader: true),
                      _buildTableCell('Jumlah\npengunjung', isHeader: true),
                      _buildTableCell('Tujuan', isHeader: true),
                      _buildTableCell('Keperluan', isHeader: true),
                      _buildTableCell('Identitas', isHeader: true),
                      _buildTableCell('Telepon/HP', isHeader: true),
                      _buildTableCell('Nama\nOperator', isHeader: true),
                      _buildTableCell('Foto Tamu', isHeader: true),
                    ],
                  ),
                  ...tableData.map((row) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(row['no'], isHeader: false),
                        _buildTableCell(row['nama'], isHeader: false),
                        _buildTableCell(row['jk'], isHeader: false),
                        _buildTableCell(row['tanggal_visit'], isHeader: false),
                        _buildTableCell(row['tanggal_selesai'],
                            isHeader: false),
                        _buildTableCell(row['asal'], isHeader: false),
                        _buildTableCell(row['jumlah'], isHeader: false),
                        _buildTableCell(row['tujuan'], isHeader: false),
                        _buildTableCell(row['keperluan'], isHeader: false),
                        _buildTableCell(row['identitas'], isHeader: false),
                        _buildTableCell(row['telepon'], isHeader: false),
                        _buildTableCell(row['operator'], isHeader: false),
                        _buildPhotoCell(row['photo']),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ];
          },
        ),
      );

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }

      String filterInfo = '';
      if (_selectedMonth != null || _selectedYear != null) {
        filterInfo =
            '_${_selectedMonth != null ? 'M$_selectedMonth' : ''}${_selectedYear != null ? 'Y$_selectedYear' : ''}';
      }
      final fileName =
          'Rekap_Tamu${filterInfo}_${_formatDateTime(DateTime.now())}.pdf';
      final filePath = '${directory!.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF berhasil diekspor ke: $filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
                label: 'OK', textColor: Colors.white, onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  pw.Widget _buildTableCell(String text, {required bool isHeader}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildPhotoCell(pw.MemoryImage? photo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      alignment: pw.Alignment.center,
      child: photo != null
          ? pw.Image(photo, width: 50, height: 60, fit: pw.BoxFit.cover)
          : pw.Container(
              width: 50,
              height: 60,
              color: PdfColors.grey300,
              child: pw.Center(
                child: pw.Text(
                  'No\nPhoto',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ),
    );
  }

  void _showDetailDialog(Map<String, dynamic> visitor) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 700,
          constraints: const BoxConstraints(maxHeight: 700),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF660300),
                      Color(0xFF8B0000),
                      Color(0xFF660300)
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.person_outline,
                          size: 28, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    const Text('Detail Tamu',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (visitor['photo_path'] != null &&
                          visitor['photo_path'].toString().isNotEmpty)
                        Container(
                          width: 150,
                          height: 180,
                          margin: const EdgeInsets.only(right: 24),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF660300), width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(visitor['photo_path']),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.person,
                                      size: 60, color: Color(0xFF660300))),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Nama', visitor['nama'] ?? '-'),
                            _buildDetailRow('Jenis Kelamin',
                                visitor['jenis_kelamin'] ?? '-'),
                            _buildDetailRow(
                                'Tanggal Jam Visit',
                                _formatDisplayDateTime(
                                    visitor['tanggal_jam_visit'])),
                            _buildDetailRow(
                                'Tanggal Jam Selesai',
                                _formatDisplayDateTime(
                                    visitor['tanggal_jam_selesai'])),
                            _buildDetailRow('Asal', visitor['asal'] ?? '-'),
                            _buildDetailRow(
                                'Jumlah Pengunjung',
                                visitor['jumlah_pengunjung']?.toString() ??
                                    '-'),
                            _buildDetailRow('Tujuan', visitor['tujuan'] ?? '-'),
                            _buildDetailRow(
                                'Keperluan', visitor['keperluan'] ?? '-'),
                            _buildDetailRow(
                                'Identitas', visitor['identitas'] ?? '-'),
                            _buildDetailRow(
                                'Telepon/HP', visitor['telepon'] ?? '-'),
                            _buildDetailRow('Nama Operator',
                                visitor['nama_operator'] ?? '-'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12)),
                      child: const Text('Tutup',
                          style: TextStyle(
                              color: Color(0xFF660300),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 180,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87))),
          const Text(': ', style: TextStyle(fontSize: 14)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 14, color: Colors.black87))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A0000), Color(0xFF660300), Color(0xFF8B0000)],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.9)
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                // Search
                SizedBox(
                  width: 300,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari nama, asal, tujuan...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 0),
                    ),
                    onChanged: (_) => _filterData(),
                  ),
                ),
                const SizedBox(width: 12),
                // Dropdown Bulan
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!)),
                  child: DropdownButton<int>(
                    value: _selectedMonth,
                    hint: const Text('Pilih Bulan',
                        style: TextStyle(fontSize: 13)),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    items: [
                      const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Semua Bulan',
                              style: TextStyle(fontSize: 13))),
                      ...List.generate(12, (index) {
                        const monthNames = [
                          'Januari',
                          'Februari',
                          'Maret',
                          'April',
                          'Mei',
                          'Juni',
                          'Juli',
                          'Agustus',
                          'September',
                          'Oktober',
                          'November',
                          'Desember'
                        ];
                        return DropdownMenuItem<int>(
                            value: index + 1,
                            child: Text(monthNames[index],
                                style: const TextStyle(fontSize: 13)));
                      }),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedMonth = value;
                      _filterData();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                // Dropdown Tahun
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!)),
                  child: DropdownButton<int>(
                    value: _selectedYear,
                    hint: const Text('Pilih Tahun',
                        style: TextStyle(fontSize: 13)),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    items: [
                      const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Semua Tahun',
                              style: TextStyle(fontSize: 13))),
                      ..._availableYears.map((year) => DropdownMenuItem<int>(
                          value: year,
                          child: Text(year.toString(),
                              style: const TextStyle(fontSize: 13)))),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedYear = value;
                      _filterData();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                // Reset Button
                if (_selectedMonth != null ||
                    _selectedYear != null ||
                    _searchController.text.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: _resetFilter,
                      icon: const Icon(Icons.refresh, size: 18),
                      label:
                          const Text('Reset', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF660300),
                        side: const BorderSide(color: Color(0xFF660300)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                const Spacer(),
                // Export PDF Button
                if (_selectedMonth != null || _selectedYear != null)
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _exportToPDF,
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Export PDF',
                          style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF660300),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        elevation: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0.9)
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 4))
                ],
              ),
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF660300)))
                  : _filteredVisitors.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 80, color: Colors.grey[400]),
                              const SizedBox(height: 20),
                              Text(
                                _selectedMonth != null ||
                                        _selectedYear != null ||
                                        _searchController.text.isNotEmpty
                                    ? 'Tidak ada data untuk filter yang dipilih'
                                    : 'Belum ada data tamu yang selesai',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: const BoxDecoration(
                                color: Color(0xFFe8300e),
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12)),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                      width: 50,
                                      child: Text('No',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 14))),
                                  SizedBox(width: 16),
                                  Expanded(
                                      flex: 2,
                                      child: Text('Nama Tamu',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 14))),
                                  Expanded(
                                      flex: 2,
                                      child: Text('Asal/Instansi',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 14))),
                                  Expanded(
                                      flex: 2,
                                      child: Text('Tujuan',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 14))),
                                  Expanded(
                                      flex: 2,
                                      child: Text('Tanggal Selesai',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 14))),
                                  SizedBox(width: 50),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: _filteredVisitors.length,
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: Colors.grey[300]),
                                itemBuilder: (context, index) {
                                  final visitor = _filteredVisitors[index];
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _showDetailDialog(visitor),
                                      hoverColor: const Color(0xFF660300)
                                          .withValues(alpha: 0.05),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 14),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF660300)
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${index + 1}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF660300)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                visitor['nama'] ?? '-',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                visitor['asal'] ?? '-',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[700]),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                visitor['tujuan'] ?? '-',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[700]),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatDisplayDateTime(visitor[
                                                    'tanggal_jam_selesai']),
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[700]),
                                              ),
                                            ),
                                            Icon(Icons.chevron_right,
                                                color: Colors.grey[400],
                                                size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

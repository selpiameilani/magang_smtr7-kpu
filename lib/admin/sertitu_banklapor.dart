import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SerTiTuBankLaporPage extends StatefulWidget {
  const SerTiTuBankLaporPage({super.key});

  @override
  State<SerTiTuBankLaporPage> createState() => _SerTiTuBankLaporPageState();
}

class _SerTiTuBankLaporPageState extends State<SerTiTuBankLaporPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];
  bool _isLoading = true;

  int? _selectedMonth;
  int? _selectedYear;
  final List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _databaseHelper.getAllSerahTerima();

      Set<int> years = {};
      for (var item in data) {
        if (item['tanggal_input'] != null ||
            item['tanggal_serah_terima'] != null) {
          try {
            String dateStr =
                item['tanggal_input'] ?? item['tanggal_serah_terima'];
            DateTime dt = DateTime.parse(dateStr);
            years.add(dt.year);
          } catch (e) {
            debugPrint('Error parsing date: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _allData = data;
          _filteredData = data;
          _availableYears.clear();
          _availableYears
              .addAll(years.toList()..sort((a, b) => b.compareTo(a)));
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterData() {
    setState(() {
      _filteredData = _allData.where((item) {
        String dateStr =
            item['tanggal_input'] ?? item['tanggal_serah_terima'] ?? '';
        if (dateStr.isEmpty) return false;

        try {
          DateTime dt = DateTime.parse(dateStr);

          bool matchMonth =
              _selectedMonth == null || dt.month == _selectedMonth;
          bool matchYear = _selectedYear == null || dt.year == _selectedYear;

          bool matchSearch = true;
          if (_searchController.text.isNotEmpty) {
            String searchText = _searchController.text.toLowerCase();
            matchSearch =
                (item['nama']?.toString().toLowerCase().contains(searchText) ??
                        false) ||
                    (item['regu_piket']
                            ?.toString()
                            .toLowerCase()
                            .contains(searchText) ??
                        false) ||
                    (item['yang_menerima']
                            ?.toString()
                            .toLowerCase()
                            .contains(searchText) ??
                        false) ||
                    (item['yang_menyerahkan']
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
      _filteredData = _allData;
    });
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
    final monthNames = [
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
    } else {
      return 'Semua Periode';
    }
  }

  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();
      final tableData = <Map<String, dynamic>>[];

      for (int i = 0; i < _filteredData.length; i++) {
        final item = _filteredData[i];
        String tanggal = _formatDisplayDateTime(
            item['tanggal_input'] ?? item['tanggal_serah_terima']);

        tableData.add({
          'no': (i + 1).toString(),
          'regu_piket': item['regu_piket']?.toString() ?? '-',
          'hari_tanggal': tanggal,
          'jam_absen': item['waktu']?.toString() ?? '-',
          'nama': item['nama']?.toString() ?? '-',
          'jabatan': item['yang_menerima']?.toString() ??
              item['yang_menyerahkan']?.toString() ??
              '-',
          'keterangan': item['keterangan']?.toString() ??
              item['laporan']?.toString() ??
              '-',
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
                    pw.Text(
                      'BANK LAPORAN SERAH TERIMA TUGAS',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'SEKRETARIAT KPU KABUPATEN SUKABUMI',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'PERIODE: ${_getPeriodText()}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                  ],
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),
                  1: const pw.FixedColumnWidth(80),
                  2: const pw.FixedColumnWidth(100),
                  3: const pw.FixedColumnWidth(80),
                  4: const pw.FixedColumnWidth(120),
                  5: const pw.FixedColumnWidth(100),
                  6: const pw.FixedColumnWidth(200),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.red900,
                    ),
                    children: [
                      _buildTableCell('No', isHeader: true),
                      _buildTableCell('Regu Piket', isHeader: true),
                      _buildTableCell('Hari/Tanggal', isHeader: true),
                      _buildTableCell('Jam Absen', isHeader: true),
                      _buildTableCell('Nama', isHeader: true),
                      _buildTableCell('Jabatan', isHeader: true),
                      _buildTableCell('Keterangan', isHeader: true),
                    ],
                  ),
                  ...tableData.map((row) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(row['no'], isHeader: false),
                        _buildTableCell(row['regu_piket'], isHeader: false),
                        _buildTableCell(row['hari_tanggal'], isHeader: false),
                        _buildTableCell(row['jam_absen'], isHeader: false),
                        _buildTableCell(row['nama'], isHeader: false),
                        _buildTableCell(row['jabatan'], isHeader: false),
                        _buildTableCell(row['keterangan'], isHeader: false),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ];
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      String filterInfo = '';
      if (_selectedMonth != null || _selectedYear != null) {
        filterInfo =
            '_${_selectedMonth != null ? 'M$_selectedMonth' : ''}${_selectedYear != null ? 'Y$_selectedYear' : ''}';
      }
      final fileName =
          'Bank_Laporan_SerTiTu$filterInfo\_${_formatDateTime(DateTime.now())}.pdf';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
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
      }
    } catch (e) {
      debugPrint('Error exporting to PDF: $e');
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

  void _showDetailDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 650,
            constraints: const BoxConstraints(maxHeight: 700),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF800020),
                        Color(0xFF660300),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        spreadRadius: 0,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Detail Serah Terima Tugas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                            'Regu Piket', data['regu_piket'] ?? '-'),
                        _buildDetailRow('Nama', data['nama'] ?? '-'),
                        _buildDetailRow(
                          'Tanggal',
                          _formatDisplayDateTime(data['tanggal_input'] ??
                              data['tanggal_serah_terima']),
                        ),
                        _buildDetailRow('Waktu', data['waktu'] ?? '-'),
                        _buildDetailRow('Laporan', data['laporan'] ?? '-'),
                        _buildDetailRow(
                            'Keterangan', data['keterangan'] ?? '-'),
                        _buildDetailRow(
                            'Yang Menerima', data['yang_menerima'] ?? '-'),
                        _buildDetailRow('Yang Menyerahkan',
                            data['yang_menyerahkan'] ?? '-'),
                        _buildDetailRow(
                            'Mengetahui', data['mengetahui'] ?? '-'),
                      ],
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: const Text(
                          'Tutup',
                          style: TextStyle(
                            color: Color(0xFF660300),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Top Bar with Filters - Compact Desktop Style
          Row(
            children: [
              // Filter Bulan
              Container(
                height: 45,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  hint:
                      const Text('Pilih Bulan', style: TextStyle(fontSize: 14)),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child:
                          Text('Semua Bulan', style: TextStyle(fontSize: 14)),
                    ),
                    ...List.generate(12, (index) {
                      final month = index + 1;
                      final monthNames = [
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
                        value: month,
                        child: Text(monthNames[index],
                            style: const TextStyle(fontSize: 14)),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedMonth = value;
                      _filterData();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Filter Tahun
              Container(
                height: 45,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: DropdownButton<int>(
                  value: _selectedYear,
                  hint:
                      const Text('Pilih Tahun', style: TextStyle(fontSize: 14)),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child:
                          Text('Semua Tahun', style: TextStyle(fontSize: 14)),
                    ),
                    ..._availableYears.map((year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString(),
                            style: const TextStyle(fontSize: 14)),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedYear = value;
                      _filterData();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Search Box
              SizedBox(
                width: 280,
                height: 45,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari data...',
                    hintStyle: const TextStyle(fontSize: 14),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  onChanged: (value) => _filterData(),
                ),
              ),
              const SizedBox(width: 12),
              // Reset Filter Button
              if (_selectedMonth != null ||
                  _selectedYear != null ||
                  _searchController.text.isNotEmpty)
                SizedBox(
                  height: 45,
                  child: OutlinedButton.icon(
                    onPressed: _resetFilter,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset', style: TextStyle(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 0),
                    ),
                  ),
                ),
              const Spacer(),
              // Export PDF Button
              if (_selectedMonth != null || _selectedYear != null)
                SizedBox(
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: _exportToPDF,
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Export PDF',
                        style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF660300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 0),
                      elevation: 0,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Data Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    spreadRadius: 0,
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedMonth != null ||
                                        _selectedYear != null ||
                                        _searchController.text.isNotEmpty
                                    ? 'Tidak ada data untuk filter yang dipilih'
                                    : 'Belum ada data',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredData.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final data = _filteredData[index];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showDetailDialog(data),
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
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF660300),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              data['nama'] ?? '-',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              data['regu_piket'] ?? '-',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today,
                                                size: 14,
                                                color: Colors.grey[600]),
                                            const SizedBox(width: 6),
                                            Text(
                                              _formatDisplayDateTime(data[
                                                      'tanggal_input'] ??
                                                  data['tanggal_serah_terima']),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Row(
                                          children: [
                                            Icon(Icons.access_time,
                                                size: 14,
                                                color: Colors.grey[600]),
                                            const SizedBox(width: 6),
                                            Text(
                                              data['waktu'] ?? '-',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey[400],
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../database_helper.dart';
import 'rekapitulitas.dart';
import 'sertitu_admin.dart' as sertitu;
import 'manajemen_pegawai.dart';
import 'debug_screen.dart';

class HomeAdminPage extends StatefulWidget {
  final String adminEmail;

  const HomeAdminPage({super.key, required this.adminEmail});

  @override
  State<HomeAdminPage> createState() => _HomeAdminPageState();
}

class _HomeAdminPageState extends State<HomeAdminPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  String _selectedMenu = 'Dashboard';
  int _totalTamu = 0;
  int _totalPerempuan = 0;
  int _totalLakiLaki = 0;
  Map<int, int> _tamuPerBulan = {};
  List<Map<String, dynamic>> _recentVisitors = [];
  bool _isLoading = true;
  bool _isSidebarExpanded = true;

  Timer? _inactivityTimer;
  final Duration _inactivityDuration = const Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _startInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDuration, () {
      _autoLogout();
    });
  }

  void _resetInactivityTimer() {
    _startInactivityTimer();
  }

  void _autoLogout() {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.timer_off, color: Color(0xFF8B0000)),
              SizedBox(width: 12),
              Text('Sesi Berakhir'),
            ],
          ),
          content: const Text(
            'Anda telah logout otomatis karena tidak ada aktivitas selama 5 Menit.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final completedTamu = await _databaseHelper.getCompletedTamu();

      int total = completedTamu.length;
      int perempuan = 0;
      int lakiLaki = 0;
      Map<int, int> tamuBulan = {
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        5: 0,
        6: 0,
        7: 0,
        8: 0,
        9: 0,
        10: 0,
        11: 0,
        12: 0
      };

      for (var tamu in completedTamu) {
        String? gender = tamu['jenis_kelamin']?.toString().toLowerCase();
        if (gender == 'perempuan') {
          perempuan++;
        } else if (gender == 'laki-laki') {
          lakiLaki++;
        }

        if (tamu['tanggal_jam_selesai'] != null &&
            tamu['tanggal_jam_selesai'].toString().isNotEmpty) {
          try {
            DateTime waktu = DateTime.parse(tamu['tanggal_jam_selesai']);
            tamuBulan[waktu.month] = (tamuBulan[waktu.month] ?? 0) + 1;
          } catch (e) {
            debugPrint('Error parsing date: $e');
          }
        }
      }

      List<Map<String, dynamic>> recent = completedTamu.take(8).toList();

      if (mounted) {
        setState(() {
          _totalTamu = total;
          _totalPerempuan = perempuan;
          _totalLakiLaki = lakiLaki;
          _tamuPerBulan = tamuBulan;
          _recentVisitors = recent;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _resetInactivityTimer,
      onPanDown: (_) => _resetInactivityTimer(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Row(
          children: [
            _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(child: _buildMainContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                _isSidebarExpanded ? Icons.menu_open : Icons.menu,
                color: const Color(0xFF8B0000),
                size: 28,
              ),
              onPressed: () {
                setState(() {
                  _isSidebarExpanded = !_isSidebarExpanded;
                });
                _resetInactivityTimer();
              },
            ),
            const SizedBox(width: 20),
            Text(
              _selectedMenu,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isSidebarExpanded ? 260 : 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFF5D0000)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          GestureDetector(
            onTap: () {
              _showOperatorPasswordVerification();
              _resetInactivityTimer();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(
                horizontal: _isSidebarExpanded ? 20 : 15,
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
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
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.account_balance,
                            size: 28,
                            color: Color(0xFF8B0000),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_isSidebarExpanded) ...[
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('KPU',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text('Admin Panel',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                  horizontal: _isSidebarExpanded ? 15 : 10),
              children: [
                _buildMenuButton('Dashboard', Icons.dashboard_rounded),
                const SizedBox(height: 8),
                _buildMenuButton('Rekapitulasi', Icons.assessment_rounded),
                const SizedBox(height: 8),
                _buildMenuButton('SiJagat', Icons.security_rounded),
                const SizedBox(height: 8),
                _buildMenuButton('Debug', Icons.bug_report),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(_isSidebarExpanded ? 15 : 10),
            child: _buildMenuButton('Logout', Icons.logout_rounded,
                isLogout: true),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuButton(String title, IconData icon,
      {bool isLogout = false}) {
    bool isSelected = _selectedMenu == title && !isLogout;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: Colors.white.withValues(alpha: 0.5))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _resetInactivityTimer();
            if (isLogout) {
              _showLogoutDialog();
            } else {
              setState(() {
                _selectedMenu = title;
              });
              if (title == 'Dashboard') {
                _loadDashboardData();
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _isSidebarExpanded ? 16 : 18,
              vertical: 14,
            ),
            child: Row(
              children: [
                Icon(icon,
                    color: isSelected ? Colors.white : Colors.white70,
                    size: 24),
                if (_isSidebarExpanded) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                ],
                if (isSelected && _isSidebarExpanded)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOperatorPasswordVerification() {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Color(0xFF8B0000)),
              SizedBox(width: 12),
              Text('Verifikasi Password Operator'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Masukkan password operator untuk mengakses pengaturan',
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password Operator',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setDialogState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: TextStyle(color: Colors.grey[700])),
            ),
            ElevatedButton(
              onPressed: () async {
                if (passwordController.text.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Password tidak boleh kosong'),
                          backgroundColor: Colors.red),
                    );
                  }
                  return;
                }

                // Verifikasi dengan database
                bool isValid = await _databaseHelper
                    .verifyOperatorPassword(passwordController.text);

                if (!mounted) return;

                if (isValid) {
                  Navigator.pop(context);
                  _showSettingsPage();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Password operator salah!'),
                        backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Colors.white,
              ),
              child: const Text('Verifikasi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          adminEmail: widget.adminEmail,
          databaseHelper: _databaseHelper,
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_selectedMenu == 'Rekapitulasi') {
      return const RekapitulitasPage();
    } else if (_selectedMenu == 'SiJagat') {
      return const sertitu.SerTiTuAdminPage();
    } else if (_selectedMenu == 'Debug') {
      return const DebugScreen();
    } else {
      return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B0000)));
    }

    return Container(
      color: const Color(0xFFF5F5F5),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: _buildStatCard('Total Pengunjung', '$_totalTamu',
                        Icons.people_rounded, const Color(0xFF8B0000))),
                const SizedBox(width: 20),
                Expanded(
                    child: _buildStatCard('Laki-laki', '$_totalLakiLaki',
                        Icons.male_rounded, const Color(0xFF2196F3))),
                const SizedBox(width: 20),
                Expanded(
                    child: _buildStatCard('Perempuan', '$_totalPerempuan',
                        Icons.female_rounded, const Color(0xFFE91E63))),
              ],
            ),
            const SizedBox(height: 25),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildMonthlyChart()),
                const SizedBox(width: 20),
                Expanded(child: _buildGenderChart()),
              ],
            ),
            const SizedBox(height: 25),
            _buildRecentVisitorsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(value,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChart() {
    double total = (_totalLakiLaki + _totalPerempuan).toDouble();
    double perempuanPercent = total > 0 ? (_totalPerempuan / total) * 100 : 0;
    double lakiLakiPercent = total > 0 ? (_totalLakiLaki / total) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Distribusi Gender',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D))),
          const SizedBox(height: 30),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CustomPaint(
                      painter: PieChartPainter(
                          perempuanPercent: perempuanPercent,
                          lakiLakiPercent: lakiLakiPercent)),
                ),
                Column(
                  children: [
                    Text('$_totalTamu',
                        style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2D2D))),
                    Text('Total',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _buildGenderLegend(
              'Laki-laki', const Color(0xFF2196F3), lakiLakiPercent),
          const SizedBox(height: 16),
          _buildGenderLegend(
              'Perempuan', const Color(0xFFE91E63), perempuanPercent),
        ],
      ),
    );
  }

  Widget _buildGenderLegend(String label, Color color, double percent) {
    return Row(
      children: [
        Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D2D2D)))),
        Text('${percent.toStringAsFixed(1)}%',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D))),
      ],
    );
  }

  Widget _buildMonthlyChart() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agt',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    int maxValue =
        _tamuPerBulan.values.fold(0, (max, val) => val > max ? val : max);
    if (maxValue == 0) maxValue = 10;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Grafik Kunjungan Per Bulan',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D))),
          const SizedBox(height: 30),
          SizedBox(
              height: 280,
              child: CustomPaint(
                  painter:
                      LineChartPainter(data: _tamuPerBulan, maxValue: maxValue),
                  child: Container())),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: months
                .map((month) => Text(month,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600])))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentVisitorsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Text('Rekap Tamu',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D))),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedMenu = 'Rekapitulasi';
                    });
                    _resetInactivityTimer();
                  },
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Lihat Semua'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8B0000)),
                ),
              ],
            ),
          ),
          if (_recentVisitors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('Belum ada pengunjung',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 16)),
                  ],
                ),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2.5),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border:
                        Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  children: [
                    _buildTableHeader('Nama'),
                    _buildTableHeader('Asal/Instansi'),
                    _buildTableHeader('Waktu Kunjungan'),
                    _buildTableHeader('Gender'),
                  ],
                ),
                ..._recentVisitors.take(6).map((visitor) {
                  return TableRow(
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: Colors.grey[200]!))),
                    children: [
                      _buildTableCell(visitor['nama'] ?? '-'),
                      _buildTableCell(
                          visitor['asal'] ?? visitor['instansi'] ?? '-'),
                      _buildTableCell(
                          _formatDateTime(visitor['tanggal_jam_selesai'])),
                      _buildTableCell(
                        visitor['jenis_kelamin'] ?? '-',
                        icon: visitor['jenis_kelamin']
                                    ?.toString()
                                    .toLowerCase() ==
                                'laki-laki'
                            ? Icons.male
                            : Icons.female,
                        iconColor: visitor['jenis_kelamin']
                                    ?.toString()
                                    .toLowerCase() ==
                                'laki-laki'
                            ? const Color(0xFF2196F3)
                            : const Color(0xFFE91E63),
                      ),
                    ],
                  );
                }),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D2D2D))),
    );
  }

  Widget _buildTableCell(String text, {IconData? icon, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
          ],
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null || dateTime.toString().isEmpty) return '-';
    try {
      DateTime dt = DateTime.parse(dateTime.toString());
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime.toString();
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Color(0xFF8B0000)),
              SizedBox(width: 12),
              Text('Konfirmasi Logout'),
            ],
          ),
          content: const Text(
              'Apakah Anda yakin ingin keluar dari dashboard admin?',
              style: TextStyle(fontSize: 15)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Batal',
                  style: TextStyle(
                      color: Colors.grey[700], fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Logout',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

// Operator Security Settings Page
class OperatorSecurityPage extends StatefulWidget {
  const OperatorSecurityPage({super.key});

  @override
  State<OperatorSecurityPage> createState() => _OperatorSecurityPageState();
}

class _OperatorSecurityPageState extends State<OperatorSecurityPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  String _currentOperatorPassword = 'pemalas123';
  String _currentOperatorCode = 'OPERATOR2024';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOperatorSettings();
  }

  Future<void> _loadOperatorSettings() async {
    setState(() {
      _isLoading = true;
    });

    final password =
        await _databaseHelper.getOperatorSetting('operator_password');
    final code = await _databaseHelper.getOperatorSetting('operator_code');

    setState(() {
      _currentOperatorPassword = password ?? 'pemalas123';
      _currentOperatorCode = code ?? 'OPERATOR2024';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Keamanan Operator'),
          backgroundColor: const Color(0xFF8B0000),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B0000)),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keamanan Operator'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF8B0000).withValues(alpha: 0.05),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  _buildSecurityCard(
                    icon: Icons.lock_person,
                    title: 'Password Verifikasi Operator',
                    subtitle:
                        'Password untuk mengakses halaman pengaturan operator',
                    currentValue: _currentOperatorPassword,
                    onTap: () => _showChangeOperatorPasswordDialog(),
                  ),
                  const SizedBox(height: 24),
                  _buildSecurityCard(
                    icon: Icons.key,
                    title: 'Kode Operator',
                    subtitle: 'Kode untuk menghapus semua data sistem',
                    currentValue: _currentOperatorCode,
                    onTap: () => _showChangeOperatorCodeDialog(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String currentValue,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B0000).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF8B0000), size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saat ini: $currentValue',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8B0000),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF8B0000)),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangeOperatorPasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_person, color: Color(0xFF8B0000)),
            SizedBox(width: 12),
            Text('Ubah Password Operator'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password Lama',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password Baru',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Konfirmasi Password Baru',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () async {
              if (oldPasswordController.text != _currentOperatorPassword) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Password lama salah!'),
                        backgroundColor: Colors.red),
                  );
                }
                return;
              }

              if (newPasswordController.text.isEmpty ||
                  confirmPasswordController.text.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Semua field harus diisi'),
                        backgroundColor: Colors.red),
                  );
                }
                return;
              }

              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Password baru tidak cocok'),
                        backgroundColor: Colors.red),
                  );
                }
                return;
              }

              // Update ke database
              bool updated = await _databaseHelper.updateOperatorSetting(
                  'operator_password', newPasswordController.text);

              if (!mounted) return;

              if (updated) {
                setState(() {
                  _currentOperatorPassword = newPasswordController.text;
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Password operator berhasil diubah!'),
                      backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Gagal mengubah password operator'),
                      backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showChangeOperatorCodeDialog() {
    final oldCodeController = TextEditingController();
    final newCodeController = TextEditingController();
    final confirmCodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.key, color: Color(0xFF8B0000)),
            SizedBox(width: 12),
            Text('Ubah Kode Operator'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCodeController,
              decoration: InputDecoration(
                labelText: 'Kode Lama',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.key_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newCodeController,
              decoration: InputDecoration(
                labelText: 'Kode Baru',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.key_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmCodeController,
              decoration: InputDecoration(
                labelText: 'Konfirmasi Kode Baru',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.key_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () async {
              if (oldCodeController.text != _currentOperatorCode) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Kode lama salah!'),
                        backgroundColor: Colors.red),
                  );
                }
                return;
              }

              if (newCodeController.text.isEmpty ||
                  confirmCodeController.text.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Semua field harus diisi'),
                        backgroundColor: Colors.red),
                  );
                }
                return;
              }

              if (newCodeController.text != confirmCodeController.text) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Kode baru tidak cocok'),
                        backgroundColor: Colors.red),
                  );
                }
                return;
              }

              // Update ke database
              bool updated = await _databaseHelper.updateOperatorSetting(
                  'operator_code', newCodeController.text);

              if (!mounted) return;

              if (updated) {
                setState(() {
                  _currentOperatorCode = newCodeController.text;
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Kode operator berhasil diubah!'),
                      backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Gagal mengubah kode operator'),
                      backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

// Custom Painters
class PieChartPainter extends CustomPainter {
  final double perempuanPercent;
  final double lakiLakiPercent;

  PieChartPainter(
      {required this.perempuanPercent, required this.lakiLakiPercent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final lakiLakiPaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.fill;

    double lakiLakiSweep = (lakiLakiPercent / 100) * 360;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -90 * (3.14159 / 180),
      lakiLakiSweep * (3.14159 / 180),
      true,
      lakiLakiPaint,
    );

    final perempuanPaint = Paint()
      ..color = const Color(0xFFE91E63)
      ..style = PaintingStyle.fill;

    double perempuanStart = -90 + lakiLakiSweep;
    double perempuanSweep = (perempuanPercent / 100) * 360;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      perempuanStart * (3.14159 / 180),
      perempuanSweep * (3.14159 / 180),
      true,
      perempuanPaint,
    );

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.6, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LineChartPainter extends CustomPainter {
  final Map<int, int> data;
  final int maxValue;

  LineChartPainter({required this.data, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B0000)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF8B0000).withValues(alpha: 0.2),
          const Color(0xFF8B0000).withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final pointPaint = Paint()
      ..color = const Color(0xFF8B0000)
      ..style = PaintingStyle.fill;

    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 5; i++) {
      double y = (size.height / 5) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final fillPath = Path();
    final List<Offset> points = [];

    double segmentWidth = size.width / 11;

    fillPath.moveTo(0, size.height);

    for (int i = 1; i <= 12; i++) {
      double x = (i - 1) * segmentWidth;
      int value = data[i] ?? 0;
      double y = size.height - (value / maxValue * size.height);

      points.add(Offset(x, y));

      if (i == 1) {
        path.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    for (var point in points) {
      canvas.drawCircle(point, 6, pointBorderPaint);
      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Settings Page
class SettingsPage extends StatefulWidget {
  final String adminEmail;
  final DatabaseHelper databaseHelper;

  const SettingsPage({
    super.key,
    required this.adminEmail,
    required this.databaseHelper,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late VideoPlayerController _controller;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/vidio_latar.mp4')
        ..setLooping(true)
        ..setVolume(0);

      await _controller.initialize();
      await _controller.play();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildGridButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OperatorSecurityPage(),
              ),
            );
          },
          child: const Text(
            'Pengaturan Operator',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Video Background
          if (_isVideoInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.center,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B0000), Color(0xFF5D0000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          // Dark Overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    childAspectRatio: 1.3,
                    children: [
                      _buildGridButton(
                        icon: Icons.people,
                        title: 'Kepegawaian',
                        subtitle: 'Kelola pegawai Jagat Saksana',
                        color: const Color(0xFFe95007),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const ManajemenPegawaiPage()),
                          );
                        },
                      ),
                      _buildGridButton(
                        icon: Icons.email,
                        title: 'Ubah Email',
                        subtitle: 'Perbarui email akun admin',
                        color: const Color(0xFFe8300e),
                        onTap: () => _showChangeEmailDialog(),
                      ),
                      _buildGridButton(
                        icon: Icons.lock,
                        title: 'Rubah Sandi',
                        subtitle: 'Perbarui password admin',
                        color: const Color(0xFFff8f00),
                        onTap: () => _showChangePasswordDialog(),
                      ),
                      _buildGridButton(
                        icon: Icons.delete_forever,
                        title: 'Hapus Data',
                        subtitle: 'Hapus semua data sistem',
                        color: const Color(0xFFffdc73),
                        onTap: () => _showDeleteDataDialog(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangeEmailDialog() {
    final newEmailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.email, color: Color(0xFFe8300e)),
            SizedBox(width: 12),
            Text('Ubah Email'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newEmailController,
              decoration: InputDecoration(
                labelText: 'Email Baru',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password Konfirmasi',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newEmailController.text.isEmpty ||
                  passwordController.text.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Semua field harus diisi'),
                        backgroundColor: Colors.red),
                  );
                }
                return;
              }

              bool isValid = await widget.databaseHelper.verifyAdminPassword(
                  widget.adminEmail, passwordController.text);

              if (!isValid) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Password salah!'),
                        backgroundColor: Colors.red),
                  );
                }
                return;
              }

              bool updated = await widget.databaseHelper
                  .updateAdminEmail(widget.adminEmail, newEmailController.text);

              if (mounted) {
                Navigator.pop(context);
                if (updated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Email berhasil diubah! Silakan login ulang'),
                        backgroundColor: Colors.green),
                  );
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Gagal mengubah email'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFe8300e),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock, color: Color(0xFFff8f00)),
            SizedBox(width: 12),
            Text('Ubah Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password Lama',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password Baru',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Konfirmasi Password Baru',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () async {
              if (oldPasswordController.text.isEmpty ||
                  newPasswordController.text.isEmpty ||
                  confirmPasswordController.text.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Semua field harus diisi'),
                        backgroundColor: Colors.red),
                  );
                }
                return;
              }

              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Password baru tidak cocok'),
                        backgroundColor: Colors.red),
                  );
                }
                return;
              }

              bool isValid = await widget.databaseHelper.verifyAdminPassword(
                  widget.adminEmail, oldPasswordController.text);

              if (!isValid) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Password lama salah!'),
                        backgroundColor: Colors.red),
                  );
                }
                return;
              }

              bool updated = await widget.databaseHelper.updateAdminPassword(
                  widget.adminEmail, newPasswordController.text);

              if (mounted) {
                Navigator.pop(context);
                if (updated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Password berhasil diubah! Silakan login ulang'),
                        backgroundColor: Colors.green),
                  );
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Gagal mengubah password'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFff8f00),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDataDialog() {
    final operatorCodeController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 12),
            Text('Hapus Semua Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PERINGATAN: Tindakan ini akan menghapus SEMUA data (Pengunjung & Bank Lapor) secara permanen!',
              style: TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: operatorCodeController,
              decoration: InputDecoration(
                labelText: 'Kode Operator',
                hintText: 'Masukkan kode operator',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.key),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password Admin',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () async {
              // Verifikasi kode operator dari database
              bool isCodeValid = await widget.databaseHelper
                  .verifyOperatorCode(operatorCodeController.text);

              if (!isCodeValid) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Kode operator salah!'),
                        backgroundColor: Colors.red),
                  );
                }
                return;
              }

              bool isValid = await widget.databaseHelper.verifyAdminPassword(
                  widget.adminEmail, passwordController.text);

              if (!isValid) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Password admin salah!'),
                        backgroundColor: Colors.red),
                  );
                }
                return;
              }

              bool deletedTamu =
                  await widget.databaseHelper.deleteAllTamuData();
              bool deletedBankLapor =
                  await widget.databaseHelper.deleteAllBankLaporData();

              if (mounted) {
                Navigator.pop(context);
                if (deletedTamu && deletedBankLapor) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Semua data berhasil dihapus'),
                        backgroundColor: Colors.green),
                  );
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Gagal menghapus beberapa data'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFffdc73),
              foregroundColor: Colors.black87,
            ),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }
}

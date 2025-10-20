import 'package:flutter/material.dart';
import 'reservasi_tamu.dart';
import 'database_helper.dart';
import 'main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  static List<Map<String, String>> activeVisitors = [];
  static int completedVisitors = 0;

  static void addVisitor(Map<String, String> visitor) {
    activeVisitors.add(visitor);
  }

  void _logoutVisitor(String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Color(0xFF660300)),
              SizedBox(width: 10),
              Text('Konfirmasi Keluar'),
            ],
          ),
          content: Text(
            "Anda yakin keluar di jam ${DateTime.now().toLocal().toString().substring(11, 16)}?",
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                "Tidak",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF660300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                await DatabaseHelper()
                    .updateTamuSelesai(name, DateTime.now().toString());
                setState(() {
                  activeVisitors
                      .removeWhere((visitor) => visitor['name'] == name);
                  completedVisitors++;
                });
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text(
                "Ya",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Hitung ukuran responsif berdasarkan lebar window
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          // Sidebar width yang responsif
          final sidebarWidth = screenWidth < 1000 ? 200.0 : 220.0;

          // Padding yang responsif
          final horizontalPadding = screenWidth < 1000 ? 20.0 : 30.0;
          final verticalPadding = screenHeight < 700 ? 20.0 : 30.0;

          // App bar height yang responsif
          final appBarHeight = screenHeight < 700 ? 70.0 : 80.0;

          return Container(
            // Background gradasi maroon
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF660300), // Maroon
                  Color(0xFF4A0200), // Dark Maroon
                ],
              ),
            ),
            child: Column(
              children: [
                // === APP BAR GRADASI MAROON ===
                Container(
                  width: double.infinity,
                  height: appBarHeight,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFF660300), // Maroon
                        Color(0xFF8B0000), // Dark Maroon
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Row(
                      children: [
                        Container(
                          width: screenWidth < 1000 ? 45 : 50,
                          height: screenWidth < 1000 ? 45 : 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/logo_kpu.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.account_balance,
                                  color: Colors.white,
                                  size: screenWidth < 1000 ? 24 : 28,
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(width: screenWidth < 1000 ? 15 : 20),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sistem Informasi Buku Tamu',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth < 1000 ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'KPU Kabupaten Sukabumi',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: screenWidth < 1000 ? 12 : 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.admin_panel_settings,
                              color: Colors.white,
                              size: screenWidth < 1000 ? 22 : 24,
                            ),
                            tooltip: 'Login Staff',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminLoginPage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // === BODY ===
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(verticalPadding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SIDEBAR KIRI - Button Reservasi di tengah
                        Container(
                          width: sidebarWidth,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: _buildNavButton(
                                icon: Icons.person_add,
                                title: 'Reservasi Tamu',
                                isActive: true,
                                isCompact: screenWidth < 1000,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ReservasiTamuPage(),
                                    ),
                                  ).then((_) {
                                    setState(() {});
                                  });
                                },
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: screenWidth < 1000 ? 20 : 25),

                        // KONTEN UTAMA
                        Expanded(
                          child: Column(
                            children: [
                              // COUNTER CARDS
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildCounterCard(
                                      count: activeVisitors.length,
                                      label: 'Sedang Berkunjung',
                                      icon: Icons.people,
                                      color: Colors.white,
                                      isCompact: screenWidth < 1000,
                                    ),
                                  ),
                                  SizedBox(width: screenWidth < 1000 ? 15 : 20),
                                  Expanded(
                                    child: _buildCounterCard(
                                      count: completedVisitors,
                                      label: 'Telah Berkunjung',
                                      icon: Icons.check_circle,
                                      color: Colors.white,
                                      isCompact: screenWidth < 1000,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: screenHeight < 700 ? 20 : 30),

                              // LIST TAMU
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.all(
                                          screenWidth < 1000 ? 20 : 25,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.people,
                                              color: const Color(0xFF660300),
                                              size:
                                                  screenWidth < 1000 ? 24 : 26,
                                            ),
                                            SizedBox(
                                              width:
                                                  screenWidth < 1000 ? 10 : 12,
                                            ),
                                            Flexible(
                                              child: Text(
                                                'Daftar Tamu yang Sedang Berkunjung',
                                                style: TextStyle(
                                                  fontSize: screenWidth < 1000
                                                      ? 18
                                                      : 20,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      const Color(0xFF660300),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Divider(
                                          height: 1, color: Colors.grey[300]),
                                      Expanded(
                                        child: activeVisitors.isEmpty
                                            ? Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.people_outline,
                                                      size: screenWidth < 1000
                                                          ? 60
                                                          : 80,
                                                      color: Colors.grey[300],
                                                    ),
                                                    SizedBox(
                                                      height: screenHeight < 700
                                                          ? 15
                                                          : 20,
                                                    ),
                                                    Text(
                                                      'Belum Ada Tamu yang Berkunjung',
                                                      style: TextStyle(
                                                        color: Colors.grey[500],
                                                        fontSize:
                                                            screenWidth < 1000
                                                                ? 14
                                                                : 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : Scrollbar(
                                                thumbVisibility: true,
                                                child: ListView.builder(
                                                  padding: EdgeInsets.all(
                                                    screenWidth < 1000
                                                        ? 15
                                                        : 20,
                                                  ),
                                                  itemCount:
                                                      activeVisitors.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final visitor =
                                                        activeVisitors[index];
                                                    return Container(
                                                      margin: EdgeInsets.only(
                                                        bottom:
                                                            screenHeight < 700
                                                                ? 10
                                                                : 12,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        border: Border.all(
                                                            color: Colors
                                                                .grey[200]!),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.03),
                                                            blurRadius: 5,
                                                            offset:
                                                                const Offset(
                                                                    0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Padding(
                                                        padding: EdgeInsets.all(
                                                          screenWidth < 1000
                                                              ? 15
                                                              : 18,
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Container(
                                                              width:
                                                                  screenWidth <
                                                                          1000
                                                                      ? 45
                                                                      : 50,
                                                              height:
                                                                  screenWidth <
                                                                          1000
                                                                      ? 45
                                                                      : 50,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: const Color(
                                                                        0xFF660300)
                                                                    .withOpacity(
                                                                        0.1),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              child: Icon(
                                                                Icons.person,
                                                                color: const Color(
                                                                    0xFF660300),
                                                                size:
                                                                    screenWidth <
                                                                            1000
                                                                        ? 24
                                                                        : 28,
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width:
                                                                  screenWidth <
                                                                          1000
                                                                      ? 15
                                                                      : 18,
                                                            ),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    visitor['name'] ??
                                                                        '',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize: screenWidth <
                                                                              1000
                                                                          ? 15
                                                                          : 17,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: Colors
                                                                          .black87,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          5),
                                                                  Wrap(
                                                                    spacing: screenWidth <
                                                                            1000
                                                                        ? 15
                                                                        : 20,
                                                                    runSpacing:
                                                                        5,
                                                                    children: [
                                                                      Row(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          Icon(
                                                                            Icons.location_on,
                                                                            size:
                                                                                14,
                                                                            color:
                                                                                Colors.grey[600],
                                                                          ),
                                                                          const SizedBox(
                                                                              width: 5),
                                                                          Flexible(
                                                                            child:
                                                                                Text(
                                                                              visitor['asal'] ?? '',
                                                                              style: TextStyle(
                                                                                color: Colors.grey[700],
                                                                                fontSize: screenWidth < 1000 ? 12 : 14,
                                                                              ),
                                                                              overflow: TextOverflow.ellipsis,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      Row(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          Icon(
                                                                            Icons.access_time,
                                                                            size:
                                                                                14,
                                                                            color:
                                                                                Colors.grey[600],
                                                                          ),
                                                                          const SizedBox(
                                                                              width: 5),
                                                                          Text(
                                                                            visitor['time'] ??
                                                                                '',
                                                                            style:
                                                                                TextStyle(
                                                                              color: Colors.grey[700],
                                                                              fontSize: screenWidth < 1000 ? 12 : 14,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .red[50],
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                              ),
                                                              child: IconButton(
                                                                onPressed: () =>
                                                                    _logoutVisitor(
                                                                        visitor['name'] ??
                                                                            ''),
                                                                icon: Icon(
                                                                  Icons.logout,
                                                                  color: const Color(
                                                                      0xFF660300),
                                                                  size: screenWidth <
                                                                          1000
                                                                      ? 20
                                                                      : 22,
                                                                ),
                                                                tooltip:
                                                                    'Check Out',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
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
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String title,
    required bool isActive,
    required bool isCompact,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF660300), Color(0xFF8B0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF660300).withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 15 : 20,
              vertical: isCompact ? 15 : 18,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: isCompact ? 22 : 24,
                ),
                SizedBox(width: isCompact ? 10 : 12),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 14 : 15,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterCard({
    required int count,
    required String label,
    required IconData icon,
    required Color color,
    required bool isCompact,
  }) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 20 : 25),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isCompact ? 55 : 65,
            height: isCompact ? 55 : 65,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF660300), Color(0xFF8B0000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isCompact ? 28 : 32,
            ),
          ),
          SizedBox(width: isCompact ? 15 : 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    color: const Color(0xFF660300),
                    fontSize: isCompact ? 32 : 36,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: isCompact ? 13 : 15,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../database_helper.dart';

class ManajemenPegawaiPage extends StatefulWidget {
  const ManajemenPegawaiPage({super.key});

  @override
  State<ManajemenPegawaiPage> createState() => _ManajemenPegawaiPageState();
}

class _ManajemenPegawaiPageState extends State<ManajemenPegawaiPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final TextEditingController _namaController = TextEditingController();
  List<Map<String, dynamic>> _pegawaiList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPegawai();
  }

  @override
  void dispose() {
    _namaController.dispose();
    super.dispose();
  }

  Future<void> _loadPegawai() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _databaseHelper.getAllPegawaiJagat();
      if (mounted) {
        setState(() {
          _pegawaiList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pegawai: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _tambahPegawai() async {
    if (_namaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama tidak boleh kosong'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final result = await _databaseHelper.insertPegawaiJagat(
        _namaController.text.trim(),
      );

      if (result > 0) {
        _namaController.clear();
        await _loadPegawai();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pegawai berhasil ditambahkan'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nama pegawai sudah ada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
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

  Future<void> _editPegawai(int id, String currentName) async {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF2196F3)),
            SizedBox(width: 12),
            Text('Edit Nama Pegawai'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Nama Pegawai',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nama tidak boleh kosong'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await _databaseHelper.updatePegawaiJagat(
                  id,
                  controller.text.trim(),
                );
                Navigator.pop(context);
                await _loadPegawai();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pegawai berhasil diupdate'),
                      backgroundColor: Colors.green,
                    ),
                  );
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _hapusPegawai(int id, String nama) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Color(0xFFE91E63)),
            SizedBox(width: 12),
            Text('Hapus Pegawai'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "$nama"?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _databaseHelper.deletePegawaiJagat(id);
                Navigator.pop(context);
                await _loadPegawai();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pegawai berhasil dihapus'),
                      backgroundColor: Colors.green,
                    ),
                  );
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showTambahDialog() {
    _namaController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Color(0xFF8B0000)),
            SizedBox(width: 12),
            Text('Tambah Pegawai Baru'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _namaController,
              decoration: InputDecoration(
                labelText: 'Nama Pegawai',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: _tambahPegawai,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Manajemen Pegawai Jagat'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header dengan tombol tambah
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Text(
                        'Total Pegawai: ${_pegawaiList.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _showTambahDialog,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Tambah Pegawai'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B0000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // List pegawai
                Expanded(
                  child: _pegawaiList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada data pegawai',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: _pegawaiList.length,
                          itemBuilder: (context, index) {
                            final pegawai = _pegawaiList[index];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B0000)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Color(0xFF8B0000),
                                    size: 28,
                                  ),
                                ),
                                title: Text(
                                  pegawai['nama'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2D2D2D),
                                  ),
                                ),
                                subtitle: Text(
                                  'ID: ${pegawai['id']}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Color(0xFF2196F3)),
                                      onPressed: () => _editPegawai(
                                        pegawai['id'],
                                        pegawai['nama'],
                                      ),
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Color(0xFFE91E63)),
                                      onPressed: () => _hapusPegawai(
                                        pegawai['id'],
                                        pegawai['nama'],
                                      ),
                                      tooltip: 'Hapus',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

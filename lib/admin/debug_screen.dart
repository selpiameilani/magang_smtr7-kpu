import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../database_helper.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({Key? key}) : super(key: key);

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> _logs = [];
  int _localTamuCount = 0;
  int _firestoreTamuCount = 0;
  bool _isConnected = false;
  String _databasePath = '';

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _startListening();
  }

  Future<void> _checkStatus() async {
    setState(() {
      _logs.add('🔍 Checking status...');
    });

    try {
      // Cek database path
      _databasePath = await _dbHelper.getDatabasePath();
      setState(() {
        _logs.add('📁 Database: $_databasePath');
      });

      // Cek apakah file database exists
      final dbFile = File(_databasePath);
      if (await dbFile.exists()) {
        final size = await dbFile.length();
        setState(() {
          _logs.add('✅ DB file exists (${size} bytes)');
        });
      } else {
        setState(() {
          _logs.add('⚠️ DB file NOT exists yet (will be created)');
        });
      }

      // Cek jumlah data lokal
      try {
        final localTamu = await _dbHelper.getAllTamu();
        _localTamuCount = localTamu.length;
        setState(() {
          _logs.add('💾 Local tamu count: $_localTamuCount');
        });
      } catch (e) {
        setState(() {
          _logs.add('❌ ERROR getting local data: $e');
        });
      }

      // Cek jumlah data Firestore
      try {
        final firestoreSnapshot = await _firestore.collection('tamu').get();
        _firestoreTamuCount = firestoreSnapshot.docs.length;
        _isConnected = true;
        setState(() {
          _logs.add('☁️ Firestore tamu count: $_firestoreTamuCount');
          _logs.add('✅ Firebase connected!');
        });
      } catch (e) {
        setState(() {
          _logs.add('❌ ERROR connecting Firebase: $e');
          _isConnected = false;
        });
      }
    } catch (e) {
      setState(() {
        _logs.add('❌ CRITICAL ERROR: $e');
        _isConnected = false;
      });
    }
  }

  void _startListening() {
    // Listen to Firestore changes
    _firestore.collection('tamu').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        String changeType = change.type.toString().split('.').last;
        String docId = change.doc.id.substring(0, 8);
        String nama = change.doc.data()?['nama'] ?? 'Unknown';

        setState(() {
          _logs.add('🔄 [$changeType] $nama (ID: $docId...)');
        });
      }

      // Update count
      setState(() {
        _firestoreTamuCount = snapshot.docs.length;
      });
    });
  }

  Future<void> _testInsert() async {
    setState(() {
      _logs.add('🧪 Testing insert...');
    });

    try {
      final testData = {
        'nama': 'Test User ${DateTime.now().millisecondsSinceEpoch}',
        'nomor_identitas': '1234567890',
        'jenis_kelamin': 'Laki-laki',
        'tanggal_jam_visit': DateTime.now().toIso8601String(),
        'tanggal_jam_selesai': '',
        'asal': 'Test City',
        'jumlah_pengunjung': '1',
        'tujuan': 'Testing',
        'keperluan': 'Test Sync',
        'identitas': 'KTP',
        'telepon': '08123456789',
        'nama_operator': 'Debug',
        'photo_path': '',
      };

      int result = await _dbHelper.insertTamu(testData);

      setState(() {
        _logs.add('✅ Inserted with ID: $result');
        _localTamuCount++;
      });

      // Wait and check Firestore
      await Future.delayed(Duration(seconds: 3));

      final firestoreSnapshot = await _firestore.collection('tamu').get();
      setState(() {
        _firestoreTamuCount = firestoreSnapshot.docs.length;
        _logs.add('✅ Firestore updated: $_firestoreTamuCount records');
      });
    } catch (e) {
      setState(() {
        _logs.add('❌ Insert failed: $e');
      });
    }
  }

  Future<void> _forceSyncFromFirestore() async {
    setState(() {
      _logs.add('🔄 Force syncing from Firestore...');
    });

    try {
      await _dbHelper.forceSyncFromFirestore();

      await Future.delayed(Duration(seconds: 2));

      final localTamu = await _dbHelper.getAllTamu();
      setState(() {
        _localTamuCount = localTamu.length;
        _logs.add('✅ Sync completed! Local: $_localTamuCount');
      });
    } catch (e) {
      setState(() {
        _logs.add('❌ Sync failed: $e');
      });
    }
  }

  Future<void> _testFirestoreConnection() async {
    setState(() {
      _logs.add('🧪 Testing Firestore connection...');
    });

    try {
      // Test Write
      await _firestore.collection('test').doc('connection_test').set({
        'timestamp': DateTime.now().toIso8601String(),
        'device': 'test',
      });
      setState(() {
        _logs.add('✅ Write test: SUCCESS');
      });

      // Test Read
      final doc =
          await _firestore.collection('test').doc('connection_test').get();
      if (doc.exists) {
        setState(() {
          _logs.add('✅ Read test: SUCCESS');
        });
      }

      // Test Read tamu collection
      final tamuSnapshot = await _firestore.collection('tamu').get();
      setState(() {
        _logs.add('📊 Tamu collection: ${tamuSnapshot.docs.length} documents');
        _firestoreTamuCount = tamuSnapshot.docs.length;
      });

      // Show first 3 documents
      for (var i = 0; i < tamuSnapshot.docs.length && i < 3; i++) {
        final doc = tamuSnapshot.docs[i];
        final nama = doc.data()['nama'] ?? 'Unknown';
        setState(() {
          _logs.add('  └─ [${i + 1}] $nama (ID: ${doc.id.substring(0, 8)}...)');
        });
      }
    } catch (e) {
      setState(() {
        _logs.add('❌ Firestore test failed: $e');
      });
    }
  }

  Future<void> _clearLogs() async {
    setState(() {
      _logs.clear();
      _logs.add('🧹 Logs cleared');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Sinkronisasi'),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _checkStatus,
            tooltip: 'Refresh Status',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: _clearLogs,
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Cards
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatusCard(
                        icon: Icons.storage,
                        title: 'Local DB',
                        value: '$_localTamuCount',
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _StatusCard(
                        icon: Icons.cloud,
                        title: 'Firestore',
                        value: '$_firestoreTamuCount',
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isConnected ? Icons.check_circle : Icons.error,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text(
                        _isConnected ? 'Connected to Firebase' : 'Disconnected',
                        style: TextStyle(
                          color: _isConnected
                              ? Colors.green[900]
                              : Colors.red[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _testInsert,
                        icon: Icon(Icons.add),
                        label: Text('Test Insert'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _forceSyncFromFirestore,
                        icon: Icon(Icons.sync),
                        label: Text('Force Sync'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _testFirestoreConnection,
                    icon: Icon(Icons.wifi_find),
                    label: Text('Test Firestore Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Logs
          Expanded(
            child: Container(
              color: Colors.black87,
              child: ListView.builder(
                padding: EdgeInsets.all(8),
                reverse: true,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[_logs.length - 1 - index];
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: TextStyle(
                        color: _getLogColor(log),
                        fontFamily: 'monospace',
                        fontSize: 12,
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

  Color _getLogColor(String log) {
    if (log.contains('✅')) return Colors.green;
    if (log.contains('❌')) return Colors.red;
    if (log.contains('🔄')) return Colors.blue;
    if (log.contains('☁️')) return Colors.orange;
    if (log.contains('💾')) return Colors.purple;
    return Colors.white;
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot>? _tamuSubscription;
  StreamSubscription<QuerySnapshot>? _serahTerimaSubscription;

  bool _isSyncingTamu = false;
  bool _isSyncingSerahTerima = false;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    await _startRealtimeSync();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      if (Platform.isWindows || Platform.isLinux) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String path = join(appDocDir.path, 'tamu_database.db');

      debugPrint('Database path: $path');

      return await openDatabase(
        path,
        version: 7,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      debugPrint('Error initializing database: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tamu (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT UNIQUE,
        nama TEXT NOT NULL,
        nomor_identitas TEXT,
        jenis_kelamin TEXT,
        tanggal_jam_visit TEXT NOT NULL,
        tanggal_jam_selesai TEXT,
        asal TEXT NOT NULL,
        jumlah_pengunjung TEXT NOT NULL,
        tujuan TEXT NOT NULL,
        keperluan TEXT NOT NULL,
        identitas TEXT NOT NULL,
        telepon TEXT NOT NULL,
        nama_operator TEXT NOT NULL,
        photo_path TEXT,
        photo_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE serah_terima_tugas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT UNIQUE,
        petugas_serah TEXT NOT NULL,
        petugas_terima TEXT NOT NULL,
        tanggal_jam TEXT NOT NULL,
        shift TEXT NOT NULL,
        catatan TEXT,
        kondisi_keamanan TEXT,
        peralatan_diserahkan TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE rekapitulasi_harian (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tanggal TEXT NOT NULL UNIQUE,
        total_tamu INTEGER DEFAULT 0,
        total_serah_terima INTEGER DEFAULT 0,
        kejadian_khusus TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE log_aktivitas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jenis_aktivitas TEXT NOT NULL,
        deskripsi TEXT NOT NULL,
        user_id TEXT,
        tanggal_waktu DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE admin (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        nama TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE pegawai_jagat (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE operator_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        setting_key TEXT NOT NULL UNIQUE,
        setting_value TEXT NOT NULL,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.insert('admin', {
      'email': 'admin@kpu.go.id',
      'password': 'admin123',
      'nama': 'Administrator',
    });

    final defaultPegawai = ['Asep Mulyana', 'Asep Nurdin', 'Andri Rustandi'];
    for (String nama in defaultPegawai) {
      await db.insert('pegawai_jagat', {
        'nama': nama,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    await db.insert('operator_settings', {
      'setting_key': 'operator_password',
      'setting_value': 'pemalas123',
      'updated_at': DateTime.now().toIso8601String(),
    });

    await db.insert('operator_settings', {
      'setting_key': 'operator_code',
      'setting_value': 'OPERATOR2024',
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE tamu ADD COLUMN jenis_kelamin TEXT');
      } catch (e) {
        debugPrint('Column jenis_kelamin might already exist: $e');
      }
    }

    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS admin (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            nama TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        var result = await db
            .query('admin', where: 'email = ?', whereArgs: ['admin@kpu.go.id']);
        if (result.isEmpty) {
          await db.insert('admin', {
            'email': 'admin@kpu.go.id',
            'password': 'admin123',
            'nama': 'Administrator',
          });
        }
      } catch (e) {
        debugPrint('Error creating admin table: $e');
      }
    }

    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS pegawai_jagat (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nama TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL
          )
        ''');

        final defaultPegawai = [
          'Asep Mulyana',
          'Asep Nurdin',
          'Andri Rustandi'
        ];
        for (String nama in defaultPegawai) {
          await db.insert(
            'pegawai_jagat',
            {'nama': nama, 'created_at': DateTime.now().toIso8601String()},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      } catch (e) {
        debugPrint('Error creating pegawai_jagat table: $e');
      }
    }

    if (oldVersion < 5) {
      try {
        var tableInfo = await db.rawQuery('PRAGMA table_info(tamu)');
        bool hasNomorIdentitas =
            tableInfo.any((column) => column['name'] == 'nomor_identitas');
        if (!hasNomorIdentitas) {
          await db.execute('ALTER TABLE tamu ADD COLUMN nomor_identitas TEXT');
        }
      } catch (e) {
        debugPrint('Error adding nomor_identitas column: $e');
      }
    }

    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS operator_settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            setting_key TEXT NOT NULL UNIQUE,
            setting_value TEXT NOT NULL,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        var existingSettings = await db.query('operator_settings');
        if (existingSettings.isEmpty) {
          await db.insert('operator_settings', {
            'setting_key': 'operator_password',
            'setting_value': 'pemalas123',
            'updated_at': DateTime.now().toIso8601String(),
          });
          await db.insert('operator_settings', {
            'setting_key': 'operator_code',
            'setting_value': 'OPERATOR2024',
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        debugPrint('Error creating operator_settings table: $e');
      }
    }

    if (oldVersion < 7) {
      try {
        var tamuTableInfo = await db.rawQuery('PRAGMA table_info(tamu)');
        bool hasFirebaseId =
            tamuTableInfo.any((column) => column['name'] == 'firebase_id');
        bool hasUpdatedAt =
            tamuTableInfo.any((column) => column['name'] == 'updated_at');
        bool hasCreatedAt =
            tamuTableInfo.any((column) => column['name'] == 'created_at');
        bool hasPhotoUrl =
            tamuTableInfo.any((column) => column['name'] == 'photo_url');

        if (!hasFirebaseId) {
          await db
              .execute('ALTER TABLE tamu ADD COLUMN firebase_id TEXT UNIQUE');
          debugPrint('✅ Added firebase_id to tamu');
        }
        if (!hasUpdatedAt) {
          await db.execute('ALTER TABLE tamu ADD COLUMN updated_at TEXT');
          await db.execute(
              'UPDATE tamu SET updated_at = datetime("now") WHERE updated_at IS NULL');
          debugPrint('✅ Added updated_at to tamu');
        }
        if (!hasCreatedAt) {
          await db.execute('ALTER TABLE tamu ADD COLUMN created_at TEXT');
          await db.execute(
              'UPDATE tamu SET created_at = datetime("now") WHERE created_at IS NULL');
          debugPrint('✅ Added created_at to tamu');
        }
        if (!hasPhotoUrl) {
          await db.execute('ALTER TABLE tamu ADD COLUMN photo_url TEXT');
          debugPrint('✅ Added photo_url to tamu');
        }

        var serahTerimaTableInfo =
            await db.rawQuery('PRAGMA table_info(serah_terima_tugas)');
        bool hasFirebaseIdSerah = serahTerimaTableInfo
            .any((column) => column['name'] == 'firebase_id');
        bool hasUpdatedAtSerah = serahTerimaTableInfo
            .any((column) => column['name'] == 'updated_at');
        bool hasCreatedAtSerah = serahTerimaTableInfo
            .any((column) => column['name'] == 'created_at');

        if (!hasFirebaseIdSerah) {
          await db.execute(
              'ALTER TABLE serah_terima_tugas ADD COLUMN firebase_id TEXT UNIQUE');
          debugPrint('✅ Added firebase_id to serah_terima_tugas');
        }
        if (!hasUpdatedAtSerah) {
          await db.execute(
              'ALTER TABLE serah_terima_tugas ADD COLUMN updated_at TEXT');
          await db.execute(
              'UPDATE serah_terima_tugas SET updated_at = datetime("now") WHERE updated_at IS NULL');
          debugPrint('✅ Added updated_at to serah_terima_tugas');
        }
        if (!hasCreatedAtSerah) {
          await db.execute(
              'ALTER TABLE serah_terima_tugas ADD COLUMN created_at TEXT');
          await db.execute(
              'UPDATE serah_terima_tugas SET created_at = datetime("now") WHERE created_at IS NULL');
          debugPrint('✅ Added created_at to serah_terima_tugas');
        }
      } catch (e) {
        debugPrint('Error adding Firebase sync columns: $e');
      }
    }
  }

  Future<void> _startRealtimeSync() async {
    try {
      print('🔄 Starting real-time sync...');

      // Listener untuk tabel tamu
      _tamuSubscription = _firestore
          .collection('tamu')
          .snapshots()
          .listen((snapshot) {
        scheduleMicrotask(() async {
          if (_isSyncingTamu) {
            print('⏭️ Skipping tamu sync (already syncing)');
            return;
          }

          _isSyncingTamu = true;
          print('🔄 Syncing ${snapshot.docChanges.length} tamu changes...');

          try {
            for (var change in snapshot.docChanges) {
              try {
                if (change.type == DocumentChangeType.added ||
                    change.type == DocumentChangeType.modified) {
                  await _syncTamuFromFirestore(change.doc);
                } else if (change.type == DocumentChangeType.removed) {
                  await _deleteTamuByFirebaseId(change.doc.id);
                }
              } catch (e) {
                print('❌ Error syncing tamu document ${change.doc.id}: $e');
              }
            }
            print('✅ Tamu sync completed');
          } finally {
            _isSyncingTamu = false;
          }
        });
      }, onError: (error) {
        print('❌ Error in tamu stream: $error');
        _isSyncingTamu = false;
      });

      // Listener untuk tabel serah_terima_tugas
      _serahTerimaSubscription = _firestore
          .collection('serah_terima_tugas')
          .snapshots()
          .listen((snapshot) {
        scheduleMicrotask(() async {
          if (_isSyncingSerahTerima) {
            print('⏭️ Skipping serah_terima sync (already syncing)');
            return;
          }

          _isSyncingSerahTerima = true;
          print('🔄 Syncing ${snapshot.docChanges.length} serah_terima changes...');

          try {
            for (var change in snapshot.docChanges) {
              try {
                if (change.type == DocumentChangeType.added ||
                    change.type == DocumentChangeType.modified) {
                  await _syncSerahTerimaFromFirestore(change.doc);
                } else if (change.type == DocumentChangeType.removed) {
                  await _deleteSerahTerimaByFirebaseId(change.doc.id);
                }
              } catch (e) {
                print('❌ Error syncing serah_terima document ${change.doc.id}: $e');
              }
            }
            print('✅ Serah_terima sync completed');
          } finally {
            _isSyncingSerahTerima = false;
          }
        });
      }, onError: (error) {
        print('❌ Error in serah_terima stream: $error');
        _isSyncingSerahTerima = false;
      });

      print('✅ Real-time sync started');

      // Lakukan initial sync dari Firestore ke SQLite
      await _initialSyncFromFirestore();
    } catch (e) {
      print('❌ Error starting real-time sync: $e');
    }
  }

  Future<void> _initialSyncFromFirestore() async {
    try {
      debugPrint('🔄 Initial sync from Firestore...');

      final tamuSnapshot = await _firestore.collection('tamu').get();
      for (var doc in tamuSnapshot.docs) {
        await _syncTamuFromFirestore(doc);
      }
      debugPrint('✅ Synced ${tamuSnapshot.docs.length} tamu records');

      final serahTerimaSnapshot =
          await _firestore.collection('serah_terima_tugas').get();
      for (var doc in serahTerimaSnapshot.docs) {
        await _syncSerahTerimaFromFirestore(doc);
      }
      debugPrint(
          '✅ Synced ${serahTerimaSnapshot.docs.length} serah_terima records');

      debugPrint('✅ Initial sync completed');
    } catch (e) {
      debugPrint('Error during initial sync: $e');
    }
  }

  Future<void> _syncTamuFromFirestore(DocumentSnapshot doc) async {
    final db = await database;
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final Map<String, dynamic> tamuData = Map.from(data);
      tamuData['firebase_id'] = doc.id;

      if (!tamuData.containsKey('created_at') ||
          tamuData['created_at'] == null) {
        tamuData['created_at'] = DateTime.now().toIso8601String();
      }
      if (!tamuData.containsKey('updated_at') ||
          tamuData['updated_at'] == null) {
        tamuData['updated_at'] = DateTime.now().toIso8601String();
      }

      final existing =
          await db.query('tamu', where: 'firebase_id = ?', whereArgs: [doc.id]);

      if (existing.isEmpty) {
        tamuData.remove('id');
        await db.insert('tamu', tamuData,
            conflictAlgorithm: ConflictAlgorithm.replace);
        debugPrint('📥 Inserted tamu: ${tamuData['nama']}');
      } else {
        final existingUpdatedAt =
            DateTime.tryParse(existing.first['updated_at']?.toString() ?? '');
        final firestoreUpdatedAt =
            DateTime.tryParse(tamuData['updated_at']?.toString() ?? '');

        if (firestoreUpdatedAt != null &&
            existingUpdatedAt != null &&
            firestoreUpdatedAt.isAfter(existingUpdatedAt)) {
          tamuData.remove('id');
          await db.update('tamu', tamuData,
              where: 'firebase_id = ?', whereArgs: [doc.id]);
          debugPrint('🔄 Updated tamu: ${tamuData['nama']}');
        }
      }
    } catch (e) {
      debugPrint('Error syncing tamu ${doc.id}: $e');
    }
  }

  Future<void> _syncSerahTerimaFromFirestore(DocumentSnapshot doc) async {
    final db = await database;
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final Map<String, dynamic> serahTerimaData = Map.from(data);
      serahTerimaData['firebase_id'] = doc.id;

      if (!serahTerimaData.containsKey('created_at') ||
          serahTerimaData['created_at'] == null) {
        serahTerimaData['created_at'] = DateTime.now().toIso8601String();
      }
      if (!serahTerimaData.containsKey('updated_at') ||
          serahTerimaData['updated_at'] == null) {
        serahTerimaData['updated_at'] = DateTime.now().toIso8601String();
      }

      final existing = await db.query('serah_terima_tugas',
          where: 'firebase_id = ?', whereArgs: [doc.id]);

      if (existing.isEmpty) {
        serahTerimaData.remove('id');
        await db.insert('serah_terima_tugas', serahTerimaData,
            conflictAlgorithm: ConflictAlgorithm.replace);
        debugPrint('📥 Inserted serah_terima');
      } else {
        final existingUpdatedAt =
            DateTime.tryParse(existing.first['updated_at']?.toString() ?? '');
        final firestoreUpdatedAt =
            DateTime.tryParse(serahTerimaData['updated_at']?.toString() ?? '');

        if (firestoreUpdatedAt != null &&
            existingUpdatedAt != null &&
            firestoreUpdatedAt.isAfter(existingUpdatedAt)) {
          serahTerimaData.remove('id');
          await db.update('serah_terima_tugas', serahTerimaData,
              where: 'firebase_id = ?', whereArgs: [doc.id]);
          debugPrint('🔄 Updated serah_terima');
        }
      }
    } catch (e) {
      debugPrint('Error syncing serah_terima ${doc.id}: $e');
    }
  }

  Future<void> _deleteTamuByFirebaseId(String firebaseId) async {
    final db = await database;
    try {
      await db
          .delete('tamu', where: 'firebase_id = ?', whereArgs: [firebaseId]);
      debugPrint('🗑️ Deleted tamu: $firebaseId');
    } catch (e) {
      debugPrint('Error deleting tamu: $e');
    }
  }

  Future<void> _deleteSerahTerimaByFirebaseId(String firebaseId) async {
    final db = await database;
    try {
      await db.delete('serah_terima_tugas',
          where: 'firebase_id = ?', whereArgs: [firebaseId]);
      debugPrint('🗑️ Deleted serah_terima: $firebaseId');
    } catch (e) {
      debugPrint('Error deleting serah_terima: $e');
    }
  }

  Future<String?> _uploadToFirestore(
      String collection, Map<String, dynamic> data) async {
    try {
      final Map<String, dynamic> uploadData = Map.from(data);
      uploadData.remove('id');
      uploadData['updated_at'] = DateTime.now().toIso8601String();

      if (!uploadData.containsKey('created_at') ||
          uploadData['created_at'] == null) {
        uploadData['created_at'] = DateTime.now().toIso8601String();
      }

      DocumentReference docRef;
      if (uploadData.containsKey('firebase_id') &&
          uploadData['firebase_id'] != null &&
          uploadData['firebase_id'].toString().isNotEmpty) {
        final firebaseId = uploadData['firebase_id'];
        uploadData.remove('firebase_id');
        docRef = _firestore.collection(collection).doc(firebaseId);
        await docRef.set(uploadData, SetOptions(merge: true));
        debugPrint('☁️ Updated $collection: ${docRef.id}');
      } else {
        uploadData.remove('firebase_id');
        docRef = await _firestore.collection(collection).add(uploadData);
        debugPrint('☁️ Added $collection: ${docRef.id}');
      }

      return docRef.id;
    } catch (e) {
      debugPrint('Error uploading to Firestore: $e');
      return null;
    }
  }

  Future<void> _deleteFromFirestore(
      String collection, String? firebaseId) async {
    try {
      if (firebaseId != null && firebaseId.isNotEmpty) {
        await _firestore.collection(collection).doc(firebaseId).delete();
        debugPrint('☁️ Deleted $collection: $firebaseId');
      }
    } catch (e) {
      debugPrint('Error deleting from Firestore: $e');
    }
  }

  Future<int> insertTamu(Map<String, dynamic> tamu) async {
    final db = await database;
    try {
      tamu['created_at'] = DateTime.now().toIso8601String();
      tamu['updated_at'] = DateTime.now().toIso8601String();

      int result = await db.insert('tamu', tamu);

      if (!_isSyncingTamu) {
        _uploadToFirestore('tamu', tamu).then((firebaseId) async {
          if (firebaseId != null) {
            await db.update('tamu', {'firebase_id': firebaseId},
                where: 'id = ?', whereArgs: [result]);
            debugPrint('✅ Tamu synced to Firestore');
          }
        }).catchError((e) {
          debugPrint('⚠️ Failed to sync tamu: $e');
          return null;
        });
      }

      await _logAktivitas(
          'INSERT_TAMU', 'Menambahkan data tamu: ${tamu['nama']}');
      await _updateRekapitulasiHarian();

      return result;
    } catch (e) {
      debugPrint('Error inserting tamu: $e');
      rethrow;
    }
  }

  Future<int> updateTamu(int id, Map<String, dynamic> tamu) async {
    final db = await database;
    try {
      final existing = await db.query('tamu', where: 'id = ?', whereArgs: [id]);
      final firebaseId =
          existing.isNotEmpty ? existing.first['firebase_id'] as String? : null;

      tamu['updated_at'] = DateTime.now().toIso8601String();
      int result =
          await db.update('tamu', tamu, where: 'id = ?', whereArgs: [id]);

      if (!_isSyncingTamu && firebaseId != null && firebaseId.isNotEmpty) {
        tamu['firebase_id'] = firebaseId;
        _uploadToFirestore('tamu', tamu).catchError((e) {
          debugPrint('⚠️ Failed to sync update: $e');
          return null;
        });
      }

      await _logAktivitas('UPDATE_TAMU', 'Mengupdate data tamu ID: $id');
      return result;
    } catch (e) {
      debugPrint('Error updating tamu: $e');
      rethrow;
    }
  }

  Future<int> deleteTamu(int id) async {
    final db = await database;
    try {
      final existing = await db.query('tamu', where: 'id = ?', whereArgs: [id]);
      final firebaseId =
          existing.isNotEmpty ? existing.first['firebase_id'] as String? : null;

      int result = await db.delete('tamu', where: 'id = ?', whereArgs: [id]);

      if (!_isSyncingTamu && firebaseId != null && firebaseId.isNotEmpty) {
        _deleteFromFirestore('tamu', firebaseId).catchError((e) {
          debugPrint('⚠️ Failed to delete from Firestore: $e');
        });
      }

      await _logAktivitas('DELETE_TAMU', 'Menghapus data tamu ID: $id');
      await _updateRekapitulasiHarian();

      return result;
    } catch (e) {
      debugPrint('Error deleting tamu: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllTamu() async {
    final db = await database;
    try {
      return await db.query('tamu', orderBy: 'created_at DESC');
    } catch (e) {
      debugPrint('Error getting all tamu: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getTamuById(int id) async {
    final db = await database;
    try {
      List<Map<String, dynamic>> results =
          await db.query('tamu', where: 'id = ?', whereArgs: [id]);
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('Error getting tamu by id: $e');
      return null;
    }
  }

  Future<int> updateTamuSelesai(String nama, String tanggalJamSelesai) async {
    final db = await database;
    try {
      final tamu = await db.query('tamu',
          where:
              'nama = ? AND (tanggal_jam_selesai IS NULL OR tanggal_jam_selesai = ?)',
          whereArgs: [nama, '']);

      if (tamu.isNotEmpty) {
        final id = tamu.first['id'] as int;
        final firebaseId = tamu.first['firebase_id'] as String?;

        final updateData = {
          'tanggal_jam_selesai': tanggalJamSelesai,
          'updated_at': DateTime.now().toIso8601String(),
        };

        int result = await db
            .update('tamu', updateData, where: 'id = ?', whereArgs: [id]);

        if (!_isSyncingTamu && firebaseId != null && firebaseId.isNotEmpty) {
          updateData['firebase_id'] = firebaseId;
          _uploadToFirestore('tamu', updateData).catchError((e) {
            debugPrint('⚠️ Failed to sync logout: $e');
            return null;
          });
        }

        await _logAktivitas(
            'LOGOUT_TAMU', 'Tamu logout: $nama pada $tanggalJamSelesai');
        return result;
      }

      return 0;
    } catch (e) {
      debugPrint('Error updating tamu selesai: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCompletedTamu() async {
    final db = await database;
    try {
      return await db.query(
        'tamu',
        where: 'tanggal_jam_selesai != ?',
        whereArgs: [''],
        orderBy: 'tanggal_jam_selesai DESC',
      );
    } catch (e) {
      debugPrint('Error getting completed tamu: $e');
      return [];
    }
  }

  Future<int> insertSerahTerima(Map<String, dynamic> serahTerima) async {
    final db = await database;
    try {
      serahTerima['created_at'] = DateTime.now().toIso8601String();
      serahTerima['updated_at'] = DateTime.now().toIso8601String();

      int result = await db.insert('serah_terima_tugas', serahTerima);

      if (!_isSyncingSerahTerima) {
        _uploadToFirestore('serah_terima_tugas', serahTerima)
            .then((firebaseId) async {
          if (firebaseId != null) {
            await db.update('serah_terima_tugas', {'firebase_id': firebaseId},
                where: 'id = ?', whereArgs: [result]);
            debugPrint('✅ Serah terima synced to Firestore');
          }
        }).catchError((e) {
          debugPrint('⚠️ Failed to sync serah_terima: $e');
          return null;
        });
      }

      await _logAktivitas(
        'INSERT_SERAH_TERIMA',
        'Serah terima dari ${serahTerima['petugas_serah']} ke ${serahTerima['petugas_terima']}',
      );
      await _updateRekapitulasiHarian();

      return result;
    } catch (e) {
      debugPrint('Error inserting serah terima: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllSerahTerima() async {
    final db = await database;
    try {
      return await db.query('serah_terima_tugas', orderBy: 'created_at DESC');
    } catch (e) {
      debugPrint('Error getting all serah terima: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getRekapitulasi() async {
    final db = await database;
    try {
      List<Map<String, dynamic>> tamuCount =
          await db.rawQuery('SELECT COUNT(*) as total FROM tamu');
      List<Map<String, dynamic>> serahTerimaCount =
          await db.rawQuery('SELECT COUNT(*) as total FROM serah_terima_tugas');
      String today = DateTime.now().toIso8601String().split('T')[0];
      List<Map<String, dynamic>> tamuHariIni = await db.rawQuery(
          'SELECT COUNT(*) as total FROM tamu WHERE DATE(created_at) = ?',
          [today]);
      List<Map<String, dynamic>> serahTerimaHariIni = await db.rawQuery(
          'SELECT COUNT(*) as total FROM serah_terima_tugas WHERE DATE(created_at) = ?',
          [today]);

      return {
        'total_tamu': tamuCount.first['total'] ?? 0,
        'total_serah_terima': serahTerimaCount.first['total'] ?? 0,
        'tamu_hari_ini': tamuHariIni.first['total'] ?? 0,
        'serah_terima_hari_ini': serahTerimaHariIni.first['total'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting rekapitulasi: $e');
      return {
        'total_tamu': 0,
        'total_serah_terima': 0,
        'tamu_hari_ini': 0,
        'serah_terima_hari_ini': 0,
      };
    }
  }

  Future<void> _updateRekapitulasiHarian() async {
    final db = await database;
    try {
      String today = DateTime.now().toIso8601String().split('T')[0];
      List<Map<String, dynamic>> tamuToday = await db.rawQuery(
        'SELECT COUNT(*) as total FROM tamu WHERE DATE(created_at) = ?',
        [today],
      );
      List<Map<String, dynamic>> serahTerimaToday = await db.rawQuery(
        'SELECT COUNT(*) as total FROM serah_terima_tugas WHERE DATE(created_at) = ?',
        [today],
      );
      int totalTamu = tamuToday.first['total'] ?? 0;
      int totalSerahTerima = serahTerimaToday.first['total'] ?? 0;
      await db.execute(
        'INSERT OR REPLACE INTO rekapitulasi_harian (tanggal, total_tamu, total_serah_terima) VALUES (?, ?, ?)',
        [today, totalTamu, totalSerahTerima],
      );
    } catch (e) {
      debugPrint('Error updating rekapitulasi harian: $e');
    }
  }

  Future<void> _logAktivitas(String jenis, String deskripsi,
      [String? userId]) async {
    final db = await database;
    try {
      await db.insert('log_aktivitas', {
        'jenis_aktivitas': jenis,
        'deskripsi': deskripsi,
        'user_id': userId ?? 'system',
      });
    } catch (e) {
      debugPrint('Error logging aktivitas: $e');
    }
  }

  Future<bool> verifyAdminPassword(String email, String password) async {
    final db = await database;
    try {
      final result = await db.query('admin',
          where: 'email = ? AND password = ?', whereArgs: [email, password]);
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error verifying admin password: $e');
      return false;
    }
  }

  Future<bool> updateAdminEmail(String oldEmail, String newEmail) async {
    final db = await database;
    try {
      final existing =
          await db.query('admin', where: 'email = ?', whereArgs: [newEmail]);
      if (existing.isNotEmpty) {
        debugPrint('Email sudah digunakan');
        return false;
      }

      final result = await db.update('admin', {'email': newEmail},
          where: 'email = ?', whereArgs: [oldEmail]);

      if (result > 0) {
        await _logAktivitas('UPDATE_ADMIN_EMAIL',
            'Email admin diubah dari $oldEmail ke $newEmail', oldEmail);
      }
      return result > 0;
    } catch (e) {
      debugPrint('Error updating admin email: $e');
      return false;
    }
  }

  Future<bool> updateAdminPassword(String email, String newPassword) async {
    final db = await database;
    try {
      final result = await db.update('admin', {'password': newPassword},
          where: 'email = ?', whereArgs: [email]);

      if (result > 0) {
        await _logAktivitas('UPDATE_ADMIN_PASSWORD',
            'Password admin diubah untuk email: $email', email);
      }
      return result > 0;
    } catch (e) {
      debugPrint('Error updating admin password: $e');
      return false;
    }
  }

  Future<bool> deleteAllTamuData() async {
    final db = await database;
    try {
      final allTamu = await db.query('tamu');
      await db.delete('tamu');

      if (!_isSyncingTamu) {
        for (var tamu in allTamu) {
          final firebaseId = tamu['firebase_id'] as String?;
          if (firebaseId != null && firebaseId.isNotEmpty) {
            _deleteFromFirestore('tamu', firebaseId);
          }
        }
      }

      await _logAktivitas(
          'DELETE_ALL_TAMU', 'Semua data tamu dihapus oleh operator');
      await _updateRekapitulasiHarian();
      return true;
    } catch (e) {
      debugPrint('Error deleting all tamu data: $e');
      return false;
    }
  }

  Future<bool> deleteAllBankLaporData() async {
    final db = await database;
    try {
      final allSerahTerima = await db.query('serah_terima_tugas');
      await db.delete('serah_terima_tugas');

      if (!_isSyncingSerahTerima) {
        for (var data in allSerahTerima) {
          final firebaseId = data['firebase_id'] as String?;
          if (firebaseId != null && firebaseId.isNotEmpty) {
            _deleteFromFirestore('serah_terima_tugas', firebaseId);
          }
        }
      }

      await _logAktivitas('DELETE_ALL_BANK_LAPOR',
          'Semua data serah terima tugas (Bank Lapor) dihapus oleh operator');
      await _updateRekapitulasiHarian();
      return true;
    } catch (e) {
      debugPrint('Error deleting all bank lapor data: $e');
      return false;
    }
  }

  Future<bool> deleteTamuByDateRange(
      DateTime startDate, DateTime endDate) async {
    final db = await database;
    try {
      final tamuToDelete = await db.query(
        'tamu',
        where: 'tanggal_jam_selesai >= ? AND tanggal_jam_selesai <= ?',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      );

      await db.delete(
        'tamu',
        where: 'tanggal_jam_selesai >= ? AND tanggal_jam_selesai <= ?',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      );

      if (!_isSyncingTamu) {
        for (var tamu in tamuToDelete) {
          final firebaseId = tamu['firebase_id'] as String?;
          if (firebaseId != null && firebaseId.isNotEmpty) {
            _deleteFromFirestore('tamu', firebaseId);
          }
        }
      }

      await _logAktivitas(
        'DELETE_TAMU_BY_DATE',
        'Data tamu dihapus untuk periode ${startDate.toString().split(' ')[0]} sampai ${endDate.toString().split(' ')[0]}',
      );
      await _updateRekapitulasiHarian();
      return true;
    } catch (e) {
      debugPrint('Error deleting tamu by date range: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> loginAdmin(
      String email, String password) async {
    final db = await database;
    try {
      final result = await db.query('admin',
          where: 'email = ? AND password = ?', whereArgs: [email, password]);

      if (result.isNotEmpty) {
        await _logAktivitas('LOGIN_ADMIN', 'Admin login: $email', email);
        return result.first;
      }
      return null;
    } catch (e) {
      debugPrint('Error login admin: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAdminByEmail(String email) async {
    final db = await database;
    try {
      final result =
          await db.query('admin', where: 'email = ?', whereArgs: [email]);
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      debugPrint('Error getting admin by email: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllPegawaiJagat() async {
    final db = await database;
    try {
      return await db.query('pegawai_jagat', orderBy: 'nama ASC');
    } catch (e) {
      debugPrint('Error getting pegawai jagat: $e');
      return [];
    }
  }

  Future<int> insertPegawaiJagat(String nama) async {
    final db = await database;
    try {
      int result = await db.insert(
        'pegawai_jagat',
        {'nama': nama, 'created_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      if (result > 0) {
        await _logAktivitas(
            'INSERT_PEGAWAI_JAGAT', 'Menambahkan pegawai jagat: $nama');
      }
      return result;
    } catch (e) {
      debugPrint('Error inserting pegawai jagat: $e');
      rethrow;
    }
  }

  Future<int> deletePegawaiJagat(int id) async {
    final db = await database;
    try {
      int result =
          await db.delete('pegawai_jagat', where: 'id = ?', whereArgs: [id]);

      if (result > 0) {
        await _logAktivitas(
            'DELETE_PEGAWAI_JAGAT', 'Menghapus pegawai jagat ID: $id');
      }
      return result;
    } catch (e) {
      debugPrint('Error deleting pegawai jagat: $e');
      rethrow;
    }
  }

  Future<int> updatePegawaiJagat(int id, String nama) async {
    final db = await database;
    try {
      int result = await db.update('pegawai_jagat', {'nama': nama},
          where: 'id = ?', whereArgs: [id]);

      if (result > 0) {
        await _logAktivitas('UPDATE_PEGAWAI_JAGAT',
            'Mengupdate pegawai jagat ID: $id menjadi $nama');
      }
      return result;
    } catch (e) {
      debugPrint('Error updating pegawai jagat: $e');
      rethrow;
    }
  }

  Future<String?> getOperatorSetting(String key) async {
    final db = await database;
    try {
      final result = await db.query('operator_settings',
          where: 'setting_key = ?', whereArgs: [key]);
      if (result.isNotEmpty) {
        return result.first['setting_value'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting operator setting: $e');
      return null;
    }
  }

  Future<bool> updateOperatorSetting(String key, String value) async {
    final db = await database;
    try {
      final result = await db.update(
        'operator_settings',
        {
          'setting_value': value,
          'updated_at': DateTime.now().toIso8601String()
        },
        where: 'setting_key = ?',
        whereArgs: [key],
      );

      if (result > 0) {
        await _logAktivitas(
            'UPDATE_OPERATOR_SETTING', 'Setting operator diubah: $key');
        return true;
      }

      await db.insert('operator_settings', {
        'setting_key': key,
        'setting_value': value,
        'updated_at': DateTime.now().toIso8601String(),
      });

      await _logAktivitas(
          'INSERT_OPERATOR_SETTING', 'Setting operator baru ditambahkan: $key');
      return true;
    } catch (e) {
      debugPrint('Error updating operator setting: $e');
      return false;
    }
  }

  Future<bool> verifyOperatorPassword(String password) async {
    final storedPassword = await getOperatorSetting('operator_password');
    return storedPassword == password;
  }

  Future<bool> verifyOperatorCode(String code) async {
    final storedCode = await getOperatorSetting('operator_code');
    return storedCode == code;
  }

  Future<String> getDatabasePath() async {
    final db = await database;
    return db.path;
  }

  Future<void> closeDatabase() async {
    await _tamuSubscription?.cancel();
    await _serahTerimaSubscription?.cancel();

    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    debugPrint('✅ Database and Firebase sync closed');
  }

  Future<String> getPhotoStoragePath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photoDir = Directory('${directory.path}/photos');

      if (!await photoDir.exists()) {
        await photoDir.create(recursive: true);
      }

      debugPrint('Photo storage path: ${photoDir.path}');
      return photoDir.path;
    } catch (e) {
      debugPrint('Error getting photo storage path: $e');
      rethrow;
    }
  }

  Future<bool> isDatabaseHealthy() async {
    try {
      final db = await database;
      await db.rawQuery('SELECT COUNT(*) FROM tamu');
      await db.rawQuery('SELECT COUNT(*) FROM serah_terima_tugas');
      await db.rawQuery('SELECT COUNT(*) FROM rekapitulasi_harian');
      await db.rawQuery('SELECT COUNT(*) FROM log_aktivitas');
      await db.rawQuery('SELECT COUNT(*) FROM admin');
      await db.rawQuery('SELECT COUNT(*) FROM pegawai_jagat');
      await db.rawQuery('SELECT COUNT(*) FROM operator_settings');
      return true;
    } catch (e) {
      debugPrint('Database health check failed: $e');
      return false;
    }
  }

  Future<void> forceSyncFromFirestore() async {
    debugPrint('🔄 Force sync from Firestore...');
    await _initialSyncFromFirestore();
  }

  Future<void> forceSyncToFirestore() async {
    debugPrint('🔄 Force sync to Firestore...');
    final db = await database;

    try {
      final allTamu = await db.query('tamu');
      for (var tamu in allTamu) {
        final firebaseId =
            await _uploadToFirestore('tamu', Map<String, dynamic>.from(tamu));
        if (firebaseId != null &&
            (tamu['firebase_id'] == null ||
                tamu['firebase_id'].toString().isEmpty)) {
          await db.update('tamu', {'firebase_id': firebaseId},
              where: 'id = ?', whereArgs: [tamu['id']]);
        }
      }
      debugPrint('✅ Synced ${allTamu.length} tamu to Firestore');

      final allSerahTerima = await db.query('serah_terima_tugas');
      for (var data in allSerahTerima) {
        final firebaseId = await _uploadToFirestore(
            'serah_terima_tugas', Map<String, dynamic>.from(data));
        if (firebaseId != null &&
            (data['firebase_id'] == null ||
                data['firebase_id'].toString().isEmpty)) {
          await db.update('serah_terima_tugas', {'firebase_id': firebaseId},
              where: 'id = ?', whereArgs: [data['id']]);
        }
      }
      debugPrint('✅ Synced ${allSerahTerima.length} serah_terima to Firestore');

      debugPrint('✅ Force sync completed');
    } catch (e) {
      debugPrint('Error force sync to Firestore: $e');
    }
  }
}
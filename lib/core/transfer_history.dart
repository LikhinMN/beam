import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';
import 'package:path/path.dart';
import 'package:beam/ui/state/app_state.dart';

class HistoryEntry {
  final String id;
  final String fileName;
  final int fileSize;
  final String direction;
  final String peerName;
  final String peerIp;
  final double? speedBytesPerSec;
  final String status;
  final String? errorReason;
  final int timestamp;

  HistoryEntry({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.direction,
    required this.peerName,
    required this.peerIp,
    this.speedBytesPerSec,
    required this.status,
    this.errorReason,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_name': fileName,
      'file_size': fileSize,
      'direction': direction,
      'peer_name': peerName,
      'peer_ip': peerIp,
      'speed_bytes_per_sec': speedBytesPerSec,
      'status': status,
      'error_reason': errorReason,
      'timestamp': timestamp,
    };
  }

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map['id'],
      fileName: map['file_name'],
      fileSize: map['file_size'],
      direction: map['direction'],
      peerName: map['peer_name'],
      peerIp: map['peer_ip'],
      speedBytesPerSec: map['speed_bytes_per_sec'],
      status: map['status'],
      errorReason: map['error_reason'],
      timestamp: map['timestamp'],
    );
  }
}

class TransferHistory {
  static final TransferHistory instance = TransferHistory._init();
  static Database? _database;

  TransferHistory._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('beam_history.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB,
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transfers (
        id TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        direction TEXT NOT NULL,
        peer_name TEXT NOT NULL,
        peer_ip TEXT NOT NULL,
        speed_bytes_per_sec REAL,
        status TEXT NOT NULL,
        error_reason TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');
  }

  Future<void> record(TransferItem item, String peerName, String peerIp) async {
    final db = await instance.database;
    final entry = HistoryEntry(
      id: item.id,
      fileName: item.fileName,
      fileSize: item.totalBytes,
      direction: item.direction.name,
      peerName: peerName,
      peerIp: peerIp,
      speedBytesPerSec: item.speedBytesPerSec,
      status: item.status.name,
      errorReason: item.errorReason,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // Use insert with conflict algorithm replace since we might update an entry from active -> completed/failed
    await db.insert('transfers', entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<HistoryEntry>> getAll() async {
    final db = await instance.database;
    final maps = await db.query('transfers', orderBy: 'timestamp DESC');
    return maps.map((map) => HistoryEntry.fromMap(map)).toList();
  }

  Future<void> clear() async {
    final db = await instance.database;
    await db.delete('transfers');
  }

  Future<void> deleteOlderThan(Duration age) async {
    final db = await instance.database;
    final threshold = DateTime.now().subtract(age).millisecondsSinceEpoch;
    await db.delete(
      'transfers',
      where: 'timestamp < ?',
      whereArgs: [threshold],
    );
  }
}

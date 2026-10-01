import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';
import '../models/telemetry_model.dart';
import '../models/alert_model.dart';
import '../models/prediction_result.dart';
import '../models/sync_queue_item.dart';
import '../models/device_model.dart';
import '../core/errors/app_exceptions.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('worker_safety.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Users Table (for cached offline session)
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        worker_id TEXT,
        cached_at INTEGER NOT NULL
      )
    ''');

    // 2. Telemetry Table (Offline-first storage)
    await db.execute('''
      CREATE TABLE telemetry (
        id TEXT PRIMARY KEY,
        worker_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        temperature REAL NOT NULL,
        heart_rate INTEGER NOT NULL,
        spo2 INTEGER NOT NULL,
        gas_level INTEGER NOT NULL,
        humidity REAL NOT NULL,
        latitude REAL,
        longitude REAL,
        battery INTEGER NOT NULL,
        motion_status TEXT NOT NULL,
        fall_detected INTEGER NOT NULL,
        sos INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        sync_attempt_count INTEGER NOT NULL DEFAULT 0,
        ai_status TEXT NOT NULL DEFAULT 'SAFE'
      )
    ''');

    await db.execute('CREATE INDEX idx_telemetry_synced ON telemetry(synced)');
    await db.execute('CREATE INDEX idx_telemetry_timestamp ON telemetry(timestamp DESC)');

    // 3. Alerts Table
    await db.execute('''
      CREATE TABLE alerts (
        id TEXT PRIMARY KEY,
        worker_id TEXT NOT NULL,
        worker_name TEXT NOT NULL,
        type TEXT NOT NULL,
        message TEXT NOT NULL,
        severity TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        acknowledged INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('CREATE INDEX idx_alerts_synced ON alerts(synced)');

    // 4. Predictions Table
    await db.execute('''
      CREATE TABLE predictions (
        id TEXT PRIMARY KEY,
        telemetry_id TEXT,
        status TEXT NOT NULL,
        confidence REAL NOT NULL,
        reason TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // 5. Sync Queue Table (Idempotent sync buffer)
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        record_type TEXT NOT NULL,
        record_id TEXT NOT NULL UNIQUE,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'PENDING'
      )
    ''');

    await db.execute('CREATE INDEX idx_sync_status ON sync_queue(status)');

    // 6. Devices Table
    await db.execute('''
      CREATE TABLE devices (
        device_id TEXT PRIMARY KEY,
        worker_id TEXT NOT NULL,
        name TEXT NOT NULL,
        last_connected INTEGER NOT NULL,
        rssi INTEGER NOT NULL
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // User Session Management
  // ---------------------------------------------------------------------------
  Future<void> saveUser(AppUser user) async {
    try {
      final db = await database;
      await db.insert(
        'users',
        user.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw AppDatabaseException('Failed to cache user session: $e');
    }
  }

  Future<AppUser?> getCachedUser() async {
    try {
      final db = await database;
      final result = await db.query('users', orderBy: 'cached_at DESC', limit: 1);
      if (result.isNotEmpty) {
        return AppUser.fromSqlite(result.first);
      }
      return null;
    } catch (e) {
      throw AppDatabaseException('Failed to retrieve cached user: $e');
    }
  }

  Future<void> clearUserSession() async {
    try {
      final db = await database;
      await db.delete('users');
    } catch (e) {
      throw AppDatabaseException('Failed to clear user session: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Telemetry Operations
  // ---------------------------------------------------------------------------
  Future<void> insertTelemetry(Telemetry telemetry) async {
    try {
      final db = await database;
      await db.insert(
        'telemetry',
        telemetry.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw AppDatabaseException('Failed to insert telemetry: $e');
    }
  }

  Future<Telemetry?> getLatestTelemetry(String workerId) async {
    try {
      final db = await database;
      final result = await db.query(
        'telemetry',
        where: 'worker_id = ? OR worker_id = ?',
        whereArgs: [workerId, ''],
        orderBy: 'timestamp DESC',
        limit: 1,
      );
      if (result.isNotEmpty) {
        return Telemetry.fromSqlite(result.first);
      }
      return null;
    } catch (e) {
      throw AppDatabaseException('Failed to get latest telemetry: $e');
    }
  }

  Future<List<Telemetry>> getTelemetryHistory(String workerId, {int limit = 50}) async {
    try {
      final db = await database;
      final result = await db.query(
        'telemetry',
        where: 'worker_id = ? OR worker_id = ?',
        whereArgs: [workerId, ''],
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      return result.map((m) => Telemetry.fromSqlite(m)).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to fetch telemetry history: $e');
    }
  }

  Future<List<Telemetry>> getUnsyncedTelemetry({int limit = 30}) async {
    try {
      final db = await database;
      final result = await db.query(
        'telemetry',
        where: 'synced = 0',
        orderBy: 'timestamp ASC',
        limit: limit,
      );
      return result.map((m) => Telemetry.fromSqlite(m)).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to fetch unsynced telemetry: $e');
    }
  }

  Future<void> markTelemetrySynced(String id) async {
    try {
      final db = await database;
      await db.update(
        'telemetry',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to mark telemetry synced: $e');
    }
  }

  Future<int> getPendingSyncCount() async {
    try {
      final db = await database;
      final telemetryCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM telemetry WHERE synced = 0'),
      ) ?? 0;
      final alertCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM alerts WHERE synced = 0'),
      ) ?? 0;
      return telemetryCount + alertCount;
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Alerts Operations
  // ---------------------------------------------------------------------------
  Future<void> insertAlert(AlertItem alert) async {
    try {
      final db = await database;
      await db.insert(
        'alerts',
        alert.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw AppDatabaseException('Failed to insert alert: $e');
    }
  }

  Future<List<AlertItem>> getRecentAlerts(String workerId, {int limit = 20}) async {
    try {
      final db = await database;
      final result = await db.query(
        'alerts',
        where: 'worker_id = ? OR worker_id = ?',
        whereArgs: [workerId, ''],
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      return result.map((m) => AlertItem.fromSqlite(m)).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to fetch recent alerts: $e');
    }
  }

  Future<List<AlertItem>> getUnsyncedAlerts({int limit = 20}) async {
    try {
      final db = await database;
      final result = await db.query(
        'alerts',
        where: 'synced = 0',
        orderBy: 'timestamp ASC',
        limit: limit,
      );
      return result.map((m) => AlertItem.fromSqlite(m)).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to fetch unsynced alerts: $e');
    }
  }

  Future<void> markAlertSynced(String id) async {
    try {
      final db = await database;
      await db.update(
        'alerts',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to mark alert synced: $e');
    }
  }

  Future<void> acknowledgeAlert(String id) async {
    try {
      final db = await database;
      await db.update(
        'alerts',
        {'acknowledged': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw AppDatabaseException('Failed to acknowledge alert: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Sync Queue Operations
  // ---------------------------------------------------------------------------
  Future<void> enqueueSyncItem(SyncQueueItem item) async {
    try {
      final db = await database;
      await db.insert(
        'sync_queue',
        item.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw AppDatabaseException('Failed to enqueue sync item: $e');
    }
  }

  Future<List<SyncQueueItem>> getPendingSyncItems({int limit = 50}) async {
    try {
      final db = await database;
      final result = await db.query(
        'sync_queue',
        where: 'status = ? OR status = ?',
        whereArgs: ['PENDING', 'FAILED'],
        orderBy: 'created_at ASC',
        limit: limit,
      );
      return result.map((m) => SyncQueueItem.fromSqlite(m)).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to fetch pending sync items: $e');
    }
  }

  Future<void> removeSyncItem(String id) async {
    try {
      final db = await database;
      await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw AppDatabaseException('Failed to remove sync item: $e');
    }
  }

  Future<void> incrementSyncRetry(String id) async {
    try {
      final db = await database;
      await db.rawUpdate('''
        UPDATE sync_queue 
        SET retry_count = retry_count + 1, status = 'FAILED'
        WHERE id = ?
      ''', [id]);
    } catch (e) {
      throw AppDatabaseException('Failed to increment sync retry: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Predictions Log
  // ---------------------------------------------------------------------------
  Future<void> insertPrediction(String telemetryId, PredictionResult pred) async {
    try {
      final db = await database;
      await db.insert(
        'predictions',
        {
          'id': '${telemetryId}_pred',
          'telemetry_id': telemetryId,
          'status': pred.status.toDisplayString(),
          'confidence': pred.confidence,
          'reason': pred.reason,
          'timestamp': pred.timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Devices Cache
  // ---------------------------------------------------------------------------
  Future<void> saveDevice(DeviceModel device, String workerId) async {
    try {
      final db = await database;
      await db.insert(
        'devices',
        device.toSqliteMap(workerId),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw AppDatabaseException('Failed to save device: $e');
    }
  }

  Future<List<DeviceModel>> getSavedDevices() async {
    try {
      final db = await database;
      final result = await db.query('devices', orderBy: 'last_connected DESC');
      return result.map((m) => DeviceModel.fromSqlite(m)).toList();
    } catch (e) {
      throw AppDatabaseException('Failed to fetch saved devices: $e');
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

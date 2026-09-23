import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'captured_notification.dart';

class NotificationDatabase {
  NotificationDatabase._();

  static final NotificationDatabase instance = NotificationDatabase._();

  static const _databaseName = 'sensa.db';
  static const _databaseVersion = 1;
  static const _tableName = 'notifications';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final pathToDatabase = join(databasesPath, _databaseName);

    return openDatabase(
      pathToDatabase,
      version: _databaseVersion,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            package_name TEXT NOT NULL,
            app_name TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> insertNotification(
    CapturedNotification notification,
  ) async {
    final database = await this.database;

    await database.insert(
      _tableName,
      {
        'id': notification.id,
        'package_name': notification.packageName,
        'app_name': notification.appName,
        'title': notification.title,
        'content': notification.content,
        'timestamp': notification.timestamp.toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<CapturedNotification>> getNotifications() async {
    final database = await this.database;

    final rows = await database.query(
      _tableName,
      orderBy: 'timestamp DESC',
    );

    return rows.map(CapturedNotification.fromDatabaseMap).toList();
  }

  Future<void> close() async {
    final database = _database;

    if (database != null) {
      await database.close();
      _database = null;
    }
  }
}
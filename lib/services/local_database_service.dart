import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'agropickup.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pickup_requests (
            id TEXT PRIMARY KEY,
            farmerId TEXT NOT NULL,
            farmerName TEXT NOT NULL,
            farmerPhone TEXT,
            collectionPointId TEXT NOT NULL,
            collectionPointName TEXT NOT NULL,
            adminContactPhone TEXT,
            assignedDriverId TEXT,
            produceType TEXT NOT NULL,
            quantity REAL NOT NULL,
            status TEXT NOT NULL,
            requestedDate TEXT NOT NULL,
            scheduledDate TEXT,
            photoUrl TEXT,
            notes TEXT,
            adminNotes TEXT,
            isSynced INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE collection_points (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            address TEXT NOT NULL,
            region TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            facilities TEXT,
            contactPhone TEXT,
            operatingHours TEXT,
            isActive INTEGER NOT NULL DEFAULT 1,
            createdAt TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE pickup_requests ADD COLUMN farmerPhone TEXT');
          await db.execute(
              'ALTER TABLE pickup_requests ADD COLUMN adminContactPhone TEXT');
        }
      },
    );
  }

  Future<void> insertOrUpdateRequest(PickupRequest request) async {
    final db = await database;
    await db.insert(
      'pickup_requests',
      request.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PickupRequest>> getUnsyncedRequests() async {
    final db = await database;
    final maps = await db.query(
      'pickup_requests',
      where: 'isSynced = ?',
      whereArgs: [0],
    );
    return maps.map((m) => PickupRequest.fromMap(m)).toList();
  }

  Future<List<PickupRequest>> getAllLocalRequests(String farmerId) async {
    final db = await database;
    final maps = await db.query(
      'pickup_requests',
      where: 'farmerId = ?',
      whereArgs: [farmerId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => PickupRequest.fromMap(m)).toList();
  }

  Future<void> markAsSynced(String requestId) async {
    final db = await database;
    await db.update(
      'pickup_requests',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [requestId],
    );
  }

  Future<void> cacheCollectionPoint(CollectionPoint point) async {
    final db = await database;
    await db.insert(
      'collection_points',
      {
        'id': point.id,
        'name': point.name,
        'address': point.address,
        'region': point.region,
        'latitude': point.latitude,
        'longitude': point.longitude,
        'facilities': point.facilities,
        'contactPhone': point.contactPhone,
        'operatingHours': point.operatingHours,
        'isActive': point.isActive ? 1 : 0,
        'createdAt': point.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CollectionPoint>> getCachedCollectionPoints() async {
    final db = await database;
    final maps = await db
        .query('collection_points', where: 'isActive = ?', whereArgs: [1]);
    return maps
        .map((m) => CollectionPoint(
              id: m['id'] as String,
              name: m['name'] as String,
              address: m['address'] as String,
              region: m['region'] as String,
              latitude: m['latitude'] as double,
              longitude: m['longitude'] as double,
              facilities: m['facilities'] as String?,
              contactPhone: m['contactPhone'] as String?,
              operatingHours: m['operatingHours'] as String?,
              isActive: (m['isActive'] as int) == 1,
              createdAt: DateTime.parse(m['createdAt'] as String),
            ))
        .toList();
  }
}

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class PhotoLocation {
  final int? id;
  final String imagePath; // filePath
  final double latitude;
  final double longitude;
  final String timestamp;
  final String mediaType;

  PhotoLocation({
    this.id,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.mediaType,
  });

  factory PhotoLocation.fromMap(Map<String, dynamic> map) {
    return PhotoLocation(
      id: map[DatabaseHelper.columnId],
      imagePath: map[DatabaseHelper.columnPath],
      latitude: map[DatabaseHelper.columnLat],
      longitude: map[DatabaseHelper.columnLon],
      timestamp: map[DatabaseHelper.columnTimestamp],
      mediaType: map[DatabaseHelper.columnMediaType],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DatabaseHelper.columnId: id,
      DatabaseHelper.columnPath: imagePath,
      DatabaseHelper.columnLat: latitude,
      DatabaseHelper.columnLon: longitude,
      DatabaseHelper.columnTimestamp: timestamp,
      DatabaseHelper.columnMediaType: mediaType,
    };
  }
}

class DatabaseHelper {
  static const _databaseName = "PhotoGallery.db";
  static const _databaseVersion = 1;

  static const table = 'photo_locations';

  static const columnId = 'id';
  static const columnPath = 'imagePath';
  static const columnLat = 'latitude';
  static const columnLon = 'longitude';
  static const columnTimestamp = 'timestamp';
  static const columnMediaType = 'mediaType';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // inisialisasi database
  _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $table (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnPath TEXT NOT NULL,
            $columnLat REAL NOT NULL,
            $columnLon REAL NOT NULL,
            $columnTimestamp TEXT NOT NULL, 
            $columnMediaType TEXT NOT NULL
          )
          ''');
  }

  Future<int> insert(PhotoLocation photo) async {
    Database db = await instance.database;
    return await db.insert(table, photo.toMap());
  }

  Future<List<PhotoLocation>> queryAllPhotos() async {
    Database db = await instance.database;
    final maps = await db.query(table, orderBy: "$columnId DESC");

    return List.generate(maps.length, (i) {
      return PhotoLocation.fromMap(maps[i]);
    });
  }

  Future<int> delete(int id) async {
    Database db = await instance.database;
    return await db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }
}
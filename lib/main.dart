import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'camera_screen.dart';
import 'database_helper.dart';
import 'media_viewer_screen.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'places_map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Galeri Foto GPS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<PhotoLocation> _photos = [];
  PhotoLocation? _lastCapturedMedia;
  String? _lastCapturedThumbnailPath;
  final dbHelper = DatabaseHelper.instance;

  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  // fungsi untuk memuat foto dari database
  void _loadPhotos() async {
    // ambil semua foto dari DB
    final allPhotos = await dbHelper.queryAllPhotos(); // sudah urut dari terbaru

    PhotoLocation? newestMedia = allPhotos.isNotEmpty ? allPhotos.first : null;

    // menentukan path thumbnail untuk UI kamera
    String? thumbnailPathForCameraUI;
    if (newestMedia != null) {
      if (newestMedia.mediaType == 'image') {
        thumbnailPathForCameraUI = newestMedia.imagePath;
      } else { // jika video, buat thumbnail-nya
        thumbnailPathForCameraUI = await _generateVideoThumbnail(newestMedia.imagePath);
      }
    }

    if (mounted) {
      setState(() {
        _photos = allPhotos;
        _lastCapturedMedia = newestMedia; // simpan objek
        _lastCapturedThumbnailPath = thumbnailPathForCameraUI;
      });
    }
  }

  // fungsi untuk membuka kamera
  void _openCamera() async {
    final dynamic result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          lastCapturedMedia: _lastCapturedMedia,
          lastCapturedThumbnailPath: _lastCapturedThumbnailPath,
        ),
      ),
    );

    if (result != null && result is Map) {
      Position location;
      if (result['location'] is Position) {
        location = result['location'];
      } else {
        location = Position(latitude: 0.0, longitude: 0.0, timestamp: DateTime.now(), accuracy: 0, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0);
      }

      String path = result['path'];
      String timestamp = result['timestamp'];
      String mediaType = result['mediaType'];

      final newPhoto = PhotoLocation(
        imagePath: path,
        latitude: location.latitude,
        longitude: location.longitude,
        timestamp: timestamp,
        mediaType: mediaType,
      );

      // simpan ke Database
      await dbHelper.insert(newPhoto);

      // muat ulang daftar foto dari DB
      _loadPhotos();
    }
  }

  // helper untuk membuat thumbnail video (di main.dart, agar GridView bisa pakai)
  Future<String?> _generateVideoThumbnail(String videoPath) async {
    if (!await File(videoPath).exists()) {
      if (kDebugMode) print("File video tidak ditemukan: $videoPath");
      return null;
    }

    // bungkus dengan try-catch untuk menangani error
    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 128,
        quality: 75,
      );
      return thumbnailPath;
    } catch (e) {
      if (kDebugMode) print("Gagal membuat thumbnail video: $e");
      return null; // kembalikan null jika gagal
    }
  }

  void _openMediaViewer(PhotoLocation photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaViewerScreen(location: photo),
      ),
    );
  }

  // untuk memilih atau batal memilih item
  void _toggleSelection(int photoId) {
    setState(() {
      if (_selectedIds.contains(photoId)) {
        _selectedIds.remove(photoId); // batal pilih
      } else {
        _selectedIds.add(photoId); // pilih
      }

      _isSelectionMode = _selectedIds.isNotEmpty;
    });
  }

  // untuk keluar dari mode pilih (ditekan 'X')
  void _exitSelectionMode() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  // untuk menghapus item yang dipilih
  Future<void> _deleteSelectedItems() async {
    // 1. Tampilkan dialog konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Hapus Media?"),
          content: Text("Anda yakin ingin menghapus ${_selectedIds.length} item? Tindakan ini tidak bisa dibatalkan."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Hapus", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    // jika pengguna tidak menekan "Hapus", batalkan
    if (confirm != true) return;

    // loop semua ID yang dipilih dan hapus
    final List<int> idsToDelete = List.from(_selectedIds);
    for (int id in idsToDelete) {
      try {
        // cari path file dari list _photos
        final photo = _photos.firstWhere((p) => p.id == id);

        // hapus file fisik dari penyimpanan HP
        final file = File(photo.imagePath);
        if (await file.exists()) {
          await file.delete();
        }

        // hapus data dari database
        await dbHelper.delete(id);
      } catch (e) {
        if (kDebugMode) {
          print("Gagal menghapus item $id: $e");
        }
      }
    }

    // 4. perbarui UI
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    // muat ulang galeri dari database
    _loadPhotos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectionMode,
        )
            : null,
        title: Text(
          _isSelectionMode ? "${_selectedIds.length} dipilih" : "Galeri Foto GPS",
        ),
        actions: _isSelectionMode
            ? [ // aksi saat Mode Pilih
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _deleteSelectedItems,
          )
        ]
            : [ // aksi saat Mode Normal
          IconButton(
            icon: const Icon(Icons.map_rounded),
            onPressed: () {
              // panggil halaman Peta Cluster
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlacesMapScreen()),
              );
            },
          )
        ],
      ),


      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[

          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Galeri Foto Anda:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: _photos.isEmpty
                ? const Center(child: Text("Belum ada foto yang disimpan."))
                : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 4.0,
                mainAxisSpacing: 4.0,
              ),
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                final photo = _photos[index];
                final dateTime = DateTime.parse(photo.timestamp);
                final formattedDate = DateFormat('dd MMM yyy...').format(dateTime);

                // cek apakah item ini sedang dipilih
                final isSelected = _selectedIds.contains(photo.id!);

                return GestureDetector(
                  onLongPress: () {
                  _toggleSelection(photo.id!);
                  },
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelection(photo.id!);
                    } else {
                      _openMediaViewer(photo);
                    }
                  },
                  child: Card(
                    elevation: 4.0,
                    clipBehavior: Clip.antiAlias,
                    child: GridTile(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (photo.mediaType == 'image')
                            Image.file(
                              File(photo.imagePath),
                              fit: BoxFit.cover,
                            ),
                          if (photo.mediaType == 'video')
                            FutureBuilder<String?>(
                              future: _generateVideoThumbnail(photo.imagePath),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                  return Image.file(
                                    File(snapshot.data!),
                                    fit: BoxFit.cover,
                                  );
                                }
                                // Tampilan placeholder jika gagal atau loading
                                return Container(
                                  color: Colors.black,
                                  child: const Icon(
                                    Icons.videocam_off_rounded,
                                    color: Colors.white54,
                                    size: 50,
                                  ),
                                );
                              },
                            ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.black, Colors.transparent],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    photo.mediaType == 'video'
                                        ? Icons.videocam_rounded
                                        : Icons.image_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      formattedDate,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        shadows: [Shadow(blurRadius: 2.0)],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (isSelected)
                            Opacity(
                              opacity: 0.4,
                              child: Container(
                                color: Colors.blueAccent,
                                child: const Center(
                                  child: Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // tombol FAB utk mengambil foto
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCamera,
        label: const Text("Ambil Media"),
        icon: const Icon(Icons.camera_alt),
        backgroundColor: Colors.green,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
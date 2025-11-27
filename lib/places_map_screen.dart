import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'database_helper.dart';
import 'media_viewer_screen.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class PlacesMapScreen extends StatefulWidget {
  const PlacesMapScreen({super.key});

  @override
  State<PlacesMapScreen> createState() => _PlacesMapScreenState();
}

class _PlacesMapScreenState extends State<PlacesMapScreen> {
  // variabel untuk menyimpan semua foto dari database
  List<PhotoLocation> _allPhotos = [];
  bool _isLoading = true;

  final Map<LatLng, PhotoLocation> _pointToPhotoMap = {};

  @override
  void initState() {
    super.initState();
    _loadAllPhotos(); // memanggil fungsi untuk memuat data saat halaman dibuka
  }

  // fungsi untuk mengambil SEMUA data dari database
  Future<void> _loadAllPhotos() async {
    final dbHelper = DatabaseHelper.instance;
    final photos = await dbHelper.queryAllPhotos();

    if (mounted) {
      setState(() {
        _allPhotos = photos
            .where((p) => p.latitude != 0.0 || p.longitude != 0.0)
            .toList();

        // kosongkan map sebelum mengisi ulang
        _pointToPhotoMap.clear();
        // isi map: setiap marker dipetakan ke objek PhotoLocation-nya
        for (final photo in _allPhotos) {
          _pointToPhotoMap[LatLng(photo.latitude, photo.longitude)] = photo;
        }

        _isLoading = false;
      });
    }
  }

  // untuk membuat thumbnail video (sama seperti di main.dart)
  Future<String?> _generateVideoThumbnail(String videoPath) async {
    if (!await File(videoPath).exists()) {
      if (kDebugMode) print("File video tidak ditemukan (map): $videoPath");
      return null;
    }
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
      if (kDebugMode) print("Gagal membuat thumbnail video (map): $e");
      return null;
    }
  }

  // fungsi untuk mengubah data List<PhotoLocation> menjadi List<Marker>
  List<Marker> _buildMarkers() {
    return _allPhotos.map((photo) {
      return Marker(
        width: 60.0,
        height: 60.0,
        point: LatLng(photo.latitude, photo.longitude),

        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaViewerScreen(location: photo),
              ),
            );
          },

          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(77),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias, // agar gambar terpotong lingkaran
            child: photo.mediaType == 'image'
                ? Image.file(
              File(photo.imagePath),
              fit: BoxFit.cover,
              width: 60,
              height: 60,
            )
                : // jika video, pakai FutureBuilder untuk thumbnail
            FutureBuilder<String?>(
              future: _generateVideoThumbnail(photo.imagePath),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                  return Stack(
                    children: [
                      Image.file(
                        File(snapshot.data!),
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                      ),
                      // ikon video di tengah thumbnail
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white70,
                          size: 30,
                        ),
                      ),
                    ],
                  );
                } else {
                  // placeholder klo thumbnail gagal atau loading
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(
                        Icons.videocam_off_rounded,
                        color: Colors.white54,
                        size: 30,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Peta Lokasi (Places)"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
        options: MapOptions(
          initialCenter: _allPhotos.isNotEmpty
              ? LatLng(_allPhotos.first.latitude, _allPhotos.first.longitude)
              : const LatLng(-6.9175, 107.6191), // fallback ke Bandung jika kosong
          initialZoom: 8.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.namamu.gpskameraapp',
          ),

          MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              // maxClusterRadius: 80,
              size: const Size(70, 70),
              markers: _buildMarkers(),

              builder: (context, markers) {
                // mendapatkan semua objek PhotoLocation dari marker di cluster ini
                List<PhotoLocation> clusterPhotos = markers
                    .map((m) => _pointToPhotoMap[m.point])
                    .whereType<PhotoLocation>() // Filter yang bukan null
                    .toList();

                // mengurutkan berdasarkan timestamp untuk mendapatkan yang terbaru
                clusterPhotos.sort((a, b) => DateTime.parse(b.timestamp).compareTo(DateTime.parse(a.timestamp)));

                // ambil photo yang paling baru
                final latestPhoto = clusterPhotos.isNotEmpty ? clusterPhotos.first : null;

                // klo ada photo terbaru, buat thumbnail-nya
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30), // ukuran cluster lebih besar
                    color: Colors.blueAccent, // warna default jika tidak ada gambar
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(77), // .withOpacity(0.3)
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: latestPhoto != null
                      ? Stack(
                    children: [
                      // nampilkan thumbnail media terbaru
                      latestPhoto.mediaType == 'image'
                          ? Image.file(
                        File(latestPhoto.imagePath),
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                      )
                          : FutureBuilder<String?>(
                        future: _generateVideoThumbnail(latestPhoto.imagePath),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                            return Stack(
                              children: [
                                Image.file(
                                  File(snapshot.data!),
                                  fit: BoxFit.cover,
                                  width: 60,
                                  height: 60,
                                ),
                                const Center(
                                  child: Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: Colors.white70,
                                    size: 30,
                                  ),
                                ),
                              ],
                            );
                          }
                          return Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(
                                Icons.videocam_off_rounded,
                                color: Colors.white54,
                                size: 30,
                              ),
                            ),
                          );
                        },
                      ),

                      // nampilkan jumlah marker di sudut
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(150),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomRight: Radius.circular(30),
                            ),
                          ),
                          child: Text(
                            markers.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                      : Center( // fallback jika tidak ada photo terbaru
                    child: Text(
                      markers.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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
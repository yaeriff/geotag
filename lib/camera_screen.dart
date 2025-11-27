import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'database_helper.dart';
import 'media_viewer_screen.dart';

class CaptureResult {
  final String path;
  final Position location;
  final DateTime timestamp;
  final String mediaType; // "image" or "video"

  CaptureResult({
    required this.path,
    required this.location,
    required this.timestamp,
    required this.mediaType,
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'location': location,
      'timestamp': timestamp.toIso8601String(), // ubah DateTime ke string
      'mediaType': mediaType,
    };
  }
}

class CameraScreen extends StatefulWidget {
  final PhotoLocation? lastCapturedMedia;
  final String? lastCapturedThumbnailPath;

  const CameraScreen({
    super.key,
    this.lastCapturedMedia,
    this.lastCapturedThumbnailPath,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  int _cameraIndex = 0; // 0 = kamera belakang, 1 = kamera depan
  bool _isRecording = false;

  // dari Ery
  String _currentMode = "image";
  // String? _lastCapturedPath;
  // String? _lastCapturedMediaType;

  @override
  void initState() {
    super.initState();

    // _lastCapturedPath = widget.initialLastCapturedPath;
    // _lastCapturedMediaType = widget.initialLastCapturedMediaType;
    // panggil _initializeCamera
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      if (kDebugMode) {
        print("Tidak ada kamera ditemukan");
      }
      return;
    }

    _controller = CameraController(
      _cameras![_cameraIndex], // milih kamera berdasarkan index
      ResolutionPreset.medium,

    //   dari Ery
      enableAudio: true,
    );

    await _controller!.initialize();
    await _controller!.prepareForVideoRecording();

    if (!mounted) return;
    setState(() {
      _isCameraInitialized = true;
    });
  }

  // fungsi utk pindah Kamera
  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      if (kDebugMode) {
        print("Tidak ada cukup kamera untuk dipindah");
      }
      return;
    }

    setState(() {
      _isCameraInitialized = false;
    });
    await _controller?.dispose();
    _cameraIndex = (_cameraIndex + 1) % _cameras!.length;

    // inisialisasi kamera baru
    await _initializeCamera();
  }

  Future<void> _captureAndPop(String mediaType, XFile file) async {
    if (!mounted) return;
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print("Layanan lokasi mati.");
        }
        return _popWithData(mediaType, file, null); // null untuk lokasi
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            print("Izin lokasi ditolak.");
          }
          return _popWithData(mediaType, file, null);
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print("Izin lokasi ditolak permanen.");
        }
        return _popWithData(mediaType, file, null);
      }

      final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      await _popWithData(mediaType, file, position);

    } catch (e) {
      if (kDebugMode) {
        print("Gagal mengambil lokasi/waktu: $e");
      }
      await _popWithData(mediaType, file, null);
    }
  }

  // buat helper baru biar tidak duplikat kode
  Future<void> _popWithData(String mediaType, XFile file, Position? position) async {
    final DateTime now = DateTime.now();

    // buat 'paket' data
    final result = CaptureResult(
      path: file.path,
      location: position ?? Position(latitude: 0.0, longitude: 0.0, timestamp: now, accuracy: 0, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0),
      timestamp: now,
      mediaType: mediaType,
    );

    if (mounted) Navigator.pop(context, result.toMap());
  }

  // fungsi ambil foto
  Future<void> _takePicture() async {
    if (!_controller!.value.isInitialized || _isRecording) return;
    try {
      final XFile file = await _controller!.takePicture();
      // panggil helper
      await _captureAndPop("image", file);
    } catch (e) {
      if (kDebugMode) {
        print("Error mengambil foto: $e");
      }
    }
  }

  // fungsi utk rekam video
  Future<void> _toggleVideoRecording() async {
    if (!_controller!.value.isInitialized) return;

    if (_isRecording) {
      // stop record
      try {
        final XFile file = await _controller!.stopVideoRecording();
        setState(() { _isRecording = false; });
        await _captureAndPop("video", file);
      } catch (e) {
        if (kDebugMode) {
          print("Error menghentikan video: $e");
        }

        setState(() { _isRecording = false; });

        if (mounted) Navigator.pop(context, null);
      }
    } else {
      // mulai record
      try {
        await _controller!.startVideoRecording();
        setState(() { _isRecording = true; });
      } catch (e) {
        if (kDebugMode) {
          print("Error memulai video: $e");
        }
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // UI dari Ery
  Widget _buildTopAppBar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildModeButton("image", "Foto"),
          const SizedBox(width: 20),
          _buildModeButton("video", "Video"),
        ],
      ),
    );
  }

  // dari Ery
  Widget _buildModeButton(String mode, String label) {
    final bool isActive = _currentMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _currentMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.blueAccent.withAlpha(77)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            color: isActive ? Colors.white : Colors.white54,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // dari Ery
  Widget _buildBottomAppBar() {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      color: Colors.black.withAlpha(102),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // thumbnail kiri
          GestureDetector(
            onTap: () {
              if (widget.lastCapturedMedia != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MediaViewerScreen(
                      location: widget.lastCapturedMedia!, // kirim objek lengkap
                    ),
                  ),
                );
              }
            },

            child: Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),

                // menggunakan data dari 'widget.lastCapturedMedia'
                image: (widget.lastCapturedThumbnailPath != null)
                    ? DecorationImage(
                  image: FileImage(File(widget.lastCapturedThumbnailPath!)),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: (widget.lastCapturedThumbnailPath == null)
                  ? const Icon(Icons.photo, color: Colors.white54)
                  : null,// kosong jika itu gambar (karena image: sudah diisi)
            ),
          ),

          // tombol utama
          GestureDetector(
            onTap: () {
              if (_currentMode == "image") {
                _takePicture();
              } else {
                _toggleVideoRecording();
              }
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 6),
                color: _isRecording
                    ? Colors.redAccent
                    : Colors.white.withAlpha(230),
              ),
            ),
          ),

          // switch kamera
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_outlined,
                color: Colors.white, size: 36),
            onPressed: _switchCamera,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTopAppBar(),

          // camera preview
          Expanded(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),

          _buildBottomAppBar(),
        ],
      ),
    );
  }
}

class _SimpleVideoPreview extends StatefulWidget {
  final String videoPath;
  const _SimpleVideoPreview({required this.videoPath});

  @override
  State<_SimpleVideoPreview> createState() => _SimpleVideoPreviewState();
}

class _SimpleVideoPreviewState extends State<_SimpleVideoPreview> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
        _controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Pratinjau Video"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            if (_controller.value.isPlaying) {
              _controller.pause();
            } else {
              _controller.play();
            }
          });
        },
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}
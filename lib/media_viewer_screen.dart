import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';
import 'map_screen.dart';
import 'gemini_service.dart';

class MediaViewerScreen extends StatefulWidget {
  final PhotoLocation location;

  const MediaViewerScreen({super.key, required this.location});

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  // --- VARIABEL AI ---
  bool _showAiCard = false; // Apakah kartu AI muncul?
  bool _isAiLoading = false;
  String _aiResult = ""; // jawaban AI
  String _lastQuestion = "";
  final TextEditingController _questionController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  // ------------------

  @override
  void initState() {
    super.initState();
    if (widget.location.mediaType == 'video') {
      _videoController = VideoPlayerController.file(File(widget.location.imagePath));
      _videoController!.initialize().then((_) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          aspectRatio: _videoController!.value.aspectRatio,
          autoPlay: true,
          looping: true,
          errorBuilder: (context, errorMessage) {
            return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.white)));
          },
        );
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _questionController.dispose();
    super.dispose();
  }

  // --- FUNGSI AI ---
  void _askGemini(String prompt) async {
    // Tutup keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isAiLoading = true;
      _aiResult = "";
      _lastQuestion = prompt;
    });

    String? result = await _geminiService.analyzeImage(
      widget.location.imagePath,
      customPrompt: prompt,
    );

    if (mounted) {
      setState(() {
        _isAiLoading = false;
        _aiResult = result ?? "Tidak ada respon.";
      });
    }
  }

  // helper functions (sama seperti sebelumnya)
  String _getFileName() => p.basename(widget.location.imagePath);
  String _getFilePath() => widget.location.imagePath;
  String _getFormattedDate() => DateFormat('dd MMMM yyyy, HH:mm:ss').format(DateTime.parse(widget.location.timestamp));
  String _getFileSize() => "${(File(widget.location.imagePath).lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB";

  void _openMap() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => MapScreen(location: widget.location)));
  }

  // --- UI UTAMA ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_getFileName(), style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // TOMBOL AI DI POJOK KANAN ATAS (Pemicu)
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.blueAccent),
            onPressed: () {
              setState(() {
                _showAiCard = true; // Munculkan kartu
              });
            },
          )
        ],
      ),
      // KITA GANTI BODY JADI STACK
      body: Stack(
        children: [
          // LAYER 1: KONTEN UTAMA (Foto/Video + Rincian)
          SingleChildScrollView(
            child: Column(
              children: [
                _buildMediaViewer(),
                _buildDetailsPanel(),
                const SizedBox(height: 100), // Ruang kosong di bawah
              ],
            ),
          ),

          // LAYER 2: KARTU AI (Overlay)
          if (_showAiCard)
            GestureDetector(
              onTap: () {
                // Klik di luar kartu untuk menutup
                setState(() => _showAiCard = false);
              },
              child: Container(
                color: Colors.black54, // Background redup
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () {}, // Klik di kartu jangan menutup
                  child: _buildAiCardUI(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- WIDGET KARTU AI (DESAIN TEMAN ANDA) ---
  Widget _buildAiCardUI() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Logo & Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Ikon Gemini (Bintang warna-warni)
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.blue, Colors.purple, Colors.red],
                    ).createShader(bounds),
                    child: const Icon(Icons.auto_awesome, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Text("Gemini", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _showAiCard = false),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Greeting Text
          const Text(
            "Hello,\nHow Can I Help You Today?",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),

          const SizedBox(height: 20),

          // AREA CHAT
          if (_lastQuestion.isNotEmpty || _aiResult.isNotEmpty)
            Container(
              height: 200, // perbesar sedikit areanya
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.grey[50], // background chat area lebih terang
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // gelembung Chat USER (Kanan)
                    if (_lastQuestion.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10, left: 40), // margin kiri besar biar menjorok ke kanan
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.blueAccent, // warna User
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(15),
                              topRight: Radius.circular(15),
                              bottomLeft: Radius.circular(15),
                              bottomRight: Radius.circular(0), // sudut tajam di kanan bawah
                            ),
                          ),
                          child: Text(
                            _lastQuestion,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),

                    // gelembung Chat AI (Kiri)
                    if (_aiResult.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ikon Gemini
                            Container(
                              margin: const EdgeInsets.only(top: 5, right: 8),
                              child: const Icon(Icons.auto_awesome, size: 20, color: Colors.purple),
                            ),
                            // teks jawaban
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(0), // sudut tajam di kiri atas
                                    topRight: Radius.circular(15),
                                    bottomLeft: Radius.circular(15),
                                    bottomRight: Radius.circular(15),
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)
                                  ],
                                ),
                                child: Text(
                                  _aiResult,
                                  style: const TextStyle(color: Colors.black87, height: 1.4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

          // loading Indicator
          if (_isAiLoading)
            const Padding(
              padding: EdgeInsets.all(10.0),
              child: LinearProgressIndicator(),
            ),

          // tombol preset (Chips)
          if (!_isAiLoading && _aiResult.isEmpty)
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text("Deskripsikan foto tersebut"),
                  onPressed: () => _askGemini("Deskripsikan foto ini secara detail."),
                  backgroundColor: Colors.white,
                  elevation: 2,
                ),
                ActionChip(
                  label: const Text("Identifikasi objek"),
                  onPressed: () => _askGemini("Sebutkan nama objek-objek yang ada di foto ini."),
                  backgroundColor: Colors.white,
                  elevation: 2,
                ),
              ],
            ),

          const SizedBox(height: 20),

          // input field "Ask Anything"
          TextField(
            controller: _questionController,
            decoration: InputDecoration(
              hintText: "Ask Anything...",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded),
                onPressed: () {
                  if (_questionController.text.isNotEmpty) {
                    _askGemini(_questionController.text);
                    _questionController.clear();
                  }
                },
              ),
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _askGemini(value);
                _questionController.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMediaViewer() {
    if (widget.location.mediaType == 'image') {
      return Container(
        margin: const EdgeInsets.all(10),
        height: 400, // batasi tinggi agar tidak terlalu besar
        child: Image.file(File(widget.location.imagePath), fit: BoxFit.contain),
      );
    }
    if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized) {
      return Container(
        margin: const EdgeInsets.all(10),
        height: 400,
        child: AspectRatio(
          aspectRatio: _chewieController!.aspectRatio ?? 16 / 9,
          child: Chewie(controller: _chewieController!),
        ),
      );
    }
    return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
  }

  Widget _buildDetailsPanel() {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.all(10),
      child: Column(
        children: [
          const ListTile(title: Text("Rincian", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
          const Divider(color: Colors.grey),
          _DetailRow(icon: Icons.calendar_today_rounded, title: "Tanggal", value: _getFormattedDate()),
          _DetailRow(icon: Icons.image_rounded, title: "Nama File", value: _getFileName()),
          _DetailRow(icon: Icons.sd_card_rounded, title: "Path", value: _getFilePath()),
          _DetailRow(icon: Icons.data_usage_rounded, title: "Ukuran", value: _getFileSize()),
          ListTile(
            leading: const Icon(Icons.map_rounded, color: Colors.blueAccent),
            title: const Text("Lokasi", style: TextStyle(color: Colors.white)),
            subtitle: Text("Lat: ${widget.location.latitude.toStringAsFixed(4)}, Lon: ${widget.location.longitude.toStringAsFixed(4)}", style: const TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            onTap: _openMap,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _DetailRow({required this.icon, required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[400]),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(value, style: TextStyle(color: Colors.grey[300]), overflow: TextOverflow.ellipsis),
    );
  }
}
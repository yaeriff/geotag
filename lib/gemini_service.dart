import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'api_key.dart';

class GeminiService {
  Future<String?> analyzeImage(String imagePath, {String? customPrompt}) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );

      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        return "Error: File gambar tidak ditemukan.";
      }
      final imageBytes = await imageFile.readAsBytes();

      final promptText = customPrompt ?? "Deskripsikan secara detail apa yang ada di dalam gambar ini. Gunakan Bahasa Indonesia.";

      final prompt = TextPart(promptText);
      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      return response.text;

    } catch (e) {
      print("Error Gemini: $e");
      return "Maaf, gagal menganalisis. Pastikan koneksi internet lancar.";
    }
  }
}
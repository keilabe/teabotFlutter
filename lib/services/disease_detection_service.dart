import 'dart:io';
import 'package:tflite/tflite.dart';
import 'package:flutter/foundation.dart';

class DiseaseDetectionService {
  static Future<Map<String, dynamic>> detectDisease({
    File? imageFile,
    String? imageUrl,
  }) async {
    debugPrint('\n=== Starting Disease Detection Service ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('Input: ${imageFile?.path ?? imageUrl ?? 'No input provided'}');

    try {
      // Load model if not already loaded
      debugPrint('Loading TFLite model...');
      await Tflite.loadModel(
        model: "assets/model.tflite",
        labels: "assets/labels.txt",
      );
      debugPrint('Model loaded successfully');

      // Process the image
      debugPrint('Running inference on image...');
      final recognitions = await Tflite.runModelOnImage(
        path: imageFile?.path ?? imageUrl ?? '',
        numResults: 1,
        threshold: 0.4,
      );

      if (recognitions == null || recognitions.isEmpty) {
        debugPrint('No disease detected in the image');
        throw Exception('No disease detected in the image');
      }

      debugPrint('Inference results:');
      debugPrint('- Label: ${recognitions[0]['label']}');
      debugPrint('- Confidence: ${(recognitions[0]['confidence'] * 100).toStringAsFixed(1)}%');

      final result = {
        'disease': recognitions[0]['label'],
        'confidence': recognitions[0]['confidence'],
      };

      debugPrint('=== Disease Detection Service Completed ===\n');
      return result;
    } catch (e) {
      debugPrint('Error in disease detection service: $e');
      debugPrint('=== Disease Detection Service Failed ===\n');
      throw Exception('Error detecting disease: $e');
    }
  }

  static Future<void> dispose() async {
    debugPrint('\n=== Disposing Disease Detection Service ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    await Tflite.close();
    debugPrint('Model disposed successfully');
    debugPrint('=== Disease Detection Service Disposed ===\n');
  }
} 
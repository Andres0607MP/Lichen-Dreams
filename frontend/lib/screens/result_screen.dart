import 'package:flutter/material.dart';

import '../models/analysis_record.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';

class ResultScreen extends StatelessWidget {
  final AnalysisRecord analysis;

  const ResultScreen({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado de análisis')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E9DD)),
              ),
              child: () {
                final base64Data = analysis.imageBase64;
                if (base64Data != null && base64Data.isNotEmpty) {
                  try {
                    final bytes = base64Decode(base64Data);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        Uint8List.fromList(bytes),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 220,
                      ),
                    );
                  } catch (_) {
                    // fall through to network/image icon
                  }
                }
                final imageUrl = analysis.imageUrl;
                if (imageUrl != null && imageUrl.isNotEmpty) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FutureBuilder<Uint8List>(
                      future: ApiService().downloadPrivateImageBytes(imageUrl),
                      builder: (context, snapshot) {
                        final data = snapshot.data;
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError || data == null) {
                          print('[Image error] result_screen: $imageUrl\n${snapshot.error}');
                          return const Center(child: Icon(Icons.broken_image, size: 48));
                        }
                        return Image.memory(
                          data,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 220,
                        );
                      },
                    ),
                  );
                }
                return const Center(child: Icon(Icons.image_outlined, size: 64));
              }(),
            ),
            const SizedBox(height: 18),
            Text(
              analysis.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text(analysis.status),
              backgroundColor: Colors.green.shade50,
            ),
            const SizedBox(height: 16),
            Text(
              analysis.summary.isNotEmpty ? analysis.summary : 'Sin descripción disponible',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 20),
            Text('Fecha: ${analysis.displayDate}'),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Detalles completos', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...analysis.raw.entries
                .where((entry) => entry.key != 'imagen_base64' && entry.key != 'image_base64')
                .map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.key}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Expanded(child: Text(entry.value.toString())),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
            PrimaryButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver al historial'),
            ),
          ],
        ),
      ),
    );
  }
}

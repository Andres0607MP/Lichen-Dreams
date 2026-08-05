import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/analysis_record.dart';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';

class ResultScreen extends StatefulWidget {
  final AnalysisRecord analysis;

  const ResultScreen({super.key, required this.analysis});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final ApiService _apiService = ApiService();
  bool _isSharing = false;

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  Widget _buildImage() {
    final base64Data = widget.analysis.imageBase64;
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

    final imageUrl = widget.analysis.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FutureBuilder<Uint8List>(
          future: _apiService.downloadPrivateImageBytes(imageUrl),
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || data == null) {
              print('[Image error] result_screen: $imageUrl\n${snapshot.error}');
              return const SizedBox(
                height: 220,
                child: Center(child: Icon(Icons.broken_image, size: 48)),
              );
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

    return const SizedBox(
      height: 220,
      child: Center(child: Icon(Icons.image_outlined, size: 64)),
    );
  }

  Future<void> _shareAnalysis() async {
    if (widget.analysis.id == null) return;

    setState(() => _isSharing = true);
    try {
      await _apiService.shareAnalysis(widget.analysis.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Análisis compartido en el mapa correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiException ? error.message : 'Error al compartir análisis'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado de análisis')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),
            const SizedBox(height: 18),
            Text(
              widget.analysis.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text(widget.analysis.status),
              backgroundColor: Colors.green.shade50,
            ),
            const SizedBox(height: 16),
            Text(
              widget.analysis.summary.isNotEmpty ? widget.analysis.summary : 'Sin descripción disponible',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 20),
            Text('Fecha: ${widget.analysis.displayDate}'),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Detalles completos', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...widget.analysis.raw.entries
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
              onPressed: _isSharing ? null : _shareAnalysis,
              loading: _isSharing,
              child: const Text('Compartir en mapa'),
            ),
            const SizedBox(height: 16),
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

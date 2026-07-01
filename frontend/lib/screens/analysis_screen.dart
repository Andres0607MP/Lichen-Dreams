import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../routes/route_names.dart';
import '../models/analysis_record.dart';
import '../screens/result_screen.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  String? _errorMessage;
  File? _selectedImage;

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _errorMessage = null;
      });
      final pickedFile = await _imagePicker.pickImage(source: source, imageQuality: 80);
      if (pickedFile == null) return;
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      await _submitAnalysis();
    } catch (error) {
      setState(() {
        _errorMessage = 'No se pudo seleccionar la imagen. Intenta de nuevo.';
      });
    }
  }

  Future<void> _submitAnalysis() async {
    if (_selectedImage == null) {
      setState(() {
        _errorMessage = 'Selecciona una imagen primero.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resultJson = await _apiService.submitAnalysis(_selectedImage!);
      final analysisJson = await _apiService.getAnalysisResult(
        resultJson['id'] is int
            ? resultJson['id'] as int
            : int.tryParse(resultJson['id']?.toString() ?? '') ?? 0,
      );
      final record = AnalysisRecord.fromJson(analysisJson);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(analysis: record),
        ),
      );
    } catch (error) {
      setState(() {
        _errorMessage = error is ApiException ? error.message : 'Error al procesar el análisis. Intenta de nuevo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  Widget _buildActionButton({required String label, required VoidCallback onPressed, required IconData icon}) {
    return FilledButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: const Color(0xFF295E2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Análisis')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E9DD)),
                image: _selectedImage != null ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover) : null,
              ),
              child: _selectedImage == null
                  ? const Center(child: Icon(Icons.photo_camera_outlined, size: 56, color: Color(0xFF2F7D32)))
                  : null,
            ),
            const SizedBox(height: 18),
            _buildActionButton(
              label: _isLoading ? 'Cargando...' : 'Tomar foto',
              onPressed: () => _pickImage(ImageSource.camera),
              icon: Icons.camera_alt_rounded,
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              label: _isLoading ? 'Cargando...' : 'Elegir fotografía de galería',
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: Icons.photo_library_rounded,
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              Column(
                children: const [
                  SizedBox(height: 12),
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Procesando imagen con el backend...'),
                ],
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            if (!_isLoading)
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.historial),
                child: const Text('Ver historial de análisis'),
              ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:provider/provider.dart';

import '../routes/route_names.dart';
import '../models/analysis_record.dart';
import '../screens/result_screen.dart';
import '../services/api_service.dart';
import '../services/navigation_service.dart';
import '../widgets/app_theme.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/modern_widgets.dart';
import '../state/analysis_state.dart';
import '../state/auth_state.dart';

const _primaryGreen = Color(0xFF4E5B4A);
const _errorRed = Color(0xFFD32F2F);

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  ImageSource _selectedSource = ImageSource.camera;
  bool _isSubmitting = false;
  bool _isNavigatingToResult = false;
  bool _showCompletedProgress = false;
  Timer? _completedProgressTimer;
  int _lastShownCompletedDataVersion = -1;
  String _previousStatus = 'idle';

  @override
  void initState() {
    super.initState();
    LichenNavigation.instance.sync(1);
  }

  @override
  void dispose() {
    _completedProgressTimer?.cancel();
    _completedProgressTimer = null;
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source, imageQuality: 80);
      if (pickedFile == null) return;
      setState(() {
        _selectedImage = File(pickedFile.path);
        _selectedSource = source;
      });
      if (mounted) {
        context.read<AnalysisState>().reset();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo seleccionar la imagen. Intenta de nuevo.')),
      );
    }
  }

  Future<void> _submitAnalysis() async {
    if (_isSubmitting) return;
    _isSubmitting = true;

    final image = _selectedImage;
    if (image == null) {
      _isSubmitting = false;
      return;
    }

    final analysisState = context.read<AnalysisState>();
    analysisState.reset();

    if (analysisState.hasActiveAnalysis) {
      _isSubmitting = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya tienes un análisis en proceso. Espera a que termine.')),
      );
      return;
    }

    int? locationId;
    if (_selectedSource == ImageSource.camera) {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación. Activa el GPS e intenta de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
        _isSubmitting = false;
        return;
      }

      if (position == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación. Activa el GPS e intenta de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
        _isSubmitting = false;
        return;
      }

      try {
        final apiService = Provider.of<ApiService>(context, listen: false);

        String municipio = '';
        String departamento = '';
        String direccion = '';

        try {
          final placemarks = await geocoding.placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            municipio = p.subAdministrativeArea ?? p.locality ?? p.administrativeArea ?? '';
            departamento = p.administrativeArea ?? '';

            final parts = <String>[];
            final thoroughfare = p.thoroughfare?.trim() ?? '';
            if (thoroughfare.isNotEmpty &&
                thoroughfare.toLowerCase() != 'unnamed road') {
              parts.add(thoroughfare);
            }
            final subLocality = p.subLocality?.trim() ?? '';
            if (subLocality.isNotEmpty &&
                subLocality.toLowerCase() != 'unnamed road') {
              parts.add(subLocality);
            }
            if (parts.isEmpty && p.name != null && p.name!.trim().isNotEmpty) {
              final name = p.name!.trim();
              if (name.toLowerCase() != 'unnamed road') {
                parts.add(name);
              }
            }
            direccion = parts.join(', ');
          }
        } catch (_) {
          // reverse geocoding no disponible, continuar con valores vacíos
        }

        final locationResponse = await apiService.findOrCreateLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          radiusMeters: 15.0,
          direccion: direccion,
          municipio: municipio,
          departamento: departamento,
          pais: 'Colombia',
        );

        final rawId = locationResponse['id_ubicacion'];
        if (rawId is int) {
          locationId = rawId;
        } else if (rawId is String && rawId.isNotEmpty) {
          locationId = int.tryParse(rawId);
        } else if (locationResponse['location'] is Map<String, dynamic>) {
          final nested = locationResponse['location'] as Map<String, dynamic>;
          final nestedId = nested['id_ubicacion'];
          if (nestedId is int) {
            locationId = nestedId;
          } else if (nestedId is String && nestedId.isNotEmpty) {
            locationId = int.tryParse(nestedId);
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar la ubicación. Intenta de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
        _isSubmitting = false;
        return;
      }

      if (locationId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación. Activa el GPS e intenta de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
        _isSubmitting = false;
        return;
      }
    }

    try {
      await analysisState.startAnalysis(
        image: image,
        locationId: locationId,
        imageSource: _selectedSource == ImageSource.camera ? 'camera' : 'gallery',
      );
    } finally {
      _isSubmitting = false;
    }
  }

  Future<void> _viewResult() async {
    _completedProgressTimer?.cancel();
    _completedProgressTimer = null;
    _showCompletedProgress = false;

    if (_isNavigatingToResult) return;
    _isNavigatingToResult = true;

    final analysisState = context.read<AnalysisState>();
    final resultJson = analysisState.lastResult;
    if (resultJson == null) {
      await analysisState.refreshStatus();
    }
    final record = AnalysisRecord.fromJson(analysisState.lastResult ?? {});
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(analysis: record),
      ),
    );
  }

  void _showCompletedProgressBriefly(AnalysisState analysisState) {
    if (_showCompletedProgress) return;
    if (_isNavigatingToResult) return;
    if (analysisState.dataVersion == _lastShownCompletedDataVersion) return;

    _lastShownCompletedDataVersion = analysisState.dataVersion;
    _showCompletedProgress = true;

    _completedProgressTimer?.cancel();
    _completedProgressTimer = Timer(const Duration(milliseconds: 400), () {
      _completedProgressTimer = null;
      if (!mounted) return;
      setState(() {
        _showCompletedProgress = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final analysisState = context.watch<AnalysisState>();

    final isProcessing = analysisState.isProcessing;
    final isCompleted = analysisState.status == 'completed';
    final isFailed = analysisState.status == 'failed';
    final isRejected = analysisState.status == 'rejected';

    final justCompleted = _previousStatus == 'processing' && analysisState.status == 'completed';
    _previousStatus = analysisState.status;

    if (justCompleted && !_isNavigatingToResult) {
      _showCompletedProgressBriefly(analysisState);
    }

    return LichenScaffold(
      apiService: Provider.of<ApiService>(context, listen: false),
      showBottomNav: true,
      showParticleBackground: false,
      onBottomNavTap: (index) {
        LichenNavigation.instance.navigateToTab(context, index);
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 28),

          if (isProcessing || _showCompletedProgress) ...[
            _buildProcessingIndicator(),
            const SizedBox(height: 16),
            Text(
              _showCompletedProgress ? 'Análisis completado' : 'Tu análisis está siendo procesado',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _showCompletedProgress ? 'Preparando resultado...' : 'Puedes seguir navegando por la app. Te notificaremos cuando esté listo.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textGray,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
          ] else if (isRejected && _selectedImage != null) ...[
            _buildRejectedPreview(analysisState.error ?? 'La imagen no corresponde a un liquen.'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _viewResult,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: Text(
                  'Ver resultado',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedImage = null;
                  });
                  Future.microtask(() {
                    if (mounted) {
                      context.read<AnalysisState>().reset();
                    }
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textGray,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Tomar otra fotografía',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else if (isCompleted && _selectedImage != null) ...[
            _buildCompletedPreview(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _viewResult,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: Text(
                  'Ver resultado',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedImage = null;
                });
                Future.microtask(() {
                  if (mounted) {
                    context.read<AnalysisState>().reset();
                  }
                });
              },
              child: Text(
                'Analizar otra imagen',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 28),
          ] else if (isFailed) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _errorRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _errorRed.withValues(alpha: 0.2)),
              ),
              child: Text(
                analysisState.error ?? 'Error al procesar el análisis. Intenta de nuevo.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _errorRed,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedImage != null)
              SizedBox(
                width: double.infinity,
                height: 52,
              child: ElevatedButton(
                onPressed: (_isSubmitting || context.watch<AnalysisState>().hasActiveAnalysis) ? null : _submitAnalysis,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    'Reintentar',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 28),
          ] else ...[
            _buildImageSection(),
            const SizedBox(height: 28),
          ],

          if (!isProcessing && !isCompleted && !isFailed && _selectedImage == null)
            _buildHistoryButton(),
          const SizedBox(height: 32),
          _buildHowItWorks(),
          const SizedBox(height: 24),
          _buildLichenInfo(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Consumer<AnalysisState>(
      builder: (context, analysisState, _) {
        final percent = (analysisState.estimatedProgress * 100).round();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _primaryGreen.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primaryGreen.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.primaryGreen,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Analizando imagen...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'La IA está estudiando la muestra',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textGray,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: analysisState.estimatedProgress,
                  minHeight: 6,
                  backgroundColor: const Color(0x1A2F7D32),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Progreso estimado: $percent%',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Esto puede tardar unos segundos...',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textGray.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms);
      },
    );
  }

  Widget _buildRejectedPreview(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _errorRed.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _errorRed.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _errorRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.photo_camera_front_rounded,
              color: _errorRed,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Imagen no válida',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _errorRed,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textGray,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildCompletedPreview() {
    final image = _selectedImage;
    if (image != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          image,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analiza un liquen',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Descubre la calidad del aire mediante inteligencia artificial',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.textGray,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    final image = _selectedImage;
    if (image != null) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              image,
              width: double.infinity,
              height: 280,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _showImageSourceOptions,
            icon: Icon(Icons.swap_horiz_rounded, size: 18, color: _primaryGreen),
            label: Text(
              'Cambiar imagen',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: context.watch<AnalysisState>().hasActiveAnalysis ? null : _submitAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: Text(
                'Analizar con IA',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _showImageSourceOptions,
      child: ModernCard(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo/foto.png',
              width: 80,
              height: 80,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              'Captura una muestra',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Toma una fotografía del liquen para iniciar el análisis',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textGray,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: context.watch<AnalysisState>().hasActiveAnalysis ? null : () => _pickImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: Text(
                  'Tomar fotografía',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImageSourceOptions() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Selecciona la fuente de la imagen',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 24),
            _buildImageSourceOption(
              icon: Icons.camera_alt_rounded,
              label: 'Tomar foto',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 16),
            _buildImageSourceOption(
              icon: Icons.photo_library_rounded,
              label: 'Elegir de galería',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: _primaryGreen.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: _primaryGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryButton() {
    return TextButton(
      onPressed: () => Navigator.pushNamed(context, AppRoutes.historial),
      child: Text(
        'Ver historial de análisis',
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _primaryGreen,
        ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    final steps = [
      {
        'icon': Icons.camera_alt_rounded,
        'title': 'Captura una muestra',
        'subtitle': 'Fotografía el liquen en su hábitat natural',
      },
      {
        'icon': Icons.auto_awesome_rounded,
        'title': 'La IA analiza el liquen',
        'subtitle': 'Identifica especies y evalúa la calidad del aire',
      },
      {
        'icon': Icons.eco_rounded,
        'title': 'Conoce la calidad del aire',
        'subtitle': 'Recibe resultados precisos sobre tu entorno',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Cómo funciona?',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _primaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        step['icon'] as IconData,
                        size: 20,
                        color: _primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step['title'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step['subtitle'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textGray,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (index < steps.length - 1) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 1.5,
                      height: 24,
                      color: _primaryGreen.withValues(alpha: 0.15),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05, end: 0, duration: 600.ms);
  }

  Widget _buildLichenInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _primaryGreen.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _primaryGreen.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Los líquenes son bioindicadores naturales',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Su presencia y estado de salud reflejan las condiciones ambientales del lugar, incluyendo la calidad del aire y los niveles de contaminación.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.textGray,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.05, end: 0, duration: 800.ms    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../routes/route_names.dart';
import '../models/analysis_record.dart';
import '../screens/result_screen.dart';
import '../services/api_service.dart';
import '../services/navigation_service.dart';
import '../widgets/app_theme.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/modern_widgets.dart';

const _primaryGreen = Color(0xFF4E5B4A);
const _errorRed = Color(0xFFD32F2F);

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
  int _selectedIndex = 0;

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
      final image = _selectedImage;
      if (image == null) return;
      final resultJson = await _apiService.submitAnalysis(image);
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analiza un liquen 🌿',
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
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
              'assets/logo/logo.png',
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
                onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
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
          border: Border.all(
            color: _primaryGreen.withValues(alpha: 0.15),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: _primaryGreen,
            ),
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

  Widget _buildLoadingIndicator() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(
          color: AppTheme.primaryGreen,
        ),
        const SizedBox(height: 16),
        Text(
          'Analizando características del liquen...',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _errorRed.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        _errorMessage ?? '',
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _errorRed,
        ),
        textAlign: TextAlign.center,
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
          border: Border.all(
            color: _primaryGreen.withValues(alpha: 0.1),
          ),
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
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.05, end: 0, duration: 800.ms);
  }

  @override
  Widget build(BuildContext context) {
    return LichenScaffold(
      apiService: _apiService,
      showBottomNav: true,
      showParticleBackground: false,
      bottomNavIndex: _selectedIndex,
      onBottomNavTap: (index) {
        LichenNavigation.instance.navigateTo(index);
        setState(() => _selectedIndex = index);
        _navigateToSection(index);
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 28),
          _buildImageSection(),
          const SizedBox(height: 28),
          if (_isLoading) _buildLoadingIndicator(),
          if (_errorMessage != null) _buildErrorMessage(),
          if (!_isLoading && _selectedImage == null && _errorMessage == null)
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

  void _navigateToSection(int index) {
    switch (index) {
      case 0:
        Navigator.pushNamed(context, AppRoutes.dashboard);
        break;
      case 1:
        break;
      case 2:
        Navigator.pushNamed(context, AppRoutes.mapa);
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.historial);
        break;
      case 4:
        Navigator.pushNamed(context, AppRoutes.perfil);
        break;
    }
  }
}
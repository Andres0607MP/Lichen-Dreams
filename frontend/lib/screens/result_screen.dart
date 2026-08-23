import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/analysis_record.dart';
import '../models/environmental_quality.dart';
import '../widgets/modern_widgets.dart';
import '../widgets/app_theme.dart';
import '../routes/route_names.dart';
import '../services/api_service.dart';
import '../state/history_state.dart';
import '../state/analysis_state.dart';
import '../state/notifications_state.dart';

class ResultScreen extends StatefulWidget {
  final AnalysisRecord analysis;

  const ResultScreen({super.key, required this.analysis});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isSharing = false;
  bool _notificationMarked = false;
  bool _hasLocation = false;
  bool _loadingLocation = true;
  bool _isShared = false;
  bool _canBeSaved = false;
  Uint8List? _cachedImageBytes;

  @override
  void initState() {
    super.initState();
    _canBeSaved = _computeCanBeSaved();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_notificationMarked && widget.analysis.id != null && widget.analysis.id != 0) {
        _notificationMarked = true;
        context.read<NotificationsState>().markAsRead('analysis_${widget.analysis.id}');
      }
    });
    _checkLocationAndShareStatus();
  }

  bool _computeCanBeSaved() {
    final rejected = widget.analysis.raw['rechazado'] == true || widget.analysis.id == 0;
    final isGallery = widget.analysis.source == 'gallery';
    final analysisId = widget.analysis.raw['id_analisis'] is int
        ? widget.analysis.raw['id_analisis'] as int
        : (widget.analysis.id ?? 0);
    return analysisId != 0 && !rejected && !isGallery;
  }

  Future<void> _checkLocationAndShareStatus() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final historyState = Provider.of<HistoryState>(context, listen: false);
    final rejected = widget.analysis.raw['rechazado'] == true;
    final analysisId = widget.analysis.raw['id_analisis'] is int
        ? widget.analysis.raw['id_analisis'] as int
        : (widget.analysis.id ?? 0);

    if (analysisId == 0 || rejected) {
      if (mounted) setState(() {
        _loadingLocation = false;
        _hasLocation = false;
        _isShared = false;
      });
      return;
    }

    try {
      await apiService.getAnalysisLocation(analysisId);
      if (mounted) {
        setState(() => _hasLocation = true);
        final isShared = historyState.isShared(analysisId) || widget.analysis.isShared;
        setState(() => _isShared = isShared);
      }
    } on ApiException catch (_) {
      if (mounted) {
        setState(() {
          _hasLocation = false;
          _isShared = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasLocation = false;
          _isShared = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildImage() {
    final base64Data = widget.analysis.imageBase64;
    if (base64Data != null && base64Data.isNotEmpty) {
      try {
        final bytes = base64Decode(base64Data);
        return Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } catch (_) {
        // fall through to network/image icon
      }
    }

    final imageUrl = widget.analysis.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (_cachedImageBytes != null) {
        return Image.memory(
          _cachedImageBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      }

      final apiService = Provider.of<ApiService>(context, listen: false);
      return FutureBuilder<Uint8List>(
        future: apiService.downloadPrivateImageBytes(imageUrl),
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.expand(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || data == null) {
            print('[Image error] result_screen: $imageUrl\n${snapshot.error}');
            return _buildImagePlaceholder();
          }
          if (_cachedImageBytes == null && mounted) {
            _cachedImageBytes = data;
          }
          return Image.memory(
            data,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        },
      );
    }

    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.15),
            AppTheme.lightGreen.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 64,
          color: AppTheme.primaryGreen.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildHeroImage() {
    return GestureDetector(
      onTap: _showImagePreview,
      child: Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImage(),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.18),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05, end: 0, duration: 600.ms);
  }

  void _showImagePreview() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _ImagePreviewDialog(imageBuilder: _buildImage),
    );
  }

  Widget _buildResultCard() {
    final quality = widget.analysis.environmentalQuality;
    print('[ANALYSIS FLOW] ResultScreen: id=${widget.analysis.id}, quality=${quality.label}, level=${quality.level.name}');

    IconData icon;
    Color color;
    String title;
    String description;
    String whatItMeans;
    String recommendation;

    switch (quality.level) {
      case EnvironmentalQualityLevel.excellent:
      case EnvironmentalQualityLevel.good:
        icon = quality.icon;
        color = quality.primaryColor;
        title = 'Líquen ${quality.label.toLowerCase()}';
        description = quality.description;
        whatItMeans =
            'Los líquenes saludables suelen encontrarse en zonas con menor contaminación atmosférica y mejores condiciones ambientales.';
        recommendation =
            'Continúa realizando análisis en otras zonas para contribuir al monitoreo ambiental.';
        break;
      case EnvironmentalQualityLevel.moderate:
        icon = quality.icon;
        color = quality.primaryColor;
        title = 'Calidad ${quality.label.toLowerCase()}';
        description = quality.description;
        whatItMeans =
            'Esto puede indicar que la zona presenta niveles moderados de contaminación o condiciones ambientales intermedias.';
        recommendation =
            'Realiza más análisis en la zona para monitorear cambios en la calidad ambiental.';
        break;
      case EnvironmentalQualityLevel.poor:
        icon = quality.icon;
        color = quality.primaryColor;
        title = 'Líquen afectado';
        description = quality.description;
        whatItMeans =
            'Esto puede indicar que la zona presenta una menor calidad del aire o condiciones ambientales desfavorables.';
        recommendation =
            'Realiza nuevos análisis en diferentes puntos cercanos y comparte el resultado para ayudar al monitoreo ambiental.';
        break;
      case EnvironmentalQualityLevel.critical:
        icon = quality.icon;
        color = quality.primaryColor;
        title = 'Contaminación ${quality.label.toLowerCase()}';
        description = quality.description;
        whatItMeans =
            'Esto indica que la zona presenta una calidad del aire peligrosa o condiciones ambientales muy desfavorables.';
        recommendation =
            'Evita exposiciones prolongadas en la zona y comparte el resultado para alertar a la comunidad.';
        break;
      case EnvironmentalQualityLevel.unknown:
        icon = quality.icon;
        color = quality.primaryColor;
        title = 'Líquen no identificado';
        description = quality.description;
        whatItMeans =
            'Esto puede deberse a una imagen borrosa, poca iluminación, que el objeto no sea un líquen o que la especie aún no haga parte del modelo.';
        recommendation = widget.analysis.summary.isNotEmpty
            ? widget.analysis.summary
            : 'Intenta tomar una nueva fotografía con mejor iluminación, enfoque y acercamiento.';
        break;
  }

    return Transform.translate(
      offset: const Offset(0, -1),
      child: ModernCard(
        gradient: [
          color.withValues(alpha: 0.06),
          quality.secondaryColor.withValues(alpha: 0.02),
        ],
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: quality.backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppTheme.textGray,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              width: double.infinity,
              color: AppTheme.borderColor.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            _buildResultSection(
              title: '¿Qué significa?',
              content: whatItMeans,
              color: color,
            ),
            const SizedBox(height: 16),
            _buildResultSection(
              title: 'Recomendación',
              content: recommendation,
              color: color,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms).scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1), duration: 500.ms);
  }

  Widget _buildResultSection({
    required String title,
    required String content,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.textGray,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Future<void> _shareAnalysis() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final analysisId = widget.analysis.raw['id_analisis'] is int
        ? widget.analysis.raw['id_analisis'] as int
        : (widget.analysis.id ?? 0);
    final isGallery = widget.analysis.source == 'gallery';
    if (analysisId == 0 || isGallery || widget.analysis.raw['rechazado'] == true) {
      if (!mounted) return;
      String message = 'Este análisis no se puede compartir porque no corresponde a un liquen.';
      if (isGallery) {
        message = 'Los análisis desde galería no se pueden compartir en el mapa.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!_hasLocation) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este análisis no tiene ubicación asociada. No se puede compartir en el mapa.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSharing = true);
    try {
      await apiService.shareAnalysis(analysisId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compartido en mapa'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      if (mounted) {
        setState(() => _isShared = true);
        try {
          context.read<AnalysisState>().markLastAsShared();
        } catch (_) {}
        try {
          context.read<HistoryState>().markAnalysisAsShared(analysisId);
        } catch (_) {}
      }
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

  Future<void> _openMap() async {
    final analysisId = widget.analysis.id;
    final isGallery = widget.analysis.source == 'gallery';
    if (analysisId == null || analysisId == 0 || isGallery || widget.analysis.raw['rechazado'] == true) {
      if (!mounted) return;
      String message = 'Este análisis no se puede abrir en el mapa porque no corresponde a un liquen.';
      if (isGallery) {
        message = 'Los análisis desde galería no están disponibles en el mapa.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.mapExplorer,
    );
  }

  Widget _buildSavedConfirmation() {
    if (!_canBeSaved) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 20),
              const SizedBox(width: 10),
              Text(
                'Análisis guardado correctamente',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tu análisis se guardó en tu historial y puedes consultarlo en tu mapa personal.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGray,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Quieres compartirlo con la comunidad?',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Al compartirlo, otros usuarios podrán verlo en el mapa.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textGray,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotSavedMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.textGray, size: 20),
              const SizedBox(width: 10),
              Text(
                'Resultado de consulta',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Este resultado no se guardó en tu historial.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGray,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Los análisis no identificados o realizados desde una imagen de galería no se publican en el mapa.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGray.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton() {
    if (_loadingLocation) {
      return const SizedBox.shrink();
    }
    final rejected = widget.analysis.raw['rechazado'] == true || widget.analysis.id == 0;
    final isGallery = widget.analysis.source == 'gallery';
    if (rejected || isGallery) {
      return _buildNotSavedMessage();
    }

    if (_isShared) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.18), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Análisis compartido',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isSharing ? null : _openMap,
              icon: Icon(Icons.map_rounded, size: 20, color: Colors.white),
              label: Text(
                'Ver en el mapa',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Este análisis ahora es visible para otros usuarios en el mapa de la comunidad.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGray,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final isShared = _isShared;
    final label = isShared ? 'Ver en mapa' : 'Compartir en mapa';
    final icon = isShared ? Icons.map_rounded : Icons.share_rounded;
    final onTap = isShared ? _openMap : _shareAnalysis;

    return GestureDetector(
      onTap: _isSharing ? null : onTap,
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryGreen,
                AppTheme.lightGreen,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_isSharing ? Icons.hourglass_empty_rounded : icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                _isSharing ? 'Compartiendo...' : label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (_isSharing) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms);
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.historial),
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryGreen, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back_rounded, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 10),
              Text(
                'Volver al historial',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0, duration: 500.ms);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado de análisis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.historial),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroImage(),
              _buildResultCard(),
              const SizedBox(height: 18),
              _buildSavedConfirmation(),
              const SizedBox(height: 14),
              _buildShareButton(),
              const SizedBox(height: 12),
              _buildBackButton(),
              const SizedBox(height: 20),
            ],
          ),
      ),
    );
  }
}

class _ImagePreviewDialog extends StatelessWidget {
  final Widget Function() imageBuilder;

  const _ImagePreviewDialog({required this.imageBuilder});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: imageBuilder(),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

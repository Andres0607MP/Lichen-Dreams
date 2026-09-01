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
import '../widgets/app_notification.dart';
import '../routes/route_names.dart';
import '../services/api_service.dart';
import '../state/analysis_state.dart';
import '../state/notifications_state.dart';
import '../config/app_config.dart';

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

  int? _speciesId;
  String? _speciesCommonName;
  String? _speciesScientificName;
  String? _speciesImageRef;
  bool _savingSpecies = false;

  int get _analysisId {
    final rawId = widget.analysis.raw['id_analisis'];
    if (rawId is int) return rawId;
    return widget.analysis.id ?? 0;
  }

  void _initSpeciesFromRecord() {
    final raw = widget.analysis.raw;
    final rawSpeciesId = raw['id_especie'];
    _speciesId = rawSpeciesId is int
        ? rawSpeciesId
        : int.tryParse(rawSpeciesId?.toString() ?? '');
    _speciesScientificName = raw['especie_nombre_cientifico']?.toString() ??
        raw['nombre_especie']?.toString();
    _speciesCommonName = raw['especie_nombre_comun']?.toString();
  }

  @override
  void initState() {
    super.initState();
    _initSpeciesFromRecord();
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
        final isShared = widget.analysis.isShared;
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

  Widget _buildSpeciesSection() {
    if (!_canBeSaved) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final hasSpecies = _speciesId != null;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.biotech_rounded,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Identifica la especie',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'La IA solo evalúa el estado ambiental del líquen. '
              'Si tú reconoces la especie, puedes asociarla al análisis.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            if (_savingSpecies)
              const LinearProgressIndicator(color: AppTheme.primaryGreen)
            else if (hasSpecies)
              _buildSelectedSpeciesChip(colorScheme)
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _openSpeciesPicker,
                    icon: const Icon(Icons.category_rounded, size: 18),
                    label: const Text('Seleccionar especie'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _saveSpecies(null),
                    child: Text(
                      'Omitir',
                      style: GoogleFonts.poppins(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

  Widget _buildSelectedSpeciesChip(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          _SpeciesThumb(imageRef: _speciesImageRef, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _speciesCommonName ?? 'Especie registrada',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_speciesScientificName != null)
                  Text(
                    _speciesScientificName!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.primaryGreen,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  'Seleccionada por ti',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _openSpeciesPicker(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Cambiar',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _saveSpecies(null),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppTheme.errorColor,
                  ),
                  tooltip: 'Quitar especie',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSpecies(
    int? idEspecie, {
    String? sciName,
    String? common,
    String? imageRef,
  }) async {
    if (_savingSpecies) return;
    final analysisId = _analysisId;
    if (analysisId == 0) return;
    setState(() => _savingSpecies = true);
    try {
      final result = await context
          .read<AnalysisState>()
          .saveAnalysisSpecies(analysisId, idEspecie);
      if (mounted) {
        setState(() {
          _speciesId = result['id_especie'] as int?;
          _speciesScientificName = result['nombre_cientifico']?.toString();
          _speciesCommonName = result['nombre_comun']?.toString();
          _speciesImageRef = idEspecie == null ? null : imageRef;
          _savingSpecies = false;
        });
        AppNotification.show(
          context,
          message: idEspecie == null
              ? 'Especie omitida'
              : 'Especie seleccionada correctamente',
          isError: idEspecie == null,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingSpecies = false);
        AppNotification.show(
          context,
          message: 'No se pudo guardar la especie',
          isError: true,
        );
      }
    }
  }

  Future<void> _openSpeciesPicker() async {
    final analysisState = context.read<AnalysisState>();
    if (analysisState.availableSpecies.isEmpty &&
        !analysisState.speciesLoading) {
      await analysisState.loadSpecies();
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            builder: (context, scrollController) =>
                _SpeciesPickerSheet(
                  analysisState: analysisState,
                  scrollController: scrollController,
                  onSelect: (id, sciname, common, imageRef) {
                    Navigator.pop(context);
                    if (id != _speciesId) {
                      _saveSpecies(id,
                          sciName: sciname, common: common, imageRef: imageRef);
                    }
                  },
                ),
          ),
        ),
      ),
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
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: Theme.of(context).colorScheme.onSurface,
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      AppNotification.show(context, message: message, isError: true);
      return;
    }

    if (!_hasLocation) {
      if (!mounted) return;
      AppNotification.show(
        context,
        message: 'Este análisis no tiene ubicación asociada. No se puede compartir en el mapa.',
        isError: true,
      );
      return;
    }

    setState(() => _isSharing = true);
    try {
      await apiService.shareAnalysis(analysisId);
      if (!mounted) return;
      AppNotification.show(context, message: 'Compartido en mapa');
      if (mounted) {
        setState(() => _isShared = true);
        try {
          context.read<AnalysisState>().markLastAsShared();
        } catch (_) {}
      }
    } catch (error) {
      if (!mounted) return;
      AppNotification.show(
        context,
        message: error is ApiException ? error.message : 'Error al compartir análisis',
        isError: true,
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
      AppNotification.show(context, message: message, isError: true);
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
               Expanded(
                 child: Text(
                   'Análisis guardado correctamente',
                   style: GoogleFonts.poppins(
                     fontSize: 14,
                     fontWeight: FontWeight.w700,
                     color: Theme.of(context).colorScheme.onSurface,
                   ),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
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
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Al compartirlo, otros usuarios podrán verlo en el mapa.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             children: [
               Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
               const SizedBox(width: 10),
               Expanded(
                 child: Text(
                   'Resultado de consulta',
                   style: GoogleFonts.poppins(
                     fontSize: 14,
                     fontWeight: FontWeight.w700,
                     color: Theme.of(context).colorScheme.onSurface,
                   ),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Los análisis no identificados o realizados desde una imagen de galería no se publican en el mapa.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
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
                 Expanded(
                   child: Text(
                     'Análisis compartido',
                     style: GoogleFonts.poppins(
                       fontSize: 15,
                       fontWeight: FontWeight.w700,
                       color: Theme.of(context).colorScheme.onSurface,
                     ),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              _buildSpeciesSection(),
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

class _SpeciesThumb extends StatelessWidget {
  final String? imageRef;
  final double size;

  const _SpeciesThumb({this.imageRef, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageRef != null && imageRef!.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: hasImage
          ? Image.network(
              AppConfig.getImageUrl(imageRef!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.eco_rounded,
                color: AppTheme.primaryGreen,
                size: 22,
              ),
            )
          : const Icon(
              Icons.eco_rounded,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
    );
  }
}

class _SpeciesPickerSheet extends StatefulWidget {
  final AnalysisState analysisState;
  final ScrollController scrollController;
  final void Function(int id, String? sciname, String? common, String? imageRef)
      onSelect;

  const _SpeciesPickerSheet({
    required this.analysisState,
    required this.scrollController,
    required this.onSelect,
  });

  @override
  State<_SpeciesPickerSheet> createState() => _SpeciesPickerSheetState();
}

class _SpeciesPickerSheetState extends State<_SpeciesPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Selecciona la especie',
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Cerrar',
              ),
            ],
          ),
          Text(
            'Catálogo de líquenes de Lichen Dreams',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Buscar especie…',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.analysisState,
              builder: (context, _) {
                if (widget.analysisState.speciesLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.primaryGreen,
                    ),
                  );
                }
                final all = widget.analysisState.availableSpecies;
                final filtered = _query.isEmpty
                    ? all
                    : all
                        .where((s) =>
                            (s['nombre_comun']?.toString().toLowerCase() ?? '')
                                .contains(_query) ||
                            (s['nombre_cientifico']
                                    ?.toString()
                                    .toLowerCase() ??
                                '')
                                .contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No se encontraron especies',
                          style: GoogleFonts.poppins(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: widget.scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final species = filtered[index];
                    final id = species['id_especie'];
                    return _SpeciesRow(
                      species: species,
                      onTap: () => widget.onSelect(
                        id is int ? id : int.parse(id.toString()),
                        species['nombre_cientifico']?.toString(),
                        species['nombre_comun']?.toString(),
                        species['imagen_referencia']?.toString(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesRow extends StatelessWidget {
  final Map<String, dynamic> species;
  final VoidCallback onTap;

  const _SpeciesRow({required this.species, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _SpeciesThumb(imageRef: species['imagen_referencia']?.toString()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      species['nombre_comun']?.toString() ?? 'Especie',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      species['nombre_cientifico']?.toString() ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.primaryGreen,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((species['habitat']?.toString() ?? '').isNotEmpty)
                      Text(
                        species['habitat'].toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.add_circle_outline_rounded,
                color: AppTheme.primaryGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

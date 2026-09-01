import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/catalog_state.dart';
import '../state/auth_state.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/app_theme.dart';
import '../config/app_config.dart';
import '../routes/route_names.dart';

class AdminSpeciesScreen extends StatefulWidget {
  const AdminSpeciesScreen({super.key});

  @override
  State<AdminSpeciesScreen> createState() => _AdminSpeciesScreenState();
}

class _AdminSpeciesScreenState extends State<AdminSpeciesScreen> {
  CatalogState? _catalogState;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _catalogState = context.read<CatalogState>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _catalogState!.species.isEmpty && !_catalogState!.loadingSpecies) {
          _catalogState!.loadSpecies();
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LichenScaffold(
      apiService: Provider.of<ApiService>(context, listen: false),
      showBottomNav: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Especies de líquenes',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.especiesPrimary),
            onPressed: () => _showSpeciesForm(context),
            tooltip: 'Nueva especie',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _catalogState!,
        builder: (context, _) {
          if (_catalogState!.loadingSpecies) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.especiesPrimary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando catálogo…',
                    style: GoogleFonts.poppins(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          if (_catalogState!.speciesError != null) {
            return _buildErrorState(context);
          }

          if (_catalogState!.species.isEmpty) {
            return _buildEmptyState(context);
          }

          final isAdmin = context.select<AuthState, bool>((a) => a.isAdmin);

          return Column(
            children: [
              if (_catalogState!.mutationPending)
                LinearProgressIndicator(minHeight: 2, color: AppTheme.especiesPrimary),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount;
                    double aspectRatio;
                    final width = constraints.maxWidth;
                    if (width < 380) {
                      crossAxisCount = 1;
                      aspectRatio = 1.3;
                    } else if (width < 520) {
                      crossAxisCount = 2;
                      aspectRatio = 0.65;
                    } else if (width < 780) {
                      crossAxisCount = 2;
                      aspectRatio = 0.70;
                    } else {
                      crossAxisCount = 3;
                      aspectRatio = 0.85;
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: aspectRatio,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _catalogState!.species.length,
                      itemBuilder: (context, index) {
                        final species = _catalogState!.species[index];
                        return _SpeciesCard(
                          species: species,
                          isAdmin: isAdmin,
                          onTap: isAdmin
                              ? () => _showSpeciesForm(context, species: species)
                              : () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.speciesDetail,
                                  arguments: species,
                                ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 56, color: AppTheme.errorColor.withValues(alpha: 0.25)),
              const SizedBox(height: 20),
              Text(
                'No se pudo cargar el catálogo',
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _catalogState!.speciesError!,
                style: GoogleFonts.poppins(fontSize: 13, color: colorScheme.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _catalogState!.loadSpecies(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Reintentar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.especiesPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.especiesPrimary.withValues(alpha: 0.10),
                      AppTheme.especiesSecondary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.eco_rounded, size: 44, color: AppTheme.especiesPrimary.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 22),
              Text(
                'Catálogo vacío',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Agrega la primera especie para comenzar a construir el catálogo de líquenes.',
                style: GoogleFonts.poppins(fontSize: 13, color: colorScheme.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => _showSpeciesForm(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Agregar primera especie', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.especiesPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSpeciesForm(BuildContext context, {Map<String, dynamic>? species}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SpeciesFormSheet(species: species),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  species == null ? 'Especie creada correctamente' : 'Especie actualizada correctamente',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> species) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.delete_outline_rounded, size: 36, color: AppTheme.errorColor.withValues(alpha: 0.7)),
        title: Text(
          'Eliminar especie',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${species['nombre_cientifico'] ?? species['nombre_comun'] ?? 'esta especie'}"? Esta acción no se puede deshacer.',
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await _catalogState!.deleteSpecies(species['id_especie']);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Especie eliminada correctamente', style: GoogleFonts.poppins(fontSize: 13))),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No se pudo eliminar: ${e.toString().replaceAll(RegExp(r'^Exception:\s*'), '')}',
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }
}

class _SpeciesCard extends StatelessWidget {
  final Map<String, dynamic> species;
  final bool isAdmin;
  final VoidCallback onTap;

  const _SpeciesCard({required this.species, required this.isAdmin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nombreCientifico = species['nombre_cientifico'] ?? 'Sin nombre científico';
    final nombreComun = species['nombre_comun'];
    final colorPredominante = species['color_predominante'];
    final tipoCrecimiento = species['tipo_crecimiento'];
    final habitat = species['habitat'];
    final imagen = species['imagen_referencia'];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppTheme.shadow05, blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imagen != null && imagen.toString().isNotEmpty
                        ? Image.network(
                            AppConfig.getImageUrl(imagen.toString()),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) => _PlaceholderIcon(),
                          )
                        : _PlaceholderIcon(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nombreCientifico,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.25,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (nombreComun != null && nombreComun.toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    nombreComun.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    if (colorPredominante != null && colorPredominante.toString().isNotEmpty)
                      _InfoChip(icon: Icons.palette_rounded, label: colorPredominante.toString()),
                    if (tipoCrecimiento != null && tipoCrecimiento.toString().isNotEmpty)
                      _InfoChip(icon: Icons.landscape_rounded, label: tipoCrecimiento.toString()),
                    if (habitat != null && habitat.toString().isNotEmpty)
                      _InfoChip(icon: Icons.forest_rounded, label: habitat.toString()),
                  ],
                ),
                const SizedBox(height: 6),
                if (isAdmin)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onTap,
                          icon: Icon(Icons.edit_rounded, size: 13),
                          label: Text('Editar', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.especiesPrimary,
                            side: BorderSide(color: AppTheme.especiesPrimary.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => _onDelete(context, species),
                        icon: Icon(Icons.delete_outline_rounded, size: 15, color: AppTheme.errorColor.withValues(alpha: 0.7)),
                        tooltip: 'Eliminar',
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.06),
                          padding: const EdgeInsets.all(5),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onDelete(BuildContext context, Map<String, dynamic> species) async {
    final screen = context.findAncestorStateOfType<_AdminSpeciesScreenState>();
    if (screen != null) {
      await screen._confirmDelete(context, species);
    }
  }
}

class _PlaceholderIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Icon(Icons.eco_rounded, size: 32, color: AppTheme.especiesPrimary.withValues(alpha: 0.15)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.especiesPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppTheme.especiesPrimary.withValues(alpha: 0.7)),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesFormSheet extends StatefulWidget {
  final Map<String, dynamic>? species;

  const _SpeciesFormSheet({this.species});

  @override
  State<_SpeciesFormSheet> createState() => _SpeciesFormSheetState();
}

class _SpeciesFormSheetState extends State<_SpeciesFormSheet> {
  static const int _maxNombreCientifico = 100;
  static const int _maxNombreComun = 100;
  static const int _maxDescripcion = 4000;
  static const int _maxColor = 50;
  static const int _maxTipoCrecimiento = 50;
  static const int _maxTolerancia = 100;
  static const int _maxIndicador = 255;
  static const int _maxHabitat = 100;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _nombreCientificoController;
  late final TextEditingController _nombreComunController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _colorController;
  late final TextEditingController _tipoCrecimientoController;
  late final TextEditingController _toleranciaController;
  late final TextEditingController _indicadorController;
  late final TextEditingController _habitatController;

  bool _isSaving = false;
  bool _autovalidate = false;
  String? _serverError;
  File? _pickedImage;
  String? _currentImageUrl;
  bool _uploadingImage = false;
  late final ApiService _apiService;
  late final CatalogState _catalogState;

  bool get _isEditing => widget.species != null;

  @override
  void initState() {
    super.initState();
    _apiService = context.read<ApiService>();
    _catalogState = context.read<CatalogState>();
    final s = widget.species;
    _nombreCientificoController = TextEditingController(text: (s?['nombre_cientifico'] as String?) ?? '');
    _nombreComunController = TextEditingController(text: (s?['nombre_comun'] as String?) ?? '');
    _descripcionController = TextEditingController(text: (s?['descripcion'] as String?) ?? '');
    _colorController = TextEditingController(text: (s?['color_predominante'] as String?) ?? '');
    _tipoCrecimientoController = TextEditingController(text: (s?['tipo_crecimiento'] as String?) ?? '');
    _toleranciaController = TextEditingController(text: (s?['nivel_tolerancia_contaminacion'] as String?) ?? '');
    _indicadorController = TextEditingController(text: (s?['indicador_calidad_aire'] as String?) ?? '');
    _habitatController = TextEditingController(text: (s?['habitat'] as String?) ?? '');
    _currentImageUrl = (s?['imagen_referencia'] as String?);
  }

  @override
  void dispose() {
    _nombreCientificoController.dispose();
    _nombreComunController.dispose();
    _descripcionController.dispose();
    _colorController.dispose();
    _tipoCrecimientoController.dispose();
    _toleranciaController.dispose();
    _indicadorController.dispose();
    _habitatController.dispose();
    super.dispose();
  }

  String? _validarNombreCientifico(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'El nombre científico es obligatorio';
    if (text.length > _maxNombreCientifico) return 'Máximo $_maxNombreCientifico caracteres';
    return null;
  }

  String? Function(String?) _validarOpcional(int maxLength) {
    return (String? value) {
      final text = value?.trim() ?? '';
      if (text.length > maxLength) return 'Máximo $maxLength caracteres';
      return null;
    };
  }

  bool get _isValid {
    final nombre = _nombreCientificoController.text.trim();
    return nombre.isNotEmpty &&
        nombre.length <= _maxNombreCientifico &&
        _nombreComunController.text.trim().length <= _maxNombreComun &&
        _descripcionController.text.trim().length <= _maxDescripcion &&
        _colorController.text.trim().length <= _maxColor &&
        _tipoCrecimientoController.text.trim().length <= _maxTipoCrecimiento &&
        _toleranciaController.text.trim().length <= _maxTolerancia &&
        _indicadorController.text.trim().length <= _maxIndicador &&
        _habitatController.text.trim().length <= _maxHabitat;
  }

  String? _trimmed(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<String?> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
        _currentImageUrl = null;
      });
    }
    return null;
  }

  Future<void> _removeImage() async {
    setState(() {
      _pickedImage = null;
      _currentImageUrl = null;
    });
  }

  Future<void> _save() async {
    setState(() => _autovalidate = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _serverError = null;
    });

    try {
      String? imageUrl = _currentImageUrl;

      if (_pickedImage != null) {
        setState(() => _uploadingImage = true);
        try {
          imageUrl = await _apiService.uploadSpeciesImage(_pickedImage!);
        } finally {
          if (mounted) {
            setState(() => _uploadingImage = false);
          }
        }
      }

      final payload = {
        'nombre_cientifico': _trimmed(_nombreCientificoController),
        'nombre_comun': _trimmed(_nombreComunController),
        'descripcion': _trimmed(_descripcionController),
        'color_predominante': _trimmed(_colorController),
        'tipo_crecimiento': _trimmed(_tipoCrecimientoController),
        'nivel_tolerancia_contaminacion': _trimmed(_toleranciaController),
        'indicador_calidad_aire': _trimmed(_indicadorController),
        'habitat': _trimmed(_habitatController),
        if (imageUrl != null && imageUrl.isNotEmpty) 'imagen_referencia': imageUrl,
      };

      if (_isEditing) {
        await _catalogState.updateSpecies(widget.species!['id_especie'], payload);
      } else {
        await _catalogState.createSpecies(payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _serverError = e.toString();
        });
      }
    }
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.especiesPrimary.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppTheme.especiesPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool required,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        autovalidateMode: _autovalidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        validator: validator,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.poppins(fontSize: 14, color: colorScheme.onSurface),
        decoration: InputDecoration(
          label: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: label),
                if (required)
                  TextSpan(text: ' *', style: TextStyle(color: colorScheme.error)),
              ],
            ),
          ),
          hintText: hint,
          counterText: '',
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500, color: colorScheme.onErrorContainer, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = _isEditing;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: viewInsets + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.especiesPrimary.withValues(alpha: 0.12),
                            AppTheme.especiesSecondary.withValues(alpha: 0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(isEditing ? Icons.edit_rounded : Icons.eco_rounded, color: AppTheme.especiesPrimary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Editar especie' : 'Nueva especie',
                            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                          ),
                          Text(
                            'Completa la ficha de la especie',
                            style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_serverError != null) _errorBanner(_serverError!),
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ImagePickerField(
                          currentImageUrl: _currentImageUrl,
                          localPreview: _pickedImage,
                          isUploading: _uploadingImage,
                          onPickImage: _pickImage,
                          onRemoveImage: _removeImage,
                        ),
                        _sectionHeader('Información de la especie', Icons.biotech_rounded),
                        _field(
                          controller: _nombreCientificoController,
                          label: 'Nombre científico',
                          required: true,
                          hint: 'Ej.: Xanthoria parietina',
                          maxLength: _maxNombreCientifico,
                          validator: _validarNombreCientifico,
                        ),
                        _field(
                          controller: _nombreComunController,
                          label: 'Nombre común',
                          required: false,
                          hint: 'Ej.: Líquen anaranjado',
                          maxLength: _maxNombreComun,
                          validator: _validarOpcional(_maxNombreComun),
                        ),
                        _field(
                          controller: _descripcionController,
                          label: 'Descripción',
                          required: false,
                          hint: 'Características generales de la especie',
                          maxLines: 3,
                          maxLength: _maxDescripcion,
                          validator: _validarOpcional(_maxDescripcion),
                        ),
                        _sectionHeader('Características', Icons.palette_rounded),
                        _field(
                          controller: _colorController,
                          label: 'Color predominante',
                          required: false,
                          hint: 'Ej.: Amarillo anaranjado',
                          maxLength: _maxColor,
                          validator: _validarOpcional(_maxColor),
                        ),
                        _field(
                          controller: _tipoCrecimientoController,
                          label: 'Tipo de crecimiento',
                          required: false,
                          hint: 'Ej.: Foliáceo, crustoso, fruticuloso',
                          maxLength: _maxTipoCrecimiento,
                          validator: _validarOpcional(_maxTipoCrecimiento),
                        ),
                        _field(
                          controller: _habitatController,
                          label: 'Hábitat',
                          required: false,
                          hint: 'Ej.: Cortezas, rocas, suelo',
                          maxLength: _maxHabitat,
                          validator: _validarOpcional(_maxHabitat),
                        ),
                        _sectionHeader('Indicadores ambientales', Icons.air_rounded),
                        _field(
                          controller: _toleranciaController,
                          label: 'Tolerancia a contaminación',
                          required: false,
                          hint: 'Ej.: Alta, media, baja',
                          maxLength: _maxTolerancia,
                          validator: _validarOpcional(_maxTolerancia),
                        ),
                        _field(
                          controller: _indicadorController,
                          label: 'Indicador de calidad del aire',
                          required: false,
                          hint: 'Ej.: Buena, moderada, mala',
                          maxLength: _maxIndicador,
                          validator: _validarOpcional(_maxIndicador),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                      child: Text('Cancelar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSaving || !_isValid ? null : _save,
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.especiesPrimary),
                        child: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isEditing ? 'Guardar cambios' : 'Crear especie', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePickerField extends StatelessWidget {
  final String? currentImageUrl;
  final File? localPreview;
  final bool isUploading;
  final Future<String?> Function() onPickImage;
  final Future<void> Function() onRemoveImage;

  const _ImagePickerField({
    required this.currentImageUrl,
    required this.localPreview,
    required this.isUploading,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = localPreview != null || (currentImageUrl != null && currentImageUrl!.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Imagen de referencia',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  AppTheme.especiesPrimary.withValues(alpha: 0.08),
                  AppTheme.especiesSecondary.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: localPreview != null
                            ? Image.file(localPreview!, fit: BoxFit.cover)
                            : Image.network(
                                AppConfig.getImageUrl(currentImageUrl!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _PlaceholderContent(onPickImage: onPickImage),
                              ),
                      ),
                      if (isUploading)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: () async {
                                  await onPickImage();
                                },
                                icon: Icon(Icons.camera_alt_rounded, size: 18, color: AppTheme.especiesPrimary),
                                tooltip: 'Cambiar imagen',
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: () async {
                                  await onRemoveImage();
                                },
                                icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.errorColor),
                                tooltip: 'Eliminar imagen',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : _PlaceholderContent(onPickImage: onPickImage),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderContent extends StatelessWidget {
  final Future<String?> Function() onPickImage;

  const _PlaceholderContent({required this.onPickImage});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await onPickImage();
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.especiesPrimary.withValues(alpha: 0.10),
                  AppTheme.especiesSecondary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.add_a_photo_rounded, size: 26, color: AppTheme.especiesPrimary.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 10),
          Text(
            'Agregar imagen de referencia',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Toca para seleccionar una foto',
            style: GoogleFonts.poppins(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}
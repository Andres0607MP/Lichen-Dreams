import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/catalog_state.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/app_theme.dart';

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
          icon: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.onSurface),
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
            icon: const Icon(Icons.add_rounded, color: AppTheme.primaryGreen),
            onPressed: () => _showSpeciesDialog(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _catalogState!,
        builder: (context, _) {
          if (_catalogState!.loadingSpecies) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_catalogState!.speciesError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar especies',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _catalogState!.speciesError!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _catalogState!.loadSpecies(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_catalogState!.species.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.eco_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'No hay especies registradas',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Agrega la primera especie para comenzar el catálogo',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      onPressed: () => _showSpeciesDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        'Crear especie',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              if (_catalogState!.mutationPending)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _catalogState!.species.length,
                  itemBuilder: (context, index) {
                    final species = _catalogState!.species[index];
                    return _SpeciesCard(
                      species: species,
                      onEdit: () => _showSpeciesDialog(context, species: species),
                      onDelete: () => _confirmDelete(context, species),
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

  Future<void> _showSpeciesDialog(BuildContext context, {Map<String, dynamic>? species}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SpeciesFormDialog(
        catalogState: _catalogState!,
        species: species,
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            species == null ? 'Especie creada correctamente' : 'Especie actualizada correctamente',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> species) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar especie', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          "¿Estás seguro de eliminar '${species['nombre_cientifico'] ?? species['nombre_comun'] ?? 'esta especie'}'?",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _catalogState!.deleteSpecies(species['id_especie']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Especie eliminada'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }
}

class _SpeciesFormDialog extends StatefulWidget {
  final CatalogState catalogState;
  final Map<String, dynamic>? species;

  const _SpeciesFormDialog({required this.catalogState, this.species});

  @override
  State<_SpeciesFormDialog> createState() => _SpeciesFormDialogState();
}

class _SpeciesFormDialogState extends State<_SpeciesFormDialog> {
  static const int _maxNombreCientifico = 100;
  static const int _maxNombreComun = 100;
  static const int _maxDescripcion = 4000;
  static const int _maxColor = 50;
  static const int _maxTipoCrecimiento = 50;
  static const int _maxTolerancia = 100;
  static const int _maxIndicador = 255;
  static const int _maxHabitat = 100;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

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

  bool get _isEditing => widget.species != null;

  @override
  void initState() {
    super.initState();
    final s = widget.species;
    _nombreCientificoController =
        TextEditingController(text: (s?['nombre_cientifico'] as String?) ?? '');
    _nombreComunController =
        TextEditingController(text: (s?['nombre_comun'] as String?) ?? '');
    _descripcionController =
        TextEditingController(text: (s?['descripcion'] as String?) ?? '');
    _colorController =
        TextEditingController(text: (s?['color_predominante'] as String?) ?? '');
    _tipoCrecimientoController =
        TextEditingController(text: (s?['tipo_crecimiento'] as String?) ?? '');
    _toleranciaController =
        TextEditingController(text: (s?['nivel_tolerancia_contaminacion'] as String?) ?? '');
    _indicadorController =
        TextEditingController(text: (s?['indicador_calidad_aire'] as String?) ?? '');
    _habitatController = TextEditingController(text: (s?['habitat'] as String?) ?? '');
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
    if (text.isEmpty) {
      return 'El nombre científico es obligatorio';
    }
    if (text.length > _maxNombreCientifico) {
      return 'Máximo $_maxNombreCientifico caracteres';
    }
    return null;
  }

  String? Function(String?) _validarOpcional(int maxLength) {
    return (String? value) {
      final text = value?.trim() ?? '';
      if (text.length > maxLength) {
        return 'Máximo $maxLength caracteres';
      }
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

  Map<String, dynamic> _buildPayload() {
    return {
      'nombre_cientifico': _trimmed(_nombreCientificoController),
      'nombre_comun': _trimmed(_nombreComunController),
      'descripcion': _trimmed(_descripcionController),
      'color_predominante': _trimmed(_colorController),
      'tipo_crecimiento': _trimmed(_tipoCrecimientoController),
      'nivel_tolerancia_contaminacion': _trimmed(_toleranciaController),
      'indicador_calidad_aire': _trimmed(_indicadorController),
      'habitat': _trimmed(_habitatController),
    };
  }

  Future<void> _save() async {
    setState(() => _autovalidate = true);
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
      _serverError = null;
    });
    try {
      final catalog = widget.catalogState;
      if (_isEditing) {
        await catalog.updateSpecies(widget.species!['id_especie'], _buildPayload());
      } else {
        await catalog.createSpecies(_buildPayload());
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _serverError = e.toString();
        });
      }
    }
  }

  Widget _sectionHeader(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppTheme.especiesPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: colorScheme.onSurfaceVariant,
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
    TextInputType? keyboardType,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        autovalidateMode: _autovalidate
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        validator: validator,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          label: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: label),
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: colorScheme.error),
                  ),
              ],
            ),
          ),
          hintText: hint,
          counterText: '',
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 20, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: colorScheme.onErrorContainer,
                height: 1.35,
              ),
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

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXLBorder),
      backgroundColor: colorScheme.surfaceContainerLowest,
      child: AnimatedPadding(
        duration: AppTheme.animationNormal,
        padding: EdgeInsets.only(bottom: viewInsets + 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.especiesPrimary.withValues(alpha: 0.12),
                        borderRadius: AppTheme.radiusMDBorder,
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_rounded : Icons.eco_rounded,
                        color: AppTheme.especiesPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Editar especie' : 'Nueva especie',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Los campos marcados con * son obligatorios',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_serverError != null) _errorBanner(_serverError!),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionHeader('Identificación'),
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
                          _sectionHeader('Apariencia'),
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
                            hint: 'Ej.: Foliáceo',
                            maxLength: _maxTipoCrecimiento,
                            validator: _validarOpcional(_maxTipoCrecimiento),
                          ),
                          _sectionHeader('Ecología'),
                          _field(
                            controller: _toleranciaController,
                            label: 'Tolerancia a contaminación',
                            required: false,
                            hint: 'Ej.: Alta',
                            maxLength: _maxTolerancia,
                            validator: _validarOpcional(_maxTolerancia),
                          ),
                          _field(
                            controller: _indicadorController,
                            label: 'Indicador de calidad del aire',
                            required: false,
                            hint: 'Ej.: Buena',
                            maxLength: _maxIndicador,
                            validator: _validarOpcional(_maxIndicador),
                          ),
                          _field(
                            controller: _habitatController,
                            label: 'Hábitat',
                            required: false,
                            hint: 'Ej.: Cortezas, rocas',
                            maxLength: _maxHabitat,
                            validator: _validarOpcional(_maxHabitat),
                          ),
                          _sectionHeader('Descripción'),
                          _field(
                            controller: _descripcionController,
                            label: 'Descripción',
                            required: false,
                            hint: 'Características generales de la especie',
                            maxLines: 4,
                            maxLength: _maxDescripcion,
                            validator: _validarOpcional(_maxDescripcion),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _isSaving ? null : () => Navigator.of(context).pop(false),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSaving || !_isValid ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.especiesPrimary,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing ? 'Guardar' : 'Crear especie',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _SpeciesCard extends StatelessWidget {
  final Map<String, dynamic> species;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SpeciesCard({
    required this.species,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final nombreCientifico = species['nombre_cientifico'] ?? 'Sin nombre científico';
    final nombreComun = species['nombre_comun'];
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombreCientifico,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (nombreComun != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          nombreComun,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded, size: 20, color: AppTheme.errorColor),
                  onPressed: onDelete,
                ),
              ],
            ),
            if (species['descripcion'] != null) ...[
              const SizedBox(height: 8),
              Text(
                species['descripcion'],
                style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

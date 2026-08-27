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
      if (_catalogState!.species.isEmpty && !_catalogState!.loadingSpecies) {
        _catalogState!.loadSpecies();
      }
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
                      'Agrega la primera especie usando el botón +',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
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
          );
        },
      ),
    );
  }

  Future<void> _showSpeciesDialog(BuildContext context, {Map<String, dynamic>? species}) async {
    final isEditing = species != null;
    final formKey = GlobalKey<FormState>();
    final nombreCientificoController = TextEditingController(text: species?['nombre_cientifico'] ?? '');
    final nombreComunController = TextEditingController(text: species?['nombre_comun'] ?? '');
    final descripcionController = TextEditingController(text: species?['descripcion'] ?? '');
    final colorController = TextEditingController(text: species?['color_predominante'] ?? '');
    final tipoCrecimientoController = TextEditingController(text: species?['tipo_crecimiento'] ?? '');
    final toleranciaController = TextEditingController(text: species?['nivel_tolerancia_contaminacion'] ?? '');
    final indicadorController = TextEditingController(text: species?['indicador_calidad_aire'] ?? '');
    final habitatController = TextEditingController(text: species?['habitat'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isEditing ? 'Editar especie' : 'Nueva especie',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreCientificoController,
                  decoration: const InputDecoration(labelText: 'Nombre científico'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nombreComunController,
                  decoration: const InputDecoration(labelText: 'Nombre común'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descripcionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: colorController,
                  decoration: const InputDecoration(labelText: 'Color predominante'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: tipoCrecimientoController,
                  decoration: const InputDecoration(labelText: 'Tipo de crecimiento'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: toleranciaController,
                  decoration: const InputDecoration(labelText: 'Tolerancia a contaminación'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: indicadorController,
                  decoration: const InputDecoration(labelText: 'Indicador calidad aire'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: habitatController,
                  decoration: const InputDecoration(labelText: 'Hábitat'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: Text(isEditing ? 'Guardar' : 'Crear', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final data = {
        'nombre_cientifico': nombreCientificoController.text.isNotEmpty ? nombreCientificoController.text : null,
        'nombre_comun': nombreComunController.text.isNotEmpty ? nombreComunController.text : null,
        'descripcion': descripcionController.text.isNotEmpty ? descripcionController.text : null,
        'color_predominante': colorController.text.isNotEmpty ? colorController.text : null,
        'tipo_crecimiento': tipoCrecimientoController.text.isNotEmpty ? tipoCrecimientoController.text : null,
        'nivel_tolerancia_contaminacion': toleranciaController.text.isNotEmpty ? toleranciaController.text : null,
        'indicador_calidad_aire': indicadorController.text.isNotEmpty ? indicadorController.text : null,
        'habitat': habitatController.text.isNotEmpty ? habitatController.text : null,
      };

      try {
        if (isEditing) {
          await _catalogState!.updateSpecies(species['id_especie'], data);
        } else {
          await _catalogState!.createSpecies(data);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? 'Especie actualizada' : 'Especie creada'),
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

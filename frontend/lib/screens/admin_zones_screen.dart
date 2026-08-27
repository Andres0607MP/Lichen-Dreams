import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/catalog_state.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/app_theme.dart';

class AdminZonesScreen extends StatefulWidget {
  const AdminZonesScreen({super.key});

  @override
  State<AdminZonesScreen> createState() => _AdminZonesScreenState();
}

class _AdminZonesScreenState extends State<AdminZonesScreen> {
  late CatalogState _catalogState;

  @override
  void initState() {
    super.initState();
    _catalogState = CatalogState(
      apiService: Provider.of<ApiService>(context, listen: false),
    );
    _catalogState.loadZones();
  }

  @override
  void dispose() {
    _catalogState.dispose();
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
          'Zonas ambientales',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.primaryGreen),
            onPressed: () => _showZoneDialog(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _catalogState,
        builder: (context, _) {
          if (_catalogState.loadingZones) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_catalogState.zonesError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar zonas',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _catalogState.zonesError!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _catalogState.loadZones(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_catalogState.zones.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'No hay zonas registradas',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Agrega la primera zona usando el botón +',
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
            itemCount: _catalogState.zones.length,
            itemBuilder: (context, index) {
              final zone = _catalogState.zones[index];
              return _ZoneCard(
                zone: zone,
                onEdit: () => _showZoneDialog(context, zone: zone),
                onDelete: () => _confirmDelete(context, zone),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showZoneDialog(BuildContext context, {Map<String, dynamic>? zone}) async {
    final isEditing = zone != null;
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: zone?['nombre_zona'] ?? '');
    final nivelRiesgoController = TextEditingController(text: zone?['nivel_riesgo'] ?? '');
    final calidadController = TextEditingController(text: zone?['calidad_promedio_aire'] ?? '');
    final descripcionController = TextEditingController(text: zone?['descripcion'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isEditing ? 'Editar zona' : 'Nueva zona',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre de la zona'),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Mínimo 2 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nivelRiesgoController,
                  decoration: const InputDecoration(labelText: 'Nivel de riesgo'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: calidadController,
                  decoration: const InputDecoration(labelText: 'Calidad promedio del aire'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descripcionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2,
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
        'nombre_zona': nombreController.text,
        'nivel_riesgo': nivelRiesgoController.text.isNotEmpty ? nivelRiesgoController.text : null,
        'calidad_promedio_aire': calidadController.text.isNotEmpty ? calidadController.text : null,
        'descripcion': descripcionController.text.isNotEmpty ? descripcionController.text : null,
      };

      try {
        if (isEditing) {
          await _catalogState.updateZone(zone!['id_zona'], data);
        } else {
          await _catalogState.createZone(data);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? 'Zona actualizada' : 'Zona creada'),
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

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> zone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar zona', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          "¿Estás seguro de eliminar '${zone['nombre_zona'] ?? 'esta zona'}'?",
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
        await _catalogState.deleteZone(zone['id_zona']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Zona eliminada'),
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

class _ZoneCard extends StatelessWidget {
  final Map<String, dynamic> zone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ZoneCard({
    required this.zone,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = zone['nombre_zona'] ?? 'Sin nombre';
    final nivelRiesgo = zone['nivel_riesgo'];
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
                        nombre,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (nivelRiesgo != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Riesgo: $nivelRiesgo',
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
            if (zone['descripcion'] != null) ...[
              const SizedBox(height: 8),
              Text(
                zone['descripcion'],
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

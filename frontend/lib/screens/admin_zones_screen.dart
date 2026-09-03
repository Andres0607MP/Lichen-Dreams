import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/catalog_state.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/app_theme.dart';
import '../widgets/app_notification.dart';

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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => ZoneEditorDialog(zone: zone),
    );

    if (result != null && mounted) {
      final data = Map<String, dynamic>.from(result);
      try {
        if (zone != null) {
          await _catalogState.updateZone(zone['id_zona'], data);
        } else {
          await _catalogState.createZone(data);
        }
        if (mounted) {
          AppNotification.show(
            context,
            message: zone != null ? 'Zona actualizada' : 'Zona creada',
          );
        }
      } catch (e) {
        if (mounted) {
          AppNotification.show(
            context,
            message: 'Error al guardar zona',
            isError: true,
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
          AppNotification.show(context, message: 'Zona eliminada');
        }
      } catch (e) {
        if (mounted) {
          AppNotification.show(
            context,
            message: 'Error al eliminar zona',
            isError: true,
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
                          'Riesgo: $nivelRiesgo · Calidad: ${zone['calidad_promedio_aire'] ?? 'sin datos'} · ${zone['total_analisis'] ?? 0} análisis',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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

class ZoneEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? zone;

  const ZoneEditorDialog({super.key, this.zone});

  @override
  State<ZoneEditorDialog> createState() => _ZoneEditorDialogState();
}

class _ZoneEditorDialogState extends State<ZoneEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _latitudController;
  late TextEditingController _longitudController;
  late TextEditingController _radioController;
  late TextEditingController _descripcionController;
  GoogleMapController? _mapController;

  final LatLng _defaultCenter = const LatLng(4.7110, -74.0721);

  @override
  void initState() {
    super.initState();
    final zone = widget.zone;
    _nombreController = TextEditingController(text: zone?['nombre_zona'] ?? '');
    _latitudController = TextEditingController(
      text: zone?['latitud']?.toString() ?? '',
    );
    _longitudController = TextEditingController(
      text: zone?['longitud']?.toString() ?? '',
    );
    _radioController = TextEditingController(
      text: zone?['radio_metros']?.toString() ?? '',
    );
    _descripcionController = TextEditingController(
      text: zone?['descripcion'] ?? '',
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _latitudController.dispose();
    _longitudController.dispose();
    _radioController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  LatLng? _getCenter() {
    final lat = double.tryParse(_latitudController.text);
    final lng = double.tryParse(_longitudController.text);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  double? _getRadio() {
    final r = double.tryParse(_radioController.text);
    return (r != null && r > 0) ? r : null;
  }

  Set<Circle> _buildPreviewCircles() {
    final center = _getCenter();
    final radio = _getRadio();
    if (center == null || radio == null) return {};

    return {
      Circle(
        circleId: const CircleId('zone_preview'),
        center: center,
        radius: radio,
        fillColor: AppTheme.mapaPrimary.withValues(alpha: 0.25),
        strokeColor: AppTheme.mapaPrimary,
        strokeWidth: 3,
      ),
      Circle(
        circleId: const CircleId('zone_center_marker'),
        center: center,
        radius: 3,
        fillColor: AppTheme.primaryGreen,
        strokeColor: Colors.white,
        strokeWidth: 2,
      ),
    };
  }

  void _zoomToZone() {
    final center = _getCenter();
    if (center == null || _mapController == null) {
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(_defaultCenter),
        );
      }
      return;
    }
    final radio = _getRadio() ?? 500;
    final zoom = _radioToZoom(radio);
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(center, zoom),
    );
  }

  double _radioToZoom(double radioMetros) {
    if (radioMetros <= 50) return 18;
    if (radioMetros <= 200) return 17;
    if (radioMetros <= 500) return 16;
    if (radioMetros <= 1000) return 15;
    if (radioMetros <= 3000) return 14;
    return 13;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.zone != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(isEditing),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildMapPreview(),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildForm(),
                  ),
                ],
              ),
            ),
            _buildActions(isEditing),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_location_alt_rounded,
            color: AppTheme.mapaPrimary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing ? 'Editar zona ambiental' : 'Nueva zona ambiental',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.zoom_out_map_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
            onPressed: _zoomToZone,
            tooltip: 'Ajustar vista a la zona',
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    final center = _getCenter();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: center ?? _defaultCenter,
          zoom: _getRadio() != null ? _radioToZoom(_getRadio()!) : 14,
        ),
        circles: _buildPreviewCircles(),
        markers: center != null
            ? {
                Marker(
                  markerId: const MarkerId('zone_center'),
                  position: center,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                ),
              }
            : {},
        onMapCreated: (controller) {
          _mapController = controller;
        },
        onTap: (latLng) {
          final radius = _radioController.text.isNotEmpty
              ? _radioController.text
              : '500';
          setState(() {
            _latitudController.text = latLng.latitude.toStringAsFixed(6);
            _longitudController.text = latLng.longitude.toStringAsFixed(6);
            if (radius.isEmpty) _radioController.text = '500';
          });
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        mapType: MapType.normal,
        zoomControlsEnabled: true,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
      ),
    );
  }

  Widget _buildForm() {
    final isEditing = widget.zone != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre de la zona',
                  prefixIcon: Icon(Icons.label_rounded, color: AppTheme.mapaPrimary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(100),
                ],
                validator: (value) {
                  if (value == null || value.trim().length < 2) {
                    return 'Mínimo 2 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _latitudController,
                decoration: InputDecoration(
                  labelText: 'Latitud',
                  prefixIcon: Icon(Icons.place_rounded, color: AppTheme.mapaPrimary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                ],
                onChanged: (_) {
                  setState(() {});
                  _zoomToZone();
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _longitudController,
                decoration: InputDecoration(
                  labelText: 'Longitud',
                  prefixIcon: Icon(Icons.place_rounded, color: AppTheme.mapaPrimary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                ],
                onChanged: (_) {
                  setState(() {});
                  _zoomToZone();
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _radioController,
                decoration: InputDecoration(
                  labelText: 'Radio (metros)',
                  prefixIcon: Icon(Icons.radar_rounded, color: AppTheme.mapaPrimary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: (_) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcionController,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.description_rounded, color: AppTheme.mapaPrimary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text(
                'La calidad del aire y el nivel de riesgo se calculan '
                'automáticamente a partir de los análisis dentro del radio.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isEditing
                    ? 'Toca el mapa para mover el centro de la zona.'
                    : 'Toca el mapa para seleccionar el centro de la zona.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _handleSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.mapaPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isEditing ? 'Guardar cambios' : 'Crear zona',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final latStr = _latitudController.text;
    final lngStr = _longitudController.text;
    final radioStr = _radioController.text;

    if (latStr.isEmpty || lngStr.isEmpty) {
      AppNotification.show(
        context,
        message: 'Debes seleccionar el centro de la zona en el mapa',
        isError: true,
      );
      return;
    }

    final data = {
      'nombre_zona': _nombreController.text.trim(),
      'latitud': double.tryParse(latStr),
      'longitud': double.tryParse(lngStr),
      'radio_metros': double.tryParse(radioStr),
      'descripcion': _descripcionController.text.isNotEmpty
          ? _descripcionController.text
          : null,
    };

    Navigator.pop(context, data);
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/app_theme.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/map_controls.dart';
import '../models/developer_map_point.dart';
import '../models/map_analysis_point.dart';

class DeveloperMapScreen extends StatefulWidget {
  const DeveloperMapScreen({super.key});

  @override
  State<DeveloperMapScreen> createState() => _DeveloperMapScreenState();
}

class _DeveloperMapScreenState extends State<DeveloperMapScreen> {
  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  final ValueNotifier<double> _zoomNotifier = ValueNotifier<double>(14);

  final List<DeveloperMapPoint> _devPoints = [];
  DeveloperMapZone? _selectedZone;

  LatLng? _pendingLatLng;
  DevMapQuality _pendingQuality = DevMapQuality.healthy;
  DevAirQuality _pendingAirQuality = DevAirQuality.good;
  DevContamination _pendingContamination = DevContamination.low;
  double _pendingConfidence = 80.0;

  bool _locationPermissionGranted = false;
  bool _locationServiceEnabled = false;
  String? _locationStatusMessage;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _serviceCheckTimer;
  bool _showEnvironmentalMarkers = true;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _serviceCheckTimer?.cancel();
    _zoomNotifier.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _locationServiceEnabled = false;
          _locationPermissionGranted = false;
          _locationStatusMessage =
              'El GPS está apagado. Actívalo para mostrar tu ubicación.';
        });
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _locationPermissionGranted = false;
            _locationStatusMessage =
                'Permiso de ubicación denegado. Puedes activarlo desde los ajustes.';
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _locationPermissionGranted = false;
          _locationStatusMessage =
              'Permiso de ubicación bloqueado permanentemente. Ve a ajustes para activarlo.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _locationPermissionGranted = true;
        _locationServiceEnabled = true;
        _locationStatusMessage = null;
      });
    }
    await _startLocationUpdates();
  }

  Future<void> _startLocationUpdates() async {
    await _positionStreamSubscription?.cancel();
    _serviceCheckTimer?.cancel();

    if (!_locationPermissionGranted || !_locationServiceEnabled) {
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      if (mounted) {
        setState(() => _currentPosition = position);
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            16,
          ),
        );
        _zoomNotifier.value = 16;
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationServiceEnabled = false;
          _locationPermissionGranted = false;
          _locationStatusMessage =
              'El GPS está apagado. Actívalo para mostrar tu ubicación.';
        });
      }
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    ).listen(
      (position) {
        if (mounted) {
          setState(() => _currentPosition = position);
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _locationServiceEnabled = false;
            _locationPermissionGranted = false;
            _locationStatusMessage =
                'El GPS está apagado. Actívalo para mostrar tu ubicación.';
          });
        }
      },
    );

    _serviceCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (mounted && !serviceEnabled && _locationServiceEnabled) {
        setState(() {
          _locationServiceEnabled = false;
          _locationPermissionGranted = false;
          _locationStatusMessage =
              'El GPS está apagado. Actívalo para mostrar tu ubicación.';
        });
      } else if (mounted && serviceEnabled && !_locationServiceEnabled) {
        setState(() {
          _locationServiceEnabled = true;
          _locationStatusMessage = null;
        });
        await _requestLocationPermission();
      }
    });
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) await _requestLocationPermission();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _animateToInitialPosition();
  }

  void _animateToInitialPosition() {
    if (!mounted || _mapController == null) return;
    final target = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(4.7110, -74.0721);
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: 14,
          tilt: 55,
          bearing: 0,
        ),
      ),
    );
    _zoomNotifier.value = 14;
  }

  void _centerOnSelected() {
    if (_selectedZone == null || _mapController == null || !mounted) return;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _selectedZone!.center,
          zoom: 17,
          tilt: 55,
          bearing: 0,
        ),
      ),
    );
    _zoomNotifier.value = 17;
  }

  void _zoomIn() {
    if (_mapController == null || !mounted) return;
    _mapController!.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    if (_mapController == null || !mounted) return;
    _mapController!.animateCamera(CameraUpdate.zoomOut());
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.normal ? MapType.satellite : MapType.normal;
    });
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _pendingLatLng = latLng;
      _pendingQuality = DevMapQuality.healthy;
      _pendingAirQuality = DevAirQuality.good;
      _pendingContamination = DevContamination.low;
      _pendingConfidence = 80.0;
      _selectedZone = null;
    });
  }

  void _onZoneTap(DeveloperMapZone zone) {
    setState(() {
      _selectedZone = zone;
      _pendingLatLng = null;
    });
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: zone.center,
          zoom: 17,
          tilt: 55,
          bearing: 0,
        ),
      ),
    );
    _zoomNotifier.value = 17;
  }

  void _savePendingPoint() {
    if (_pendingLatLng == null) return;
    setState(() {
      _devPoints.add(DeveloperMapPoint(
        latitude: _pendingLatLng!.latitude,
        longitude: _pendingLatLng!.longitude,
        quality: _pendingQuality,
        airQuality: _pendingAirQuality,
        contamination: _pendingContamination,
        confidence: _pendingConfidence,
        createdAt: DateTime.now(),
      ));
      _pendingLatLng = null;
    });
  }

  void _cancelPendingPoint() {
    setState(() {
      _pendingLatLng = null;
    });
  }

  AirQualityLevel _getLevelForQuality(DevMapQuality quality) {
    switch (quality) {
      case DevMapQuality.healthy:
        return AirQualityLevel.good;
      case DevMapQuality.contaminated:
        return AirQualityLevel.poor;
    }
  }

  AirQualityLevel _getLevelForZone(DeveloperMapZone zone) {
    switch (zone.zoneType) {
      case DevMapZoneType.healthy:
        return AirQualityLevel.good;
      case DevMapZoneType.contaminated:
        return AirQualityLevel.poor;
      case DevMapZoneType.transition:
        return AirQualityLevel.moderate;
    }
  }

  AirQualityLevel _calculateVisualQuality(List<DeveloperMapPoint> points) {
    if (points.isEmpty) return AirQualityLevel.moderate;
    final hasHealthy = points.any((p) => p.quality == DevMapQuality.healthy);
    final hasContaminated = points.any((p) => p.quality == DevMapQuality.contaminated);
    if (hasHealthy && hasContaminated) return AirQualityLevel.moderate;
    if (hasHealthy) return AirQualityLevel.good;
    if (hasContaminated) return AirQualityLevel.poor;
    return AirQualityLevel.moderate;
  }

  double _hueForLevel(AirQualityLevel level) {
    switch (level) {
      case AirQualityLevel.good:
        return BitmapDescriptor.hueGreen;
      case AirQualityLevel.moderate:
        return BitmapDescriptor.hueYellow;
      case AirQualityLevel.poor:
        return BitmapDescriptor.hueRed;
    }
  }

  Color _statusColor(AirQualityLevel level) {
    switch (level) {
      case AirQualityLevel.good:
        return AppTheme.successColor;
      case AirQualityLevel.moderate:
        return AppTheme.warningColor;
      case AirQualityLevel.poor:
        return AppTheme.errorColor;
    }
  }

  String _zoneStatusLabel(DeveloperMapZone zone) {
    switch (zone.zoneType) {
      case DevMapZoneType.healthy:
        return 'Saludable';
      case DevMapZoneType.contaminated:
        return 'Contaminado';
      case DevMapZoneType.transition:
        return 'Transición';
    }
  }

  String _qualityLabel(DevMapQuality quality) {
    switch (quality) {
      case DevMapQuality.healthy:
        return 'Saludable';
      case DevMapQuality.contaminated:
        return 'Contaminado';
    }
  }

  String _airQualityLabel(DevAirQuality air) {
    switch (air) {
      case DevAirQuality.good:
        return 'Buena';
      case DevAirQuality.moderate:
        return 'Moderada';
      case DevAirQuality.bad:
        return 'Mala';
    }
  }

  String _contaminationLabel(DevContamination contamination) {
    switch (contamination) {
      case DevContamination.low:
        return 'Baja';
      case DevContamination.medium:
        return 'Media';
      case DevContamination.high:
        return 'Alta';
    }
  }

  Set<Marker> _buildMarkers() {
    if (!_showEnvironmentalMarkers) return const {};
    final zones = calculateZones(_devPoints);
    return zones.map((zone) {
      final level = _getLevelForZone(zone);

      return Marker(
        markerId: MarkerId('dev_zone_${zone.id}'),
        position: zone.center,
        icon: BitmapDescriptor.defaultMarkerWithHue(_hueForLevel(level)),
        infoWindow: InfoWindow(
          title: zone.label,
          snippet: zone.interpretation,
        ),
        onTap: () => _onZoneTap(zone),
      );
    }).toSet();
  }

  Set<Circle> _buildCircles() {
    final zones = calculateZones(_devPoints);
    final Set<Circle> circles = {};
    for (final zone in zones) {
      final level = _getLevelForZone(zone);
      Color fill;
      Color stroke;
      switch (level) {
        case AirQualityLevel.good:
          fill = AppTheme.successColor.withValues(alpha: 0.18);
          stroke = AppTheme.successColor.withValues(alpha: 0.5);
          break;
        case AirQualityLevel.moderate:
          fill = AppTheme.warningColor.withValues(alpha: 0.18);
          stroke = AppTheme.warningColor.withValues(alpha: 0.5);
          break;
        case AirQualityLevel.poor:
          fill = AppTheme.errorColor.withValues(alpha: 0.18);
          stroke = AppTheme.errorColor.withValues(alpha: 0.5);
          break;
      }
      circles.add(Circle(
        circleId: CircleId('dev_zone_${zone.id}'),
        center: zone.center,
        radius: zone.radius,
        fillColor: fill,
        strokeColor: stroke,
        strokeWidth: 2,
      ));
    }
    return circles;
  }

  @override
  Widget build(BuildContext context) {
    return LichenScaffold(
      showBottomNav: false,
      showParticleBackground: false,
      isFullScreen: true,
      body: !_locationServiceEnabled || !_locationPermissionGranted
          ? _buildLocationRequired()
          : _buildMapContent(),
    );
  }

  Widget _buildMapContent() {
    final selected = _selectedZone;
    final aggregateLevel = _calculateVisualQuality(_devPoints);
    final aggregateColor = _statusColor(aggregateLevel);
    final statusColor = selected != null
        ? _statusColor(_getLevelForZone(selected))
        : (_devPoints.isNotEmpty ? aggregateColor : AppTheme.primaryGreen);
    final zones = calculateZones(_devPoints);
    final hasTransition = zones.any((zone) => zone.zoneType == DevMapZoneType.transition);
    final hasHealthy = _devPoints.any((p) => p.quality == DevMapQuality.healthy);
    final aggregateText = hasTransition
        ? 'Transición'
        : (hasHealthy ? 'Saludable' : 'Contaminado');

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(4.7110, -74.0721),
              zoom: 14,
              tilt: 55,
              bearing: 0,
            ),
            mapType: _mapType,
            markers: _buildMarkers(),
            circles: _buildCircles(),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            onMapCreated: _onMapCreated,
            onCameraMove: (position) {
              _zoomNotifier.value = position.zoom;
            },
            onTap: _onMapTap,
          ),
          if (selected != null) _buildTopOverlay(selected, statusColor),
          if (selected == null && _devPoints.isNotEmpty)
            _buildAggregateOverlay(aggregateText, aggregateColor),
          _buildLegend(),
          _buildMapControls(),
          _buildBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildAggregateOverlay(String statusText, Color statusColor) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, -20 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ).animate().scale(
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Zona calculada',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$statusText · ${_devPoints.length} puntos',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
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

  Widget _buildTopOverlay(DeveloperMapZone zone, Color statusColor) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, -20 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ).animate().scale(
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      zone.label,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                     Text(
                       '${_zoneStatusLabel(zone)} · ${zone.points.length} análisis',
                       style: GoogleFonts.poppins(
                         fontSize: 12,
                         fontWeight: FontWeight.w500,
                         color: statusColor,
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

  Widget _buildLegend() {
    return Positioned(
      left: 16,
      bottom: 180,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 600),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _legendItem('🟢', 'Saludable'),
              const SizedBox(width: 8),
              _legendItem('🟡', 'Moderado'),
              const SizedBox(width: 8),
              _legendItem('🔴', 'Contaminado'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendItem(String emoji, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      right: 16,
      top: 16,
      child: Column(
        children: [
          MapControlButton(
            icon: Icons.my_location_rounded,
            onTap: () {
              _mapController?.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          )
                        : const LatLng(4.7110, -74.0721),
                    zoom: 16,
                    tilt: 55,
                    bearing: 0,
                  ),
                ),
              );
              _zoomNotifier.value = 16;
            },
            tooltip: 'Mi ubicación',
          ),
          const SizedBox(height: 8),
          MapZoomControls(
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
          ),
          const SizedBox(height: 8),
          MapControlButton(
            icon: _mapType == MapType.normal
                ? Icons.map_rounded
                : Icons.satellite_rounded,
            onTap: _toggleMapType,
            tooltip: 'Tipo de mapa',
            active: _mapType == MapType.satellite,
          ),
          const SizedBox(height: 8),
          MapControlButton(
            icon: _showEnvironmentalMarkers
                ? Icons.location_on_rounded
                : Icons.location_off_rounded,
            onTap: () {
              setState(() {
                _showEnvironmentalMarkers = !_showEnvironmentalMarkers;
              });
            },
            tooltip: _showEnvironmentalMarkers ? 'Ocultar puntos ambientales' : 'Mostrar puntos ambientales',
            active: _showEnvironmentalMarkers,
            iconColor: _showEnvironmentalMarkers ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          if (_selectedZone != null) ...[
            const SizedBox(height: 8),
            MapControlButton(
              icon: Icons.center_focus_strong_rounded,
              onTap: _centerOnSelected,
              tooltip: 'Centrar zona',
              iconColor: AppTheme.primaryGreen,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    if (_pendingLatLng != null) {
      return _buildAddPointSheet();
    }
    if (_selectedZone != null) {
      return _buildPointDetailsSheet(_selectedZone!);
    }
    return const SizedBox.shrink();
  }

  Widget _buildAddPointSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.32,
      minChildSize: 0.24,
      maxChildSize: 0.48,
      snap: true,
      snapSizes: const [0.24, 0.32, 0.48],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
            children: [
              _buildSheetHandle(),
              const SizedBox(height: 8),
              Text(
                'Nuevo punto',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _buildRadioSection(
                title: 'Tipo',
                options: const [
                  {'value': DevMapQuality.healthy, 'label': 'Saludable'},
                  {'value': DevMapQuality.contaminated, 'label': 'Contaminado'},
                ],
                groupValue: _pendingQuality,
                onChanged: (v) {
                  setState(() {
                    _pendingQuality = v!;
                    if (v == DevMapQuality.healthy) {
                      _pendingAirQuality = DevAirQuality.good;
                      _pendingContamination = DevContamination.low;
                    } else {
                      _pendingAirQuality = DevAirQuality.bad;
                      _pendingContamination = DevContamination.high;
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Resumen automático',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildPreviewRow(
                'Calidad del aire',
                _pendingAirQuality == DevAirQuality.good ? 'Buena' : 'Mala',
                _pendingAirQuality == DevAirQuality.good ? Icons.air_rounded : Icons.air_rounded,
                _pendingAirQuality == DevAirQuality.good ? AppTheme.successColor : AppTheme.errorColor,
              ),
              const SizedBox(height: 6),
              _buildPreviewRow(
                'Contaminación',
                _pendingContamination == DevContamination.low ? 'Baja' : 'Alta',
                Icons.water_damage_rounded,
                _pendingContamination == DevContamination.low ? AppTheme.successColor : AppTheme.errorColor,
              ),
              const SizedBox(height: 6),
              _buildPreviewRow(
                'Resultado visual',
                _pendingQuality == DevMapQuality.healthy ? 'Verde' : 'Rojo',
                Icons.circle_rounded,
                _pendingQuality == DevMapQuality.healthy ? AppTheme.successColor : AppTheme.errorColor,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Confianza',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${_pendingConfidence.toInt()}%',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _pendingConfidence,
                min: 0,
                max: 100,
                divisions: 100,
                activeColor: AppTheme.primaryGreen,
                inactiveColor: AppTheme.borderColor,
                label: '${_pendingConfidence.toInt()}%',
                onChanged: (v) => setState(() => _pendingConfidence = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cancelPendingPoint,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(
                        'Cancelar',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                        side: const BorderSide(color: AppTheme.borderColor, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _savePendingPoint,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        'Guardar',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreviewRow(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioSection({
    required String title,
    required List<Map<String, dynamic>> options,
    required dynamic groupValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            final value = opt['value'];
            final label = opt['label'] as String;
            final isSelected = groupValue == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryGreen.withValues(alpha: 0.12)
                        : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : AppTheme.borderColor.withValues(alpha: 0.4),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: isSelected ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPointDetailsSheet(DeveloperMapZone zone) {
    final level = _getLevelForZone(zone);
    final statusColor = _statusColor(level);

    return DraggableScrollableSheet(
      initialChildSize: 0.18,
      minChildSize: 0.14,
      maxChildSize: 0.55,
      snap: true,
      snapSizes: const [0.18, 0.42, 0.55],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
            children: [
              _buildSheetHandle(),
              const SizedBox(height: 8),
              _buildSheetHeader(zone, statusColor),
              const SizedBox(height: 12),
              _buildSheetDetails(zone, statusColor),
              const SizedBox(height: 14),
              _buildSheetActions(zone),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.borderColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildSheetHeader(DeveloperMapZone zone, Color statusColor) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.eco_rounded,
            color: statusColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                zone.label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_zoneStatusLabel(zone)} · ${zone.points.length} análisis',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${(zone.points.map((p) => p.confidence).reduce((a, b) => a + b) / zone.points.length * 100).toInt()}%',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSheetDetails(DeveloperMapZone zone, Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _detailChip(
                icon: Icons.verified_rounded,
                label: 'Resultado',
                value: _zoneStatusLabel(zone),
                color: statusColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _detailChip(
                icon: Icons.map_rounded,
                label: 'Registros',
                value: '${zone.points.length}',
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_rounded, size: 16, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  zone.interpretation,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (zone.zoneType == DevMapZoneType.transition) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, size: 16, color: AppTheme.warningColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Zona de transición por superposición de círculos de observación',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        ...zone.points.map((point) {
          final pointLevel = _getLevelForQuality(point.quality);
          final pointColor = _statusColor(pointLevel);
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.circle_rounded, size: 12, color: pointColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_qualityLabel(point.quality)} · ${_airQualityLabel(point.airQuality)} · ${_contaminationLabel(point.contamination)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${(point.confidence * 100).toInt()}%',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.developer_mode_rounded,
                  size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Punto de prueba (sandbox)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Punto simulado para pruebas visuales. '
          'No afecta la base de datos real.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _detailChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetActions(DeveloperMapZone zone) {
    return Row(
      children: [
        if (zone.zoneType != DevMapZoneType.transition)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  for (final point in zone.points) {
                    _devPoints.remove(point);
                  }
                  _selectedZone = null;
                });
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(
                'Eliminar punto',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (zone.zoneType != DevMapZoneType.transition)
          const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              setState(() => _selectedZone = null);
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(
              'Cerrar',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gps_off_rounded,
                size: 40,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ubicación requerida',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _locationStatusMessage ??
                  'Activa la ubicación de tu dispositivo para ver el mapa ambiental.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _requestLocationPermission,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: Text(
                'Reintentar',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _openLocationSettings,
              icon: Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
              label: Text(
                'Abrir ajustes de ubicación',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

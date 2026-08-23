import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../routes/route_names.dart';
import '../widgets/app_theme.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/map_controls.dart';
import '../services/api_service.dart';
import '../state/map_state.dart';
import '../state/auth_state.dart';
import '../models/map_analysis_point.dart';
import '../models/environmental_zone.dart';

class MapExplorerScreen extends StatefulWidget {
  final int pointId;

  const MapExplorerScreen({super.key, required this.pointId});

  @override
  State<MapExplorerScreen> createState() => _MapExplorerScreenState();
}

class _MapExplorerScreenState extends State<MapExplorerScreen> {
  MapAnalysisPoint? _selectedPoint;
  EnvironmentalZone? _selectedZone;
  GoogleMapController? _mapController;
  bool _locationPermissionGranted = false;
  bool _locationServiceEnabled = false;
  String? _locationStatusMessage;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _serviceCheckTimer;
  MapType _mapType = MapType.normal;
  final ValueNotifier<double> _zoomNotifier = ValueNotifier<double>(15);
  bool _showOwn = true;
  bool _showCommunity = true;
  bool _showZones = true;
  bool _showCircles = true;

  static const Color moderateYellow = Color(0xFFFFC107);

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = context.read<AuthState>();
      final mapState = context.read<MapState>();
      mapState.updateUserId(authState.userId);
      if (!mapState.loading && mapState.points.isEmpty) {
        mapState.loadPoints();
      }
      if (widget.pointId != 0) {
        _selectPointById(widget.pointId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant MapExplorerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pointId != widget.pointId && widget.pointId != 0) {
      _selectPointById(widget.pointId);
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _serviceCheckTimer?.cancel();
    _zoomNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _selectPointById(int pointId) async {
    final mapState = context.read<MapState>();
    final targetPoint = mapState.points.where((p) => p.id == pointId).toList();
    final point = targetPoint.isNotEmpty ? targetPoint.first : null;
    if (point != null && _selectedPoint?.id != point.id) {
      if (!mounted) return;
      setState(() {
        _selectedPoint = point;
        _selectedZone = null;
      });
      _animateToSelectedPoint();
    }
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

  Future<void> _shareAnalysis(MapAnalysisPoint point) async {
    debugPrint('=== SHARE ANALYSIS START ===');
    debugPrint('pointId: ${point.id}');
    debugPrint('lat: ${point.lat}, lng: ${point.lng}');
    debugPrint('zoneName: ${point.zoneName}');
    debugPrint('species: ${point.species}');
    debugPrint('airQuality: ${point.airQuality}');
    debugPrint('status: ${point.status}');
    debugPrint('analyses length: ${point.analyses.length}');

    final apiService = Provider.of<ApiService>(context, listen: false);
    final analysisId = point.id;

    if (analysisId == 0) {
      debugPrint('SHARE ERROR: analysisId inválido');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este análisis no se puede compartir: id inválido.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (point.lat == 0 && point.lng == 0) {
      debugPrint('SHARE ERROR: sin ubicación válida');
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

    debugPrint('SHARE: calling API /analysis/$analysisId/share');
    try {
      await apiService.shareAnalysis(analysisId);
      debugPrint('SHARE SUCCESS: API respondió OK');
      if (!mounted) return;
      final mapState = context.read<MapState>();
      await mapState.loadPoints();
      debugPrint('SHARE: puntos recargados desde backend');
      final refreshedPoint = mapState.points.firstWhere((p) => p.id == analysisId, orElse: () => point);
      debugPrint('SHARE: punto refrescado status=${refreshedPoint.status}, isShared=${refreshedPoint.isShared}');
      if (!mounted) return;
      setState(() {
        _selectedPoint = refreshedPoint;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compartido en mapa'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e, stack) {
      debugPrint('SHARE ERROR: $e');
      debugPrint('SHARE STACK: $stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al compartir: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (mounted) {
      _animateToSelectedPoint();
    }
    debugPrint('MAP EXPLORER: mapa creado, zoom=${_zoomNotifier.value}');
  }

  void _animateToSelectedPoint() {
    if (!mounted || _mapController == null) return;
    final target = _selectedPoint?.latLng ??
        (_currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : const LatLng(4.7110, -74.0721));
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: 16,
          tilt: 50,
          bearing: 0,
        ),
      ),
    );
    _zoomNotifier.value = 16;
  }

  void _centerOnSelected() {
    if (!mounted || _mapController == null) return;
    if (_selectedZone != null) {
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
    } else if (_selectedPoint != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _selectedPoint!.latLng,
            zoom: 17,
            tilt: 55,
            bearing: 0,
          ),
        ),
      );
      _zoomNotifier.value = 17;
    }
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _selectedPoint = null;
      _selectedZone = null;
    });
  }

  void _onZoneTap(EnvironmentalZone zone) {
    setState(() {
      _selectedZone = zone;
      _selectedPoint = null;
    });
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: zone.center,
          zoom: 16,
          tilt: 55,
          bearing: 0,
        ),
      ),
    );
    _zoomNotifier.value = 16;
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  void _zoomIn() {
    if (_mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.zoomIn(),
    );
  }

  void _zoomOut() {
    if (_mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.zoomOut(),
    );
  }

  Set<Marker> _buildMarkers(List<MapAnalysisPoint> points, List<EnvironmentalZone> zones, MapState mapState) {
    final Set<Marker> markers = {};
    final Set<int> seenIds = {};

    for (final point in points) {
      if (seenIds.contains(point.id)) continue;
      seenIds.add(point.id);

      final role = _markerRole(point, mapState);
      markers.add(_buildAnalysisMarker(point, role: role));
    }

    for (final zone in zones) {
      final isSelected = _selectedZone?.id == zone.id;

      markers.add(Marker(
        markerId: MarkerId('env_zone_marker_${zone.id}'),
        position: zone.center,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected ? BitmapDescriptor.hueAzure : zone.type.hue,
        ),
        infoWindow: InfoWindow(
          title: zone.label,
          snippet: '${zone.points.length} análisis · ${zone.type.label}',
        ),
        onTap: () => _onZoneTap(zone),
      ));
    }

    return markers;
  }

  String _markerRole(MapAnalysisPoint point, MapState mapState) {
    final isOwn = point.idUsuario == mapState.userId;
    if (isOwn) {
      return point.isShared ? 'own-published' : 'own-private';
    }
    return point.isShared ? 'community' : 'own-private';
  }

  Marker _buildAnalysisMarker(MapAnalysisPoint point, {required String role}) {
    final level = point.visualQualityLevel;
    final hue = level.hue;

    return Marker(
      markerId: MarkerId('analysis_${point.id}'),
      position: point.markerLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      infoWindow: InfoWindow(
        title: point.zoneName,
        snippet: '${point.species} - ${point.airQuality}',
      ),
      onTap: () => _onPointTap(point),
    );
  }

  void _onPointTap(MapAnalysisPoint point) {
    setState(() {
      _selectedPoint = point;
      _selectedZone = null;
    });
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: point.latLng,
          zoom: 17,
          tilt: 55,
          bearing: 0,
        ),
      ),
    );
    _zoomNotifier.value = 17;
    debugPrint('MAP EXPLORER: punto tocado id=${point.id}, zoom aplicado=17');
  }

  @override
  Widget build(BuildContext context) {
    final mapState = context.watch<MapState>();

    return LichenScaffold(
      showBottomNav: false,
      showParticleBackground: false,
      isFullScreen: true,
      body: mapState.loading
          ? const Center(child: CircularProgressIndicator())
          : mapState.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No fue posible cargar el mapa',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Verifica tu conexión e intenta nuevamente',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textGray,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: mapState.loadPoints,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : !_locationServiceEnabled || !_locationPermissionGranted
                  ? _buildLocationRequired()
                  : _buildMapContent(mapState),
    );
  }

  Widget _buildMapContent(MapState mapState) {
    final points = _visiblePoints(mapState);
    final zones = _showZones ? calculateEnvironmentalZones(points) : <EnvironmentalZone>[];
    final selected = _selectedPoint;
    final selectedZone = _selectedZone;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: selectedZone != null
                  ? selectedZone.center
                  : (selected != null
                      ? selected.latLng
                      : (_currentPosition != null
                          ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                          : const LatLng(4.7110, -74.0721))),
              zoom: selectedZone != null || selected != null ? 16 : MapAnalysisPoint.defaultMapZoom,
              tilt: 55,
              bearing: 0,
            ),
            mapType: _mapType,
            markers: _buildMarkers(points, zones, mapState),
            circles: {..._buildZoneCircles(zones), if (_showCircles) ..._buildIndividualCircles(points)},
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomGesturesEnabled: true,
            zoomControlsEnabled: false,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            onMapCreated: _onMapCreated,
            onCameraMove: (position) {
              _zoomNotifier.value = position.zoom;
            },
            onTap: _onMapTap,
          ),
          if (selectedZone != null)
            _buildZoneTopOverlay(selectedZone),
          if (selected == null && selectedZone == null && points.isNotEmpty && _showZones)
            _buildAggregateOverlay(points, zones),
          if (selected != null && selectedZone == null)
            _buildPointTopOverlay(selected, selected.visualQualityLevel.statusColor),
          _buildLegend(),
          _buildMapControls(),
          _buildBottomSheet(),
        ],
      ),
    );
  }

  List<MapAnalysisPoint> _visiblePoints(MapState mapState) {
    final result = <MapAnalysisPoint>[];
    final seenIds = <int>{};
    void addPoints(List<MapAnalysisPoint> source) {
      for (final point in source) {
        if (!seenIds.contains(point.id)) {
          seenIds.add(point.id);
          result.add(point);
        }
      }
    }

    if (_showOwn) addPoints(mapState.ownPoints);
    if (_showCommunity) addPoints(mapState.sharedPoints);
    return result;
  }

  Set<Circle> _buildZoneCircles(List<EnvironmentalZone> zones) {
    final Set<Circle> circles = {};
    for (final zone in zones) {
      circles.add(zone.toCircle());
    }
    return circles;
  }

  Set<Circle> _buildIndividualCircles(List<MapAnalysisPoint> points) {
    final Set<Circle> circles = {};
    for (final point in points) {
      final level = point.visualQualityLevel;
      if (level == AirQualityLevel.moderate) continue;
      final circle = point.toEnvironmentalCircle();
      circles.add(circle);
    }
    return circles;
  }

  Widget _buildPointTopOverlay(MapAnalysisPoint point, Color statusColor) {
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
            color: AppTheme.surfaceColor.withValues(alpha: 0.92),
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
                      point.zoneName,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                     Text(
                        '${point.statusLabel} · ${_formatDate(point.date)}',
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

  Widget _buildAggregateOverlay(List<MapAnalysisPoint> points, List<EnvironmentalZone> zones) {
    final hasTransition = zones.any((z) => z.type == EnvironmentalZoneType.transition);
    final hasHealthy = points.any((p) => p.visualQualityLevel == AirQualityLevel.good);
    final hasContaminated = points.any((p) => p.visualQualityLevel == AirQualityLevel.poor);

    if (!hasTransition && !(hasHealthy && hasContaminated)) return const SizedBox.shrink();

    final aggregateText = hasTransition ? 'Transición' : 'Mixta';
    final aggregateColor = hasTransition ? moderateYellow : moderateYellow;

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
            color: AppTheme.surfaceColor.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: aggregateColor.withValues(alpha: 0.35),
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
                  color: aggregateColor,
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
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$aggregateText · ${points.length} observaciones',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: aggregateColor,
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

  Widget _buildZoneTopOverlay(EnvironmentalZone zone) {
    final statusColor = zone.qualityLevel.statusColor;
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
            color: AppTheme.surfaceColor.withValues(alpha: 0.92),
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
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${zone.type.label} · ${zone.points.length} análisis',
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

  Widget _buildLayerControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
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
          _layerToggle('Mis análisis', _showOwn, AppTheme.primaryGreen, (value) {
            setState(() => _showOwn = value);
          }),
          const SizedBox(width: 8),
          _layerToggle('Comunidad', _showCommunity, AppTheme.errorColor, (value) {
            setState(() => _showCommunity = value);
          }),
          const SizedBox(width: 8),
          _layerToggle('Zonas', _showZones, moderateYellow, (value) {
            setState(() => _showZones = value);
          }),
        ],
      ),
    );
  }

  Widget _layerToggle(String label, bool active, Color color, ValueChanged<bool> onChanged, {IconData? icon}) {
    return GestureDetector(
      onTap: () => onChanged(!active),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : AppTheme.backgroundColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.6) : AppTheme.borderColor.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? (active ? Icons.visibility_rounded : Icons.visibility_off_rounded),
              size: 14,
              color: active ? color : AppTheme.textGray,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? color : AppTheme.textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      left: 16,
      bottom: 16,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLayerControls(),
            const SizedBox(height: 8),
            Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
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
              _legendItem(AppTheme.successColor, 'Saludable'),
              const SizedBox(width: 10),
              _legendItem(moderateYellow, 'Moderado'),
              const SizedBox(width: 10),
              _legendItem(AppTheme.errorColor, 'Contaminado'),
             ],
           ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
                spreadRadius: 0.5,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
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
                        : (_selectedPoint?.latLng ??
                            const LatLng(4.7110, -74.0721)),
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
          MapControlButton(
            icon: _mapType == MapType.normal
                ? Icons.map_rounded
                : Icons.satellite_rounded,
            onTap: _toggleMapType,
            tooltip: 'Tipo de mapa',
            active: _mapType == MapType.satellite,
          ),
          const SizedBox(height: 8),
          MapZoomControls(
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
          ),
          if (_selectedPoint != null || _selectedZone != null) ...[
            const SizedBox(height: 8),
            MapControlButton(
              icon: Icons.close_rounded,
              onTap: () {
                setState(() {
                  _selectedPoint = null;
                  _selectedZone = null;
                });
              },
              tooltip: 'Limpiar selección',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    if (_selectedZone != null) {
      return _buildZoneDetailsSheet(_selectedZone!);
    }
    if (_selectedPoint != null) {
      return _buildPointDetailsSheet(_selectedPoint!);
    }
    return const SizedBox.shrink();
  }

  Widget _buildZoneDetailsSheet(EnvironmentalZone zone) {
    final statusColor = zone.qualityLevel.statusColor;

    return DraggableScrollableSheet(
      initialChildSize: 0.18,
      minChildSize: 0.14,
      maxChildSize: 0.55,
      snap: true,
      snapSizes: const [0.18, 0.42, 0.55],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.96),
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
              _buildZoneSheetHeader(zone, statusColor),
              const SizedBox(height: 12),
              _buildZoneSheetDetails(zone, statusColor),
              const SizedBox(height: 14),
              _buildZoneSheetActions(zone),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPointDetailsSheet(MapAnalysisPoint point) {
    final showUserInfo = point.usuario != null && point.visibilidad == 'shared';
    return DraggableScrollableSheet(
      initialChildSize: 0.18,
      minChildSize: 0.14,
      maxChildSize: 0.55,
      snap: true,
      snapSizes: const [0.18, 0.42, 0.55],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.96),
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
              _buildSheetHeader(point, showUserInfo: showUserInfo),
              const SizedBox(height: 12),
              _buildSheetDetails(point),
              const SizedBox(height: 14),
              _buildSheetActions(point),
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

  Widget _buildSheetHeader(MapAnalysisPoint point, {bool showUserInfo = false}) {
    final level = point.visualQualityLevel;
    final statusColor = level.statusColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showUserInfo && point.usuario != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                  backgroundImage: point.usuario!['foto_perfil'] != null && point.usuario!['foto_perfil'].toString().isNotEmpty
                      ? NetworkImage(point.usuario!['foto_perfil'].toString())
                      : null,
                  child: point.usuario!['foto_perfil'] == null || point.usuario!['foto_perfil'].toString().isEmpty
                      ? Icon(Icons.person_rounded, size: 16, color: AppTheme.primaryGreen)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    point.usuario!['nombre']?.toString() ?? 'Usuario',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        Row(
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
                    point.zoneName,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                   Text(
                      '${level.statusLabel} · ${point.species}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textGray,
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
                '${(point.confidence * 100).toInt()}%',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSheetDetails(MapAnalysisPoint point) {
    final level = point.visualQualityLevel;
    final statusColor = level.statusColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _detailChip(
                icon: Icons.verified_rounded,
                label: 'Resultado IA',
                value: level.statusLabel,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _detailChip(
                icon: Icons.biotech_rounded,
                label: 'Especie',
                value: point.species,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _detailChip(
                icon: Icons.air_rounded,
                label: 'Calidad aire',
                value: point.airQuality,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _detailChip(
                icon: Icons.water_damage_rounded,
                label: 'Contaminación',
                value: point.contaminationLevel ?? 'No registrada',
                color: statusColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _detailChip(
          icon: Icons.calendar_today_rounded,
          label: 'Fecha',
          value: _formatDateTime(point.date),
          color: AppTheme.textDark,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.psychology_rounded,
                  size: 16, color: AppTheme.textGray),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Explicación ambiental',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Análisis de bioindicadores basado en ${point.species}. '
           'El resultado sugiere una condición ${level.statusLabel.toLowerCase()} '
          'en la zona con una confianza del ${(point.confidence * 100).toInt()}%.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            height: 1.5,
            color: AppTheme.textGray,
          ),
        ),
      ],
    );
  }

  Widget _buildZoneSheetHeader(EnvironmentalZone zone, Color statusColor) {
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
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${zone.type.label} · ${zone.points.length} análisis',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textGray,
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
            '${(zone.avgConfidence * 100).toInt()}%',
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

  Widget _buildZoneSheetDetails(EnvironmentalZone zone, Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _detailChip(
                icon: Icons.verified_rounded,
                label: 'Resultado',
                value: zone.type.label,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _detailChip(
                icon: Icons.map_rounded,
                label: 'Registros',
                value: '${zone.points.length}',
                color: AppTheme.textDark,
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
                    color: AppTheme.textDark,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (zone.type == EnvironmentalZoneType.transition) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: moderateYellow.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: moderateYellow.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, size: 16, color: moderateYellow),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Zona de transición: coinciden observaciones saludables y afectadas.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: moderateYellow,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        ...zone.points.map((point) {
          final pointColor = point.visualQualityLevel.statusColor;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.circle_rounded, size: 12, color: pointColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${point.species} · ${point.airQuality}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                Text(
                  '${(point.confidence * 100).toInt()}%',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textGray,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildZoneSheetActions(EnvironmentalZone zone) {
    return Row(
      children: [
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

  Widget _detailChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withValues(alpha: 0.6),
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
                    color: AppTheme.textGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetActions(MapAnalysisPoint point) {
    debugPrint('SHEET ACTIONS: pointId=${point.id}, isShared=${point.isShared}, status=${point.status}');
    final isShared = point.isShared;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              if (isShared) {
                debugPrint('SHEET ACTIONS: navegando al mapa');
                Navigator.pushNamed(context, AppRoutes.mapa);
              } else {
                debugPrint('SHEET ACTIONS: iniciando compartir');
                _shareAnalysis(point);
              }
            },
            icon: Icon(
              isShared ? Icons.map_rounded : Icons.share_rounded,
              size: 18,
            ),
            label: Text(
              isShared ? 'Ver en mapa' : 'Compartir',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryGreen,
              side: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
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
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.mapa);
            },
            icon: const Icon(Icons.explore_rounded, size: 18),
            label: Text(
              'Explorar zona',
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
                color: AppTheme.textDark,
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
                color: AppTheme.textGray,
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
              icon: Icon(Icons.settings_rounded, color: AppTheme.textGray),
              label: Text(
                'Abrir ajustes de ubicación',
                style: GoogleFonts.poppins(
                  color: AppTheme.textGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} $hours:$minutes';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../routes/route_names.dart';
import '../widgets/app_theme.dart';
import '../widgets/lichen_scaffold.dart';
import '../services/navigation_service.dart';
import '../state/map_state.dart';
import '../state/auth_state.dart';
import '../models/map_analysis_point.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapAnalysisPoint? _selectedPoint;
  int? _expandedAnalysisId;
  int _selectedIndex = 2;
  GoogleMapController? _mapController;
  bool _locationPermissionGranted = false;
  bool _locationServiceEnabled = false;
  String? _locationStatusMessage;
  Set<Marker>? _cachedMarkers;
  String? _markersHash;
  Map<AirQualityLevel, bool> expandedGroups = {
    AirQualityLevel.good: true,
    AirQualityLevel.moderate: false,
    AirQualityLevel.poor: false,
  };
  bool _showMyAnalyses = true;
  bool _showCommunity = true;
  bool _showZones = true;
  Set<AirQualityLevel> _qualityFilters = {};
  Set<ContaminationLevel> _contaminationFilters = {};
  Set<ConfidenceLevel> _confidenceFilters = {};
  DateRange _dateRange = DateRange.all;
  String? _selectedFilterChip;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationServiceEnabled = false;
        _locationPermissionGranted = false;
        _locationStatusMessage = 'El GPS está apagado. Actívalo para mostrar tu ubicación.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationPermissionGranted = false;
          _locationStatusMessage = 'Permiso de ubicación denegado. Puedes activarlo desde los ajustes.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationPermissionGranted = false;
        _locationStatusMessage = 'Permiso de ubicación bloqueado permanentemente. Ve a ajustes para activarlo.';
      });
      return;
    }

    setState(() {
      _locationPermissionGranted = true;
      _locationServiceEnabled = true;
      _locationStatusMessage = null;
    });
  }

  @override
  void initState() {
    super.initState();
    LichenNavigation.instance.sync(2);
    _requestLocationPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = context.read<AuthState>();
      final mapState = context.read<MapState>();
      mapState.updateUserId(authState.userId);
      if (!mapState.loading && mapState.points.isEmpty) {
        mapState.loadPoints();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _onBottomNavTap(int index) {
    LichenNavigation.instance.navigateTo(index);
    setState(() => _selectedIndex = index);
    _navigateToSection(index);
  }

  void _navigateToSection(int index) {
    switch (index) {
      case 0:
        Navigator.pushNamed(context, AppRoutes.dashboard);
        break;
      case 1:
        Navigator.pushNamed(context, AppRoutes.analisis);
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.historial);
        break;
      case 4:
        Navigator.pushNamed(context, AppRoutes.perfil);
        break;
    }
  }

  Set<Marker> _buildMarkers(List<MapAnalysisPoint> points) {
    final hash = points.map((p) => '${p.id}:${p.qualityLevel.name}').join('|');
    if (_markersHash == hash && _cachedMarkers != null) {
      return _cachedMarkers!;
    }
    _markersHash = hash;
    return _cachedMarkers = points.map((point) {
      final level = point.qualityLevel;
      BitmapDescriptor hue;
      switch (level) {
        case AirQualityLevel.good:
          hue = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
          break;
        case AirQualityLevel.moderate:
          hue = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
          break;
        case AirQualityLevel.poor:
          hue = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
          break;
      }
      return Marker(
        markerId: MarkerId('analysis_${point.id}'),
        position: point.latLng,
        icon: hue,
        infoWindow: InfoWindow(
          title: point.zoneName,
          snippet: '${point.species} - ${point.airQuality}',
        ),
        onTap: () {
          setState(() {
            _selectedPoint = point;
          });
        },
      );
    }).toSet();
  }

  Color _qualityColor(AirQualityLevel level) {
    switch (level) {
      case AirQualityLevel.good:
        return AppTheme.successColor;
      case AirQualityLevel.moderate:
        return const Color(0xFFFFC107);
      case AirQualityLevel.poor:
        return AppTheme.errorColor;
    }
  }

  String _qualityLabel(AirQualityLevel level) {
    switch (level) {
      case AirQualityLevel.good:
        return 'Saludable';
      case AirQualityLevel.moderate:
        return 'Moderada';
      case AirQualityLevel.poor:
        return 'Contaminada';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildLegend() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemCount = AirQualityLevel.values.length;
        final spacing = 10.0;
        final availableWidth = constraints.maxWidth;
        final itemWidth = (availableWidth - spacing * (itemCount - 1)) / itemCount;

        return Row(
          children: AirQualityLevel.values.map((level) {
            final color = _qualityColor(level);

            return SizedBox(
              width: itemWidth,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _qualityLabel(level).toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildHeader(int pointCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mapa ambiental',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Explora observaciones de líquenes y patrones de calidad del aire',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.textGray,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            '$pointCount ${pointCount == 1 ? "análisis registrado" : "análisis registrados"}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
      ),
      child: _buildLegend(),
    );
  }

  Widget _buildMapCard(Set<Marker> markers, Set<Circle> circles, LatLng initialPosition, double zoom) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapHeight = (constraints.maxWidth * 0.52).clamp(300.0, 420.0);
        return SizedBox(
          height: mapHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialPosition,
                    zoom: zoom,
                  ),
                  markers: markers,
                  circles: circles,
                  myLocationEnabled: _locationPermissionGranted && _locationServiceEnabled,
                  myLocationButtonEnabled: _locationPermissionGranted && _locationServiceEnabled,
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    debugPrint('MAP SCREEN: mapa creado, zoom inicial=$zoom');
                  },
                  onTap: (_) {},
                ),
              ),
              if (_locationStatusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.borderColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppTheme.textGray,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _locationStatusMessage!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textGray,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInlineFilters() {
    final chips = <Widget>[
      _buildFilterChip(label: 'Todos', value: null),
      _buildFilterChip(label: 'Mis análisis', value: 'own'),
      _buildFilterChip(label: 'Comunidad', value: 'community'),
      _buildFilterChip(label: 'Saludable', value: 'good'),
      _buildFilterChip(label: 'Contaminado', value: 'poor'),
      _buildFilterChip(label: 'Transición', value: 'moderate'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips,
      ),
    );
  }

  Widget _buildFilterChip({required String label, required String? value}) {
    final isActive = _selectedFilterChip == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            if (_selectedFilterChip == value) {
              _selectedFilterChip = null;
            } else {
              _selectedFilterChip = value;
            }
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryGreen.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? AppTheme.primaryGreen : AppTheme.textGray,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisPanel(String title, List<MapAnalysisPoint> points, bool showEmptyState, {bool showUserInfo = false}) {
    if (showEmptyState) return _buildEmptyState();

    final groups = <AirQualityLevel, List<MapAnalysisPoint>>{
      AirQualityLevel.good: [],
      AirQualityLevel.moderate: [],
      AirQualityLevel.poor: [],
    };
    for (final point in points) {
      groups[point.qualityLevel]!.add(point);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Análisis realizados en diferentes ubicaciones',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppTheme.textGray,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        ...groups.entries.map((entry) {
          final level = entry.key;
          final groupPoints = entry.value;
          if (groupPoints.isEmpty) return const SizedBox.shrink();
          return _QualityGroup(
            level: level,
            points: groupPoints,
            isExpanded: expandedGroups[level] ?? false,
            onToggle: () {
              setState(() {
                expandedGroups[level] = !(expandedGroups[level] ?? false);
              });
            },
            selectedPoint: _selectedPoint,
            expandedAnalysisId: _expandedAnalysisId,
            onCardTap: (point) {
              setState(() {
                _selectedPoint = point;
                _expandedAnalysisId = point.id;
                expandedGroups[point.qualityLevel] = true;
              });
              if (point.lat.isFinite && point.lng.isFinite) {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: point.latLng,
                      zoom: 18,
                      tilt: 55,
                      bearing: 0,
                    ),
                  ),
                );
              } else {
                debugPrint('MAP SCREEN: punto sin coordenadas válidas id=${point.id}');
              }
            },
            formatDate: _formatDate,
            qualityColor: _qualityColor(level),
            showUserInfo: showUserInfo,
          );
        }),
        if (_selectedPoint != null)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedPoint = null;
                  _expandedAnalysisId = null;
                });
              },
              icon: Icon(Icons.close_rounded, size: 18, color: AppTheme.textGray),
              label: Text(
                'Limpiar selección',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textGray,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
      child: Column(
        children: [
          Icon(
            Icons.eco_rounded,
            size: 40,
            color: AppTheme.textGray.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin análisis publicados',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Los análisis aparecerán aquí cuando los usuarios decidan compartirlos en el mapa ambiental.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<MapAnalysisPoint> _getFilteredOwnPoints(MapState mapState) {
    var points = List<MapAnalysisPoint>.from(mapState.ownPoints);
    points = mapState.applyAdvancedFilters(
      points,
      qualityLevels: _qualityFilters.isEmpty ? null : _qualityFilters,
      contaminationLevels: _contaminationFilters.isEmpty ? null : _contaminationFilters,
      confidenceLevels: _confidenceFilters.isEmpty ? null : _confidenceFilters,
      dateRange: _dateRange,
    );
    if (_selectedFilterChip != null && _selectedFilterChip != 'own' && _selectedFilterChip != 'community') {
      final qualityMap = {'good': AirQualityLevel.good, 'moderate': AirQualityLevel.moderate, 'poor': AirQualityLevel.poor};
      final level = qualityMap[_selectedFilterChip];
      if (level != null) {
        points = points.where((p) => p.qualityLevel == level).toList();
      }
    }
    return points;
  }

  List<MapAnalysisPoint> _getFilteredCommunityPoints(MapState mapState) {
    var points = List<MapAnalysisPoint>.from(mapState.communityPoints);
    points = mapState.applyAdvancedFilters(
      points,
      qualityLevels: _qualityFilters.isEmpty ? null : _qualityFilters,
      contaminationLevels: _contaminationFilters.isEmpty ? null : _contaminationFilters,
      confidenceLevels: _confidenceFilters.isEmpty ? null : _confidenceFilters,
      dateRange: _dateRange,
    );
    if (_selectedFilterChip != null && _selectedFilterChip != 'own' && _selectedFilterChip != 'community') {
      final qualityMap = {'good': AirQualityLevel.good, 'moderate': AirQualityLevel.moderate, 'poor': AirQualityLevel.poor};
      final level = qualityMap[_selectedFilterChip];
      if (level != null) {
        points = points.where((p) => p.qualityLevel == level).toList();
      }
    }
    return points;
  }

  List<MapAnalysisPoint> _getOriginPoints(MapState mapState) {
    switch (_selectedFilterChip) {
      case 'own':
        return List<MapAnalysisPoint>.from(mapState.ownPoints);
      case 'community':
        return List<MapAnalysisPoint>.from(mapState.communityPoints);
      case 'good':
      case 'moderate':
      case 'poor':
        final qualityMap = {'good': AirQualityLevel.good, 'moderate': AirQualityLevel.moderate, 'poor': AirQualityLevel.poor};
        final level = qualityMap[_selectedFilterChip];
        final allPoints = [...mapState.ownPoints, ...mapState.communityPoints];
        if (level != null) {
          return allPoints.where((p) => p.qualityLevel == level).toList();
        }
        return allPoints;
      case null:
        final result = <MapAnalysisPoint>[];
        if (_showMyAnalyses) result.addAll(mapState.ownPoints);
        if (_showCommunity) result.addAll(mapState.communityPoints);
        return result;
    }
    final result = <MapAnalysisPoint>[];
    if (_showMyAnalyses) result.addAll(mapState.ownPoints);
    if (_showCommunity) result.addAll(mapState.communityPoints);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final mapState = context.watch<MapState>();

    if (mapState.loading && mapState.points.isEmpty) {
      return LichenScaffold(
        showBottomNav: true,
        bottomNavIndex: _selectedIndex,
        onBottomNavTap: _onBottomNavTap,
        showParticleBackground: false,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(40.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (mapState.error != null && mapState.points.isEmpty) {
      return LichenScaffold(
        showBottomNav: true,
        bottomNavIndex: _selectedIndex,
        onBottomNavTap: _onBottomNavTap,
        showParticleBackground: false,
        body: Center(
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
        ),
      );
    }

    final originPoints = _getOriginPoints(mapState);
    final filteredPoints = mapState.applyAdvancedFilters(
      originPoints,
      qualityLevels: _qualityFilters.isEmpty ? null : _qualityFilters,
      contaminationLevels: _contaminationFilters.isEmpty ? null : _contaminationFilters,
      confidenceLevels: _confidenceFilters.isEmpty ? null : _confidenceFilters,
      dateRange: _dateRange,
    );
    final ownPoints = _getFilteredOwnPoints(mapState);
    final communityPoints = _getFilteredCommunityPoints(mapState);
    final markers = _buildMarkers(filteredPoints);
    final circles = mapState.filteredCircles(showZones: _showZones, showOwn: _showMyAnalyses, showCommunity: _showCommunity);
    final initialPosition = _selectedPoint != null
        ? _selectedPoint!.latLng
        : const LatLng(4.7110, -74.0721);
    final initialZoom = _selectedPoint != null ? 16.0 : MapAnalysisPoint.defaultMapZoom;

    return LichenScaffold(
      showBottomNav: true,
      bottomNavIndex: _selectedIndex,
      onBottomNavTap: _onBottomNavTap,
      showParticleBackground: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        physics: const BouncingScrollPhysics(),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildHeader(filteredPoints.length),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInlineFilters(),
          const SizedBox(height: 12),
          _buildLegendSection(),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.mapExplorer);
              },
              icon: Icon(Icons.explore_rounded, color: AppTheme.successColor),
              label: Text(
                'Explorar mapa',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.successColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildMapCard(markers, circles, initialPosition, initialZoom),
          const SizedBox(height: 20),
          if (ownPoints.isNotEmpty)
            _buildAnalysisPanel(
              'Mis análisis',
              ownPoints,
              false,
              showUserInfo: false,
            ),
          if (communityPoints.isNotEmpty)
            _buildAnalysisPanel(
              'Análisis compartidos por la comunidad',
              communityPoints,
              false,
              showUserInfo: true,
            ),
          if (ownPoints.isEmpty && communityPoints.isEmpty)
            _buildAnalysisPanel(
              'Observaciones ambientales',
              filteredPoints,
              true,
              showUserInfo: false,
            ),
        ],
      ),
    );
  }
}

class _QualityGroup extends StatelessWidget {
  final AirQualityLevel level;
  final List<MapAnalysisPoint> points;
  final bool isExpanded;
  final VoidCallback onToggle;
  final MapAnalysisPoint? selectedPoint;
  final int? expandedAnalysisId;
  final ValueChanged<MapAnalysisPoint> onCardTap;
  final String Function(DateTime) formatDate;
  final Color qualityColor;
  final bool showUserInfo;

  const _QualityGroup({
    required this.level,
    required this.points,
    required this.isExpanded,
    required this.onToggle,
    this.selectedPoint,
    this.expandedAnalysisId,
    required this.onCardTap,
    required this.formatDate,
    required this.qualityColor,
    this.showUserInfo = false,
  });

  String get _groupLabel {
    switch (level) {
      case AirQualityLevel.good:
        return 'Saludables';
      case AirQualityLevel.moderate:
        return 'Moderadas';
      case AirQualityLevel.poor:
        return 'Contaminadas';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: qualityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      color: qualityColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _groupLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: qualityColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${points.length} ${points.length == 1 ? "observación" : "observaciones"}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: qualityColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 250),
                    turns: isExpanded ? 0.5 : 0.0,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: AppTheme.textGray.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Divider(height: 1, color: AppTheme.borderColor.withValues(alpha: 0.25)),
                        const SizedBox(height: 8),
                        ...points.map((point) {
                          final isSelected = selectedPoint?.id == point.id;
                          final isAnalysisExpanded = expandedAnalysisId == point.id;
                          return _AnalysisCard(
                            point: point,
                            isSelected: isSelected,
                            isExpanded: isAnalysisExpanded,
                            onTap: () => onCardTap(point),
                            formattedDate: formatDate(point.date),
                            showUserInfo: showUserInfo,
                          );
                        }),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final MapAnalysisPoint point;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;
  final String formattedDate;
  final bool showUserInfo;

  const _AnalysisCard({
    required this.point,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
    required this.formattedDate,
    this.showUserInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    final level = point.qualityLevel;
    final color = _qualityColor(level);
    final backgroundColor = _qualityBackground(level);
    final label = _qualityLabel(level);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: isSelected ? 0.45 : 0.15),
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showUserInfo && point.usuario != null) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                      backgroundImage: point.usuario!['foto_perfil'] != null && point.usuario!['foto_perfil'].toString().isNotEmpty
                          ? NetworkImage(point.usuario!['foto_perfil'].toString())
                          : null,
                      child: point.usuario!['foto_perfil'] == null || point.usuario!['foto_perfil'].toString().isEmpty
                          ? Icon(Icons.person_rounded, size: 14, color: AppTheme.primaryGreen)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        point.usuario!['nombre']?.toString() ?? 'Usuario',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      color: color,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          point.zoneName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          point.species,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 250),
                    turns: isExpanded ? 0.5 : 0.0,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: AppTheme.textGray.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textGray,
                      ),
                    ),
                  ),
                  Text(
                    '${(point.confidence * 100).toInt()}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: isExpanded
                    ? Column(
                        children: [
                          const SizedBox(height: 10),
                          Divider(height: 1, color: AppTheme.borderColor.withValues(alpha: 0.3)),
                          const SizedBox(height: 10),
                          _DetailRow(label: 'Calidad del aire', value: label),
                          const SizedBox(height: 6),
                          _DetailRow(label: 'Contaminación', value: point.contaminationLevel ?? 'No disponible'),
                          const SizedBox(height: 6),
                          _DetailRow(label: 'Confianza IA', value: '${(point.confidence * 100).toInt()}%'),
                          const SizedBox(height: 6),
                          _DetailRow(label: 'Fecha', value: formattedDate),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _qualityColor(AirQualityLevel level) {
    switch (level) {
      case AirQualityLevel.good:
        return AppTheme.successColor;
      case AirQualityLevel.moderate:
        return const Color(0xFFFFC107);
      case AirQualityLevel.poor:
        return AppTheme.errorColor;
    }
  }

  Color _qualityBackground(AirQualityLevel level) {
    switch (level) {
      case AirQualityLevel.good:
        return const Color(0xFFE8F5E9);
      case AirQualityLevel.moderate:
        return const Color(0xFFFFF9C4);
      case AirQualityLevel.poor:
        return const Color(0xFFFFEBEE);
    }
  }

  String _qualityLabel(AirQualityLevel level) {
    switch (level) {
      case AirQualityLevel.good:
        return 'Buena';
      case AirQualityLevel.moderate:
        return 'Moderada';
      case AirQualityLevel.poor:
        return 'Deficiente';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGray,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

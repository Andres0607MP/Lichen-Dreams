import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../routes/route_names.dart';
import '../widgets/app_theme.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/map_controls.dart';
import '../services/navigation_service.dart';
import '../state/map_state.dart';
import '../state/auth_state.dart';
import '../state/analysis_state.dart';
import '../models/map_analysis_point.dart';
import '../models/developer_map_point.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapAnalysisPoint? _selectedPoint;
  int? _expandedAnalysisId;
  GoogleMapController? _mapController;
  bool _locationPermissionGranted = false;
  bool _locationServiceEnabled = false;
  String? _locationStatusMessage;
  Set<Marker>? _cachedMarkers;
  String? _markersHash;
  Map<AirQualityLevel, bool> expandedOwnGroups = {
    AirQualityLevel.good: true,
    AirQualityLevel.moderate: false,
    AirQualityLevel.poor: false,
  };
  Map<AirQualityLevel, bool> expandedCommunityGroups = {
    AirQualityLevel.good: true,
    AirQualityLevel.moderate: false,
    AirQualityLevel.poor: false,
  };
  Map<AirQualityLevel, bool> expandedFilteredGroups = {
    AirQualityLevel.good: true,
    AirQualityLevel.moderate: false,
    AirQualityLevel.poor: false,
  };
  bool _showMyAnalyses = true;
  bool _showCommunity = true;
  bool _showZones = true;
  MapType _mapType = MapType.normal;
  ScrollController? _scrollController;
  bool _showBackToMap = false;
  Set<AirQualityLevel> _qualityFilters = {};
  Set<ContaminationLevel> _contaminationFilters = {};
  Set<ConfidenceLevel> _confidenceFilters = {};
  DateRange _dateRange = DateRange.all;
  String? _selectedFilterChip;

  @override
  void dispose() {
    AnalysisState.removeAnalysisCompletedListener(_onAnalysisCompleted);
    _scrollController?.dispose();
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
    _scrollController = ScrollController();
    _scrollController!.addListener(_onScroll);
    AnalysisState.addAnalysisCompletedListener(_onAnalysisCompleted);
    _requestLocationPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = context.read<AuthState>();
      final mapState = context.read<MapState>();
      mapState.updateUserId(authState.userId);
      if (!mapState.loading) {
        mapState.loadPoints();
      }
    });
  }

  void _onAnalysisCompleted() {
    if (!mounted) return;
    context.read<MapState>().loadPoints();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _onBottomNavTap(int index) {
    LichenNavigation.instance.navigateToTab(context, index);
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

  void _onScroll() {
    if (_scrollController == null || !mounted) return;
    final offset = _scrollController!.offset;
    final show = offset > 300;
    if (_showBackToMap != show) {
      setState(() {
        _showBackToMap = show;
      });
    }
  }

  void _scrollToTop() {
    if (_scrollController == null || !mounted) return;
    _scrollController!.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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
        position: point.markerLatLng,
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

  /// Adaptación mínima de [MapAnalysisPoint] a [DeveloperMapPoint] para poder
  /// reutilizar la lógica real `calculateZones()` del mapa de desarrollador.
  ///
  /// Solo participan las observaciones individuales `good` (saludable) y
  /// `poor` (contaminada/crítica); `moderate` NO se convierte en un resultado
  /// individual y no alimenta las zonas de transición.
  List<DeveloperMapPoint> _buildDeveloperPoints(List<MapAnalysisPoint> points) {
    final result = <DeveloperMapPoint>[];
    for (final point in points) {
      DevMapQuality quality;
      switch (point.qualityLevel) {
        case AirQualityLevel.good:
          quality = DevMapQuality.healthy;
          break;
        case AirQualityLevel.poor:
          quality = DevMapQuality.contaminated;
          break;
        case AirQualityLevel.moderate:
          continue;
      }
      result.add(DeveloperMapPoint(
        latitude: point.lat,
        longitude: point.lng,
        quality: quality,
        airQuality: quality == DevMapQuality.healthy
            ? DevAirQuality.good
            : DevAirQuality.bad,
        contamination: switch (point.contaminationLevelCategory) {
          ContaminationLevel.low => DevContamination.low,
          ContaminationLevel.medium => DevContamination.medium,
          ContaminationLevel.high => DevContamination.high,
          ContaminationLevel.unknown => DevContamination.low,
        },
        confidence: point.confidence,
        createdAt: point.date,
      ));
    }
    return result;
  }

  /// Zonas de transición derivadas de la proximidad entre observaciones
  /// saludables y contaminadas, calculadas con `calculateZones()` REAL.
  /// Se renderizan únicamente como Circle amarillo (igual que el mapa de
  /// desarrollador); no reemplazan círculos de precisión ni marcadores.
  Set<Circle> _buildTransitionCircles(List<MapAnalysisPoint> filteredPoints) {
    final zones = calculateZones(_buildDeveloperPoints(filteredPoints));
    final circles = <Circle>{};
    for (final zone in zones) {
      if (zone.zoneType != DevMapZoneType.transition) continue;
      circles.add(Circle(
        circleId: CircleId('main_transition_${zone.id}'),
        center: zone.center,
        radius: zone.radius,
        fillColor: AppTheme.warningColor.withValues(alpha: 0.18),
        strokeColor: AppTheme.warningColor.withValues(alpha: 0.5),
        strokeWidth: 2,
      ));
    }
    return circles;
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildLegend() {
    const items = <(Color, String)>[
      (AppTheme.successColor, 'Saludable'),
      (Color(0xFFFFC107), 'Zona transición*'),
      (AppTheme.errorColor, 'Contaminada'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final itemCount = items.length;
            final spacing = 10.0;
            final availableWidth = constraints.maxWidth;
            final itemWidth = (availableWidth - spacing * (itemCount - 1)) / itemCount;

            return Row(
              children: items.map((item) {
                final color = item.$1;
                final label = item.$2;

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
                          label.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        ),
        const SizedBox(height: 6),
        Text(
          '* Zona de transición derivada de la proximidad entre saludable y contaminado',
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Explora observaciones de líquenes y patrones de calidad del aire',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            '$pointCount ${pointCount == 1 ? "análisis registrado" : "análisis registrados"}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
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
        color: Theme.of(context).colorScheme.surface,
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
                  mapType: _mapType,
                  markers: markers,
                  circles: circles,
                  myLocationEnabled: _locationPermissionGranted && _locationServiceEnabled,
                  myLocationButtonEnabled: _locationPermissionGranted && _locationServiceEnabled,
                  zoomGesturesEnabled: true,
                  zoomControlsEnabled: false,
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
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _locationStatusMessage!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 60,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
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
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Column(
                  children: [
                    MapZoomControls(
                      onZoomIn: _zoomIn,
                      onZoomOut: _zoomOut,
                    ),
                    const SizedBox(height: 8),
                    MapControlButton(
                      icon: _mapType == MapType.normal
                          ? Icons.satellite_rounded
                          : Icons.map_rounded,
                      onTap: _toggleMapType,
                      tooltip: 'Cambiar tipo de mapa',
                      active: _mapType == MapType.satellite,
                    ),
                  ],
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
      const SizedBox(width: 8),
      _buildFilterChip(
        label: 'Filtros',
        value: '__advanced__',
        icon: Icons.tune_rounded,
      ),
    ];

    return Stack(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: chips,
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 40,
          child: IgnorePointer(
            ignoring: true,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.0),
                    Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
                  ],
                ),
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({required String label, required String? value, IconData? icon}) {
    final isAdvanced = value == '__advanced__';
    final isActive = isAdvanced
        ? (_qualityFilters.isNotEmpty || _contaminationFilters.isNotEmpty || _confidenceFilters.isNotEmpty || _dateRange != DateRange.all)
        : _selectedFilterChip == value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: () {
          if (isAdvanced) {
            _showAdvancedFilters();
          } else {
            setState(() {
              if (_selectedFilterChip == value) {
                _selectedFilterChip = null;
              } else {
                _selectedFilterChip = value;
              }
            });
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryGreen.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isActive ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdvancedFilters() {
    final tempQuality = Set<AirQualityLevel>.from(_qualityFilters);
    final tempContamination = Set<ContaminationLevel>.from(_contaminationFilters);
    final tempConfidence = Set<ConfidenceLevel>.from(_confidenceFilters);
    DateRange? tempDateRange = _dateRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.3))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filtros avanzados',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setModalState(() {
                          tempQuality.clear();
                          tempContamination.clear();
                          tempConfidence.clear();
                          tempDateRange = DateRange.all;
                        });
                      },
                      icon: Icon(Icons.refresh_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      label: Text(
                        'Limpiar',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFilterSectionTitle('Calidad del aire'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AirQualityLevel.values.map((level) {
                          final label = switch (level) {
                            AirQualityLevel.good => 'Saludable',
                            AirQualityLevel.moderate => 'Moderado',
                            AirQualityLevel.poor => 'Contaminado',
                          };
                          final isSelected = tempQuality.contains(level);
                          return _buildFilterChoiceChip(
                            label: label,
                            isSelected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  tempQuality.add(level);
                                } else {
                                  tempQuality.remove(level);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      _buildFilterSectionTitle('Contaminación'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ContaminationLevel.values.map((level) {
                          if (level == ContaminationLevel.unknown) return const SizedBox.shrink();
                          String label;
                          switch (level) {
                            case ContaminationLevel.low:
                              label = 'Baja';
                              break;
                            case ContaminationLevel.medium:
                              label = 'Media';
                              break;
                            case ContaminationLevel.high:
                              label = 'Alta';
                              break;
                            default:
                              return const SizedBox.shrink();
                          }
                          final isSelected = tempContamination.contains(level);
                          return _buildFilterChoiceChip(
                            label: label,
                            isSelected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  tempContamination.add(level);
                                } else {
                                  tempContamination.remove(level);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      _buildFilterSectionTitle('Confianza IA'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ConfidenceLevel.values.map((level) {
                          final label = switch (level) {
                            ConfidenceLevel.high => 'Alta',
                            ConfidenceLevel.medium => 'Media',
                            ConfidenceLevel.low => 'Baja',
                          };
                          final isSelected = tempConfidence.contains(level);
                          return _buildFilterChoiceChip(
                            label: label,
                            isSelected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  tempConfidence.add(level);
                                } else {
                                  tempConfidence.remove(level);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      _buildFilterSectionTitle('Fecha'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: DateRange.values.map((range) {
                          final label = switch (range) {
                            DateRange.today => 'Hoy',
                            DateRange.week => 'Última semana',
                            DateRange.month => 'Último mes',
                            DateRange.all => 'Todos',
                          };
                          final isSelected = tempDateRange == range;
                          return _buildFilterChoiceChip(
                            label: label,
                            isSelected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                tempDateRange = selected ? range : DateRange.all;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.3))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _qualityFilters = tempQuality;
                        _contaminationFilters = tempContamination;
                        _confidenceFilters = tempConfidence;
                        _dateRange = tempDateRange ?? DateRange.all;
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Aplicar',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildFilterChoiceChip({
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
  }) {
    return InkWell(
      onTap: () => onSelected(!isSelected),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.3) : AppTheme.borderColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisPanel(String title, List<MapAnalysisPoint> points, bool showEmptyState, {bool showUserInfo = false, Map<AirQualityLevel, bool>? expandedGroups}) {
    if (showEmptyState) return _buildEmptyState();

    final groups = <AirQualityLevel, List<MapAnalysisPoint>>{
      AirQualityLevel.good: [],
      AirQualityLevel.moderate: [],
      AirQualityLevel.poor: [],
    };
    for (final point in points) {
      groups[point.qualityLevel]!.add(point);
    }

    final expandedGroupsState = expandedGroups ?? <AirQualityLevel, bool>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Análisis realizados en diferentes ubicaciones',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            isExpanded: expandedGroupsState[level] ?? false,
            onToggle: () {
              setState(() {
                expandedGroupsState[level] = !(expandedGroupsState[level] ?? false);
              });
            },
            selectedPoint: _selectedPoint,
            expandedAnalysisId: _expandedAnalysisId,
            onCardTap: (point) {
              setState(() {
                _selectedPoint = point;
                _expandedAnalysisId = point.id;
                expandedGroupsState[point.qualityLevel] = true;
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
              icon: Icon(Icons.close_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              label: Text(
                'Limpiar selección',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin análisis publicados',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Los análisis aparecerán aquí cuando los usuarios decidan compartirlos en el mapa ambiental.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Verifica tu conexión e intenta nuevamente',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final transitionCircles = _showZones
        ? _buildTransitionCircles(filteredPoints)
        : const <Circle>{};
    final allCircles = {...circles, ...transitionCircles};
    final initialPosition = _selectedPoint != null
        ? _selectedPoint!.latLng
        : const LatLng(4.7110, -74.0721);
    final initialZoom = _selectedPoint != null ? 16.0 : MapAnalysisPoint.defaultMapZoom;

    return LichenScaffold(
      showBottomNav: true,
      onBottomNavTap: _onBottomNavTap,
      showParticleBackground: false,
      bodyIsScrollable: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              controller: _scrollController,
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
          _buildMapCard(markers, allCircles, initialPosition, initialZoom),
          const SizedBox(height: 20),
          if (ownPoints.isNotEmpty)
            _buildAnalysisPanel(
              'Mis análisis',
              ownPoints,
              false,
              showUserInfo: false,
              expandedGroups: expandedOwnGroups,
            ),
          if (communityPoints.isNotEmpty)
            _buildAnalysisPanel(
              'Análisis compartidos por la comunidad',
              communityPoints,
              false,
              showUserInfo: true,
              expandedGroups: expandedCommunityGroups,
            ),
          if (ownPoints.isEmpty && communityPoints.isEmpty)
            _buildAnalysisPanel(
              'Observaciones ambientales',
              filteredPoints,
              true,
              showUserInfo: false,
              expandedGroups: expandedFilteredGroups,
            ),
        ],
      ),
    ),
      if (_showBackToMap)
        Positioned(
          right: 16,
          bottom: 24,
          child: AnimatedOpacity(
            opacity: _showBackToMap ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: MapControlButton(
              icon: Icons.map_rounded,
              onTap: _scrollToTop,
              tooltip: 'Volver al mapa',
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class _QualityGroup extends StatefulWidget {
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

  @override
  State<_QualityGroup> createState() => _QualityGroupState();
}

class _QualityGroupState extends State<_QualityGroup> {
  static const int _initialVisibleItems = 5;
  bool _showAll = false;

  String get _groupLabel {
    switch (widget.level) {
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
    final visiblePoints = _showAll
        ? widget.points
        : widget.points.take(_initialVisibleItems).toList();
    final hasMore = widget.points.length > _initialVisibleItems;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.qualityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      color: widget.qualityColor,
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
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.qualityColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.points.length} ${widget.points.length == 1 ? "observación" : "observaciones"}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.qualityColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 250),
                    turns: widget.isExpanded ? 0.5 : 0.0,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: widget.isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Divider(height: 1, color: AppTheme.borderColor.withValues(alpha: 0.25)),
                        const SizedBox(height: 8),
                        ...visiblePoints.map((point) {
                          final isSelected = widget.selectedPoint?.id == point.id;
                          final isAnalysisExpanded = widget.expandedAnalysisId == point.id;
                          return _AnalysisCard(
                            point: point,
                            isSelected: isSelected,
                            isExpanded: isAnalysisExpanded,
                            onTap: () => widget.onCardTap(point),
                            formattedDate: widget.formatDate(point.date),
                            showUserInfo: widget.showUserInfo,
                          );
                        }),
                        if (hasMore)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showAll = !_showAll;
                              });
                            },
                            icon: Icon(
                              _showAll
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            label: Text(
                              _showAll
                                  ? 'Ver menos'
                                  : 'Ver ${widget.points.length - _initialVisibleItems} más',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
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
                        ? NetworkImage(AppConfig.getImageUrl(point.usuario!['foto_perfil'].toString()))
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
                          color: Theme.of(context).colorScheme.onSurface,
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
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          point.species,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              color: Theme.of(context).colorScheme.onSurface,
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

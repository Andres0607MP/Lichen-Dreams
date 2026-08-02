import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../routes/route_names.dart';
import '../widgets/app_theme.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/modern_widgets.dart';
import '../services/api_service.dart';
import '../services/navigation_service.dart';
import '../models/map_analysis_point.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapAnalysisPoint? _selectedPoint;
  int _selectedIndex = 2;
  GoogleMapController? _mapController;
  bool _locationPermissionGranted = false;
  bool _locationServiceEnabled = false;
  String? _locationStatusMessage;

  Future<List<MapAnalysisPoint>> _loadMapPoints() async {
    final api = ApiService();
    try {
      final jsonList = await api.getMapPoints();
      return jsonList
          .map((json) => MapAnalysisPoint.fromJson(json))
          .toList();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: _reloadPoints,
            ),
          ),
        );
      }
      rethrow;
    }
  }

  void _reloadPoints() {
    setState(() {});
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
    LichenNavigation.instance.navigateTo(2);
    _requestLocationPermission();
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

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: AirQualityLevel.values.map((level) {
        Color color;
        switch (level) {
          case AirQualityLevel.good:
            color = AppTheme.successColor;
            break;
          case AirQualityLevel.moderate:
            color = AppTheme.warningColor;
            break;
          case AirQualityLevel.poor:
            color = AppTheme.errorColor;
            break;
        }
        return Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              level.name.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textGray,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Set<Marker> _buildMarkers(List<MapAnalysisPoint> points) {
    return points.map((point) {
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

  Widget _buildAnalysisCard(MapAnalysisPoint point) {
    final level = point.qualityLevel;
    final style = switch (level) {
      AirQualityLevel.good => (
        color: AppTheme.successColor,
        backgroundColor: const Color(0xFFE8F5E9),
        label: 'Bueno'
      ),
      AirQualityLevel.moderate => (
        color: AppTheme.warningColor,
        backgroundColor: const Color(0xFFFFF3E0),
        label: 'Moderado'
      ),
      AirQualityLevel.poor => (
        color: AppTheme.errorColor,
        backgroundColor: const Color(0xFFFFEBEE),
        label: 'Deficiente'
      ),
    };

    return ModernCard(
      backgroundColor: style.backgroundColor,
      borderRadius: AppTheme.cardRadius,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                point.zoneName,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  style.label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: style.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            icon: Icons.air_rounded,
            label: 'Calidad del aire',
            value: style.label,
            valueColor: style.color,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.eco_rounded,
            label: 'Especie de líquen',
            value: point.species,
            valueColor: AppTheme.textDark,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.water_drop_rounded,
            label: 'Contaminación',
            value: point.contaminationLevel ?? 'No disponible',
            valueColor: AppTheme.textDark,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.check_circle_rounded,
            label: 'Confianza de la IA',
            value: '${(point.confidence * 100).toInt()}%',
            valueColor: point.confidence >= 0.8
                ? AppTheme.successColor
                : point.confidence >= 0.6
                    ? AppTheme.warningColor
                    : AppTheme.errorColor,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Fecha',
            value: _formatDate(point.date),
            valueColor: AppTheme.textGray,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppTheme.textGray,
        ),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppTheme.textGray,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LichenScaffold(
      showBottomNav: true,
      bottomNavIndex: _selectedIndex,
      onBottomNavTap: _onBottomNavTap,
      showParticleBackground: false,
      body: FutureBuilder<List<MapAnalysisPoint>>(
        future: _loadMapPoints(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
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
                      onPressed: _reloadPoints,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final points = snapshot.data ?? <MapAnalysisPoint>[];
          final showEmptyState = points.isEmpty;

          final markers = _buildMarkers(points);
          final initialPosition = _selectedPoint != null
              ? _selectedPoint!.latLng
              : const LatLng(4.7110, -74.0721);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mapa ambiental',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Visualiza la calidad del aire estimada por análisis de líquenes',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textGray,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildLegend(),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: 400,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: initialPosition,
                          zoom: 12,
                        ),
                        markers: markers,
                        myLocationEnabled: _locationPermissionGranted && _locationServiceEnabled,
                        myLocationButtonEnabled: _locationPermissionGranted && _locationServiceEnabled,
                        zoomGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        onTap: (latLng) {},
                      ),
                      if (_locationStatusMessage != null)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.borderColor.withValues(alpha: 0.4),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
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
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.mapExplorer);
                  },
                  icon: Icon(Icons.explore_rounded, color: AppTheme.successColor),
                  label: Text(
                    'Explorar mapa',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.successColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (showEmptyState)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 64,
                        color: AppTheme.textGray.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Aún no hay análisis publicados',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Los análisis aparecerán aquí cuando los usuarios decidan compartirlos en el mapa ambiental.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textGray,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SectionHeader(
                    title: 'Zonas analizadas',
                    subtitle: '${points.length} zonas con datos de calidad del aire',
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedPoint != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildAnalysisCard(_selectedPoint!),
              ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Todas las zonas',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...points.map((point) {
                        final level = point.qualityLevel;
                        final style = switch (level) {
                          AirQualityLevel.good => (
                            color: AppTheme.successColor,
                            backgroundColor: const Color(0xFFE8F5E9),
                            label: 'Bueno'
                          ),
                          AirQualityLevel.moderate => (
                            color: AppTheme.warningColor,
                            backgroundColor: const Color(0xFFFFF3E0),
                            label: 'Moderado'
                          ),
                          AirQualityLevel.poor => (
                            color: AppTheme.errorColor,
                            backgroundColor: const Color(0xFFFFEBEE),
                            label: 'Deficiente'
                          ),
                        };
                        final isSelected = _selectedPoint?.id == point.id;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPoint = point;
                            });
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLng(point.latLng),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: style.backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: style.color.withValues(alpha: 0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: style.color,
                                  child: const Icon(
                                    Icons.eco_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
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
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${style.label} · ${point.species}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppTheme.textGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${(point.confidence * 100).toInt()}%',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: style.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

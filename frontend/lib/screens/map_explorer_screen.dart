import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/app_theme.dart';
import '../services/api_service.dart';
import '../models/map_analysis_point.dart';

class MapExplorerScreen extends StatefulWidget {
  const MapExplorerScreen({super.key});

  @override
  State<MapExplorerScreen> createState() => _MapExplorerScreenState();
}

class _MapExplorerScreenState extends State<MapExplorerScreen> {
  List<MapAnalysisPoint> _points = [];
  MapAnalysisPoint? _selectedPoint;
  GoogleMapController? _mapController;
  bool _isLoading = true;
  String? _errorMessage;
  bool _locationPermissionGranted = false;
  bool _locationServiceEnabled = false;
  String? _locationStatusMessage;

  @override
  void initState() {
    super.initState();
    _loadMapPoints();
    _requestLocationPermission();
  }

  Future<void> _loadMapPoints() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ApiService();
      final jsonList = await api.getMapPoints();
      final points = jsonList
          .map((json) => MapAnalysisPoint.fromJson(json))
          .toList();

      setState(() {
        _points = points;
        _isLoading = false;
        if (points.isNotEmpty) {
          _selectedPoint = points.first;
        }
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Error inesperado al cargar el mapa';
        _isLoading = false;
      });
    }
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

  BitmapDescriptor _getMarkerColor(AirQualityLevel level) {
    switch (level) {
      case AirQualityLevel.good:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case AirQualityLevel.moderate:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      case AirQualityLevel.poor:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  Set<Marker> _buildMarkers(List<MapAnalysisPoint> points) {
    // Future clustering-ready: points can be grouped here before creating markers.
    return points.map((point) {
      final level = point.qualityLevel;
      final icon = _getMarkerColor(level);

      return Marker(
        markerId: MarkerId('analysis_${point.id}'),
        position: point.latLng,
        icon: icon,
        infoWindow: InfoWindow(
          title: point.zoneName,
          snippet: '${point.species} - ${point.airQuality}',
        ),
        onTap: () {
          setState(() {
            _selectedPoint = point;
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(point.latLng),
          );
        },
      );
    }).toSet();
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: AirQualityLevel.values.map((level) {
          final color = switch (level) {
            AirQualityLevel.good => AppTheme.successColor,
            AirQualityLevel.moderate => AppTheme.warningColor,
            AirQualityLevel.poor => AppTheme.errorColor,
          };
          final label = switch (level) {
            AirQualityLevel.good => 'Bueno',
            AirQualityLevel.moderate => 'Moderado',
            AirQualityLevel.poor => 'Deficiente',
          };

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textGray),
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
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppTheme.textDark,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildAnalysisCard(MapAnalysisPoint point, {Key? key}) {
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

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  point.zoneName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          const SizedBox(height: 12),
          _buildInfoRow(Icons.eco_rounded, 'Especie', point.species),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.air_rounded, 'Calidad del aire', style.label, valueColor: style.color),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.calendar_today_rounded, 'Fecha', _formatDate(point.date)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navegación pendiente
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Ver análisis',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mapa ambiental',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(4.7110, -74.0721),
              zoom: 12,
            ),
            markers: _buildMarkers(_points),
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
          Positioned(
            left: 12,
            top: 12,
            child: _buildLegend(),
          ),
          if (_selectedPoint != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _selectedPoint != null
                    ? _buildAnalysisCard(_selectedPoint!, key: ValueKey(_selectedPoint!.id))
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}

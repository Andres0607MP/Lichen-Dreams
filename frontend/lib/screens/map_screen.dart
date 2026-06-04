import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  final CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(4.7110, -74.0721),
    zoom: 12,
  );

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa interactivo')),
      body: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: _initialCameraPosition,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                mapType: MapType.normal,
                markers: {
                  const Marker(
                    markerId: MarkerId('default_location'),
                    position: LatLng(4.7110, -74.0721),
                    infoWindow: InfoWindow(title: 'Zona de análisis'),
                  ),
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                Chip(label: Text('Bueno')),
                Chip(label: Text('Regular')),
                Chip(label: Text('Malo')),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/analysis_record.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

class SpeciesScreen extends StatefulWidget {
  const SpeciesScreen({super.key});

  @override
  State<SpeciesScreen> createState() => _SpeciesScreenState();
}

class _SpeciesScreenState extends State<SpeciesScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Map<String, dynamic>>> _speciesFuture;

  @override
  void initState() {
    super.initState();
    _speciesFuture = _loadSpecies();
  }

  Future<List<Map<String, dynamic>>> _loadSpecies() async {
    final history = await _apiService.getAnalysisHistory();
    final speciesList = <Map<String, dynamic>>[];
    for (final analysis in history) {
      final id = analysis['id'] is int ? analysis['id'] as int : int.tryParse(analysis['id']?.toString() ?? '');
      if (id != null) {
        try {
          final species = await _apiService.getSpecies(id);
          final rawSpecies = species['data'] is List
              ? List<Map<String, dynamic>>.from(species['data'])
              : [species as Map<String, dynamic>];
          speciesList.addAll(rawSpecies);
        } catch (_) {
          continue;
        }
      }
    }
    return speciesList;
  }

  Widget _buildSpeciesItem(Map<String, dynamic> species) {
    final nombreCientifico = species['nombre_cientifico']?.toString() ?? species['scientific_name']?.toString() ?? 'Desconocido';
    final nombreComun = species['nombre_comun']?.toString() ?? species['common_name']?.toString() ?? 'No disponible';
    final tolerancia = species['tolerancia']?.toString() ?? species['tolerance']?.toString() ?? 'No disponible';
    final calidad = species['calidad_aire']?.toString() ?? species['air_quality']?.toString() ?? 'No disponible';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        title: Text(nombreCientifico, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nombre común: $nombreComun'),
            Text('Tolerancia: $tolerancia'),
            Text('Calidad del aire: $calidad'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_rounded),
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(nombreCientifico),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nombre común: $nombreComun'),
                  const SizedBox(height: 8),
                  Text('Tolerancia: $tolerancia'),
                  const SizedBox(height: 8),
                  Text('Calidad del aire: $calidad'),
                  const SizedBox(height: 12),
                  Text(species['descripcion']?.toString() ?? species['description']?.toString() ?? 'Sin más detalles'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Especies identificadas')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _speciesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error al cargar especies:\n${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    PrimaryButton(onPressed: () => setState(() => _speciesFuture = _loadSpecies()), child: const Text('Reintentar')),
                  ],
                ),
              ),
            );
          }

          final species = snapshot.data ?? [];
          if (species.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No se encontraron especies en tu historial de análisis.'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            itemCount: species.length,
            itemBuilder: (context, index) => _buildSpeciesItem(species[index]),
          );
        },
      ),
    );
  }
}

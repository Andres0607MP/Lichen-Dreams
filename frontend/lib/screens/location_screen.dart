import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _municipioController = TextEditingController();
  final TextEditingController _departamentoController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _direccionController.dispose();
    _municipioController.dispose();
    _departamentoController.dispose();
    super.dispose();
  }

  Future<void> _saveLocation() async {
    if (!_formKey.currentState!.validate()) return;

    final latitude = double.tryParse(_latitudeController.text.replaceAll(',', '.'));
    final longitude = double.tryParse(_longitudeController.text.replaceAll(',', '.'));
    if (latitude == null || longitude == null) {
      _showMessage('Latitud o longitud inválida', success: false);
      return;
    }

    final locationData = {
      'latitude': latitude,
      'longitude': longitude,
      'direccion': _direccionController.text.trim(),
      'municipio': _municipioController.text.trim(),
      'departamento': _departamentoController.text.trim(),
      'pais': 'Colombia',
    };

    setState(() => _isSaving = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.saveLocation(locationData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicación guardada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      _showMessage(error is ApiException ? error.message : 'Error al guardar ubicación');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF2F7D32)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar ubicación')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              TextFormField(
                controller: _latitudeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _buildInputDecoration('Latitud', Icons.location_on_rounded),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Latitud requerida';
                  }
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Latitud inválida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _longitudeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _buildInputDecoration('Longitud', Icons.location_on_outlined),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Longitud requerida';
                  }
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Longitud inválida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _direccionController,
                decoration: _buildInputDecoration('Dirección', Icons.home_rounded),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Dirección requerida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _municipioController,
                decoration: _buildInputDecoration('Municipio', Icons.location_city_rounded),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Municipio requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _departamentoController,
                decoration: _buildInputDecoration('Departamento', Icons.map_rounded),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Departamento requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                onPressed: _isSaving ? null : _saveLocation,
                loading: _isSaving,
                child: const Text('Guardar ubicación'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

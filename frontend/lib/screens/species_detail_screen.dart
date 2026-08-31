import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../widgets/app_theme.dart';
import '../config/app_config.dart';
import '../state/auth_state.dart';

class SpeciesDetailScreen extends StatelessWidget {
  final Map<String, dynamic> species;

  const SpeciesDetailScreen({super.key, required this.species});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nombreCientifico = species['nombre_cientifico'] ?? 'Sin nombre científico';
    final nombreComun = species['nombre_comun']?.toString();
    final descripcion = species['descripcion']?.toString();
    final colorPredominante = species['color_predominante']?.toString();
    final tipoCrecimiento = species['tipo_crecimiento']?.toString();
    final habitat = species['habitat']?.toString();
    final imagen = species['imagen_referencia']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          nombreCientifico,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagen != null && imagen.isNotEmpty)
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.especiesPrimary.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    AppConfig.getImageUrl(imagen),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) =>
                        _ImagePlaceholder(),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppTheme.backgroundColor,
                ),
                child: _ImagePlaceholder(),
              ),
            const SizedBox(height: 20),
            Text(
              nombreCientifico,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
                letterSpacing: -0.3,
              ),
            ),
            if (nombreComun != null && nombreComun.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                nombreComun,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textGray,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (descripcion != null && descripcion.isNotEmpty) ...[
              Text(
                descripcion,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildDetailRow(context, 'Color predominante', colorPredominante, Icons.palette_rounded),
            if (tipoCrecimiento != null && tipoCrecimiento.isNotEmpty)
              _buildDetailRow(context, 'Tipo de crecimiento', tipoCrecimiento, Icons.landscape_rounded),
            if (habitat != null && habitat.isNotEmpty)
              _buildDetailRow(context, 'Hábitat', habitat, Icons.forest_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String? value, IconData icon) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.especiesPrimary.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundColor,
      child: Icon(Icons.eco_rounded, size: 64, color: AppTheme.especiesPrimary.withValues(alpha: 0.15)),
    );
  }
}

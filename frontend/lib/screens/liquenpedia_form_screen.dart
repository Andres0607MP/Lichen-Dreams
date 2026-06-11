import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/liquenpedia_article.dart';
import '../services/api_service.dart';
import '../widgets/app_theme.dart';
import '../widgets/modern_widgets.dart';

class LiquenpediaFormScreen extends StatefulWidget {
  final LiquenpediaArticle? articleToEdit;

  const LiquenpediaFormScreen({super.key, this.articleToEdit});

  @override
  State<LiquenpediaFormScreen> createState() => _LiquenpediaFormScreenState();
}

class _LiquenpediaFormScreenState extends State<LiquenpediaFormScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _tituloController;
  late TextEditingController _contenidoController;
  late TextEditingController _autorController;
  late TextEditingController _categoriaController;
  late TextEditingController _imagenController;

  String _estadoPublicacion = 'publicado';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(
      text: widget.articleToEdit?.titulo ?? '',
    );
    _contenidoController = TextEditingController(
      text: widget.articleToEdit?.contenido ?? '',
    );
    _autorController = TextEditingController(
      text: widget.articleToEdit?.autor ?? '',
    );
    _categoriaController = TextEditingController(
      text: widget.articleToEdit?.categoria ?? '',
    );
    _imagenController = TextEditingController(
      text: widget.articleToEdit?.imagenArticulo ?? '',
    );
    _estadoPublicacion = widget.articleToEdit?.estadoPublicacion ?? 'publicado';
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _contenidoController.dispose();
    _autorController.dispose();
    _categoriaController.dispose();
    _imagenController.dispose();
    super.dispose();
  }

  Future<void> _guardarArticulo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.articleToEdit == null) {
        // Crear nuevo
        await _apiService.createLiquenpediaArticle(
          titulo: _tituloController.text,
          contenido: _contenidoController.text,
          autor: _autorController.text,
          categoria: _categoriaController.text,
          estadoPublicacion: _estadoPublicacion,
          imagenArticulo: _imagenController.text.isNotEmpty
              ? _imagenController.text
              : null,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Artículo creado exitosamente'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        // Actualizar
        await _apiService.updateLiquenpediaArticle(
          widget.articleToEdit!.id ?? 0,
          titulo: _tituloController.text,
          contenido: _contenidoController.text,
          autor: _autorController.text,
          categoria: _categoriaController.text,
          estadoPublicacion: _estadoPublicacion,
          imagenArticulo: _imagenController.text.isNotEmpty
              ? _imagenController.text
              : null,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Artículo actualizado exitosamente'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.articleToEdit == null
                  ? 'Nuevo artículo'
                  : 'Editar artículo',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            Text(
              'Crea contenido educativo sobre líquenes',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.textGray,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sección 1: Información básica
              _buildSectionHeader('Información Básica'),
              const SizedBox(height: 16),

              // Título
              TextFormField(
                controller: _tituloController,
                decoration: InputDecoration(
                  labelText: 'Título del artículo',
                  hintText: 'Ej: Liquen Xanthoria',
                  prefixIcon: const Icon(Icons.title_rounded),
                  helperText: 'Máximo 150 caracteres',
                ),
                maxLength: 150,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El título es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Autor
              TextFormField(
                controller: _autorController,
                decoration: InputDecoration(
                  labelText: 'Autor',
                  hintText: 'Nombre del especialista',
                  prefixIcon: const Icon(Icons.person_rounded),
                  helperText: 'Quién escribió este artículo',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El autor es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Sección 2: Clasificación
              _buildSectionHeader('Clasificación'),
              const SizedBox(height: 16),

              // Categoría
              TextFormField(
                controller: _categoriaController,
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  hintText: 'Ej: Hongos, Algas, Bacterias',
                  prefixIcon: const Icon(Icons.category_rounded),
                  helperText: 'Tipo biológico del líquen',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'La categoría es requerida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Estado de publicación
              DropdownButtonFormField<String>(
                value: _estadoPublicacion,
                decoration: InputDecoration(
                  labelText: 'Estado de publicación',
                  prefixIcon: const Icon(Icons.publish_rounded),
                  helperText: 'Controla la visibilidad del artículo',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'publicado',
                    child: Text('Publicado'),
                  ),
                  DropdownMenuItem(value: 'borrador', child: Text('Borrador')),
                  DropdownMenuItem(
                    value: 'archivado',
                    child: Text('Archivado'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _estadoPublicacion = value ?? 'publicado');
                },
              ),
              const SizedBox(height: 24),

              // Sección 3: Contenido Visual
              _buildSectionHeader('Contenido Visual'),
              const SizedBox(height: 16),

              // Imagen
              TextFormField(
                controller: _imagenController,
                decoration: InputDecoration(
                  labelText: 'URL de imagen',
                  hintText: 'https://ejemplo.com/imagen.jpg',
                  prefixIcon: const Icon(Icons.image_rounded),
                  helperText: 'Imagen que represente el líquen (opcional)',
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!value.startsWith('http://') &&
                        !value.startsWith('https://')) {
                      return 'La URL debe comenzar con http:// o https://';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Sección 4: Contenido Educativo
              _buildSectionHeader('Contenido Educativo'),
              const SizedBox(height: 16),

              // Contenido
              TextFormField(
                controller: _contenidoController,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: 'Descripción detallada',
                  hintText: 'Escribe información educativa sobre el líquen...',
                  prefixIcon: const Icon(Icons.description_rounded),
                  alignLabelWithHint: true,
                  helperText: 'Mínimo 50 caracteres',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El contenido es requerido';
                  }
                  if (value.length < 50) {
                    return 'El contenido debe tener al menos 50 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _guardarArticulo,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_isLoading ? 'Guardando...' : 'Guardar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.cancel_rounded),
                      label: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}

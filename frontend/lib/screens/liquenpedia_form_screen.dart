import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../models/liquenpedia_article.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import '../widgets/app_theme.dart';

class LiquenpediaFormScreen extends StatefulWidget {
  final LiquenpediaArticle? articleToEdit;

  const LiquenpediaFormScreen({super.key, this.articleToEdit});

  @override
  State<LiquenpediaFormScreen> createState() => _LiquenpediaFormScreenState();
}

class _LiquenpediaFormScreenState extends State<LiquenpediaFormScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _tituloController;
  late TextEditingController _contenidoController;
  late TextEditingController _autorController;
  late TextEditingController _categoriaController;
  late TextEditingController _imagenController;
  File? _pickedImage;

  String _estadoPublicacion = 'borrador';
  bool _isLoading = false;

  String _translateToBackend(String estadoEs) {
    const mapping = {
      'publicado': 'published',
      'borrador': 'draft',
      'archivado': 'archived',
    };
    return mapping[estadoEs] ?? 'draft';
  }

  String _translateToFrontend(String estadoEn) {
    const mapping = {
      'published': 'publicado',
      'draft': 'borrador',
      'archived': 'archivado',
    };
    return mapping[estadoEn] ?? 'borrador';
  }

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
    _estadoPublicacion = _translateToFrontend(
      widget.articleToEdit?.estadoPublicacion ?? 'draft',
    );
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

  Future<void> _pickAndUploadImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      setState(() {
        _pickedImage = File(pickedFile.path);
        _isLoading = true;
      });

      final image = _pickedImage;
      if (image == null) return;
      final uploadedUrl = await _apiService.uploadImage(image, imageType: 'article');
      if (!mounted) return;

      setState(() {
        _imagenController.text = uploadedUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Imagen subida correctamente'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir imagen: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _guardarArticulo() async {
    final state = _formKey.currentState;
    if (state == null || !state.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final estadoBackend = _translateToBackend(_estadoPublicacion);

      if (widget.articleToEdit == null) {
        await _apiService.createLiquenpediaArticle(
          titulo: _tituloController.text,
          contenido: _contenidoController.text,
          autor: _autorController.text,
          categoria: _categoriaController.text,
          estadoPublicacion: estadoBackend,
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
        await _apiService.updateLiquenpediaArticle(
          widget.articleToEdit?.id ?? 0,
          titulo: _tituloController.text,
          contenido: _contenidoController.text,
          autor: _autorController.text,
          categoria: _categoriaController.text,
          estadoPublicacion: estadoBackend,
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionCard(
                icon: Icons.info_rounded,
                title: 'Información Básica',
                subtitle: 'Detalles fundamentales del artículo',
                color: AppTheme.primaryGreen,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _tituloController,
                      decoration: InputDecoration(
                        labelText: 'Título del artículo',
                        hintText: 'Ej: Liquen Xanthoria',
                        prefixIcon: const Icon(Icons.title_rounded),
                        helperText: 'Máximo 150 caracteres',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
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
                    TextFormField(
                      controller: _autorController,
                      decoration: InputDecoration(
                        labelText: 'Autor',
                        hintText: 'Nombre del especialista',
                        prefixIcon: const Icon(Icons.person_rounded),
                        helperText: 'Quién escribió este artículo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El autor es requerido';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms),
              const SizedBox(height: 16),
              _buildSectionCard(
                icon: Icons.category_rounded,
                title: 'Clasificación',
                subtitle: 'Taxonomía y estado del artículo',
                color: AppTheme.lightGreen,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _categoriaController,
                      decoration: InputDecoration(
                        labelText: 'Categoría',
                        hintText: 'Ej: Hongos, Algas, Bacterias',
                        prefixIcon: const Icon(Icons.category_rounded),
                        helperText: 'Tipo biológico del líquen',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'La categoría es requerida';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _estadoPublicacion,
                      decoration: InputDecoration(
                        labelText: 'Estado de publicación',
                        prefixIcon: const Icon(Icons.publish_rounded),
                        helperText: 'Controla la visibilidad del artículo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'publicado',
                          child: Text('Publicado'),
                        ),
                        DropdownMenuItem(
                          value: 'borrador',
                          child: Text('Borrador'),
                        ),
                        DropdownMenuItem(
                          value: 'archivado',
                          child: Text('Archivado'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _estadoPublicacion = value ?? 'borrador');
                      },
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms),
              const SizedBox(height: 16),
              _buildSectionCard(
                icon: Icons.image_rounded,
                title: 'Contenido Visual',
                subtitle: 'Imagen representativa del líquen',
                color: AppTheme.accentGreen,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _imagenController.text.isNotEmpty
                              ? AppTheme.primaryGreen.withValues(alpha: 0.3)
                              : AppTheme.borderColor,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (_imagenController.text.isNotEmpty || _pickedImage != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 120,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                                ),
                                child: () {
                                  final img = _pickedImage;
                                  if (img != null) {
                                    return Image.file(
                                      img,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return Image.network(
                                    AppConfig.getImageUrl(_imagenController.text),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      print('[Image.network error] liquenpedia_form_screen: ${_imagenController.text}\n$error');
                                      return Center(
                                        child: Icon(
                                          Icons.image_rounded,
                                          size: 40,
                                          color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                                        ),
                                      );
                                    },
                                  );
                                }(),
                              ),
                            )
                        else
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: AppTheme.primaryGreen.withValues(alpha: 0.04),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.cloud_upload_rounded,
                                    size: 40,
                                    color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Toca para subir una imagen',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: AppTheme.textGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _imagenController,
                            decoration: InputDecoration(
                              labelText: 'URL de imagen',
                              hintText: 'https://ejemplo.com/imagen.jpg',
                              prefixIcon: const Icon(Icons.link_rounded, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: AppTheme.backgroundColor,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _pickAndUploadImage,
                            icon: const Icon(Icons.photo_library_rounded, size: 18),
                            label: const Text('Subir desde dispositivo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryGreen,
                              side: BorderSide(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 700.ms),
              const SizedBox(height: 16),
              _buildSectionCard(
                icon: Icons.description_rounded,
                title: 'Contenido Educativo',
                subtitle: 'Información detallada sobre el líquen',
                color: AppTheme.darkGreen,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _contenidoController,
                      maxLines: 10,
                      decoration: InputDecoration(
                        labelText: 'Descripción detallada',
                        hintText: 'Escribe información educativa sobre el líquen...',
                        prefixIcon: const Icon(Icons.description_rounded, size: 20),
                        alignLabelWithHint: true,
                        helperText: 'Mínimo 50 caracteres',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        height: 1.6,
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
                  ],
                ),
              ).animate().fadeIn(duration: 800.ms),
              const SizedBox(height: 24),
              _isLoading
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Guardando artículo...',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        _buildSaveButton(),
                        const SizedBox(height: 12),
                        _buildCancelButton(),
                      ],
                    ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.06),
            color.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.2),
                      color.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _guardarArticulo,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          shadowColor: AppTheme.primaryGreen.withValues(alpha: 0.35),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Guardar artículo'),
                ],
              ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.close_rounded, size: 18),
        label: const Text('Cancelar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textGray,
          side: BorderSide(
            color: AppTheme.borderColor,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
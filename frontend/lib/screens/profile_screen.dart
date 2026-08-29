import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/profile_state.dart';
import '../state/auth_state.dart';
import '../widgets/lichen_scaffold.dart';
import '../widgets/app_theme.dart';
import '../services/navigation_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _tipoDocumentoController = TextEditingController();
  final TextEditingController _numeroDocumentoController = TextEditingController();
  final TextEditingController _fechaNacimientoController = TextEditingController();
  File? _selectedImage;
  Map<String, dynamic>? _originalProfile;

  @override
  void initState() {
    super.initState();
    LichenNavigation.instance.sync(4);
    Future.microtask(() {
      if (mounted) {
        final profileState = context.read<ProfileState>();
        if (!profileState.hasFreshData) {
          profileState.loadProfile();
        }
      }
    });
  }

  void _navigateToTab(int index) {
    LichenNavigation.instance.navigateToTab(context, index);
  }

  Future<void> _onBottomNavTap(int index) async {
    if (_hasPendingChanges()) {
      final shouldSave = await showDialog<bool>(
        context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text('Tienes cambios pendientes en tu perfil. ¿Qué deseas hacer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context, false);
              await _discardAndNavigate(index);
            },
            child: const Text('Salir sin guardar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
      );

      if (shouldSave == true) {
        await _saveAndNavigate(index);
      } else if (shouldSave == false) {
        await _discardAndNavigate(index);
      }
      return;
    }

    _navigateToTab(index);
  }

  Future<void> _saveAndNavigate(int index) async {
    await _updateProfile();
    if (!mounted) return;
    _navigateToTab(index);
  }

  Future<void> _discardAndNavigate(int index) async {
    context.read<ProfileState>().discardChanges();
    setState(() {
      _selectedImage = null;
    });
    _loadProfile();
    if (!mounted) return;
    _navigateToTab(index);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _tipoDocumentoController.dispose();
    _numeroDocumentoController.dispose();
    _fechaNacimientoController.dispose();
    super.dispose();
  }

  String _getInitial(dynamic value) {
    final s = value?.toString() ?? '';
    return s.isNotEmpty ? s[0].toUpperCase() : 'U';
  }

  Widget _buildImage(Map<String, dynamic> profile) {
    final img = _selectedImage;
    if (img != null) {
      return ClipOval(
        child: Image.file(
          img,
          fit: BoxFit.cover,
        ),
      );
    }
    final fotoPerfil = profile['foto_perfil']?.toString();
    if (fotoPerfil != null && fotoPerfil.isNotEmpty) {
      return _CachedProfileImage(imagePath: fotoPerfil);
    }
    return Center(
      child: Text(
        _getInitial(profile['nombre']),
        style: const TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (pickedFile != null && mounted) {
        final file = File(pickedFile.path);
        setState(() {
          _selectedImage = file;
        });
        context.read<ProfileState>().setPendingImage(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    final updateData = {
      'nombre': _nameController.text,
      'apellido': _lastNameController.text,
      'correo': _emailController.text,
      'telefono': _phoneController.text,
      'tipo_documento': _tipoDocumentoController.text.isEmpty ? null : _tipoDocumentoController.text,
      'numero_documento': _numeroDocumentoController.text.isEmpty ? null : _numeroDocumentoController.text,
      'fecha_nacimiento': _fechaNacimientoController.text.isEmpty ? null : _fechaNacimientoController.text,
    };

    await context.read<ProfileState>().updateProfile(updateData);
    final profile = context.read<ProfileState>().profile;
    if (profile != null) {
      _originalProfile = Map<String, dynamic>.from(profile);
      context.read<AuthState>().updateUserFromProfile(profile);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Perfil actualizado correctamente'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _selectedImage = null;
      });
    }
  }

  void _loadProfile() {
    final profile = context.read<ProfileState>().profile ?? {};
    _nameController.text = profile['nombre'] ?? '';
    _lastNameController.text = profile['apellido'] ?? '';
    _emailController.text = profile['correo'] ?? '';
    _phoneController.text = profile['telefono'] ?? '';
    _tipoDocumentoController.text = profile['tipo_documento'] ?? '';
    _numeroDocumentoController.text = profile['numero_documento'] ?? '';
    _fechaNacimientoController.text = profile['fecha_nacimiento'] ?? '';
    _originalProfile = Map<String, dynamic>.from(profile);
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _fechaNacimientoController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  bool _hasPendingChanges() {
    final profileState = context.read<ProfileState>();
    final original = _originalProfile ?? {};
    final hasImage = _selectedImage != null || profileState.pendingImage != null;

    final fieldsChanged = _nameController.text != (original['nombre'] ?? '') ||
        _lastNameController.text != (original['apellido'] ?? '') ||
        _phoneController.text != (original['telefono'] ?? '') ||
        _tipoDocumentoController.text != (original['tipo_documento'] ?? '') ||
        _numeroDocumentoController.text != (original['numero_documento'] ?? '') ||
        _fechaNacimientoController.text != (original['fecha_nacimiento'] ?? '');

    return hasImage || fieldsChanged;
  }

  @override
  Widget build(BuildContext context) {
    final profileState = context.select<ProfileState, Map<String, dynamic>?>((s) => s.profile);
    final profile = profileState ?? {};
    final isLoading = context.select<ProfileState, bool>((s) => s.loading);

    if (_nameController.text.isEmpty && profile.isNotEmpty) {
      _loadProfile();
    }

    return LichenScaffold(
      apiService: Provider.of<ApiService>(context, listen: false),
      showBottomNav: true,
      onBottomNavTap: _onBottomNavTap,
      showParticleBackground: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
Container(
                     width: 140,
                     height: 140,
                     clipBehavior: Clip.hardEdge,
                     decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryGreen, AppTheme.darkGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _buildImage(profile),
                  ),
                  const SizedBox(height: 16),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       ElevatedButton.icon(
                         style: ElevatedButton.styleFrom(
                           backgroundColor: AppTheme.primaryGreen,
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(10),
                           ),
                         ),
                         onPressed: () => _pickImage(ImageSource.gallery),
                         icon: const Icon(Icons.photo_library_rounded),
                         label: const Text('Galería'),
                       ),
                       const SizedBox(width: 12),
                       ElevatedButton.icon(
                         style: ElevatedButton.styleFrom(
                           backgroundColor: AppTheme.primaryGreen,
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(10),
                           ),
                         ),
                         onPressed: () => _pickImage(ImageSource.camera),
                         icon: const Icon(Icons.camera_alt_rounded),
                         label: const Text('Cámara'),
                       ),
                     ],
                   ),
                   if (_selectedImage != null) ...[
                     const SizedBox(height: 12),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                       decoration: BoxDecoration(
                         color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: Text(
                         'Imagen seleccionada (se guardará al presionar "Guardar cambios")',
                         style: TextStyle(
                           fontSize: 12,
                           color: AppTheme.primaryGreen,
                           fontWeight: FontWeight.w500,
                         ),
                       ),
                     ),
                   ],
                 ],
               ),
             ),
             const SizedBox(height: 36),

             Container(
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.surface,
                 borderRadius: BorderRadius.circular(16),
                 border: Border.all(
                   color: Theme.of(context).colorScheme.outlineVariant,
                   width: 1.5,
                 ),
                 boxShadow: [
                   BoxShadow(
                     color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
                     blurRadius: 10,
                     offset: const Offset(0, 4),
                   ),
                 ],
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     'Información Personal',
                     style: TextStyle(
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                       color: AppTheme.primaryGreen,
                     ),
                   ),
                   const SizedBox(height: 16),
                   _buildEditableField(
                     controller: _nameController,
                     label: 'Nombre',
                     icon: Icons.person_rounded,
                   ),
                   const SizedBox(height: 14),
                   _buildEditableField(
                     controller: _lastNameController,
                     label: 'Apellido',
                     icon: Icons.person_rounded,
                   ),
                   const SizedBox(height: 14),
                   _buildEditableField(
                     controller: _emailController,
                     label: 'Correo Electrónico',
                     icon: Icons.email_rounded,
                     readOnly: true,
                   ),
                   const SizedBox(height: 14),
                   _buildEditableField(
                     controller: _phoneController,
                     label: 'Teléfono',
                     icon: Icons.phone_rounded,
                     keyboardType: TextInputType.phone,
                   ),
                 ],
               ),
             ),
             const SizedBox(height: 20),

             Container(
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.surface,
                 borderRadius: BorderRadius.circular(16),
                 border: Border.all(
                   color: Theme.of(context).colorScheme.outlineVariant,
                   width: 1.5,
                 ),
                 boxShadow: [
                   BoxShadow(
                     color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
                     blurRadius: 10,
                     offset: const Offset(0, 4),
                   ),
                 ],
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     'Documentación',
                     style: TextStyle(
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                       color: AppTheme.primaryGreen,
                     ),
                   ),
                   const SizedBox(height: 16),
                   _buildEditableField(
                     controller: _tipoDocumentoController,
                     label: 'Tipo de Documento (CC, TI, CE, PASAPORTE)',
                     icon: Icons.card_giftcard_rounded,
                   ),
                   const SizedBox(height: 14),
                   _buildEditableField(
                     controller: _numeroDocumentoController,
                     label: 'Número de Documento',
                     icon: Icons.numbers_rounded,
                     keyboardType: TextInputType.number,
                   ),
                 ],
               ),
             ),
             const SizedBox(height: 20),

             Container(
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.surface,
                 borderRadius: BorderRadius.circular(16),
                 border: Border.all(
                   color: Theme.of(context).colorScheme.outlineVariant,
                   width: 1.5,
                 ),
                 boxShadow: [
                   BoxShadow(
                     color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
                     blurRadius: 10,
                     offset: const Offset(0, 4),
                   ),
                 ],
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     'Información Adicional',
                     style: TextStyle(
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                       color: AppTheme.primaryGreen,
                     ),
                   ),
                   const SizedBox(height: 16),
                   GestureDetector(
                     onTap: _selectDate,
                     child: Container(
                       padding: const EdgeInsets.symmetric(
                         horizontal: 16,
                         vertical: 14,
                       ),
                       decoration: BoxDecoration(
                         border: Border.all(
                           color: Theme.of(context).colorScheme.outlineVariant,
                           width: 1.5,
                         ),
                         borderRadius: BorderRadius.circular(12),
                         color: Theme.of(context).colorScheme.surfaceContainerHighest,
                       ),
                       child: Row(
                         children: [
                           Icon(
                             Icons.cake_rounded,
                             color: AppTheme.primaryGreen,
                           ),
                           const SizedBox(width: 12),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   'Fecha de Nacimiento',
                                   style: TextStyle(
                                     fontSize: 12,
                                     color: Theme.of(context).colorScheme.onSurfaceVariant,
                                     fontWeight: FontWeight.w500,
                                   ),
                                 ),
                                 const SizedBox(height: 4),
                                 Text(
                                   _fechaNacimientoController.text.isEmpty
                                       ? 'Selecciona una fecha'
                                       : _fechaNacimientoController.text,
                                   style: TextStyle(
                                     fontSize: 16,
                                     color: Theme.of(context).colorScheme.onSurface,
                                     fontWeight: FontWeight.w500,
                                   ),
                                 ),
                               ],
                             ),
                           ),
                           Icon(
                             Icons.calendar_today_rounded,
                             color: AppTheme.primaryGreen,
                             size: 20,
                           ),
                         ],
                       ),
                     ),
                   ),
                 ],
               ),
             ),
             const SizedBox(height: 28),

             SizedBox(
               width: double.infinity,
               height: 56,
               child: Container(
                 decoration: BoxDecoration(
                   gradient: LinearGradient(
                     colors: [AppTheme.primaryGreen, AppTheme.darkGreen],
                     begin: Alignment.topLeft,
                     end: Alignment.bottomRight,
                   ),
                   borderRadius: BorderRadius.circular(12),
                   boxShadow: [
                     BoxShadow(
                       color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                       blurRadius: 15,
                       offset: const Offset(0, 6),
                     ),
                   ],
                 ),
                 child: Material(
                   color: Colors.transparent,
                   child: InkWell(
                     onTap: isLoading ? null : _updateProfile,
                     borderRadius: BorderRadius.circular(12),
                     child: Center(
                       child: isLoading
                           ? SizedBox(
                               width: 24,
                               height: 24,
                               child: CircularProgressIndicator(
                                 strokeWidth: 2.5,
                                 valueColor: AlwaysStoppedAnimation<Color>(
                                   Theme.of(context).colorScheme.onPrimary,
                                 ),
                               ),
                             )
                           : Row(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 Icon(Icons.save_rounded, color: Theme.of(context).colorScheme.onPrimary),
                                 const SizedBox(width: 12),
                                 Text(
                                   'Guardar Cambios',
                                   style: TextStyle(
                                     fontSize: 16,
                                     fontWeight: FontWeight.bold,
                                     color: Theme.of(context).colorScheme.onPrimary,
                                   ),
                                 ),
                               ],
                             ),
                     ),
                   ),
                 ),
               ),
             ),
             const SizedBox(height: 16),

             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.secondaryContainer,
                 borderRadius: BorderRadius.circular(10),
                 border: Border.all(
                   color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                   width: 1,
                 ),
               ),
               child: Row(
                 children: [
                   Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSecondaryContainer),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       'Registrado: ${profile['fecha_registro'] ?? 'N/A'}',
                       style: TextStyle(
                         color: Theme.of(context).colorScheme.onSecondaryContainer,
                         fontSize: 12,
                         fontWeight: FontWeight.w500,
                       ),
                     ),
                   ),
                 ],
               ),
             ),
           ],
         ),
       ),
     );
   }

   Widget _buildEditableField({
     required TextEditingController controller,
     required String label,
     required IconData icon,
     bool readOnly = false,
     TextInputType keyboardType = TextInputType.text,
   }) {
     final colorScheme = Theme.of(context).colorScheme;
     return TextField(
       controller: controller,
       readOnly: readOnly,
       keyboardType: keyboardType,
       decoration: InputDecoration(
         labelText: label,
         prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
         border: OutlineInputBorder(
           borderRadius: BorderRadius.circular(12),
           borderSide: BorderSide(
             color: colorScheme.outlineVariant,
             width: 1.5,
           ),
         ),
         enabledBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(12),
           borderSide: BorderSide(
             color: colorScheme.outlineVariant,
             width: 1.5,
           ),
         ),
         focusedBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(12),
           borderSide: BorderSide(
             color: AppTheme.primaryGreen,
             width: 2,
           ),
         ),
         filled: true,
         fillColor: readOnly ? colorScheme.surfaceContainerHighest : colorScheme.surface,
         labelStyle: TextStyle(
           color: colorScheme.onSurfaceVariant,
           fontWeight: FontWeight.w500,
         ),
         contentPadding: const EdgeInsets.symmetric(
           vertical: 14,
           horizontal: 12,
          ),
        ),
      );
   }
}

class _CachedProfileImage extends StatefulWidget {
  final String imagePath;

  const _CachedProfileImage({required this.imagePath});

  @override
  State<_CachedProfileImage> createState() => _CachedProfileImageState();
}

class _CachedProfileImageState extends State<_CachedProfileImage> {
  Uint8List? _bytes;
  bool _loading = true;
  static final Map<String, Uint8List?> _cache = {};

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (_cache.containsKey(widget.imagePath)) {
      _bytes = _cache[widget.imagePath];
      if (mounted) setState(() => _loading = false);
      return;
    }

    final apiService = Provider.of<ApiService>(context, listen: false);

    // Diagnóstico temporal [GOOGLE-DEBUG]: confirmar qué URL intenta cargarse.
    final isRemote = widget.imagePath.startsWith('http://') ||
        widget.imagePath.startsWith('https://');
    debugPrint('[GOOGLE-DEBUG] Profile image path: ${widget.imagePath} '
        'isRemote=$isRemote');

    try {
      _bytes = await apiService.downloadImageBytes(widget.imagePath);
      if (_bytes != null) {
        _cache[widget.imagePath] = _bytes;
        debugPrint('[GOOGLE-DEBUG] Profile image cargada: '
            '${_bytes!.length} bytes');
      }
    } catch (e) {
      _bytes = null;
      debugPrint('[GOOGLE-DEBUG] Profile image error: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ));
    }
    if (_bytes != null) {
      return Image.memory(_bytes!, fit: BoxFit.cover);
    }
    return const Center(
      child: Icon(Icons.person_rounded, size: 56, color: Colors.white70),
    );
  }
}

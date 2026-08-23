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
import '../services/navigation_service.dart';
import '../routes/route_names.dart';

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
  int _selectedIndex = 4;
  Map<String, dynamic>? _originalProfile;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        final profileState = context.read<ProfileState>();
        if (!profileState.hasFreshData) {
          profileState.loadProfile();
        }
      }
    });
  }

  void _navigateToSection(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, AppRoutes.analisis);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, AppRoutes.mapa);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, AppRoutes.historial);
        break;
    }
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
                backgroundColor: const Color(0xFF2F7D32),
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

    LichenNavigation.instance.navigateTo(index);
    setState(() => _selectedIndex = index);
    _navigateToSection(index);
  }

  Future<void> _saveAndNavigate(int index) async {
    await _updateProfile();
    if (!mounted) return;
    LichenNavigation.instance.navigateTo(index);
    setState(() => _selectedIndex = index);
    _navigateToSection(index);
  }

  Future<void> _discardAndNavigate(int index) async {
    context.read<ProfileState>().discardChanges();
    setState(() {
      _selectedImage = null;
    });
    _loadProfile();
    if (!mounted) return;
    LichenNavigation.instance.navigateTo(index);
    setState(() => _selectedIndex = index);
    _navigateToSection(index);
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2F7D32),
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
      bottomNavIndex: _selectedIndex,
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2F7D32), Color(0xFF1B5E20)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2F7D32).withValues(alpha: 0.4),
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
                          backgroundColor: const Color(0xFF2F7D32),
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
                          backgroundColor: const Color(0xFF2F7D32),
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
                        color: const Color(0xFF2F7D32).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Imagen seleccionada (se guardará al presionar "Guardar cambios")',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF2F7D32),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE1E9DD),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información Personal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2F7D32),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE1E9DD),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Documentación',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2F7D32),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE1E9DD),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información Adicional',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2F7D32),
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
                          color: const Color(0xFFE1E9DD),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cake_rounded,
                            color: Color(0xFF2F7D32),
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
                                    color: Colors.grey.shade600,
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
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: Color(0xFF2F7D32),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2F7D32), Color(0xFF1B5E20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2F7D32).withValues(alpha: 0.35),
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
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_rounded, color: Colors.white),
                                SizedBox(width: 12),
                                Text(
                                  'Guardar Cambios',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.blue.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Registrado: ${profile['fecha_registro'] ?? 'N/A'}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
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
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2F7D32)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE1E9DD),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE1E9DD),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF2F7D32),
            width: 2,
          ),
        ),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
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
    try {
      _bytes = await apiService.downloadPrivateImageBytes(widget.imagePath);
      if (_bytes != null) {
        _cache[widget.imagePath] = _bytes;
      }
    } catch (_) {
      _bytes = null;
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

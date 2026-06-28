import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../routes/route_names.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const routeName = '/register';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  late TextEditingController _apellidoController;
  late TextEditingController _telefonoController;
  late TextEditingController _numeroDocumentoController;
  final ApiService _apiService = ApiService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;
  late AnimationController _animationController;
  late AnimationController _fadeController;
  
  // Enums y variables para tipo_documento y fecha_nacimiento
  final List<String> _tiposDocumento = ['CC', 'TI', 'CE', 'PASAPORTE'];
  String? _selectedTipoDocumento;
  DateTime? _selectedFechaNacimiento;
  
  // Variables de validación en tiempo real
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _apellidoError;
  String? _numeroDocumentoError;
  String? _telefonoError;
  String? _tipoDocumentoError;
  String? _fechaNacimientoError;

  @override
  void initState() {
    super.initState();
    
    // Inicializar controladores de texto
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _apellidoController = TextEditingController();
    _numeroDocumentoController = TextEditingController();
    _telefonoController = TextEditingController();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    _numeroDocumentoController.dispose();
    _apiService.dispose();
    _animationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade400 : Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ============= VALIDACIÓN CRUZADA GLOBAL EN TIEMPO REAL =============

  /// Valida TODOS los campos cuando cualquiera cambia
  void _validateAllFields() {
    setState(() {
      // Validar nombre
      if (_nameController.text.isEmpty) {
        _nameError = 'El nombre es obligatorio';
      } else if (_nameController.text.length < 2) {
        _nameError = 'El nombre debe tener al menos 2 caracteres';
      } else {
        _nameError = null;
      }

      // Validar apellido
      if (_apellidoController.text.isNotEmpty && _apellidoController.text.length < 2) {
        _apellidoError = 'El apellido debe tener al menos 2 caracteres';
      } else {
        _apellidoError = null;
      }

      // Validar email
      if (_emailController.text.isEmpty) {
        _emailError = 'El correo es obligatorio';
      } else if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(_emailController.text)) {
        _emailError = 'Correo inválido';
      } else {
        _emailError = null;
      }

      // Validar contraseña
      if (_passwordController.text.isEmpty) {
        _passwordError = 'La contraseña es obligatoria';
      } else if (_passwordController.text.length < 6) {
        _passwordError = 'Mínimo 6 caracteres';
      } else {
        _passwordError = null;
      }

      // Validar confirmación de contraseña
      if (_confirmPasswordController.text.isEmpty) {
        _confirmPasswordError = 'Confirma tu contraseña';
      } else if (_confirmPasswordController.text != _passwordController.text) {
        _confirmPasswordError = 'Las contraseñas no coinciden';
      } else {
        _confirmPasswordError = null;
      }

      // Validar tipo documento
      if (_selectedTipoDocumento != null && _numeroDocumentoController.text.isEmpty) {
        _tipoDocumentoError = 'Ingresa el número de documento';
      } else {
        _tipoDocumentoError = null;
      }

      // Validar número documento
      if (_numeroDocumentoController.text.isNotEmpty) {
        if (!RegExp(r'^\d+$').hasMatch(_numeroDocumentoController.text)) {
          _numeroDocumentoError = 'Solo se permiten números';
        } else if (_numeroDocumentoController.text.length < 5) {
          _numeroDocumentoError = 'El número debe tener al menos 5 dígitos';
        } else {
          _numeroDocumentoError = null;
        }
      } else {
        _numeroDocumentoError = null;
      }

      // Validar teléfono
      if (_telefonoController.text.isNotEmpty) {
        if (!RegExp(r'^\d+$').hasMatch(_telefonoController.text)) {
          _telefonoError = 'Solo se permiten números';
        } else if (_telefonoController.text.length < 7) {
          _telefonoError = 'El teléfono debe tener al menos 7 dígitos';
        } else {
          _telefonoError = null;
        }
      } else {
        _telefonoError = null;
      }

      // Validar fecha nacimiento (siempre válida si es null)
      _fechaNacimientoError = null;
    });
  }

  /// Verificar si el formulario es válido
  bool get _isFormValid {
    return _nameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _nameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmPasswordError == null &&
        _apellidoError == null &&
        _numeroDocumentoError == null &&
        _telefonoError == null &&
        _tipoDocumentoError == null &&
        _fechaNacimientoError == null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2F7D32),
              const Color(0xFF1B5E20),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0, end: 1).animate(
                  CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOut,
                  )),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo animado
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.4),
                                    Colors.white.withOpacity(0.1),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.2),
                                    blurRadius: 25,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_add_rounded,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // Título
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: -10, end: 1.5),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Text(
                            'Crear Cuenta',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: value,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Subtítulo
                      Text(
                        'Únete a la comunidad de observadores',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Tarjeta de formulario
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Campo de nombre
                            _buildAnimatedTextField(
                              index: 0,
                              controller: _nameController,
                              label: 'Nombre completo',
                              icon: Icons.person_rounded,
                              onChanged: (_) => _validateAllFields(),
                              errorText: _nameError,
                            ),
                            const SizedBox(height: 18),

                            // Campo de apellido
                            _buildAnimatedTextField(
                              index: 1,
                              controller: _apellidoController,
                              label: 'Apellido (opcional)',
                              icon: Icons.person_rounded,
                              onChanged: (_) => _validateAllFields(),
                              errorText: _apellidoError,
                            ),
                            const SizedBox(height: 18),

                            // Campo de tipo de documento (Dropdown)
                            _buildAnimatedDropdown(
                              index: 2,
                              label: 'Tipo de documento (opcional)',
                              icon: Icons.card_giftcard_rounded,
                              value: _selectedTipoDocumento,
                              items: _tiposDocumento,
                              errorText: _tipoDocumentoError,
                              onChanged: (value) {
                                setState(() => _selectedTipoDocumento = value);
                                _validateAllFields();
                              },
                            ),
                            const SizedBox(height: 18),

                            // Campo de número de documento
                            _buildAnimatedTextField(
                              index: 3,
                              controller: _numeroDocumentoController,
                              label: 'Número de documento (opcional)',
                              icon: Icons.numbers_rounded,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _validateAllFields(),
                              errorText: _numeroDocumentoError,
                            ),
                            const SizedBox(height: 18),

                            // Campo de teléfono
                            _buildAnimatedTextField(
                              index: 4,
                              controller: _telefonoController,
                              label: 'Teléfono (opcional)',
                              icon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) => _validateAllFields(),
                              errorText: _telefonoError,
                            ),
                            const SizedBox(height: 18),

                            // Campo de fecha de nacimiento (DatePicker)
                            _buildAnimatedDatePicker(
                              index: 5,
                              label: 'Fecha de nacimiento (opcional)',
                              icon: Icons.cake_rounded,
                              selectedDate: _selectedFechaNacimiento,
                              errorText: _fechaNacimientoError,
                              onDateSelected: (date) {
                                setState(() => _selectedFechaNacimiento = date);
                                _validateAllFields();
                              },
                            ),
                            const SizedBox(height: 18),

                            // Campo de correo
                            _buildAnimatedTextField(
                              index: 6,
                              controller: _emailController,
                              label: 'Correo electrónico',
                              icon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (_) => _validateAllFields(),
                              errorText: _emailError,
                            ),
                            const SizedBox(height: 18),

                            // Campo de contraseña
                            _buildAnimatedTextField(
                              index: 7,
                              controller: _passwordController,
                              label: 'Contraseña',
                              icon: Icons.lock_rounded,
                              obscureText: _obscurePassword,
                              onChanged: (_) => _validateAllFields(),
                              errorText: _passwordError,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: const Color(0xFF2F7D32),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Campo de confirmación de contraseña
                            _buildAnimatedTextField(
                              index: 8,
                              controller: _confirmPasswordController,
                              label: 'Confirmar contraseña',
                              icon: Icons.lock_person_rounded,
                              obscureText: _obscureConfirmPassword,
                              onChanged: (_) => _validateAllFields(),
                              errorText: _confirmPasswordError,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: const Color(0xFF2F7D32),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Create account button
                            _buildAnimatedRegisterButton(),
                            const SizedBox(height: 20),

                            // Divisor
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'Ya tienes cuenta',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Botón de inicio de sesión
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.login_rounded, size: 20),
                              label: const Text('Inicia sesión'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF2F7D32),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 24,
                                ),
                                foregroundColor: const Color(0xFF2F7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Pie de página
                      Text(
                        'Protegiendo lichen, preservando aire limpio',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTextField({
    required int index,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    String? errorText,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 120)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, color: const Color(0xFF2F7D32)),
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red.shade300 : const Color(0xFFE1E9DD),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red.shade300 : const Color(0xFFE1E9DD),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red.shade400 : const Color(0xFF2F7D32),
                  width: 2.5,
                ),
              ),
              labelStyle: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Colors.red.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    errorText,
                    style: TextStyle(
                      color: Colors.red.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDropdown({
    required int index,
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    String? errorText,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 120)),
      curve: Curves.easeOut,
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animValue)),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: errorText != null ? Colors.red.shade300 : const Color(0xFFE1E9DD),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(14),
              color: Colors.grey.shade50,
            ),
            child: DropdownButton<String>(
              value: value,
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
              underline: const SizedBox(),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2F7D32)),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hint: Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Colors.red.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    errorText,
                    style: TextStyle(
                      color: Colors.red.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDatePicker({
    required int index,
    required String label,
    required IconData icon,
    required DateTime? selectedDate,
    required Function(DateTime?) onDateSelected,
    String? errorText,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 120)),
      curve: Curves.easeOut,
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animValue)),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? DateTime.now(),
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
                    child: child!,
                  );
                },
              );
              if (pickedDate != null) {
                onDateSelected(pickedDate);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: errorText != null ? Colors.red.shade300 : const Color(0xFFE1E9DD),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(14),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFF2F7D32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedDate != null
                              ? DateFormat('dd/MM/yyyy').format(selectedDate)
                              : 'Selecciona una fecha',
                          style: TextStyle(
                            fontSize: 16,
                            color: selectedDate != null
                                ? Colors.grey.shade700
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.calendar_today, color: const Color(0xFF2F7D32), size: 20),
                ],
              ),
            ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Colors.red.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    errorText,
                    style: TextStyle(
                      color: Colors.red.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedRegisterButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
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
              color: const Color(0xFF2F7D32).withOpacity(0.35),
              blurRadius: 15,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading || !_isFormValid
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    final fullName = _nameController.text.trim();
                    final email = _emailController.text.trim();
                    final password = _passwordController.text;

                    setState(() => _loading = true);
                    try {
                      // Formatear fecha de nacimiento para enviar al backend (YYYY-MM-DD)
                      String? fechaNacimientoFormatted;
                      if (_selectedFechaNacimiento != null) {
                        fechaNacimientoFormatted = DateFormat('yyyy-MM-dd').format(_selectedFechaNacimiento!);
                      }

                      await _apiService.register(
                        fullName,
                        email,
                        password,
                        apellido: _apellidoController.text.isEmpty ? null : _apellidoController.text,
                        phone: _telefonoController.text.isEmpty ? null : _telefonoController.text,
                        tipoDocumento: _selectedTipoDocumento,
                        numeroDocumento: _numeroDocumentoController.text.isEmpty ? null : _numeroDocumentoController.text,
                        fechaNacimiento: fechaNacimientoFormatted,
                      );
                      messenger.showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.white),
                              SizedBox(width: 12),
                              Text('¡Cuenta creada! Inicia sesión ahora'),
                            ],
                          ),
                          backgroundColor: Colors.green.shade400,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                      if (!mounted) return;
                      Future.delayed(const Duration(seconds: 1), () {
                        if (mounted) navigator.pushReplacementNamed(AppRoutes.login);
                      });
                    } catch (error) {
                      if (!mounted) return;
                      final message = error is ApiException ? error.message : 'Error al crear la cuenta';
                      _showMessage(message, isError: true);
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_loading)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.9),
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    _loading ? 'Creando cuenta...' : 'Crear cuenta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _isFormValid && !_loading
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../state/auth_state.dart';
import '../../widgets/lichen_scaffold.dart';
import '../../widgets/app_theme.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/settings_widgets.dart';
import '../../routes/route_names.dart';
import 'legal_settings_screen.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Best-effort: sincroniza rol/nombre/proveedor desde /auth/me.
    unawaited(context.read<AuthState>().syncProvider());
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final isGoogle = authState.isGoogleAccount;

    return LichenScaffold(
      apiService: Provider.of<ApiService>(context, listen: false),
      showBottomNav: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Flexible(
          child: Text(
            'Privacidad y seguridad',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSection(
              title: 'Privacidad',
              children: [
                SettingsTile(
                  icon: Icons.share_rounded,
                  iconColor: const Color(0xFF4F7A45),
                  title: 'Análisis compartidos',
                  subtitle: 'Controla qué análisis pueden ver otros usuarios en el mapa',
                  onTap: () => _navigateToSharedAnalyses(context),
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.location_on_rounded,
                  iconColor: const Color(0xFFFF8F00),
                  title: 'Permisos de ubicación',
                  subtitle: 'Gestionado por los ajustes del dispositivo',
                  onTap: () => _showLocationPermissionsInfo(context),
                ),
                const SizedBox(height: 8),
                SettingsInfoTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF00897B),
                  title: 'Análisis compartidos',
                  value: 'Autor visible',
                  subtitle:
                      'Al compartir un análisis, el mapa muestra tu nombre y foto de perfil '
                      'como autor, tal como están registrados en el sistema.',
                ),
              ],
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.02),

            const SizedBox(height: 20),

            SettingsSection(
              title: 'Seguridad',
              children: [
                if (!isGoogle) ...[
                  SettingsTile(
                    icon: Icons.lock_rounded,
                    iconColor: const Color(0xFF00897B),
                    title: 'Cambiar contraseña',
                    subtitle: 'Actualiza tu credencial de acceso',
                    onTap: () => _handleChangePassword(context),
                  ),
                  const SizedBox(height: 8),
                ],
                SettingsTile(
                  icon: Icons.vpn_key_rounded,
                  iconColor: const Color(0xFF1976D2),
                  title: 'Método de inicio de sesión',
                  subtitle: isGoogle ? 'Google' : 'Correo y contraseña',
                  onTap: () => _showLoginMethodInfo(context, isGoogle),
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.devices_rounded,
                  iconColor: const Color(0xFF1976D2),
                  title: 'Sesiones activas',
                  subtitle: 'Gestiona tus sesiones iniciadas',
                  onTap: () => _navigateToSessions(context),
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.logout_rounded,
                  iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  title: 'Cerrar sesión',
                  subtitle: 'Cierra tu sesión actual en este dispositivo',
                  onTap: () async {
                    await context.read<AuthState>().logout(context);
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.login,
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.02),

            const SizedBox(height: 20),

            SettingsSection(
              title: 'Cuenta',
              children: [
                SettingsTile(
                  icon: Icons.delete_outline_rounded,
                  iconColor: AppTheme.errorColor,
                  title: 'Eliminar cuenta',
                  subtitle: 'Desactiva tu cuenta permanentemente',
                  titleColor: AppTheme.errorColor,
                  onTap: () => _handleDeleteAccount(context, isGoogle),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 150.ms).slideY(begin: 0.02),

            const SizedBox(height: 20),

            SettingsSection(
              title: 'Información',
              children: [
                SettingsTile(
                  icon: Icons.policy_rounded,
                  iconColor: const Color(0xFF1976D2),
                  title: 'Política de privacidad',
                  subtitle: 'Conoce cómo protegemos tu información',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LegalSettingsScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.help_outline_rounded,
                  iconColor: const Color(0xFFFF8F00),
                  title: 'Ayuda y soporte',
                  subtitle: 'Preguntas frecuentes y asistencia',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.helpSettings),
                ),
                const SizedBox(height: 8),
                SettingsTile(
                  icon: Icons.description_rounded,
                  iconColor: const Color(0xFF5D4037),
                  title: 'Licencias',
                  subtitle: 'Información de las dependencias utilizadas',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.licensesSettings),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideY(begin: 0.02),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _navigateToSharedAnalyses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SharedAnalysesScreen()),
    );
  }

  void _showLocationPermissionsInfo(BuildContext context) {
    SettingsDialog.showInfo(
      context: context,
      title: 'Permisos de ubicación',
      content:
          'Los permisos de ubicación se gestionan desde los ajustes de tu dispositivo. '
          'Para cambiar los permisos, ve a Ajustes > Aplicaciones > Lichen Dreams > Permisos.',
    );
  }

  void _navigateToSessions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SessionsScreen()),
    );
  }

  Future<void> _handleChangePassword(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _ChangePasswordDialog(),
    );

    if (result == true && context.mounted) {
      SettingsDialog.showInfo(
        context: context,
        title: 'Contraseña actualizada',
        content:
            'Tu contraseña ha sido cambiada exitosamente. Por favor, inicia sesión nuevamente.',
      );
      if (context.mounted) {
        await context.read<AuthState>().clearAuthState(context);
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.login,
            (route) => false,
          );
        }
      }
    }
  }

  void _showLoginMethodInfo(BuildContext context, bool isGoogle) {
    SettingsDialog.showInfo(
      context: context,
      title: 'Método de inicio de sesión',
      content: isGoogle
          ? 'Tu cuenta está vinculada con Google y no utiliza una contraseña local. '
              'Por eso la opción "Cambiar contraseña" no está disponible.'
          : 'Tu cuenta utiliza correo electrónico y contraseña para iniciar sesión.',
    );
  }

  Future<void> _handleDeleteAccount(BuildContext context, bool isGoogle) async {
    if (isGoogle) {
      SettingsDialog.showInfo(
        context: context,
        title: 'Eliminar cuenta de Google',
        content:
            'La eliminación de una cuenta de Google requiere una reautenticación con Google '
            'que actualmente no está disponible. Por seguridad, esta opción permanece '
            'deshabilitada para cuentas de Google en esta versión.',
      );
      return;
    }

    final confirm = await SettingsDialog.showConfirm(
      context: context,
      title: 'Eliminar cuenta',
      content:
          'Esta acción desactivará tu cuenta permanentemente. Tus datos se conservarán pero no podrás acceder a ellos.',
      confirmText: 'Continuar',
      cancelText: 'Cancelar',
      titleColor: AppTheme.errorColor,
    );

    if (confirm == true && context.mounted) {
      final password = await showDialog<String>(
        context: context,
        builder: (context) => const _DeleteAccountDialog(),
      );

      if (password != null && password.isNotEmpty && context.mounted) {
        try {
          final apiService = Provider.of<ApiService>(context, listen: false);
          await apiService.deleteAccount(password: password);

            if (context.mounted) {
              await context.read<AuthState>().clearAuthState(context);
              if (context.mounted) {
                SettingsDialog.showInfo(
                  context: context,
                  title: 'Cuenta eliminada',
                  content: 'Tu cuenta ha sido eliminada exitosamente.',
                );
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.login,
                    (route) => false,
                  );
                }
              }
            }
        } catch (e) {
          if (context.mounted) {
            SettingsDialog.showInfo(
              context: context,
              title: 'Error',
              content: 'No se pudo eliminar la cuenta. Verifica tu contraseña.',
            );
          }
        }
      }
    }
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _error = 'Todos los campos son obligatorios';
        _loading = false;
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _error = 'Las contraseñas no coinciden';
        _loading = false;
      });
      return;
    }

    if (newPassword.length < 6) {
      setState(() {
        _error = 'La contraseña debe tener al menos 6 caracteres';
        _loading = false;
      });
      return;
    }

    if (!newPassword.contains(RegExp(r'[^a-zA-Z0-9]'))) {
      setState(() {
        _error = 'La contraseña debe incluir al menos un carácter especial';
        _loading = false;
      });
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('ApiException: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Cambiar contraseña',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirmar nueva contraseña',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.poppins(color: AppTheme.errorColor, fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: Text('Cancelar', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _changePassword,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text('Cambiar', style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Confirmar eliminación',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppTheme.errorColor),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Text(
            'Ingresa tu contraseña para confirmar la eliminación de tu cuenta:',
            style: GoogleFonts.poppins(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('Cancelar', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _passwordController.text),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
          child: Text('Eliminar', style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    );
  }
}

class SharedAnalysesScreen extends StatefulWidget {
  const SharedAnalysesScreen({super.key});

  @override
  State<SharedAnalysesScreen> createState() => _SharedAnalysesScreenState();
}

class _SharedAnalysesScreenState extends State<SharedAnalysesScreen> {
  List<dynamic> _analyses = [];
  bool _loading = true;
  String? _error;
  Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadAnalyses();
  }

  Future<void> _loadAnalyses() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final analyses = await apiService.getMyAnalyses();
      final sharedAnalyses = analyses.where((a) {
        final visibilidad = a['visibilidad']?.toString() ?? '';
        return visibilidad == 'shared';
      }).toList();
      setState(() {
        _analyses = sharedAnalyses;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _stopSharing(Map<String, dynamic> analysis) async {
    final analysisId = analysis['id_analisis'] as int?;
    if (analysisId == null) return;

    final confirmed = await SettingsDialog.showConfirm(
      context: context,
      title: '¿Dejar de compartir este análisis?',
      content:
          'Este análisis dejará de ser visible para otros usuarios en el mapa comunitario.\n\n'
          '¿Quieres continuar?',
      confirmText: 'Dejar de compartir',
      cancelText: 'Cancelar',
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processingIds.add(analysisId));

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.updateAnalysisVisibility(analysisId, 'private');
      if (mounted) {
        AppNotification.show(context, message: 'El análisis ya no es público.');
        await _loadAnalyses();
      }
    } catch (e) {
      if (mounted) {
        AppNotification.show(
          context,
          message: 'No se pudo actualizar la visibilidad del análisis. Inténtalo nuevamente.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(analysisId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Análisis compartidos',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error: $_error',
                      style: GoogleFonts.poppins(color: AppTheme.errorColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: _analyses.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _analyses.length,
                              itemBuilder: (context, index) {
                                final analysis = _analyses[index] as Map<String, dynamic>;
                                return _buildAnalysisCard(analysis);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Text(
        'Aquí puedes administrar los análisis que has hechos públicos. '
        'Los análisis compartidos pueden aparecer en el mapa comunitario '
        'y ser visibles para otros usuarios.',
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.share_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes análisis compartidos',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando compartas un análisis desde tu historial, aparecerá aquí para que puedas administrar su visibilidad.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.history_rounded),
              label: Text('Ver mi historial', style: GoogleFonts.poppins()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
                side: const BorderSide(color: AppTheme.primaryGreen),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(Map<String, dynamic> analysis) {
    final analysisId = analysis['id_analisis'] as int?;
    final isProcessing = _processingIds.contains(analysisId);
    final resultado = analysis['resultado_ia']?.toString() ?? 'Desconocido';
    final fecha = analysis['fecha_creacion']?.toString() ?? '';
    final especie = analysis['nombre_especie']?.toString();
    final calidadAire = analysis['calidad_del_aire']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    resultado,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Compartido',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (especie != null) ...[
              const SizedBox(height: 4),
              Text(
                especie,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  fecha,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (calidadAire != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.air_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    calidadAire,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: isProcessing ? null : () => _stopSharing(analysis),
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline_rounded, size: 18),
                label: Text(
                  'Dejar de compartir',
                  style: GoogleFonts.poppins(
                    color: isProcessing ? Theme.of(context).colorScheme.onSurfaceVariant : AppTheme.errorColor,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<dynamic> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final sessions = await apiService.getSessions();
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _revokeSession(int sessionId) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.revokeSession(sessionId);
      await _loadSessions();
      if (mounted) {
        AppNotification.show(context, message: 'Sesión revocada');
      }
    } catch (e) {
      if (mounted) {
        SettingsDialog.showInfo(
          context: context,
          title: 'Error',
          content: 'No se pudo revocar la sesión.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Sesiones activas',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error: $_error',
                      style: GoogleFonts.poppins(color: AppTheme.errorColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _sessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No hay sesiones',
                          style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index] as Map<String, dynamic>;
                        final isActive = session['estado_sesion'] == 'active';
                        final dispositivo = session['dispositivo']?.toString() ?? 'Desconocido';
                        final fechaInicio = session['fecha_inicio']?.toString() ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Icon(
                              isActive ? Icons.check_circle : Icons.cancel,
                              color: isActive ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            title: Text(
                              dispositivo,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              fechaInicio,
                              style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            trailing: isActive
                                ? TextButton(
                                    onPressed: () => _revokeSession(session['id_sesion'] as int),
                                    child: Text(
                                      'Revocar',
                                      style: GoogleFonts.poppins(color: AppTheme.errorColor),
                                    ),
                                  )
                                : Chip(
                                    label: Text(
                                      session['estado_sesion']?.toString() ?? '',
                                      style: GoogleFonts.poppins(fontSize: 12),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
    );
  }
}

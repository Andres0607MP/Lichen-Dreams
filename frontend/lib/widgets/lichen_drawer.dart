import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../routes/route_names.dart';
import '../services/api_service.dart';
import '../services/navigation_service.dart';
import '../widgets/app_theme.dart';
import '../state/auth_state.dart';
import '../state/dev_tools_session.dart';

class LichenDrawer extends StatefulWidget {
  final String? userRole;
  final ApiService apiService;
  final int selectedIndex;

  const LichenDrawer({
    super.key,
    this.userRole,
    required this.apiService,
    this.selectedIndex = 0,
  });

  @override
  State<LichenDrawer> createState() => _LichenDrawerState();
}

class _LichenDrawerState extends State<LichenDrawer> {
  Timer? _longPressTimer;
  final List<LogicalKeyboardKey> _enteredSequence = [];
  static const List<LogicalKeyboardKey> _konamiCode = [
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
  ];

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _longPressTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _longPressTimer?.cancel();
        _showKonamiDialog();
      }
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _longPressTimer?.cancel();
  }

  void _showKonamiDialog() {
    _enteredSequence.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.4)),
              ),
              title: Row(
                children: [
                  Icon(Icons.developer_mode_rounded, color: AppTheme.primaryGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Activar herramientas de desarrollador',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingresa la secuencia:',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textGray,
                    ),
                  ),
                  const SizedBox(height: 12),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: List.generate(5, (index) {
                      final entered = index < _enteredSequence.length;
                      final key = entered ? _enteredSequence[index] : null;
                      IconData icon;
                      switch (key) {
                        case LogicalKeyboardKey.arrowUp:
                          icon = Icons.arrow_upward_rounded;
                          break;
                        case LogicalKeyboardKey.arrowDown:
                          icon = Icons.arrow_downward_rounded;
                          break;
                        case LogicalKeyboardKey.arrowLeft:
                          icon = Icons.arrow_back_rounded;
                          break;
                        case LogicalKeyboardKey.arrowRight:
                          icon = Icons.arrow_forward_rounded;
                          break;
                        default:
                          icon = Icons.radio_button_unchecked_rounded;
                      }
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 36,
                          decoration: BoxDecoration(
                            color: entered
                                ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                                : AppTheme.backgroundColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: entered
                                  ? AppTheme.primaryGreen
                                  : AppTheme.borderColor.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            icon,
                            size: 20,
                            color: entered ? AppTheme.primaryGreen : AppTheme.textGray,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _konamiButton(
                        icon: Icons.arrow_upward_rounded,
                        onTap: () => _handleKonamiTap(LogicalKeyboardKey.arrowUp, setModalState),
                      ),
                      _konamiButton(
                        icon: Icons.arrow_downward_rounded,
                        onTap: () => _handleKonamiTap(LogicalKeyboardKey.arrowDown, setModalState),
                      ),
                      _konamiButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => _handleKonamiTap(LogicalKeyboardKey.arrowLeft, setModalState),
                      ),
                      _konamiButton(
                        icon: Icons.arrow_forward_rounded,
                        onTap: () => _handleKonamiTap(LogicalKeyboardKey.arrowRight, setModalState),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _enteredSequence.clear();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.poppins(
                      color: AppTheme.textGray,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _konamiButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.borderColor.withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 28,
          color: AppTheme.textDark,
        ),
      ),
    );
  }

  void _handleKonamiTap(LogicalKeyboardKey key, StateSetter setModalState) {
    setModalState(() {
      _enteredSequence.add(key);
    });

    if (_enteredSequence.length == _konamiCode.length) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_enteredSequence.length == _konamiCode.length) {
          if (_listEquals(_enteredSequence, _konamiCode)) {
            DevToolsSession.instance.unlock();
            _showSuccessDialog();
          } else {
            _showErrorDialog();
          }
        }
      });
    }
  }

  bool _listEquals(List<LogicalKeyboardKey> a, List<LogicalKeyboardKey> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.3), width: 1.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 32,
                  color: AppTheme.successColor,
                ),
              ).animate().scale(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                  ),
              const SizedBox(height: 16),
              Text(
                'Mapa desarrollador desbloqueado',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ya puedes acceder a las herramientas de desarrollador.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
    });
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.3), width: 1.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.close_rounded,
                size: 32,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 12),
              Text(
                'Secuencia incorrecta',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Intenta nuevamente.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.pop(context);
        _enteredSequence.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.userRole == 'admin';
    final devUnlocked = DevToolsSession.instance.isUnlocked;

    return Drawer(
      backgroundColor: AppTheme.backgroundColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(17, 165, 185, 167)
                      .withValues(alpha: 0.1),
                  AppTheme.backgroundColor,
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo/logo.png',
                  width: 210,
                  height: 84,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                Text(
                  'Lichen Dreams',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          _buildNavItem(
            context,
            index: 0,
            icon: Icons.home_rounded,
            title: 'Inicio',
            route: AppRoutes.dashboard,
          ),
          _buildNavItem(
            context,
            index: 1,
            icon: Icons.camera_alt_rounded,
            title: 'Análisis',
            route: AppRoutes.analisis,
          ),
          _buildNavItem(
            context,
            index: 2,
            icon: Icons.map_rounded,
            title: 'Mapa',
            route: AppRoutes.mapa,
          ),
          _buildNavItem(
            context,
            index: 3,
            icon: Icons.history_rounded,
            title: 'Historial',
            route: AppRoutes.historial,
          ),
          _buildNavItem(
            context,
            index: 4,
            icon: Icons.person_rounded,
            title: 'Perfil',
            route: AppRoutes.perfil,
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.eco_rounded, color: AppTheme.primaryGreen),
            title: Text('Liquenpedia', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.liquenpedia);
            },
          ),
          if (isAdmin)
            ListTile(
              leading: Icon(
                Icons.admin_panel_settings_rounded,
                color: AppTheme.primaryGreen,
              ),
              title: Text('Administración', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminUsers);
              },
            ),
          if (isAdmin && devUnlocked)
            ListTile(
              leading: Icon(
                Icons.developer_mode_rounded,
                color: AppTheme.primaryGreen,
              ),
              title: Text('Mapa desarrollador', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.developerMap);
              },
            ),
          GestureDetector(
            onLongPressStart: _onLongPressStart,
            onLongPressEnd: _onLongPressEnd,
            child: ListTile(
              leading: Icon(Icons.settings_rounded, color: AppTheme.primaryGreen),
              title: Text('Configuración', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.configuracion);
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: AppTheme.primaryGreen),
            title: Text('Cerrar sesión', style: GoogleFonts.poppins()),
            onTap: () async {
              await context.read<AuthState>().logout(context);
              DevToolsSession.instance.lock();
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String title,
    required String route,
  }) {
    final isActive = widget.selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? AppTheme.primaryGreen : AppTheme.primaryGreen.withValues(alpha: 0.7),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: isActive ? AppTheme.textDark : AppTheme.textGray,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      tileColor: isActive ? AppTheme.primaryGreen.withValues(alpha: 0.08) : null,
      onTap: () {
        Navigator.pop(context);
        LichenNavigation.instance.navigateTo(index);
        Navigator.pushNamed(context, route);
      },
    );
  }
}

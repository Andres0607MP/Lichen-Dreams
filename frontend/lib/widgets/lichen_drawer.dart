import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../routes/route_names.dart';
import '../services/api_service.dart';
import '../widgets/app_theme.dart';

class LichenDrawer extends StatelessWidget {
  final String? userRole;
  final ApiService apiService;

  const LichenDrawer({
    super.key,
    this.userRole,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
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
          ListTile(
            leading: Icon(Icons.home_rounded, color: AppTheme.primaryGreen),
            title: Text('Inicio', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.dashboard);
            },
          ),
          ListTile(
            leading: Icon(Icons.eco_rounded, color: AppTheme.primaryGreen),
            title: Text('Lichenpedia', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.liquenpedia);
            },
          ),
          ListTile(
            leading: Icon(Icons.person_rounded, color: AppTheme.primaryGreen),
            title: Text('Perfil', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.perfil);
            },
          ),
          if (userRole == 'admin')
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
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: AppTheme.primaryGreen),
            title: Text('Cerrar sesión', style: GoogleFonts.poppins()),
            onTap: () async {
              await apiService.clearAuth();
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
}
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/analysis_record.dart';
import '../../screens/result_screen.dart';
import '../../services/api_service.dart';
import '../../state/analysis_state.dart';
import '../../state/notifications_state.dart';
import '../app_theme.dart';
import 'active_analysis_card.dart';
import 'notification_card.dart';
import 'notification_empty.dart';

class NotificationSheet extends StatefulWidget {
  const NotificationSheet({super.key});

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  String _selectedFilter = 'all';
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationsState>().loadNotifications();
      }
    });
  }

  void _selectFilter(String filter) {
    setState(() => _selectedFilter = filter);
  }

  Future<void> _markAllAsRead(NotificationsState notificationsState) async {
    await notificationsState.markAllAsRead();
  }

  Future<void> _handleClear(NotificationsState notificationsState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Limpiar notificaciones',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        content: Text(
          '¿Eliminar todas las notificaciones del centro de actividad?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.textGray,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGray,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Eliminar',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _clearing = true);
    try {
      await notificationsState.clearAllFromBackend();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notificaciones eliminadas correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar notificaciones: $e')),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> notifications,
  ) {
    switch (_selectedFilter) {
      case 'analysis':
        return notifications.where((n) => n['tipo']?.toString() == 'analysis').toList();
      case 'system':
        return notifications.where((n) => n['tipo']?.toString() != 'analysis').toList();
      case 'all':
      default:
        return notifications;
    }
  }

  List<Map<String, dynamic>> _sortByDateDesc(List<Map<String, dynamic>> notifications) {
    final sorted = List<Map<String, dynamic>>.from(notifications);
    sorted.sort((a, b) {
      final dateA = DateTime.tryParse(a['fecha']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = DateTime.tryParse(b['fecha']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });
    return sorted;
  }

  bool _shouldShowActiveCard(AnalysisState analysisState) {
    return analysisState.hasActiveAnalysis;
  }

  void _handleNotificationTap({
    required BuildContext context,
    required Map<String, dynamic> notification,
    required NotificationsState notificationsState,
    required ApiService apiService,
    required AnalysisState analysisState,
  }) async {
    final tipo = notification['tipo']?.toString() ?? 'general';
    final estado = notification['estado']?.toString() ?? '';
    final analysisId = notification['analysis_id'];
    final notificationId = notification['id']?.toString() ?? '';

    if (tipo == 'analysis' && estado == 'completed' && analysisId != null) {
      try {
        final analysisJson = await apiService.getAnalysisResult(analysisId as int);
        if (!context.mounted) return;
        final record = AnalysisRecord.fromJson(analysisJson);
        await notificationsState.markAsRead(notificationId);
        await notificationsState.markAsReadBackend(notificationId, apiService: apiService);
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(analysis: record),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar el análisis: $e')),
        );
      }
    } else if (tipo == 'analysis' && estado == 'processing') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El análisis aún está en proceso')),
      );
    } else if (tipo == 'analysis' && estado == 'failed') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El análisis falló. Intenta nuevamente.')),
      );
    } else {
      if (!context.mounted) return;
      await notificationsState.markAsRead(notificationId);
      await notificationsState.markAsReadBackend(notificationId, apiService: apiService);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsState = context.watch<NotificationsState>();
    final analysisState = context.watch<AnalysisState>();
    final apiService = Provider.of<ApiService>(context, listen: false);
    final unreadCount = notificationsState.unreadCount;
    final filteredNotifications = _applyFilter(notificationsState.notifications);
    final sortedNotifications = _sortByDateDesc(filteredNotifications);
    final showActiveCard = _shouldShowActiveCard(analysisState);
    final hasNotifications = notificationsState.notifications.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            _buildHeader(context, notificationsState, unreadCount, hasNotifications),
            _buildFilters(),
            const SizedBox(height: 4),
            if (showActiveCard)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ActiveAnalysisCard(analysisState: analysisState),
              ),
            if (sortedNotifications.isEmpty)
              Expanded(
                child: _selectedFilter == 'system'
                    ? _buildSystemEmpty()
                    : const NotificationEmpty(),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: sortedNotifications.length,
                  itemBuilder: (context, index) {
                    final notification = sortedNotifications[index];
                    return NotificationCard(
                      notification: notification,
                      index: index,
                      isLast: index == sortedNotifications.length - 1,
                      onTap: () => _handleNotificationTap(
                        context: context,
                        notification: notification,
                        notificationsState: notificationsState,
                        apiService: apiService,
                        analysisState: analysisState,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemEmpty() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.08),
                      AppTheme.lightGreen.withValues(alpha: 0.04),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.borderColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.notifications_off_outlined,
                  size: 36,
                  color: AppTheme.textGray.withValues(alpha: 0.35),
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 500.ms),
              const SizedBox(height: 20),
              Text(
                'Sin novedades del sistema',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
              const SizedBox(height: 6),
              Text(
                'No hay avisos generales en este momento',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textGray.withValues(alpha: 0.8),
                  height: 1.4,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 220.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 48,
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.borderColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, duration: 400.ms);
  }

  Widget _buildHeader(
    BuildContext context,
    NotificationsState notificationsState,
    int unreadCount,
    bool hasNotifications,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryGreen.withValues(alpha: 0.12),
                  AppTheme.lightGreen.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Centro de actividad',
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unreadCount > 0
                      ? '$unreadCount pendiente${unreadCount == 1 ? '' : 's'}'
                      : 'Todo al día',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: unreadCount > 0
                        ? AppTheme.warningColor
                        : AppTheme.textGray.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (hasNotifications)
            TextButton.icon(
              onPressed: _clearing ? null : () => _handleClear(notificationsState),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: _clearing ? AppTheme.textGray.withValues(alpha: 0.4) : AppTheme.errorColor,
              ),
              label: Text(
                _clearing ? 'Eliminando...' : 'Limpiar',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _clearing ? AppTheme.textGray.withValues(alpha: 0.4) : AppTheme.errorColor,
                ),
              ),
            ),
          if (unreadCount > 0 && !hasNotifications)
            TextButton(
              onPressed: () => _markAllAsRead(notificationsState),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Marcar todas',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          if (unreadCount > 0 && hasNotifications)
            TextButton(
              onPressed: () => _markAllAsRead(notificationsState),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Marcar todas',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 80.ms)
        .slideY(begin: 0.08, end: 0, duration: 400.ms);
  }

  Widget _buildFilters() {
    final filters = [
      {'key': 'all', 'label': 'Todas'},
      {'key': 'analysis', 'label': 'Análisis'},
      {'key': 'system', 'label': 'Sistema'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.asMap().entries.map((entry) {
            final idx = entry.key;
            final filter = entry.value;
            final isSelected = _selectedFilter == filter['key'];
            return Padding(
              padding: EdgeInsets.only(
                left: idx == 0 ? 0 : 10,
              ),
              child: _FilterChip(
                label: filter['label']!,
                isSelected: isSelected,
                onTap: () => _selectFilter(filter['key']!),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.12)
              : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryGreen
                : AppTheme.borderColor.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppTheme.primaryGreen : AppTheme.textGray,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}

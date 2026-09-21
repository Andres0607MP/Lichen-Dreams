import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import '../app_theme.dart';

String formatRelativeTime(DateTime date) {
  final now = DateTime.now().toUtc();
  final diff = now.difference(date.toUtc());

  if (diff.isNegative) {
    final abs = diff.inSeconds.abs();
    if (abs < 60) return 'ahora mismo';
    final mins = diff.inMinutes.abs();
    if (mins < 60) return 'hace $mins ${mins == 1 ? 'min' : 'min'}';
    final hours = diff.inHours.abs();
    if (hours < 24) return 'hace $hours ${hours == 1 ? 'h' : 'h'}';
    final days = diff.inDays.abs();
    if (days < 7) return 'hace $days ${days == 1 ? 'día' : 'días'}';
    final months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}, $hour12:$minute $period';
  }

  if (diff.inSeconds < 30) return 'Ahora';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return 'hace $m ${m == 1 ? 'min' : 'min'}';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return 'hace $h ${h == 1 ? 'h' : 'h'}';
  }
  if (diff.inDays == 1) return 'Ayer';
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return 'hace $d ${d == 1 ? 'día' : 'días'}';
  }
  if (diff.inDays < 30) {
    final w = (diff.inDays / 7).floor();
    return 'hace $w ${w == 1 ? 'sem' : 'sem'}';
  }
  final months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}, $hour12:$minute $period';
}

Color notificationStatusColor(String estado, String tipo) {
  switch (estado) {
    case 'completed':
      return AppTheme.successColor;
    case 'processing':
      return AppTheme.warningColor;
    case 'failed':
      return AppTheme.errorColor;
    case 'rejected':
      return AppTheme.errorColor;
    default:
      return tipo == 'analysis' ? AppTheme.primaryGreen : AppTheme.lightGreen;
  }
}

IconData notificationStatusIcon(String estado, String tipo) {
  switch (estado) {
    case 'completed':
      return Icons.check_circle_rounded;
    case 'processing':
      return Icons.pending_rounded;
    case 'failed':
      return Icons.error_rounded;
    case 'rejected':
      return Icons.error_rounded;
    default:
      return tipo == 'analysis' ? Icons.analytics_rounded : Icons.notifications_rounded;
  }
}

class NotificationCard extends StatefulWidget {
  final Map<String, dynamic> notification;
  final int index;
  final VoidCallback? onTap;
  final bool isLast;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.index,
    this.onTap,
    this.isLast = false,
  });

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  Timer? _timer;
  late DateTime _notificationDate;
  String _relativeTime = '';

  @override
  void initState() {
    super.initState();
    _parseDate();
    _updateRelativeTime();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _updateRelativeTime();
      }
    });
  }

  void _parseDate() {
    final fechaStr = widget.notification['fecha']?.toString();
    if (fechaStr != null && fechaStr.isNotEmpty) {
      try {
        final parsed = DateTime.parse(fechaStr);
        // If the parsed date is naive (no timezone info), treat as UTC
        _notificationDate = parsed.isUtc ? parsed : parsed.toUtc();
      } catch (_) {
        _notificationDate = DateTime.now().toUtc();
      }
    } else {
      _notificationDate = DateTime.now().toUtc();
    }
  }

  void _updateRelativeTime() {
    if (!mounted) return;
    setState(() {
      _relativeTime = formatRelativeTime(_notificationDate);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.notification['estado']?.toString() ?? 'general';
    final tipo = widget.notification['tipo']?.toString() ?? 'general';
    final titulo = widget.notification['titulo']?.toString() ?? 'Notificación';
    final mensaje = widget.notification['mensaje']?.toString() ?? '';
    final leida = (widget.notification['leida'] ?? true) as bool;

    final statusColor = notificationStatusColor(estado, tipo);
    final statusIcon = notificationStatusIcon(estado, tipo);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: EdgeInsets.only(
          top: widget.index == 0 ? 4 : 0,
          bottom: widget.isLast ? 0 : 10,
        ),
        decoration: BoxDecoration(
          color: leida
              ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.55)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border(
            left: BorderSide(
              color: leida ? statusColor.withValues(alpha: 0.15) : statusColor,
              width: 3,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: leida ? 0.02 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            const BoxShadow(
              color: Color(0x05000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!leida)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 8, top: 2),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                titulo,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight:
                                      leida ? FontWeight.w500 : FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (mensaje.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            mensaje,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: leida
                                  ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (_relativeTime.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _relativeTime,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: leida
                                  ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
                                  : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 420.ms, delay: Duration(milliseconds: widget.index * 70))
        .slideY(begin: 0.08, end: 0, duration: 420.ms, curve: Curves.easeOut);
  }
}

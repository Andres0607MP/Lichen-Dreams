import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/analysis_record.dart';
import '../../screens/result_screen.dart';
import '../../state/analysis_state.dart';
import '../app_theme.dart';

class ActiveAnalysisCard extends StatelessWidget {
  final AnalysisState analysisState;
  final int index;

  const ActiveAnalysisCard({
    super.key,
    required this.analysisState,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final status = analysisState.status;
    final bool isProcessing = status == 'processing';
    final bool isCompleted = status == 'completed';

    if (!isProcessing && !isCompleted) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: isProcessing ? _handleProcessingTap(context) : _handleCompletedTap(context),
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isProcessing
                ? [
                    AppTheme.primaryGreen.withValues(alpha: 0.08),
                    AppTheme.lightGreen.withValues(alpha: 0.04),
                  ]
                : [
                    AppTheme.successColor.withValues(alpha: 0.10),
                    AppTheme.successColor.withValues(alpha: 0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isProcessing ? AppTheme.warningColor : AppTheme.successColor)
                .withValues(alpha: 0.30),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isProcessing ? AppTheme.warningColor : AppTheme.successColor)
                  .withValues(alpha: isProcessing ? 0.08 : 0.10),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: (isProcessing ? AppTheme.warningColor : AppTheme.successColor)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isProcessing ? AppTheme.warningColor : AppTheme.successColor)
                          .withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isProcessing ? Icons.science_rounded : Icons.check_circle_rounded,
                    color: isProcessing ? AppTheme.warningColor : AppTheme.successColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isProcessing ? 'Analizando muestra...' : 'Tu análisis está listo',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isProcessing
                            ? 'La IA está estudiando tu muestra de líquen'
                            : 'Toca para ver el resultado del análisis',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isProcessing) ...[
              const SizedBox(height: 16),
              _buildAnimatedProgress(context),
              const SizedBox(height: 8),
              Text(
                'Progreso del análisis',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _handleCompletedTap(context),
                  icon: Icon(
                    Icons.visibility_rounded,
                    color: AppTheme.successColor,
                    size: 18,
                  ),
                  label: Text(
                    'Ver resultado',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.successColor,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.successColor.withValues(alpha: 0.10),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: Duration(milliseconds: index * 60))
        .slideY(begin: 0.08, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }

  Widget _buildAnimatedProgress(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: AppTheme.borderColor.withValues(alpha: 0.25),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: constraints.maxWidth * 0.3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(
                    colors: [
                      AppTheme.primaryGreen,
                      AppTheme.lightGreen,
                    ],
                  ),
                ),
              )
                  .animate(
                    onPlay: (controller) =>
                        controller.repeat(reverse: true, period: 1600.ms),
                  )
                  .slideX(begin: -1.2, end: 2.2, duration: 1400.ms, curve: Curves.linear),
            ),
          ],
        );
      },
    );
  }

  VoidCallback _handleProcessingTap(BuildContext context) {
    return () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El análisis aún está en proceso'),
          backgroundColor: Colors.black87,
        ),
      );
    };
  }

  VoidCallback _handleCompletedTap(BuildContext context) {
    return () async {
      try {
        final resultJson = analysisState.lastResult;
        if (resultJson == null) {
          await analysisState.refreshStatus();
        }
        final record = AnalysisRecord.fromJson(analysisState.lastResult ?? {});
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
          SnackBar(
            content: Text('No se pudo cargar el análisis: $e'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    };
  }
}

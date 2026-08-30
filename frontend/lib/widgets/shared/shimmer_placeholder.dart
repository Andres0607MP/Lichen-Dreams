import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../widgets/app_theme.dart';

class ArticleShimmerPlaceholder extends StatelessWidget {
  const ArticleShimmerPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder (16:9, coherente con ArticleCard)
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: AppTheme.borderColor.withValues(alpha: 0.3),
              ).animate().shimmer(duration: 1500.ms, color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          // Content placeholder
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title placeholder
                Container(
                  height: 20,
                  width: double.infinity,
                  color: AppTheme.borderColor.withValues(alpha: 0.3),
                ).animate().shimmer(duration: 1200.ms, delay: 100.ms, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 8),
                // Badges placeholder
                Row(
                  children: [
                    Container(
                      height: 20,
                      width: 80,
                      color: AppTheme.borderColor.withValues(alpha: 0.3),
                    ).animate().shimmer(duration: 1000.ms, delay: 200.ms, color: Colors.white.withValues(alpha: 0.1)),
                    const SizedBox(width: 8),
                    Container(
                      height: 20,
                      width: 80,
                      color: AppTheme.borderColor.withValues(alpha: 0.3),
                    ).animate().shimmer(duration: 1000.ms, delay: 300.ms, color: Colors.white.withValues(alpha: 0.1)),
                  ],
                ),
                const SizedBox(height: 12),
                // Author placeholder
                Row(
                  children: [
                    Container(
                      height: 20,
                      width: 40,
                      color: AppTheme.borderColor.withValues(alpha: 0.3),
                    ).animate().shimmer(duration: 800.ms, delay: 400.ms, color: Colors.white.withValues(alpha: 0.1)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 20,
                        width: double.infinity,
                        color: AppTheme.borderColor.withValues(alpha: 0.3),
                      ).animate().shimmer(duration: 800.ms, delay: 500.ms, color: Colors.white.withValues(alpha: 0.1)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Admin actions placeholder (if admin)
                // We'll omit for simplicity; admin actions are small
              ],
            ),
          ),
        ],
      ),
    );
  }
}
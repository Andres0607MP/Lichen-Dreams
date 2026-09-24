with open(r'C:\Users\mance\Documents\Steffi\Lichen-Dreams\frontend\lib\screens\history_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

insert_marker = """    );
  }

  Color _getMetricStrokeColor"""

new_marker = """    );
  }

  Future<void> _showAnalysisActionSheet({
    required AnalysisRecord record,
    required VoidCallback onViewAnalysis,
    required VoidCallback onViewChart,
    required VoidCallback? onDelete,
    required VoidCallback? onViewMap,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.eco_rounded, color: AppTheme.primaryGreen, size: 26),
                      const SizedBox(width: 12),
                      Text(
                        'Opciones de análisis',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _ActionSheetTile(
                    icon: Icons.visibility_rounded,
                    label: 'Ver análisis',
                    color: AppTheme.primaryGreen,
                    onTap: () {
                      Navigator.pop(context);
                      onViewAnalysis();
                    },
                  ),
                  _ActionSheetTile(
                    icon: Icons.show_chart_rounded,
                    label: 'Ver perfil ambiental',
                    color: AppTheme.primaryGreen,
                    onTap: () {
                      Navigator.pop(context);
                      onViewChart();
                    },
                  ),
                  if (onViewMap != null)
                    _ActionSheetTile(
                      icon: Icons.map_rounded,
                      label: 'Ver en mapa',
                      color: AppTheme.primaryGreen,
                      onTap: () {
                        Navigator.pop(context);
                        onViewMap();
                      },
                    ),
                  if (onDelete != null)
                    _ActionSheetTile(
                      icon: Icons.delete_rounded,
                      label: 'Eliminar',
                      color: AppTheme.errorColor,
                      isDestructive: true,
                      onTap: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMetricStrokeColor"""

if insert_marker in content:
    content = content.replace(insert_marker, new_marker)
    with open(r'C:\Users\mance\Documents\Steffi\Lichen-Dreams\frontend\lib\screens\history_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("SUCCESS: _showAnalysisActionSheet inserted")
else:
    print("FAILED: insert marker not found")
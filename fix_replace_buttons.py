with open(r'C:\Users\mance\Documents\Steffi\Lichen-Dreams\frontend\lib\screens\history_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old = """const SizedBox(width: 10),
                  IconButton(
                    onPressed: onChartTap,
                    icon: Icon(Icons.show_chart_rounded, size: 18, color: AppTheme.primaryGreen),
                    tooltip: 'Ver perfil ambiental',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    ),
                  ),
                  if (record.isShared)
                    IconButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.mapExplorer,
                        );
                      },
                      icon: Icon(Icons.map_rounded, size: 18, color: AppTheme.primaryGreen),
                      tooltip: 'Ver en mapa',
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      ),
                    ),
                  if (onDelete != null)
                    _DeleteButton(
                      onPressed: !isDeleting ? onDelete : null,
                    ),
              ],
            ),
          ),
        ),
      ),
    ))));
  }"""

new = """const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showAnalysisActionSheet(
                      record: record,
                      onViewAnalysis: onTap!,
                      onViewChart: onChartTap,
                      onDelete: onDelete,
                      onViewMap: record.isShared
                          ? () => Navigator.pushNamed(context, AppRoutes.mapExplorer)
                          : null,
                    ),
                    icon: Icon(Icons.more_vert_rounded, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    tooltip: 'Más opciones',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ))));
  }"""

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\mance\Documents\Steffi\Lichen-Dreams\frontend\lib\screens\history_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("SUCCESS: Action buttons replaced")
else:
    print("FAILED: Pattern not found")
    # Debug
    idx = content.find('const SizedBox(width: 10),')
    if idx >= 0:
        print("First 200 chars at position:")
        print(repr(content[idx:idx+200]))
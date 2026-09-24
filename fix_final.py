with open(r'C:\Users\mance\Documents\Steffi\Lichen-Dreams\frontend\lib\screens\history_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

idx = 33786
end = content.find('              ],\n            ),', idx)
old_block = content[idx:end]

print(f"Old block length: {len(old_block)}")

new_block = """const SizedBox(width: 8),
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
                  ),"""

content = content[:idx] + new_block + content[end:]

with open(r'C:\Users\mance\Documents\Steffi\Lichen-Dreams\frontend\lib\screens\history_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("SUCCESS: Replacement done")
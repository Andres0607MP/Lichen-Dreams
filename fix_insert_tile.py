with open(r'C:\Users\mance\Documents\Steffi\Lichen-Dreams\frontend\lib\screens\history_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the exact location to insert: after the '  }' that ends _InfoChip and before '  Future<void> _deleteRecord'
insert_marker = """    );
  }

  Future<void> _deleteRecord"""

new_marker = """    );
  }

  Widget _ActionSheetTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDestructive ? color : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: isDestructive ? color.withValues(alpha: 0.08) : null,
    );
  }

  Future<void> _deleteRecord"""

if insert_marker in content:
    content = content.replace(insert_marker, new_marker)
    with open(r'C:\Users\mance\Documents\Steffi\Lichen-Dreams\frontend\lib\screens\history_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("SUCCESS: _ActionSheetTile inserted")
else:
    print("FAILED: insert marker not found")
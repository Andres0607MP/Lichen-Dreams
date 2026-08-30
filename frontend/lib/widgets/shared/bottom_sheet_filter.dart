import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../../state/articles_state.dart';

class BottomSheetFilter extends StatefulWidget {
  final void Function(String? status, List<int> categoryIds, String? sort) onApply;
  final String? initialStatus;
  final List<int> initialCategoryIds;
  final String? initialSort;

  const BottomSheetFilter({
    Key? key,
    required this.onApply,
    this.initialStatus,
    this.initialCategoryIds = const [],
    this.initialSort,
  }) : super(key: key);

  @override
  State<BottomSheetFilter> createState() => _BottomSheetFilterState();
}

class _BottomSheetFilterState extends State<BottomSheetFilter> {
  final List<String> _statusOptions = ['Publicado', 'Borrador', 'Archivado'];
  final List<String> _sortOptions = [
    'Más reciente',
    'Más antiguo',
    'Título A-Z',
    'Título Z-A',
  ];

  late String? _selectedStatus;
  late List<int> _selectedCategoryIds;
  late String? _selectedSort;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
    _selectedCategoryIds = List.of(widget.initialCategoryIds);
    _selectedSort = widget.initialSort;
  }

  @override
  Widget build(BuildContext context) {
    final articlesState = context.watch<ArticlesState>();
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtrar artículos',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Category filter
            _buildCategoryFilter(articlesState),
            const SizedBox(height: 20),
            // Status filter
            _buildStatusFilter(),
            const SizedBox(height: 20),
            // Sort filter
            _buildSortFilter(),
            const SizedBox(height: 30),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = null;
                        _selectedCategoryIds = [];
                        _selectedSort = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textGray,
                      side: BorderSide(color: AppTheme.borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(
                        _selectedStatus,
                        List.of(_selectedCategoryIds),
                        _selectedSort,
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Aplicar filtros'),
                  ),
                ),
            ],
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(ArticlesState articlesState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categoría',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todas'),
              selected: _selectedCategoryIds.isEmpty,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategoryIds = [];
                  } else {
                    // If deselecting "Todas", we need to clear? We'll handle elsewhere.
                  }
                });
              },
              selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
              labelStyle: GoogleFonts.poppins(
                color: _selectedCategoryIds.isEmpty
                    ? AppTheme.primaryGreen
                    : AppTheme.textGray,
              ),
            ),
            ...articlesState.categorias.map((categoria) {
              return ChoiceChip(
                label: Text(categoria.nombreCategoria),
                selected: _selectedCategoryIds.contains(categoria.idCategoria),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCategoryIds.add(categoria.idCategoria);
                    } else {
                      _selectedCategoryIds.remove(categoria.idCategoria);
                    }
                    // If any category selected, deselect "Todas" implicitly by clearing when applying?
                  });
                },
                selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                labelStyle: GoogleFonts.poppins(
                  color: _selectedCategoryIds.contains(categoria.idCategoria)
                      ? AppTheme.primaryGreen
                      : AppTheme.textGray,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estado',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: _selectedStatus == null,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedStatus = null;
                  }
                });
              },
              selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
              labelStyle: GoogleFonts.poppins(
                color: _selectedStatus == null
                    ? AppTheme.primaryGreen
                    : AppTheme.textGray,
              ),
            ),
            ..._statusOptions.map((status) {
              return ChoiceChip(
                label: Text(status),
                selected: _selectedStatus == status,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedStatus = status;
                    } else {
                      _selectedStatus = null;
                    }
                  });
                },
                selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                labelStyle: GoogleFonts.poppins(
                  color: _selectedStatus == status
                      ? AppTheme.primaryGreen
                      : AppTheme.textGray,
                ),
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  Widget _buildSortFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ordenar por',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _sortOptions.map((sort) {
            return ChoiceChip(
              label: Text(sort),
              selected: _selectedSort == sort,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSort = sort;
                  } else {
                    _selectedSort = null;
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
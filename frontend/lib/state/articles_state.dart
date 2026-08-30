import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/liquenpedia_article.dart';

class CategoriaArticulo {
  final int idCategoria;
  final String nombreCategoria;
  final String? descripcion;
  final String? color;
  final String? icono;
  final int orden;

  CategoriaArticulo({
    required this.idCategoria,
    required this.nombreCategoria,
    this.descripcion,
    this.color,
    this.icono,
    this.orden = 0,
  });

  factory CategoriaArticulo.fromJson(Map<String, dynamic> json) {
    return CategoriaArticulo(
      idCategoria: json['id_categoria'] as int,
      nombreCategoria: json['nombre_categoria'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      color: json['color'] as String?,
      icono: json['icono'] as String?,
      orden: json['orden'] as int? ?? 0,
    );
  }
}

class ArticlesState extends ChangeNotifier {
  final ApiService _apiService;
  ArticlesState({ApiService? apiService}) : _apiService = apiService ?? ApiService();
  List<LiquenpediaArticle> _articles = [];
  List<CategoriaArticulo> _categorias = [];
  bool _loading = false;
  bool _loadingCategorias = false;
  String? _error;
  String? _categoriasError;
  bool _isAdmin = false;
  DateTime? _lastLoadedAt;
  static const Duration _cacheDuration = Duration(seconds: 60);

  List<LiquenpediaArticle> get articles => List.unmodifiable(_articles);
  List<CategoriaArticulo> get categorias => List.unmodifiable(_categorias);
  bool get loading => _loading;
  bool get loadingCategorias => _loadingCategorias;
  String? get error => _error;
  String? get categoriasError => _categoriasError;
  bool get isAdmin => _isAdmin;
  bool get hasFreshData => _lastLoadedAt != null && DateTime.now().difference(_lastLoadedAt!) < _cacheDuration;

  Future<void> loadArticles({bool force = false}) async {
    if (_loading) return;
    if (!force && hasFreshData) return;
    setState(() => _loading = true);
    _error = null;
    try {
      final items = await _apiService.getLiquenpediaArticles();
      _articles = items.map((json) => LiquenpediaArticle.fromJson(json)).toList();
      _lastLoadedAt = DateTime.now();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> loadCategorias() async {
    if (_loadingCategorias) return;
    setState(() => _loadingCategorias = true);
    _categoriasError = null;
    try {
      final items = await _apiService.getCategoriasLiquenpedia();
      _categorias = items.map((json) => CategoriaArticulo.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      _categoriasError = e.toString();
      notifyListeners();
    } finally {
      setState(() => _loadingCategorias = false);
    }
  }

  Future<void> checkAdminRole() async {
    final role = await _apiService.getSavedRole();
    _isAdmin = role == 'admin';
    notifyListeners();
  }

  Future<void> reset() {
    _articles = [];
    _categorias = [];
    _error = null;
    _categoriasError = null;
    _loading = false;
    _loadingCategorias = false;
    _lastLoadedAt = null;
    notifyListeners();
    return Future.value();
  }

  Future<void> refresh() async {
    await loadArticles(force: true);
  }

  Future<void> createArticle({
    required String titulo,
    required String contenido,
    required String autor,
    required String categoria,
    int? idCategoria,
    required String estadoPublicacion,
    String? imagenArticulo,
    String? fotoPerfilAutor,
  }) async {
    final json = await _apiService.createLiquenpediaArticle(
      titulo: titulo,
      contenido: contenido,
      autor: autor,
      categoria: categoria,
      idCategoria: idCategoria,
      estadoPublicacion: estadoPublicacion,
      imagenArticulo: imagenArticulo,
      fotoPerfilAutor: fotoPerfilAutor,
    );
    _articles.insert(0, LiquenpediaArticle.fromJson(json));
    notifyListeners();
  }

  Future<void> updateArticle(int id, {
    String? titulo,
    String? contenido,
    String? autor,
    String? categoria,
    int? idCategoria,
    String? estadoPublicacion,
    String? imagenArticulo,
    String? fotoPerfilAutor,
  }) async {
    final json = await _apiService.updateLiquenpediaArticle(
      id,
      titulo: titulo,
      contenido: contenido,
      autor: autor,
      categoria: categoria,
      idCategoria: idCategoria,
      estadoPublicacion: estadoPublicacion,
      imagenArticulo: imagenArticulo,
      fotoPerfilAutor: fotoPerfilAutor,
    );
    final updated = LiquenpediaArticle.fromJson(json);
    final index = _articles.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _articles[index] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteArticle(int id) async {
    await _apiService.deleteLiquenpediaArticle(id);
    _articles.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  List<LiquenpediaArticle> search(String query) {
    if (query.isEmpty) return _articles;
    final q = query.toLowerCase();
    return _articles.where((a) =>
      a.titulo.toLowerCase().contains(q) ||
      a.categoria.toLowerCase().contains(q)
    ).toList();
  }

  void setState(bool Function() fn) {
    final changed = fn();
    if (changed) notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/liquenpedia_article.dart';

class ArticlesState extends ChangeNotifier {
  final ApiService _apiService;
  ArticlesState({ApiService? apiService}) : _apiService = apiService ?? ApiService();
  List<LiquenpediaArticle> _articles = [];
  bool _loading = false;
  String? _error;
  bool _isAdmin = false;
  DateTime? _lastLoadedAt;
  static const Duration _cacheDuration = Duration(seconds: 60);

  List<LiquenpediaArticle> get articles => List.unmodifiable(_articles);
  bool get loading => _loading;
  String? get error => _error;
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

  Future<void> checkAdminRole() async {
    final role = await _apiService.getSavedRole();
    _isAdmin = role == 'admin';
    notifyListeners();
  }

  Future<void> reset() {
    _articles = [];
    _error = null;
    _loading = false;
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
    required String estadoPublicacion,
    String? imagenArticulo,
  }) async {
    final json = await _apiService.createLiquenpediaArticle(
      titulo: titulo,
      contenido: contenido,
      autor: autor,
      categoria: categoria,
      estadoPublicacion: estadoPublicacion,
      imagenArticulo: imagenArticulo,
    );
    _articles.insert(0, LiquenpediaArticle.fromJson(json));
    notifyListeners();
  }

  Future<void> updateArticle(int id, {
    String? titulo,
    String? contenido,
    String? autor,
    String? categoria,
    String? estadoPublicacion,
    String? imagenArticulo,
  }) async {
    final json = await _apiService.updateLiquenpediaArticle(
      id,
      titulo: titulo,
      contenido: contenido,
      autor: autor,
      categoria: categoria,
      estadoPublicacion: estadoPublicacion,
      imagenArticulo: imagenArticulo,
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/screens/admin_species_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/state/catalog_state.dart';

class _FakeApiService extends ApiService {
  bool failCreate = false;
  bool failUpdate = false;
  int createCount = 0;
  int updateCount = 0;
  List<Map<String, dynamic>> stored = [];

  @override
  Future<List<dynamic>> getAdminSpecies() async => stored;

  @override
  Future<Map<String, dynamic>> createAdminSpecies(Map<String, dynamic> data) async {
    if (failCreate) {
      throw ApiException('Ya existe una especie con el nombre cientÃ­fico especificado');
    }
    createCount++;
    final created = <String, dynamic>{...data, 'id_especie': 1};
    stored = [created];
    return created;
  }

  @override
  Future<Map<String, dynamic>> updateAdminSpecies(int id, Map<String, dynamic> data) async {
    if (failUpdate) {
      throw ApiException('Error interno al actualizar la especie');
    }
    updateCount++;
    final updated = <String, dynamic>{...data, 'id_especie': id};
    stored = [updated];
    return updated;
  }

  @override
  Future<void> deleteAdminSpecies(int id) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  CatalogState catalog() => CatalogState(apiService: _FakeApiService());

  Widget app(CatalogState state) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: _FakeApiService()),
        ChangeNotifierProvider<CatalogState>.value(value: state),
      ],
      child: const MaterialApp(home: AdminSpeciesScreen()),
    );
  }

  testWidgets('save is disabled until required field is valid', (tester) async {
    final state = catalog();
    await tester.pumpWidget(app(state));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_rounded));
    await tester.pumpAndSettle();

    final ButtonStyleButton saveButton = tester.widget(
      find.widgetWithText(ElevatedButton, 'Crear especie'),
    );
    expect(saveButton.onPressed, isNull, reason: 'Debe estar deshabilitado con el nombre vacÃ­o');

    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tester.pump();
    final emptyAfterSpaces = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Crear especie'),
    );
    expect(emptyAfterSpaces.onPressed, isNull, reason: 'Solo espacios no debe habilitar el guardado');

    await tester.enterText(find.byType(TextFormField).first, '  Xanthoria parietina  ');
    await tester.pump();
    final validButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Crear especie'),
    );
    expect(validButton.onPressed, isNotNull, reason: 'Con nombre vÃ¡lido debe habilitarse');

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('spaces-only input is rejected and no request is sent', (tester) async {
    final api = _FakeApiService();
    final state = CatalogState(apiService: api);
    await tester.pumpWidget(app(state));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tester.pump();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Crear especie'),
    );
    expect(button.onPressed, isNull);
    expect(api.createCount, 0, reason: 'No debe enviarse peticiÃ³n con nombre invÃ¡lido');

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('backend error keeps dialog open, preserves data and shows message', (tester) async {
    final api = _FakeApiService()..failCreate = true;
    final state = CatalogState(apiService: api);
    await tester.pumpWidget(app(state));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Lobaria pulmonaria');
    await tester.enterText(find.byType(TextFormField).at(1), 'LÃ­quen pulmonar');
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear especie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ya existe una especie con el nombre cientÃ­fico especificado'),
        findsOneWidget, reason: 'Debe mostrarse el error del backend dentro del diÃ¡logo');
    expect(find.text('Nueva especie'), findsOneWidget, reason: 'El diÃ¡logo debe permanecer abierto');
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text,
      'Lobaria pulmonaria',
      reason: 'Los datos introducidos deben conservarse',
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('valid create closes dialog and calls the service once', (tester) async {
    final api = _FakeApiService();
    final state = CatalogState(apiService: api);
    await tester.pumpWidget(app(state));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '  Xanthoria parietina  ');
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear especie'));
    await tester.pumpAndSettle();

    expect(api.createCount, 1);
    expect(api.stored.first['nombre_cientifico'], 'Xanthoria parietina',
        reason: 'El payload debe enviarse con trim aplicado');
    expect(find.text('Nueva especie'), findsNothing, reason: 'El diÃ¡logo debe cerrarse al guardar');
  });

  testWidgets('editing prefills fields, trims and updates', (tester) async {
    final api = _FakeApiService()
      ..stored = [
        {
          'id_especie': 7,
          'nombre_cientifico': '  Usnea barbata  ',
          'nombre_comun': 'Barba de viejo',
          'habitat': 'Bosques',
        },
      ];
    final state = CatalogState(apiService: api);
    await tester.pumpWidget(app(state));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Editar especie'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text,
      '  Usnea barbata  ',
    );

    await tester.enterText(find.byType(TextFormField).first, '  Usnea longissima  ');
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.updateCount, 1);
    expect(api.stored.first['nombre_cientifico'], 'Usnea longissima');
    expect(api.stored.first['nombre_comun'], 'Barba de viejo');
    expect(find.text('Editar especie'), findsNothing);
  });
}

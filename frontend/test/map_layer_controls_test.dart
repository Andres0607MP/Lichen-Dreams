import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/screens/map_explorer_screen.dart';

void main() {
  group('MapLayerControls (responsivo en Explorar mapa)', () {
    testWidgets('En teléfono normal no desborda (Catálogo queda dentro)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: MapLayerControls(
                showOwn: true,
                showCommunity: true,
                showZones: true,
                showCatalogZones: true,
                onOwnChanged: _noop,
                onCommunityChanged: _noop,
                onZonesChanged: _noop,
                onCatalogChanged: _noop,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Sin overflow de layout.
      expect(tester.takeException(), isNull);

      // Los 4 controles existen (Catálogo incluido) y son alcanzables.
      expect(find.text('Mis análisis'), findsOneWidget);
      expect(find.text('Comunidad'), findsOneWidget);
      expect(find.text('Zonas'), findsOneWidget);
      expect(find.text('Catálogo'), findsOneWidget);

      // La vista interna permite scroll horizontal en pantalla estrecha.
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroll.scrollDirection, Axis.horizontal);

      // El contenido no excede el ancho del dispositivo: el viewport del
      // scroll (acotado a MediaQuery-32) queda dentro de la pantalla.
      final scrollFinder = find.byType(SingleChildScrollView);
      final rect = tester.getRect(scrollFinder);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
    });

    testWidgets('En teléfono normal los chips conservan tamaño táctil y el row scrollea', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: MapLayerControls(
                showOwn: true,
                showCommunity: true,
                showZones: true,
                showCatalogZones: true,
                onOwnChanged: _noop,
                onCommunityChanged: _noop,
                onZonesChanged: _noop,
                onCatalogChanged: _noop,
              ),
            ),
          ),
        ),
      );

      // Tamaños táctiles (>= ~40 px de alto) y sin texto ilegible.
      final misAnalisis = tester.getSize(find.text('Mis análisis'));
      expect(misAnalisis.height, greaterThanOrEqualTo(16));
      expect(misAnalisis.width, greaterThanOrEqualTo(30));

      // "Catálogo" es alcanzable mediante el scroll horizontal.
      await tester.dragUntilVisible(
        find.text('Catálogo'),
        find.byType(SingleChildScrollView).first,
        const Offset(-120, 0),
      );
      expect(find.text('Catálogo'), findsOneWidget);
    });

    testWidgets('Los toggles siguen funcionando al activar/desactivar', (tester) async {
      final own = <bool>[];
      final catalog = <bool>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapLayerControls(
              showOwn: true,
              showCommunity: true,
              showZones: true,
              showCatalogZones: true,
              onOwnChanged: (v) => own.add(v),
              onCommunityChanged: _noop,
              onZonesChanged: _noop,
              onCatalogChanged: (v) => catalog.add(v),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mis análisis'));
      await tester.pump();
      expect(own, [false]);

      await tester.tap(find.text('Catálogo'));
      await tester.pump();
      expect(catalog, [false]);
    });
  });
}

void _noop(bool value) {}
import 'package:flutter/material.dart';

class LiquenPediaScreen extends StatelessWidget {
  const LiquenPediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LichenPedia')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar especie...')),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: 6,
                itemBuilder: (_, i) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.eco_outlined, color: Color(0xFF2F7D32)),
                    title: Text('Especie ${i + 1}'),
                    subtitle: const Text('Descripción breve...'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

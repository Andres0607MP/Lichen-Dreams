import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado de Análisis')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: const Center(child: Icon(Icons.image_outlined, size: 64)),
            ),
            const SizedBox(height: 16),
            const Text('Estado estimado del líquen', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: 0.7, color: Colors.greenAccent.shade700, backgroundColor: Colors.redAccent.shade100),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.map_outlined),
              label: const Text('Ver en el mapa'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Detalles del Análisis'),
            ),
          ],
        ),
      ),
    );
  }
}

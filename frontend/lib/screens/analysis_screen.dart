import 'package:flutter/material.dart';
import 'dart:async';

import '../routes/route_names.dart';
import '../widgets/common_widgets.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with SingleTickerProviderStateMixin {
  bool _processing = false;

  void _startProcessing() async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pushNamed(context, AppRoutes.historial); // temporary route placeholder
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Análisis')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E9DD)),
              ),
              child: const Center(child: Icon(Icons.photo_camera_outlined, size: 56, color: Color(0xFF2F7D32))),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              onPressed: _processing ? null : _startProcessing,
              child: const Text('Tomar foto'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Elegir fotografía de galería'),
            ),
            const SizedBox(height: 18),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: _processing ? 1 : 0,
              child: _processing
                  ? Column(
                      children: const [
                        SizedBox(height: 12),
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Procesando imagen con IA...'),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

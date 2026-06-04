import 'package:flutter/material.dart';

class BrandHeader extends StatelessWidget {
  final double size;
  const BrandHeader({this.size = 92, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F0E7),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Icon(
            Icons.spa_rounded,
            size: 48,
            color: Color(0xFF2F7D32),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Lichen\nDreams',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(height: 1.05),
        ),
        const SizedBox(height: 8),
        const Text(
          'Lee el aire, entiende tu entorno',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool loading;
  const PrimaryButton({required this.onPressed, this.loading = false, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: const Color(0xFF295E2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      child: loading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : child,
    );
  }
}

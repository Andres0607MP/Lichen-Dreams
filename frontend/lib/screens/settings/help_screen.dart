import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      _FAQ(
        question: '¿Cómo analizo un líquen?',
        answer:
            'Desde la pantalla principal, pulsa el botón de análisis, selecciona una foto de tu galería o toma una nueva. '
            'La aplicación procesará la imagen y te mostrará el resultado junto con la calidad del aire estimada.',
      ),
      _FAQ(
        question: '¿Qué significa el resultado del análisis?',
        answer:
            'El resultado indica la especie identificada, el nivel de liquenización y la calidad del aire asociada. '
            'Los valores se generan a partir de características visuales de la imagen y modelos de inteligencia artificial.',
      ),
      _FAQ(
        question: '¿Qué son los líquenes bioindicadores?',
        answer:
            'Son organismos que reaccionan a cambios en la contaminación del aire. '
            'Su presencia, forma y color permiten estimar la calidad ambiental de una zona.',
      ),
      _FAQ(
        question: '¿Cómo funcionan los análisis compartidos?',
        answer:
            'Puedes compartir un análisis desde tu historial para que aparezca en el mapa comunitario. '
            'Otros usuarios podrán ver el resultado; tú podrás dejar de compartirlo en cualquier momento.',
      ),
      _FAQ(
        question: '¿Cómo puedo dejar de compartir un análisis?',
        answer:
            'Entra en Privacidad y seguridad > Análisis compartidos, selecciona el análisis y pulsa Dejar de compartir.',
      ),
      _FAQ(
        question: '¿Cómo cambio mi contraseña?',
        answer:
            'Entra en Privacidad y seguridad > Cambiar contraseña. Introduce tu contraseña actual y la nueva. '
            'Después deberás iniciar sesión nuevamente.',
      ),
      _FAQ(
        question: '¿Cómo cierro sesión?',
        answer:
            'Entra en Privacidad y seguridad y pulsa Cerrar sesión. Se cerrará tu sesión actual y volverás al inicio de sesión.',
      ),
      _FAQ(
        question: '¿Cómo funcionan las sesiones activas?',
        answer:
            'La sección Sesiones activas muestra los dispositivos donde has iniciado sesión. '
            'Puedes revocar cualquiera que ya no reconozcas.',
      ),
      _FAQ(
        question: '¿Cómo inicio sesión con Google?',
        answer:
            'En la pantalla de inicio, pulsa el botón Continuar con Google y autoriza el acceso con tu cuenta de Google.',
      ),
      _FAQ(
        question: '¿Qué ocurre con mi información cuando comparto un análisis?',
        answer:
            'El análisis pasa a ser visible para otros usuarios en el mapa. '
            'Además, se muestra la información de autor registrada en el sistema, como el nombre y la foto de perfil asociada al autor.',
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ayuda y soporte',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          final faq = faqs[index];
          final headerIndex = index;

          return _FAQItem(faq: faq, index: headerIndex)
              .animate()
              .fadeIn(duration: 250.ms, delay: (index * 40).ms)
              .slideY(begin: 0.04);
        },
      ),
    );
  }
}

class _FAQ {
  final String question;
  final String answer;
  const _FAQ({required this.question, required this.answer});
}

class _FAQItem extends StatelessWidget {
  final _FAQ faq;
  final int index;

  const _FAQItem({required this.faq, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('faq_$index'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppTheme.primaryGreen,
          collapsedIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
          title: Text(
            faq.question,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          children: [
            Text(
              faq.answer,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

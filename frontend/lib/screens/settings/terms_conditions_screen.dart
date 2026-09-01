import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../widgets/lichen_scaffold.dart';
import '../../widgets/app_theme.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LichenScaffold(
      apiService: Provider.of<ApiService>(context, listen: false),
      showBottomNav: false,
      bodyIsScrollable: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Términos y condiciones',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HeaderCard(),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Términos de uso',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    textTheme: GoogleFonts.poppinsTextTheme(
                      Theme.of(context).textTheme,
                    ).copyWith(
                      bodySmall: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.6,
                        color: colorScheme.onSurface,
                      ),
                      titleMedium: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    colorScheme: colorScheme,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: const [
                      _TermsSection(
                        title: '1. Aceptación de los términos',
                        content:
                            'Al acceder y utilizar Lichen Dreams, aceptas cumplir con estos términos y condiciones. '
                            'Si no estás de acuerdo con alguna parte de estos términos, no utilices la aplicación.',
                      ),
                      _TermsSection(
                        title: '2. Descripción del servicio',
                        content:
                            'Lichen Dreams es una aplicación móvil diseñada como proyecto académico (ADSO) para '
                            'analizar imágenes de líquenes y obtener una estimación de la calidad del aire asociada. '
                            'La aplicación procesa fotografías mediante modelos de inteligencia artificial y presenta '
                            'resultados informativos que no sustituyen evaluaciones ambientales profesionales.',
                      ),
                      _TermsSection(
                        title: '3. Cuenta y acceso',
                        content:
                            'Para utilizar algunas funciones, debes crear una cuenta con información veraz y actualizada. '
                            'Eres responsable de mantener la confidencialidad de tus credenciales y de todas las actividades '
                            'realizadas desde tu cuenta. Puedes iniciar sesión con correo y contraseña o mediante una cuenta de Google.',
                      ),
                      _TermsSection(
                        title: '4. Uso de la aplicación',
                        content:
                            'Te comprometes a utilizar Lichen Dreams únicamente para fines legítimos y de acuerdo con la ley. '
                            'No debes utilizar la aplicación para enviar contenido malicioso, interferir con su funcionamiento '
                            'o intentar acceder a datos o sistemas sin autorización.',
                      ),
                      _TermsSection(
                        title: '5. Análisis de líquenes y resultados de IA',
                        content:
                            'Los resultados generados por la aplicación son estimaciones automáticas basadas en modelos de '
                            'inteligencia artificial. Estos resultados pueden no ser exactos y no deben interpretarse como '
                            'certificaciones oficiales de calidad del aire. Lichen Dreams no garantiza la precisión, '
                            'fiabilidad o idoneidad de los resultados para ningún propósito específico.',
                      ),
                      _TermsSection(
                        title: '6. Contenido generado por usuarios',
                        content:
                            'Eres responsable del contenido que generes o compartas desde la aplicación, incluyendo '
                            'fotografías, nombres de análisis y cualquier información asociada. No debes compartir '
                            'contenido que sea ilegal, ofensivo o que infrinja derechos de terceros.',
                      ),
                      _TermsSection(
                        title: '7. Publicación y contenido compartido',
                        content:
                            'Puedes optar por compartir tus análisis en el mapa comunitario de Lichen Dreams. '
                            'Al hacerlo, otros usuarios podrán ver la información del análisis, incluyendo la fecha, '
                            'la calidad del aire estimada y la información de autor registrada en el sistema, como tu nombre '
                            'y tu foto de perfil. Puedes dejar de compartir un análisis en cualquier momento desde la sección '
                            'de Análisis compartidos.',
                      ),
                      _TermsSection(
                        title: '8. Privacidad y datos',
                        content:
                            'Tratamos tus datos personales conforme a la Política de privacidad de Lichen Dreams. '
                            'La información de cuenta, los análisis y los datos de perfil se almacenan en sistemas '
                            'controlados para el funcionamiento de la aplicación. Puedes solicitar la eliminación de tu '
                            'cuenta en cualquier momento desde la sección de Privacidad y seguridad.',
                      ),
                      _TermsSection(
                        title: '9. Ubicación',
                        content:
                            'Lichen Dreams puede utilizar datos de ubicación para asociar análisis a zonas ambientales '
                            'y mejorar las estimaciones de calidad del aire. Los permisos de ubicación se gestionan desde '
                            'los ajustes de tu dispositivo y puedes revocarlos en cualquier momento.',
                      ),
                      _TermsSection(
                        title: '10. Propiedad intelectual',
                        content:
                            'Lichen Dreams, su marca, diseño y código fuente están protegidos por las leyes de propiedad '
                            'intelectual aplicables. La aplicación utiliza software de código abierto cuyas licencias '
                            'puedes consultar en la sección de Licencias. No puedes copiar, modificar o distribuir la '
                            'aplicación sin autorización expresa.',
                      ),
                      _TermsSection(
                        title: '11. Limitaciones de responsabilidad',
                        content:
                            'Lichen Dreams se proporciona "tal cual", sin garantías de ningún tipo. '
                            'En la medida permitida por la ley, el equipo desarrollador no será responsable por daños '
                            'directos, indirectos o consecuentes derivados del uso o la imposibilidad de uso de la aplicación, '
                            'incluyendo decisiones tomadas a partir de los resultados de los análisis.',
                      ),
                      _TermsSection(
                        title: '12. Disponibilidad del servicio',
                        content:
                            'Nos esforzamos por mantener la aplicación disponible y funcional, pero no garantizamos '
                            'un servicio ininterrumpido. Podemos suspender, limitar o modificar funcionalidades en cualquier '
                            'momento, especialmente tratándose de un proyecto académico sujeto a cambios.',
                      ),
                      _TermsSection(
                        title: '13. Modificaciones de los términos',
                        content:
                            'Podemos actualizar estos términos para reflejar cambios en la aplicación o en los requisitos '
                            'legales. Te notificaremos sobre cambios sustanciales dentro de la propia aplicación o por '
                            'otros medios disponibles. El uso continuado de Lichen Dreams después de los cambios implica '
                            'tu aceptación de los nuevos términos.',
                      ),
                      _TermsSection(
                        title: '14. Terminación de la cuenta',
                        content:
                            'Puedes eliminar tu cuenta en cualquier momento desde la sección de Privacidad y seguridad. '
                            'La eliminación desactiva tu acceso y deja de mostrar tu información en la aplicación. '
                            'Podemos suspender o cancelar cuentas que incumplan estos términos sin previo aviso.',
                      ),
                      _TermsSection(
                        title: '15. Contacto',
                        content:
                            'Si tienes preguntas sobre estos términos, puedes contactarnos a través de los medios '
                            'disponibles en la aplicación o en los canales oficiales del proyecto.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final titleSize = isCompact ? 16.0 : 18.0;
        final subtitleSize = isCompact ? 12.0 : 13.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Términos y condiciones',
                          style: GoogleFonts.poppins(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estas condiciones regulan el uso de Lichen Dreams.',
                          style: GoogleFonts.poppins(
                            fontSize: subtitleSize,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String title;
  final String content;

  const _TermsSection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.6,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

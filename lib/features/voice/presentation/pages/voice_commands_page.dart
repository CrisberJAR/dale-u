import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:flutter/material.dart';

/// Chuleta de comandos. Los ejemplos son frases que el teléfono sí entiende.
class VoiceCommandsPage extends StatelessWidget {
  const VoiceCommandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: VendorLook.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: VendorLook.background,
        appBar: AppBar(
          backgroundColor: VendorLook.background,
          foregroundColor: VendorLook.ink,
          title: Text('Qué puedo decir', style: VendorLook.title),
        ),
        body: SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            itemCount: voiceCommandGroups.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  'Pulsa Hablar y di una frase como estas. '
                  'No hace falta decirla igual: basta con que se parezca.',
                  style: VendorLook.body,
                );
              }
              return _GroupCard(group: voiceCommandGroups[index - 1]);
            },
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final VoiceCommandGroup group;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VendorLook.surface,
        borderRadius: BorderRadius.circular(VendorLook.radius),
        border: Border.fromBorderSide(VendorLook.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(group.icon, size: 30, color: VendorLook.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: VendorLook.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final example in group.examples)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.record_voice_over,
                        size: 22,
                        color: VendorLook.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '«$example»',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: VendorLook.ink,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (group.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(group.note!, style: VendorLook.body),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un grupo de la chuleta. Los tests comprueban que los ejemplos se entiendan.
class VoiceCommandGroup {
  const VoiceCommandGroup({
    required this.title,
    required this.icon,
    required this.examples,
    this.note,
  });

  final String title;
  final IconData icon;
  final List<String> examples;
  final String? note;
}

const voiceCommandGroups = <VoiceCommandGroup>[
  VoiceCommandGroup(
    title: 'Apuntar un cliente nuevo',
    icon: Icons.person_add,
    examples: [
      'Nuevo cliente María',
      'Agregar cliente Juan teléfono 987654321',
      'Registra una nueva clienta llamada Rosa',
      'Anota un cliente Pedro 912345678',
    ],
    note: 'Si dices números al final, los guarda como teléfono.',
  ),
  VoiceCommandGroup(
    title: 'Anotar un fiado',
    icon: Icons.add_shopping_cart,
    examples: [
      'Fiado a María 5000',
      'Anota un fiado de Juan 20 soles',
      'María 10 soles de fiado',
      'Fiar a Rosa mil quinientos',
    ],
    note: 'Suma a la deuda y queda con la fecha y la hora del momento.',
  ),
  VoiceCommandGroup(
    title: 'Anotar un pago',
    icon: Icons.payments,
    examples: [
      'Pago María 100',
      'Pagó María 100',
      'Pago de Juan 5000',
      'Anota el pago de Rosa mil',
      'Juan 15 soles de pago',
    ],
    note: 'Resta de la deuda. Si paga de más, queda saldo a favor.',
  ),
  VoiceCommandGroup(
    title: 'Preguntar cuánto debe',
    icon: Icons.help_outline,
    examples: [
      'Cuánto debe María',
      'Saldo de Juan',
      'Deuda de Rosa',
      'Consulta el saldo de Pedro',
    ],
    note: 'Te lo dice en voz alta, sin abrir nada.',
  ),
  VoiceCommandGroup(
    title: 'Buscar en la lista',
    icon: Icons.search,
    examples: ['Buscar María', 'Buscar a Juan', 'Encuentra a Rosa', 'María'],
    note: 'Desde la pantalla principal abre Mis clientes ya filtrado. '
        'Basta un pedazo del nombre: «Mari» encuentra a María.',
  ),
  VoiceCommandGroup(
    title: 'Cómo decir el dinero',
    icon: Icons.attach_money,
    examples: ['cinco mil', '5000', '20 soles', 'mil quinientos'],
    note: 'Puedes decir «soles» o no decirlo: entiende las dos formas.',
  ),
  VoiceCommandGroup(
    title: 'Céntimos',
    icon: Icons.savings,
    examples: [
      'un sol cincuenta',
      'dos soles con treinta',
      'cincuenta céntimos',
      '1.50',
    ],
    note: 'Va dentro de la frase: «fiado a Ander un sol cincuenta».',
  ),
];

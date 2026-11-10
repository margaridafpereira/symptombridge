import 'package:flutter/material.dart';

import '../theme.dart';
import 'consult_screen.dart';
import 'intake_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(padding: const EdgeInsets.all(24), children: [
                const SizedBox(height: 24),
                const Row(children: [
                  Icon(Icons.record_voice_over, color: C.primary, size: 32),
                  SizedBox(width: 12),
                  Text('SymptomBridge', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 12),
                const Text(
                  'O doente descreve os sintomas por voz. A app transcreve, organiza e mostra ao médico os sinais '
                  'de alarme e as hipóteses a considerar, cada uma com as palavras de onde veio.',
                  style: TextStyle(fontSize: 16, color: C.muted, height: 1.4),
                ),
                const SizedBox(height: 28),
                _ModeCard(
                  icon: Icons.medical_services_outlined,
                  title: 'Consulta',
                  text: 'O aparelho fica na secretária e ouve a conversa. O ecrã do médico atualiza-se ao vivo.',
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ConsultScreen())),
                ),
                const SizedBox(height: 14),
                _ModeCard(
                  icon: Icons.chat_outlined,
                  title: 'Pré-consulta',
                  text: 'Na sala de espera ou em casa, o doente responde a algumas perguntas. No fim, envia ao médico.',
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const IntakeScreen())),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.shield_outlined, color: C.muted),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Projeto de portefólio, não é um dispositivo médico. O doente nunca vê hipóteses; tudo vai '
                        'para um profissional, que decide. Use casos fictícios, não dados reais de saúde.',
                        style: TextStyle(color: C.muted, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.icon, required this.title, required this.text, required this.onTap});
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: C.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: C.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(color: C.muted, height: 1.35)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: C.muted),
            ]),
          ),
        ),
      );
}

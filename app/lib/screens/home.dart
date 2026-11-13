import 'package:flutter/material.dart';

import '../clinician/clinician_screens.dart';
import '../lang.dart';
import '../theme.dart';
import 'intake_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(actions: const [LangButton()]),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(padding: const EdgeInsets.all(24), children: [
                const Row(children: [
                  Icon(Icons.record_voice_over, color: C.primary, size: 32),
                  SizedBox(width: 12),
                  Flexible(child: Text('SymptomBridge', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    'Conte-nos o que sente, por voz ou por escrito, antes da consulta. O médico recebe as suas '
                        'respostas organizadas e fica a saber o que é mais importante.',
                    'Tell us how you feel before your appointment, by voice or in writing. The doctor gets your '
                        'answers organised and knows what matters most.',
                  ),
                  style: const TextStyle(fontSize: 16, color: C.muted, height: 1.4),
                ),
                const SizedBox(height: 28),
                _ModeCard(
                  icon: Icons.chat_outlined,
                  title: context.tr('Começar a pré-consulta', 'Start the pre-visit questions'),
                  text: context.tr(
                    'Algumas perguntas simples, em poucos minutos. No fim, as respostas seguem para o médico.',
                    'A few simple questions, in a few minutes. At the end, your answers go to the doctor.',
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const IntakeScreen())),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.shield_outlined, color: C.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr(
                          'Projeto de portefólio, não é um dispositivo médico. As suas respostas vão para um '
                              'profissional, que decide. Use casos fictícios, não dados reais de saúde.',
                          'A portfolio project, not a medical device. Your answers go to a professional, who '
                              'decides. Use made-up cases, not real health data.',
                        ),
                        style: const TextStyle(color: C.muted, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 32),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.badge_outlined),
                    label: Text(context.tr('Área do profissional de saúde', 'Healthcare professionals')),
                    onPressed: () => openClinicianArea(context),
                  ),
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

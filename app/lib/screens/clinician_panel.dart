import 'package:flutter/material.dart';
import 'package:symptom_engine/symptom_engine.dart';

import '../session.dart';
import '../theme.dart';

/// The clinician's view of one patient: red flags first, then what the
/// patient said, then conditions to consider. Every item shows the words it
/// came from, so nothing has to be taken on trust.
class ClinicianPanel extends StatelessWidget {
  const ClinicianPanel({super.key, required this.session, this.onAsk});
  final Session session;

  /// Tapping a suggested question (consultation mode) hands it to the caller.
  final ValueChanged<String>? onAsk;

  @override
  Widget build(BuildContext context) {
    final a = session.assessment;
    final e = a.extraction;
    final empty = session.turns.isEmpty;

    return ListView(padding: const EdgeInsets.all(16), children: [
      _ModelStatus(session: session),
      const SizedBox(height: 12),
      if (empty)
        const _Hint('Assim que o doente falar, os sintomas, os sinais de alarme e as hipóteses aparecem aqui.')
      else ...[
        if (a.redFlags.isNotEmpty) ...[
          for (final f in a.redFlags) _RedFlagCard(flag: f),
          const SizedBox(height: 8),
        ],
        _Facts(e: e),
        _Section(
          title: 'O que o doente refere',
          child: e.present.isEmpty
              ? const _Muted('Ainda nada de clínico.')
              : Wrap(spacing: 8, runSpacing: 8, children: [for (final f in e.present) _FindingChip(f)]),
        ),
        if (e.absent.isNotEmpty)
          _Section(
            title: 'O que nega',
            child: Wrap(spacing: 8, runSpacing: 8, children: [for (final f in e.absent) _FindingChip(f)]),
          ),
        _Section(
          title: 'Hipóteses a considerar',
          trailing: 'apoio à decisão, não diagnóstico',
          child: a.hypotheses.isEmpty
              ? const _Muted('Sem informação suficiente.')
              : Column(children: [
                  for (var i = 0; i < a.hypotheses.length; i++)
                    _HypothesisCard(h: a.hypotheses[i], rank: i + 1, onAsk: onAsk),
                ]),
        ),
        if (a.merge != null && a.merge!.notes.isNotEmpty)
          _Section(
            title: 'Notas para confirmar',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final n in a.merge!.notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, size: 16, color: C.muted),
                    const SizedBox(width: 6),
                    Expanded(child: Text(n, style: const TextStyle(fontSize: 13))),
                  ]),
                ),
            ]),
          ),
      ],
      const SizedBox(height: 12),
      const _Muted('Projeto de portefólio, não é um dispositivo médico. Os sinais de alarme e as hipóteses '
          'são sugestões para um profissional confirmar.'),
    ]);
  }
}

class _ModelStatus extends StatelessWidget {
  const _ModelStatus({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = !session.usesModel
        ? (Icons.rule, C.muted, 'Só regras · modelo de linguagem não ligado')
        : session.modelRunning
            ? (Icons.auto_awesome, C.primary, 'Regras + Gemini · a analisar…')
            : session.modelError != null
                ? (Icons.cloud_off, C.urgent, 'Só regras · modelo indisponível (${session.modelError})')
                : (Icons.auto_awesome, C.primary, 'Regras + Gemini');
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600))),
      if (session.modelRunning) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
    ]);
  }
}

class _RedFlagCard extends StatelessWidget {
  const _RedFlagCard({required this.flag});
  final RedFlag flag;

  @override
  Widget build(BuildContext context) {
    final emergency = flag.urgency == Urgency.emergency;
    final color = emergency ? C.alarm : C.urgent;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border(left: BorderSide(color: color, width: 5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(emergency ? Icons.emergency : Icons.warning_amber_rounded, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(flag.pt, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Text(emergency ? 'EMERGENTE' : 'URGENTE',
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
          ]),
          const SizedBox(height: 6),
          Text(flag.actionPt, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final q in flag.evidence) _Quote(q)]),
        ]),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.e});
  final Extraction e;

  @override
  Widget build(BuildContext context) {
    final items = [
      if (e.age != null) ('Idade', '${e.age} anos'),
      if (e.temperature != null) ('Temperatura', '${e.temperature!.toStringAsFixed(1)} °C'),
      if (e.severity != null) ('Dor', '${e.severity}/10'),
      if (e.durations.isNotEmpty) ('Duração', e.durations.join(' · ')),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(spacing: 10, runSpacing: 8, children: [
        for (final (label, value) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$label  ', style: const TextStyle(color: C.muted, fontSize: 12)),
              TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ])),
          ),
      ]),
    );
  }
}

class _FindingChip extends StatelessWidget {
  const _FindingChip(this.f);
  final Finding f;

  @override
  Widget build(BuildContext context) {
    final (icon, tip) = switch (f.source) {
      FindingSource.rules => (Icons.rule, 'encontrado pelas regras'),
      FindingSource.model => (Icons.auto_awesome, 'encontrado pelo modelo de linguagem'),
      FindingSource.both => (Icons.done_all, 'regras e modelo concordam'),
    };
    final color = f.present ? C.primary : C.muted;
    return Tooltip(
      message: '«${f.evidence}» · $tip',
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
        decoration: BoxDecoration(
          color: f.present ? C.primary.withValues(alpha: 0.08) : C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(TextSpan(children: [
              TextSpan(
                text: f.concept.pt,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: f.present ? C.text : C.muted,
                  decoration: f.present ? null : TextDecoration.lineThrough,
                ),
              ),
              TextSpan(text: '  «${f.evidence}»', style: const TextStyle(color: C.muted, fontSize: 12)),
            ])),
          ),
        ]),
      ),
    );
  }
}

class _HypothesisCard extends StatelessWidget {
  const _HypothesisCard({required this.h, required this.rank, this.onAsk});
  final Hypothesis h;
  final int rank;
  final ValueChanged<String>? onAsk;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 12, backgroundColor: C.primary.withValues(alpha: 0.12),
                child: Text('$rank', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.primary))),
            const SizedBox(width: 10),
            Expanded(child: Text(h.condition.pt, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            if (h.condition.dangerous)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: C.alarm.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: const Text('não falhar', style: TextStyle(color: C.alarm, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 8),
          _Line('A favor', [for (final f in h.supporting) f.concept.pt], C.primary),
          if (h.against.isNotEmpty) _Line('Contra', [for (final f in h.against) f.concept.pt], C.urgent),
          if (h.askNext.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('Perguntar', style: TextStyle(color: C.muted, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in h.askNext.take(3))
                ActionChip(
                  avatar: const Icon(Icons.help_outline, size: 16),
                  label: Text(c.askPt!),
                  onPressed: onAsk == null ? null : () => onAsk!(c.askPt!),
                ),
            ]),
          ],
        ]),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.items, this.color);
  final String label;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$label: ', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          TextSpan(text: items.join(', '), style: const TextStyle(fontSize: 13)),
        ])),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
            Semantics(header: true, child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
            if (trailing != null) Text(trailing!, style: const TextStyle(color: C.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

class _Quote extends StatelessWidget {
  const _Quote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: C.line)),
        child: Text('«$text»', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
      );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: C.muted, fontSize: 12.5));
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
        child: Row(children: [
          const Icon(Icons.hearing, color: C.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: C.muted))),
        ]),
      );
}

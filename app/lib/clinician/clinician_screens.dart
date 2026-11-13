import 'package:flutter/material.dart';

import '../lang.dart';
import '../screens/consult_screen.dart';
import '../theme.dart';
import 'access.dart';

/// Opens [destination] if a clinician is signed in, otherwise asks for the
/// code first. Every route to the clinician's screen goes through here.
Future<void> openClinicianArea(BuildContext context, {Widget? destination}) async {
  final target = destination ?? const ClinicianHome();
  if (ClinicianAccess.instance.signedIn) {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => target));
    return;
  }
  await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ClinicianSignIn(then: target)));
}

class ClinicianSignIn extends StatefulWidget {
  const ClinicianSignIn({super.key, required this.then});
  final Widget then;

  @override
  State<ClinicianSignIn> createState() => _ClinicianSignInState();
}

class _ClinicianSignInState extends State<ClinicianSignIn> {
  final _code = TextEditingController();
  bool _wrong = false;

  void _submit() {
    if (ClinicianAccess.instance.signIn(_code.text)) {
      Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => widget.then));
    } else {
      setState(() => _wrong = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Área do profissional de saúde', 'Healthcare professionals')),
          actions: const [LangButton()],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
              const Icon(Icons.badge_outlined, size: 48, color: C.primary),
              const SizedBox(height: 16),
              Text(context.tr('Só para profissionais de saúde', 'For healthcare professionals only'),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Aqui aparecem sinais de alarme e hipóteses clínicas. Numa instituição, a entrada seria '
                      'com o login institucional.',
                  'This shows red flags and clinical hypotheses. In a hospital, you would sign in with your '
                      'institutional account.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: C.muted, height: 1.4),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _code,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: context.tr('Código de acesso', 'Access code'),
                  errorText: _wrong ? context.tr('Código errado.', 'Wrong code.') : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: _submit, child: Text(context.tr('Entrar', 'Sign in'))),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
                child: Text(
                  context.tr('Demonstração: o código é ${ClinicianAccess.demoCode}.',
                      'Demo: the code is ${ClinicianAccess.demoCode}.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.muted, fontSize: 13),
                ),
              ),
            ]),
          ),
        ),
      );
}

class ClinicianHome extends StatelessWidget {
  const ClinicianHome({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Área do profissional', 'Clinician area')),
          actions: [
            const LangButton(),
            TextButton.icon(
              icon: const Icon(Icons.logout),
              label: Text(context.tr('Sair', 'Sign out')),
              onPressed: () {
                ClinicianAccess.instance.signOut();
                Navigator.popUntil(context, (r) => r.isFirst);
              },
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListenableBuilder(
              listenable: Inbox.instance,
              builder: (context, _) {
                final items = Inbox.instance.items;
                return ListView(padding: const EdgeInsets.all(20), children: [
                  Material(
                    color: C.primary,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ConsultScreen())),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(children: [
                          const Icon(Icons.medical_services_outlined, color: Colors.white, size: 30),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(context.tr('Nova consulta', 'New consultation'),
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                  context.tr('Ouvir a conversa com o doente e ver o painel ao vivo.',
                                      'Listen to the conversation with the patient and follow the live panel.'),
                                  style: const TextStyle(color: Colors.white70)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Flexible(
                      child: Text(context.tr('Pré-consultas recebidas', 'Pre-visit answers received'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    if (items.isNotEmpty)
                      CircleAvatar(radius: 11, backgroundColor: C.primary,
                          child: Text('${items.length}', style: const TextStyle(color: Colors.white, fontSize: 12))),
                  ]),
                  const SizedBox(height: 4),
                  Text(context.tr('As que têm sinais de alarme aparecem primeiro.', 'Those with red flags come first.'),
                      style: const TextStyle(color: C.muted, fontSize: 13)),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                      child: Text(
                        context.tr(
                          'Ainda não chegou nenhuma. Para experimentar: saia, faça uma pré-consulta como doente e volte a entrar.',
                          'None yet. To try it: sign out, answer the pre-visit questions as a patient, and sign back in.',
                        ),
                        style: const TextStyle(color: C.muted),
                      ),
                    ),
                  for (final i in items) _IntakeTile(item: i),
                ]);
              },
            ),
          ),
        ),
      );
}

class _IntakeTile extends StatelessWidget {
  const _IntakeTile({required this.item});
  final SentIntake item;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final color = item.emergency ? C.alarm : (item.urgent ? C.urgent : C.primary);
    final t = item.sentAt;
    final time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: C.line)),
      color: C.surface,
      child: ListTile(
        leading: Icon(item.urgent ? Icons.warning_amber_rounded : Icons.description_outlined, color: color),
        title: Text(item.summary(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          context.tr('Enviada às $time', 'Sent at $time'),
          if (item.urgent) item.session.assessment.redFlags.map((f) => f.label(lang)).join(' · '),
        ].join(' · ')),
        trailing: IconButton(
          tooltip: context.tr('Arquivar', 'Archive'),
          icon: const Icon(Icons.archive_outlined),
          onPressed: () => Inbox.instance.remove(item),
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ConsultScreen(session: item.session))),
      ),
    );
  }
}

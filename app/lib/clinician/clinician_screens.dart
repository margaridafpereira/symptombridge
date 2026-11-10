import 'package:flutter/material.dart';

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
  String? _error;

  void _submit() {
    if (ClinicianAccess.instance.signIn(_code.text)) {
      Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => widget.then));
    } else {
      setState(() => _error = 'Código errado.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Área do profissional de saúde')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
              const Icon(Icons.badge_outlined, size: 48, color: C.primary),
              const SizedBox(height: 16),
              const Text('Só para profissionais de saúde',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'Aqui aparecem sinais de alarme e hipóteses clínicas. Numa instituição, a entrada seria '
                'com o login institucional.',
                textAlign: TextAlign.center,
                style: TextStyle(color: C.muted, height: 1.4),
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
                  labelText: 'Código de acesso',
                  errorText: _error,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: _submit, child: const Text('Entrar')),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
                child: const Text(
                  'Demonstração: o código é ${ClinicianAccess.demoCode}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.muted, fontSize: 13),
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
          title: const Text('Área do profissional'),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Sair'),
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
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(children: [
                          Icon(Icons.medical_services_outlined, color: Colors.white, size: 30),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Nova consulta',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                              SizedBox(height: 4),
                              Text('Ouvir a conversa com o doente e ver o painel ao vivo.',
                                  style: TextStyle(color: Colors.white70)),
                            ]),
                          ),
                          Icon(Icons.chevron_right, color: Colors.white),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    const Flexible(
                      child: Text('Pré-consultas recebidas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    if (items.isNotEmpty)
                      CircleAvatar(radius: 11, backgroundColor: C.primary,
                          child: Text('${items.length}', style: const TextStyle(color: Colors.white, fontSize: 12))),
                  ]),
                  const SizedBox(height: 4),
                  const Text('As que têm sinais de alarme aparecem primeiro.', style: TextStyle(color: C.muted, fontSize: 13)),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                      child: const Text(
                        'Ainda não chegou nenhuma. Para experimentar: saia, faça uma pré-consulta como doente e volte a entrar.',
                        style: TextStyle(color: C.muted),
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
        title: Text(item.summary, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          'Enviada às $time',
          if (item.urgent) item.session.assessment.redFlags.map((f) => f.pt).join(' · '),
        ].join(' · ')),
        trailing: IconButton(
          tooltip: 'Arquivar',
          icon: const Icon(Icons.archive_outlined),
          onPressed: () => Inbox.instance.remove(item),
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ConsultScreen(session: item.session))),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:symptom_engine/symptom_engine.dart';

import '../session.dart';

/// Who may see the clinician's screen. A real deployment would use the
/// institution's sign-in (SSO, professional card); this demo uses a code that
/// is shown on the sign-in page, so anyone evaluating the project can enter.
class ClinicianAccess extends ChangeNotifier {
  ClinicianAccess._();
  static final instance = ClinicianAccess._();

  static const demoCode = '2468';

  bool _signedIn = false;
  bool get signedIn => _signedIn;

  bool signIn(String code) {
    _signedIn = code.trim() == demoCode;
    notifyListeners();
    return _signedIn;
  }

  void signOut() {
    _signedIn = false;
    notifyListeners();
  }
}

/// A pre-visit interview the patient sent.
class SentIntake {
  SentIntake(this.session, this.sentAt);
  final Session session;
  final DateTime sentAt;

  bool get emergency => session.assessment.redFlags.any((f) => f.urgency == Urgency.emergency);
  bool get urgent => session.assessment.redFlags.isNotEmpty;

  /// The first complaint the patient mentioned, for the list.
  String get summary {
    final present = session.assessment.extraction.present.toList();
    return present.isEmpty ? 'Sem sintomas identificados' : present.take(3).map((f) => f.concept.pt).join(', ');
  }
}

/// Pre-visit interviews waiting for the clinician. In this single-device demo
/// they live in memory; across devices it would be a small sync service.
class Inbox extends ChangeNotifier {
  Inbox._();
  static final instance = Inbox._();

  final _items = <SentIntake>[];

  /// Emergencies first, then urgent, then the oldest.
  List<SentIntake> get items => [..._items]..sort((a, b) {
      int rank(SentIntake i) => i.emergency ? 0 : (i.urgent ? 1 : 2);
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.sentAt.compareTo(b.sentAt);
    });

  void add(SentIntake i) {
    _items.add(i);
    notifyListeners();
  }

  @visibleForTesting
  void clear() => _items.clear();

  void remove(SentIntake i) {
    _items.remove(i);
    i.session.dispose();
    notifyListeners();
  }
}

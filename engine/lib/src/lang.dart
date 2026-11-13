/// The language of the conversation: what the patient speaks, what the
/// lexicon matches and what the screens show.
enum Lang {
  pt,
  en;

  /// Picks the text for this language.
  String pick(String pt, String en) => this == Lang.pt ? pt : en;
}

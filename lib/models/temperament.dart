/// Dog temperament categories. Drives booking rules and UI mood-picker.
///
/// The `dbValue` matches the CHECK constraint on `public.dogs.temperament`
/// (snake_case), and the rule-flag getters mirror the server-side logic
/// in the `create-booking` Edge Function.
enum Temperament {
  calm('calm', '😌'),
  playful('playful', '😄'),
  shy('shy', '😟'),
  anxious('anxious', '😰'),
  passiveAggressive('passive_aggressive', '😒'),
  reactive('reactive', '🐕‍🦺'),
  aggressive('aggressive', '😠');

  final String dbValue;
  final String emoji;
  const Temperament(this.dbValue, this.emoji);

  /// Parses the database string back into an enum, returning null for unknown
  /// or null inputs.
  static Temperament? fromDb(String? v) {
    if (v == null) return null;
    for (final t in Temperament.values) {
      if (t.dbValue == v) return t;
    }
    return null;
  }

  /// True iff bookings with this temperament require a walker with at least
  /// 3 years of experience. Currently only `aggressive`.
  bool get requiresExperiencedWalker => this == Temperament.aggressive;

  /// True iff this temperament cannot be combined with a group walk.
  /// `aggressive`, `passive_aggressive`, and `reactive` all block groups.
  bool get blocksGroupWalks =>
      this == Temperament.aggressive ||
      this == Temperament.passiveAggressive ||
      this == Temperament.reactive;
}

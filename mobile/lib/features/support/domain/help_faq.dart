/// One published help entry (Admin › FAQ, audience CUSTOMER/DRIVER/MERCHANT).
class HelpFaq {
  const HelpFaq({
    required this.id,
    required this.question,
    required this.answer,
  });

  final String id;
  final String question;
  final String answer;
}

abstract interface class HelpFaqRepository {
  /// [audience] is CUSTOMER, DRIVER or MERCHANT (the shell the user is in).
  Future<List<HelpFaq>> list({required String audience});
}

/// Nominee in an award category.
class AwardNominee {
  final String categoryId;
  final String nomineeId;
  final String displayTitle;
  final int scoreProof;
  final bool isFinalist;
  final int votes;

  const AwardNominee({
    required this.categoryId,
    required this.nomineeId,
    required this.displayTitle,
    required this.scoreProof,
    required this.isFinalist,
    this.votes = 0,
  });
}

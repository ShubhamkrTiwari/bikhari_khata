/// A suggested payment to simplify debts: [from] pays [to] the [amount].
class Settlement {
  final String from;
  final String to;
  final double amount;

  const Settlement({
    required this.from,
    required this.to,
    required this.amount,
  });
}

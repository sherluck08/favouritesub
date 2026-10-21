class PlanCard {
  final String planSize;
  final String planType;
  final String planAmount;
  final String planId;
  final String planValidity;

  PlanCard({
    required this.planSize,
    required this.planType,
    required this.planAmount,
    required this.planValidity,
    this.planId = '',
  });
}

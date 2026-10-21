import 'package:flutter/foundation.dart';
import '../models/plan_card.dart';

class PlanProvider extends ChangeNotifier {
  PlanCard? _selectedPlan;

  PlanCard? get selectedPlan => _selectedPlan;

  void setSelectedPlan(PlanCard? plan) {
    _selectedPlan = plan;
    notifyListeners();
  }
}

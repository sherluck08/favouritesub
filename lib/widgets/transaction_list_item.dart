import 'package:flutter/material.dart';
import 'package:favouritesub/utils/utils.dart';
import '../models/transaction_item.dart';

class TransactionListItem extends StatelessWidget {
  final TransactionItem item;
  final bool showPins;
  const TransactionListItem({
    super.key,
    required this.item,
    this.showPins = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = item.status == 'successful';
    final isProcessing = item.status.toLowerCase() == 'processing';
    final amountText = item.amount;
    final dateText = _formatDate(item.timestamp);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                getAssetForTransactionType(item.transactionType, item),
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    getTransactionDisplayText(item),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    dateText,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? Colors.green.shade50
                        : isProcessing
                        ? Colors.blue.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isSuccess ? 'successful' : item.status,
                    style: TextStyle(
                      color: isSuccess
                          ? Colors.green
                          : isProcessing
                          ? Colors.blue
                          : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d - $hh:$mm';
  }
}

String getTransactionDisplayText(TransactionItem item) {
  switch (item.transactionType) {
    case TransactionType.cable:
      return item.packageName ?? 'Cable Subscription';
    case TransactionType.airtime:
      return '${item.networkName} Airtime';
    case TransactionType.electricity:
      return item.packageName ?? 'Electricity';
    case TransactionType.rechargeCard:
      return '${Utils.getNetworkName(item.networkId)} Recharge Card';
    case TransactionType.exam:
      return item.examName ?? 'Exam';
    default:
      return '${item.networkName}  ${item.planSize} ${item.planType}';
  }
}

String getAssetForTransactionType(
  TransactionType transactionType,
  TransactionItem item,
) {
  switch (transactionType) {
    case TransactionType.cable:
      return Utils.getAssetForCable(item.packageName ?? '');
    case TransactionType.electricity:
      return Utils.getAssetForElectricity(item.packageName ?? '');
    case TransactionType.data:
      return Utils.logoFor(item.networkName);
    case TransactionType.airtime:
      return Utils.logoFor(item.networkName);
    case TransactionType.rechargeCard:
      return Utils.logoFor(Utils.getNetworkName(item.networkId));
    case TransactionType.exam:
      return Utils.getAssetForExam(item.examName ?? '');
    default:
      return Utils.getAssetForElectricity('');
  }
}

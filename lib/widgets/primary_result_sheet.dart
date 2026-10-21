import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DetailEntry {
  final String label;
  final String value;
  const DetailEntry(this.label, this.value);
}

Future<void> showPrimaryResultSheet(
  BuildContext context, {
  required String title,
  String? message,
  List<DetailEntry> details = const [],
  String? copySectionLabel,
  String? copyText,
  String primaryButtonLabel = 'Close',
  VoidCallback? onPrimaryPressed,
  String? secondaryButtonLabel,
  VoidCallback? onSecondaryPressed,
  IconData? icon,
  required Color color,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom + 16;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: bottomInset,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon ?? Icons.receipt_long, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (message != null && message.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(message, style: const TextStyle(color: Colors.black54)),
              ],
              if (details.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      for (int i = 0; i < details.length; i++) ...[
                        _row(details[i].label, details[i].value),
                        if (i != details.length - 1) const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ],
              if (copyText != null && copyText.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  copySectionLabel ?? 'Token',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          copyText,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: copyText),
                          );
                          if (ctx.mounted)
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Copied')),
                            );
                        },
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await Navigator.of(ctx).maybePop();
                        if (onPrimaryPressed != null) {
                          Future.microtask(onPrimaryPressed);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(primaryButtonLabel),
                    ),
                  ),
                  if (secondaryButtonLabel != null &&
                      onSecondaryPressed != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await Navigator.of(ctx).maybePop();
                          Future.microtask(onSecondaryPressed);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(secondaryButtonLabel),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _row(String label, String value) {
  return Row(
    children: [
      Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.black54,
        ),
      ),
      const Spacer(),
      Flexible(child: Text(value, textAlign: TextAlign.right)),
    ],
  );
}

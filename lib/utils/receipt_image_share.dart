import 'dart:io';
import 'dart:ui' as ui;

import 'package:favouritesub/config/brand.dart';
import 'package:favouritesub/models/transaction_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReceiptImageShare {
  const ReceiptImageShare._();

  static Future<void> share(
    BuildContext context, {
    required GlobalKey boundaryKey,
    required TransactionItem item,
  }) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('Receipt is not ready yet.');
      }

      final deviceRatio = View.of(context).devicePixelRatio;
      final image = await renderObject.toImage(
        pixelRatio: deviceRatio.clamp(2.0, 3.0).toDouble(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('Could not create receipt image.');

      final directory = await getTemporaryDirectory();
      final safeReference = item.id
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final file = File(
        '${directory.path}/${Brand.current.appName}_receipt_${safeReference.isEmpty ? DateTime.now().millisecondsSinceEpoch : safeReference}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

      if (!context.mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '${Brand.current.appName} transaction receipt',
        subject: '${Brand.current.appName} receipt',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share receipt image: $error')),
      );
    }
  }
}

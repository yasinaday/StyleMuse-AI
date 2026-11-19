import 'package:material_ui/material_ui.dart';
import 'play_billing.dart';

/// Embed only after authenticated server configuration succeeds. The parent
/// localizes labels/status, while the price itself is always supplied by Play.
class PlayBillingPacks extends StatelessWidget {
  const PlayBillingPacks(
      {super.key,
      required this.controller,
      required this.buyLabel,
      required this.unavailableLabel,
      required this.statusLabel});
  final PlayBillingController controller;
  final String buyLabel;
  final String unavailableLabel;
  final String Function(String) statusLabel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.products.isEmpty) Text(unavailableLabel),
            for (final product in controller.products)
              ListTile(
                title: Text(product.title),
                subtitle: Text(product.price),
                trailing: FilledButton(
                  onPressed: ['ready', 'credited', 'cancelled']
                          .contains(controller.state)
                      ? () => controller.buy(product)
                      : null,
                  child: Text(buyLabel),
                ),
              ),
            Text(statusLabel(controller.state)),
          ],
        ),
      );
}

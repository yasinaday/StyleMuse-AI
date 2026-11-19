import 'package:material_ui/material_ui.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'play_billing.dart';

/// Prices are never estimated: only native Play ProductDetails are payable.
class PlayBillingPacks extends StatelessWidget {
  const PlayBillingPacks(
      {super.key,
      required this.controller,
      required this.buyLabel,
      required this.unavailableLabel,
      required this.statusLabel});
  final PlayBillingController controller;
  final String buyLabel, unavailableLabel;
  final String Function(String) statusLabel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) =>
            Column(mainAxisSize: MainAxisSize.min, children: [
          for (final count in [10, 25, 50, 100, 200]) _pack(count),
          Text(statusLabel(controller.state)),
        ]),
      );

  Widget _pack(int count) {
    ProductDetails? product;
    for (final candidate in controller.products) {
      if (candidate.id == 'style_tokens_$count' ||
          candidate.id == 'tokens_$count') {
        product = candidate;
        break;
      }
    }
    final selected = product;
    final enabled = selected != null &&
        selected.price.trim().isNotEmpty &&
        ['ready', 'credited', 'cancelled'].contains(controller.state);
    return Container(
      key: ValueKey('play-pack-$count'),
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFF6DEEF), Color(0xFFE8DDF6)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDAC0E1))),
      child: ListTile(
        leading: const Icon(Icons.auto_awesome, color: Color(0xFF804483)),
        title: Text('$count Stil Jetonu',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(selected?.price.trim().isNotEmpty == true
            ? selected!.price
            : unavailableLabel),
        trailing: FilledButton(
            onPressed: enabled ? () => controller.buy(selected) : null,
            child: Text(buyLabel)),
      ),
    );
  }
}

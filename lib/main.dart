import 'package:flutter/material.dart';

void main() => runApp(const StyleMuseApp());

class StyleMuseApp extends StatelessWidget {
  const StyleMuseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StyleMuse AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9B6B80)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFFAF7),
      ),
      home: const WardrobeHome(),
    );
  }
}

class ClothingItem {
  final String name;
  final String category;
  const ClothingItem(this.name, this.category);
}

class WardrobeHome extends StatefulWidget {
  const WardrobeHome({super.key});
  @override
  State<WardrobeHome> createState() => _WardrobeHomeState();
}

class _WardrobeHomeState extends State<WardrobeHome> {
  int page = 0;
  final items = <ClothingItem>[];
  final categories = ['Top', 'Bottom', 'Dress', 'Shoes', 'Outerwear', 'Accessory'];

  Future<void> addItem() async {
    final controller = TextEditingController();
    String category = categories.first;
    final item = await showDialog<ClothingItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Add clothing'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, decoration: const InputDecoration(labelText: 'Item name')),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (value) => update(() => category = value ?? category),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) Navigator.pop(context, ClothingItem(name, category));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (item != null && mounted) setState(() => items.add(item));
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Discover', 'My Wardrobe', 'Outfits', 'Settings'];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset('assets/stylemuse-icon.png', width: 32, height: 32, excludeFromSemantics: true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('StyleMuse AI · ${titles[page]}', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: switch (page) {
          0 => ListView(padding: const EdgeInsets.all(20), children: [
            const Text('Your style, every day.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(child: ListTile(title: const Text('Your wardrobe'), subtitle: Text('${items.length} pieces added'), trailing: const Icon(Icons.chevron_right), onTap: () => setState(() => page = 1))),
            const Card(child: ListTile(title: Text('Outfit inspiration'), subtitle: Text('Build looks using clothes you own.'))),
          ]),
          1 => items.isEmpty
              ? const Center(child: Text('Your wardrobe is empty. Tap + to add clothing.'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.checkroom),
                    title: Text(items[index].name),
                    subtitle: Text(items[index].category),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => items.removeAt(index)),
                    ),
                  ),
                ),
          2 => Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(items.length < 2
                ? 'Add at least two clothing items to start creating outfits.'
                : 'Your ${items.length} items are ready. Outfit builder is coming next.',
                textAlign: TextAlign.center),
          )),
          _ => const ListView(children: [
            ListTile(title: Text('Language'), subtitle: Text('English (initial release)')),
            ListTile(title: Text('Data'), subtitle: Text('Prototype: changes are not yet saved after closing the app')),
            ListTile(title: Text('Premium'), subtitle: Text('Coming later')),
          ]),
        },
      ),
      floatingActionButton: page == 1 ? FloatingActionButton.extended(
        onPressed: addItem, icon: const Icon(Icons.add), label: const Text('Add item'),
      ) : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (value) => setState(() => page = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.checkroom_outlined), label: 'Wardrobe'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'Outfits'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

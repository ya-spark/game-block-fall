import 'package:flutter/material.dart';

import '../core/config/products.dart';
import '../core/purchase/purchase_service.dart';
import '../core/services.dart';
import 'parent_gate_dialog.dart';
import 'test_ids.dart';
import 'widgets.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shop',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: KidColors.orange,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            key: TestIds.shopRestore,
            onPressed: s.purchases.restore,
            child: const Text('Restore'),
          ),
        ],
      ),
      body: KidPage(
        child: ListenableBuilder(
          listenable: s.profile,
          builder: (context, _) {
            final products = s.purchases.products;
            if (!s.purchases.available || products.isEmpty) {
              return const Center(
                key: TestIds.shopUnavailable,
                child: Text('Store unavailable right now.'),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                for (final p in _ordered(products))
                  KidPanel(
                    child: ListTile(
                      leading: p.def.coins > 0
                          ? const CoinIcon(size: 32)
                          : null,
                      title: Text(p.def.title),
                      subtitle: Text(p.def.description),
                      trailing: _owned(s, p.def)
                          ? const Chip(label: Text('Owned'))
                          : FilledButton(
                              key: TestIds.shopBuy(p.def.id),
                              onPressed: () async {
                                if (await askParentGate(context, s)) {
                                  await s.purchases.buy(p.def.id);
                                }
                              },
                              child: Text(p.price),
                            ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Remove Ads first, then coin packs in ascending size, then anything else.
  static List<StoreProduct> _ordered(List<StoreProduct> products) {
    int rank(ProductDef d) => d.coins > 0 ? 1 : (d.grants != null ? 0 : 2);
    return [...products]..sort((a, b) {
      final r = rank(a.def).compareTo(rank(b.def));
      return r != 0 ? r : a.def.coins.compareTo(b.def.coins);
    });
  }

  bool _owned(Services s, ProductDef d) =>
      d.grants == ProductDef.removeAdsGrant && s.profile.data.adsRemoved;
}

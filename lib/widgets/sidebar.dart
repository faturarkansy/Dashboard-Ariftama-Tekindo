import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: const EdgeInsets.all(0),
        children: [
          const DrawerHeader(
            child: Text("ARIFTAMA TEKINDO"),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text("Dashboard"),
            onTap: () {
              context.go('/dashboard');
            },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text("Pesanan"),
            onTap: () {
              context.go('/pesanan');
            },
          ),
          ListTile(
            leading: const Icon(Icons.chair_rounded),
            title: const Text("Manajemen Produk"),
            onTap: () {
              context.go('/manajemen-produk');
            },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text("Manajemen Jasa"),
            onTap: () {
              context.go('/manajemen-jasa');
            },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text("Manajemen Pesan & Garansi"),
            onTap: () {
              context.go('/manajemen-pesan-garansi');
            },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text("Manajemen Customer"),
            onTap: () {
              context.go('/manajemen-customer');
            },
          ),
        ],
      ),
    );
  }
}

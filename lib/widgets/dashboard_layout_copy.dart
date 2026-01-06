import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screen/dashboard_screen.dart';
import '../screen/pesanan_screen.dart';
import '../screen/manajemen_produk_screen.dart';
import '../screen/manajemen_jasa_screen.dart';
import '../screen/manajemen_pesan_garansi_screen.dart';

class DashboardLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final String breadcrumb;
  final String currentRoute;

  const DashboardLayout({
    super.key,
    required this.child,
    required this.title,
    required this.breadcrumb,
    required this.currentRoute,
  });

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  bool _showProfileMenu = false;
  OverlayEntry? _overlayEntry;

  void _toggleMenu(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 980) {
      if (_overlayEntry == null) {
        final overlay = Overlay.of(context);
        _overlayEntry = OverlayEntry(
          builder: (context) =>
              Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        _overlayEntry?.remove();
                        _overlayEntry = null;
                      },
                      behavior: HitTestBehavior.translucent,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Positioned(
                    top: 84,
                    right: 18,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 160,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ListTile(
                              title: Text(
                                "Profile",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ListTile(
                              title: Text(
                                "Logout",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              onTap: () {
                                _overlayEntry?.remove();
                                _overlayEntry = null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        );
        overlay.insert(_overlayEntry!);
      } else {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth <= 980;

          return Row(
            children: [
              // Sidebar
              Padding(
                padding: const EdgeInsets.all(14),
                child: Container(
                  width: isCompact ? 70 : 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C684C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 22),
                      Center(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: isCompact ? 50 : 65,
                          height: isCompact ? 50 : 65,
                        ),
                      ),
                      if (!isCompact)
                        const Center(
                          child: Text(
                            'ARIFTAMA TEKINDO',
                            style: TextStyle(color: Colors.white, fontSize: 17),
                          ),
                        ),
                      const SizedBox(height: 20),
                      SidebarItem(
                        label: 'Dashboard',
                        icon: Icons.dashboard,
                        route: '/dashboard',
                        isActive: widget.currentRoute == '/dashboard',
                        compact: isCompact,
                      ),
                      SidebarItem(
                        label: 'Pesanan',
                        icon: Icons.shopping_cart,
                        route: '/pesanan',
                        isActive: widget.currentRoute == '/pesanan',
                        compact: isCompact,
                      ),
                      SidebarItem(
                        label: 'Manajemen Produk',
                        icon: Icons.chair_rounded,
                        route: '/manajemen-produk',
                        isActive: widget.currentRoute == '/manajemen-produk',
                        compact: isCompact,
                      ),
                      SidebarItem(
                        label: 'Manajemen Jasa',
                        icon: Icons.design_services_rounded,
                        route: '/manajemen-jasa',
                        isActive: widget.currentRoute == '/manajemen-jasa',
                        compact: isCompact,
                      ),
                      SidebarItem(
                        label: 'Manajemen Pesan & Garansi',
                        icon: Icons.shield_sharp,
                        route: '/manajemen-pesan-garansi',
                        isActive: widget.currentRoute == '/manajemen-pesan-garansi',
                        compact: isCompact,
                      ),
                      SidebarItem(
                        label: 'Manajemen Customer',
                        icon: Icons.people_alt_rounded,
                        route: '/manajemen-customer',
                        isActive: widget.currentRoute == '/manajemen-customer',
                        compact: isCompact,
                      ),
                    ],
                  ),
                ),
              ),

              // Main content
              Expanded(
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, top: 35, bottom: 12),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.title,
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold)),
                                  Text(widget.breadcrumb,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              GestureDetector(
                                onTap: () {
                                  _toggleMenu(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Text(
                                        "Halo, Admin",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.account_circle_outlined,
                                          size: 35, color: Colors.black),
                                      Icon(Icons.keyboard_arrow_down, size: 22),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                          if (_showProfileMenu)
                            Positioned(
                              right: 0,
                              top: 60,
                              child: Container(
                                width: 150,
                                padding:
                                const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                    )
                                  ],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(height: 1, thickness: 1),
                                    ListTile(
                                      dense: true,
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      title: const Text("Profile"),
                                      onTap: () {
                                        print("Profile clicked");
                                      },
                                    ),
                                    ListTile(
                                      dense: true,
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      title: Text("Logout",
                                          style: TextStyle(
                                              color: Colors.red[700])),
                                      onTap: () {
                                        print("Logout clicked");
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            )
                        ],
                      ),
                    ),
                    Expanded(child: widget.child),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}

class SidebarItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final String route;
  final bool isActive;
  final bool compact;

  const SidebarItem({
    super.key,
    required this.label,
    required this.icon,
    required this.route,
    required this.isActive,
    required this.compact,
  });

  @override
  State<SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<SidebarItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isHoveredOrActive = _isHovering || widget.isActive;
    final bgColor = isHoveredOrActive
        ? const Color(0xFF5A4630) // cokelat tua
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 13),
        verticalOffset: 0,
        preferBelow: false,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: Icon(widget.icon, color: Colors.white),
            title: widget.compact
                ? null
                : Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            onTap: () => context.go(widget.route),
          ),
        ),
      ),
    );
  }
}

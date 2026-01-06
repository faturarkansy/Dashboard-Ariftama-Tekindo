import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screen/dashboard_screen.dart';
import '../screen/pesanan_screen.dart';
import '../screen/manajemen_produk_screen.dart';
import '../screen/manajemen_jasa_screen.dart';
import '../screen/manajemen_pesan_garansi_screen.dart';
import '../screen/add_produk_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_client.dart';
import '../widgets/custom_app_notification.dart';
import 'package:quickalert/quickalert.dart';
import 'package:dio/dio.dart';

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

  void showAppNotification(BuildContext context, AppNotificationType type, String title, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0, left: 0, right: 0,
        child: CustomAppNotification(
          type: type,
          title: title,
          message: message,
          onClose: () => entry.remove(),
        ),
      ),
    );

    overlay.insert(entry);

    // Hilang otomatis setelah 3 detik
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  void _toggleMenu(BuildContext context) {
    if (_overlayEntry == null) {
      final overlay = Overlay.of(context);
      _overlayEntry = OverlayEntry(
        // 🔴 GANTI 'context' DI SINI MENJADI 'ctx' ATAU '_'
        // Agar tidak bentrok dengan 'context' utama di atas
        builder: (ctx) => Stack(
          children: [
            // Area transparan untuk mendeteksi klik di luar dropdown
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

            // Dropdown
            Positioned(
              top: 84,
              right: 17,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 158,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.black,
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        title: Text(
                          "Logout",
                          style: TextStyle(color: Colors.red[700]),
                        ),
                        onTap: () async {
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            final token = prefs.getString("ACCESS_TOKEN");

                            if (token == null) {
                              // Gunakan 'context' (milik DashboardLayout), BUKAN 'ctx'
                              if (context.mounted) {
                                showAppNotification(
                                  context,
                                  AppNotificationType.error,
                                  "Logout Gagal",
                                  "Token tidak ditemukan. Silakan login ulang.",
                                );
                              }
                              return;
                            }

                            final response = await ApiClient.dio.post(
                              "/admin/auth/logout",
                              options: Options(
                                headers: {
                                  "Authorization": "Bearer $token",
                                },
                              ),
                            );

                            if (response.statusCode == 200) {
                              await prefs.remove("ACCESS_TOKEN");

                              // Hapus Overlay
                              _overlayEntry?.remove();
                              _overlayEntry = null;

                              // Cek context utama (DashboardLayout)
                              if (context.mounted) {
                                showAppNotification(
                                  context,
                                  AppNotificationType.success,
                                  "Logout Berhasil",
                                  response.data["message"] ?? "Anda telah keluar",
                                );

                                await Future.delayed(const Duration(seconds: 2));

                                // ✅ SEKARANG INI AKAN BERJALAN
                                // Karena 'context' merujuk ke DashboardLayout yang masih ada
                                if (context.mounted) {
                                  context.go("/login");
                                }
                              }
                            } else {
                              if (context.mounted) {
                                showAppNotification(
                                  context,
                                  AppNotificationType.error,
                                  "Logout Gagal",
                                  response.data["message"] ?? "Terjadi kesalahan",
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showAppNotification(
                                context,
                                AppNotificationType.error,
                                "Error",
                                "Gagal melakukan logout: $e",
                              );
                            }
                          }
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isCollapsed = screenWidth < 950; // breakpoint responsive
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Padding(
            padding: const EdgeInsets.only(
              left: 14,
              top: 14,
              bottom: 14,
            ), // jarak kiri, atas, bawah
            child: Container(
              width: isCollapsed ? 70 : 220,
              decoration: BoxDecoration(
                color: const Color(0xFF7C684C),
                borderRadius: BorderRadius.circular(12), // sudut membulat
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 22),
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 50,
                      height: 50,
                    ),
                  ),
                  if (!isCollapsed)
                    const Center(
                      child: Text(
                        'ARIFTAMA TEKINDO',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Expanded( // 1. Expanded agar mengisi sisa tinggi layar
                    child: SingleChildScrollView( // 2. ScrollView agar bisa digulir
                      child: Column(
                        children: [
                          SidebarItem(
                            label: 'Dashboard',
                            icon: Icons.dashboard,
                            route: '/dashboard',
                            isActive: widget.currentRoute == '/dashboard',
                            isCollapsed: isCollapsed,
                          ),
                          SidebarItem(
                            label: 'Pesanan',
                            icon: Icons.shopping_cart,
                            route: '/pesanan',
                            isActive: widget.currentRoute == '/pesanan',
                            isCollapsed: isCollapsed,
                          ),
                          SidebarItem(
                            label: 'Manajemen Produk',
                            icon: Icons.chair_rounded,
                            route: '/manajemen-produk',
                            isActive: widget.currentRoute == '/manajemen-produk',
                            isCollapsed: isCollapsed,
                          ),
                          SidebarItem(
                            label: 'Manajemen Jasa',
                            icon: Icons.design_services_rounded,
                            route: '/manajemen-jasa',
                            isActive: widget.currentRoute == '/manajemen-jasa',
                            isCollapsed: isCollapsed,
                          ),
                          SidebarItem(
                            label: 'Manajemen Pesan & Garansi',
                            icon: Icons.shield_sharp,
                            route: '/manajemen-pesan-garansi',
                            isActive: widget.currentRoute == '/manajemen-pesan-garansi',
                            isCollapsed: isCollapsed,
                          ),
                          SidebarItem(
                            label: 'Manajemen Customer',
                            icon: Icons.people_alt_rounded,
                            route: '/manajemen-customer',
                            isActive: widget.currentRoute == '/manajemen-customer',
                            isCollapsed: isCollapsed,
                          ),

                          // Tambahan padding bawah agar item terakhir tidak terlalu mepet
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
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
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 35, bottom: 12),
                  child: Stack(
                    clipBehavior: Clip.none, // ⬅️ penting biar menu gak kepotong
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.title,
                                  style: const TextStyle(
                                      fontSize: 22, fontWeight: FontWeight.bold)),
                              Text(widget.breadcrumb,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              _toggleMenu(context); // ⬅️ panggil fungsi toggle menu
                            },
                            child: Container(
                              padding: const EdgeInsets.only(
                                  top: 5, bottom: 5, left: 15, right: 5),
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

                      // ⬇️ ini taruh paling akhir biar z-index tinggi
                      if (_showProfileMenu)
                        Positioned(
                          right: 0,
                          top: 60,
                          child: Container(
                            width: 150,
                            padding: const EdgeInsets.symmetric(vertical: 8),
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
                                const Divider(height: 1, thickness: 1), // garis pemisah
                                ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                  title: const Text("Profile"),
                                  onTap: () {
                                    print("Profile clicked");
                                  },
                                ),
                                ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                  title: Text("Logout",
                                      style: TextStyle(color: Colors.red[700])),
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

                // Main page content
                Expanded(child: widget.child),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class SidebarItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final String route;
  final bool isActive;
  final bool isCollapsed;

  const SidebarItem({
    super.key,
    required this.label,
    required this.icon,
    required this.route,
    required this.isActive,
    required this.isCollapsed,
  });

  @override
  State<SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<SidebarItem> {
  bool _isHovering = false;
  OverlayEntry? _tooltipOverlay;

  void _showTooltip(BuildContext context) {
    if (!widget.isCollapsed) return; // hanya muncul saat collapsed

    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    _tooltipOverlay = OverlayEntry(
      builder: (_) => Positioned(
        left: offset.dx + renderBox.size.width + 8, // posisi kanan ikon
        top: offset.dy + (renderBox.size.height / 2) - 18,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_tooltipOverlay!);
  }

  void _hideTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final isHoveredOrActive = _isHovering || widget.isActive;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        _showTooltip(context);
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        _hideTooltip();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isHoveredOrActive ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: widget.isCollapsed
            ? GestureDetector(
          onTap: () => context.go(widget.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Icon(
                widget.icon,
                color: Colors.white,
              ),
            ),
          ),
        )
            : ListTile(
          leading: Icon(widget.icon, color: Colors.white),
          title: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          onTap: () => context.go(widget.route),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
        ),
      ),
    );
  }
}

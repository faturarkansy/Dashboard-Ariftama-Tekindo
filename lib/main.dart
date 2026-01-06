import 'package:dashboard_ariftama/screen/login_screen.dart';
import 'package:dashboard_ariftama/screen/manajemen_customer_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'widgets/dashboard_layout.dart';
import 'screen/dashboard_screen.dart';
import 'screen/pesanan_screen.dart';
import 'screen/manajemen_produk_screen.dart';
import 'screen/manajemen_jasa_screen.dart';
import 'screen/manajemen_pesan_garansi_screen.dart';
import 'screen/add_produk_screen.dart';
import 'screen/edit_produk_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  // init data tanggal untuk locale Indonesia
  await initializeDateFormatting('id_ID', null);

  runApp(const MyApp());
}


/// Cek login
Future<bool> _isLoggedIn() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString("ACCESS_TOKEN");
  return token != null && token.isNotEmpty;
}

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => NoTransitionPage(
        child: const LoginScreen(),
      ),
      redirect: (context, state) async {
        return await _isLoggedIn() ? '/dashboard' : null;
      },
    ),

    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) => NoTransitionPage(
        child: DashboardLayout(
          currentRoute: state.uri.toString(),
          child: DashboardContent(),
          title: 'Dashboard',
          breadcrumb: 'Dashboard',
        ),
      ),
      redirect: (context, state) async {
        return await _isLoggedIn() ? null : '/login';
      },
    ),

    GoRoute(
      path: '/pesanan',
      pageBuilder: (context, state) => NoTransitionPage(
        child: DashboardLayout(
          currentRoute: state.uri.toString(),
          child: OrdersContent(),
          title: 'Pesanan',
          breadcrumb: 'Pesanan',
        ),
      ),
      redirect: (context, state) async {
        return await _isLoggedIn() ? null : '/login';
      },
    ),

    GoRoute(
      path: '/manajemen-produk',
      pageBuilder: (context, state) => NoTransitionPage(
        child: DashboardLayout(
          currentRoute: state.uri.toString(),
          child: ManagementProductContent(),
          title: 'Manajemen Produk',
          breadcrumb: 'Manajemen Produk',
        ),
      ),
      redirect: (context, state) async {
        return await _isLoggedIn() ? null : '/login';
      },
    ),

    GoRoute(
      path: '/manajemen-jasa',
      pageBuilder: (context, state) => NoTransitionPage(
        child: DashboardLayout(
          currentRoute: state.uri.toString(),
          child: ServiceManagementContent(),
          title: 'Manajemen Jasa',
          breadcrumb: 'Manajemen Jasa',
        ),
      ),
      redirect: (context, state) async {
        return await _isLoggedIn() ? null : '/login';
      },
    ),

    GoRoute(
      path: '/manajemen-pesan-garansi',
      pageBuilder: (context, state) => NoTransitionPage(
        child: DashboardLayout(
          currentRoute: state.uri.toString(),
          child: GuaranteeManagementContent(),
          title: 'Manajemen Pesan dan Garansi',
          breadcrumb: 'Manajemen Pesan dan Garansi',
        ),
      ),
      redirect: (context, state) async {
        return await _isLoggedIn() ? null : '/login';
      },
    ),

    GoRoute(
      path: '/manajemen-customer',
      pageBuilder: (context, state) => NoTransitionPage(
        child: DashboardLayout(
          currentRoute: state.uri.toString(),
          child: CustomerManagementContent(),
          title: 'Manajemen Customer',
          breadcrumb: 'Manajemen Customer',
        ),
      ),
      redirect: (context, state) async {
        return await _isLoggedIn() ? null : '/login';
      },
    ),

    GoRoute(
      path: '/manajemen-produk/add-produk',
      pageBuilder: (context, state) => NoTransitionPage(
        child: DashboardLayout(
          currentRoute: state.uri.toString(),
          child: AddProductScreen(),
          title: 'Tambah Produk',
          breadcrumb: 'Manajemen Produk > Tambah Produk',
        ),
      ),
      redirect: (context, state) async {
        return await _isLoggedIn() ? null : '/login';
      },
    ),

    GoRoute(
      path: '/manajemen-produk/edit-produk',
      pageBuilder: (context, state) {
        final productId = state.extra as int? ?? 0;
        return NoTransitionPage(
          child: DashboardLayout(
            currentRoute: state.uri.toString(),
            child: EditProductScreen(productId: productId),
            title: 'Edit Produk',
            breadcrumb: 'Manajemen Produk > Edit Produk',
          ),
        );
      },
      redirect: (context, state) async {
        return await _isLoggedIn() ? null : '/login';
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      title: 'Dashboard Ariftama',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
      ),
    );
  }
}

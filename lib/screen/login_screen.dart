import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../widgets/custom_app_notification.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _loading = false;
  bool rememberMe = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showAppNotification(AppNotificationType type, String title, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
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

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showAppNotification(
          AppNotificationType.error,
          "Login Gagal",
          "Email dan password wajib diisi"
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await ApiClient.dio.post(
        "/admin/auth/login",
        data: {"email": email, "password": password},
      );

      final data = response.data;
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("ACCESS_TOKEN", data["token"]);

      // 🟢 1. Tampilkan Notifikasi Sukses
      showAppNotification(
          AppNotificationType.success,
          "Sukses",
          data["message"] ?? "Login berhasil"
      );

      // 🟢 2. Tunggu 2 Detik agar notifikasi terbaca
      await Future.delayed(const Duration(seconds: 2));

      // 🟢 3. Pindah ke Dashboard otomatis
      if (mounted) {
        context.go("/dashboard");
      }

    } on DioException catch (e) {
      final message = e.response?.data["message"] ?? "Login gagal";
      if (!mounted) return;

      showAppNotification(
          AppNotificationType.error,
          "Error",
          message
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- FORGOT PASSWORD ----------------
  void _showForgotPasswordDialog() {
    final TextEditingController forgotEmailController = TextEditingController();
    final List<TextEditingController> pinControllers =
    List.generate(4, (index) => TextEditingController());

    Future<void> sendForgotPassword() async {
      final email = forgotEmailController.text.trim();
      if (email.isEmpty) {
        showAppNotification(
            AppNotificationType.error,
            "Gagal",
            "Email wajib diisi"
        );
        return;
      }

      try {
        final response = await ApiClient.dio.post(
          "/admin/auth/forgot-password",
          data: {"email": email},
        );
        if (!mounted) return;

        showAppNotification(
            AppNotificationType.success,
            "Berhasil",
            response.data["message"] ?? "Kode PIN terkirim ke email"
        );

      } on DioException catch (e) {
        final message = e.response?.data["message"] ?? "Gagal mengirim email";
        showAppNotification(
            AppNotificationType.error,
            "Error",
            message
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: 350),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Lupa Password",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E2A01)),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Kami akan mengirimkan pesan ke Email anda untuk mereset password.",
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Input email + button "Kirim"
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: forgotEmailController,
                          decoration: InputDecoration(
                            hintText: "Masukkan Email anda",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: sendForgotPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text("Kirim",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text("Masukkan kode PIN yang tertera pada Email"),
                  const SizedBox(height: 12),

                  // PIN boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(4, (i) {
                      return SizedBox(
                        width: 55,
                        height: 55,
                        child: TextField(
                          controller: pinControllers[i],
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            counterText: "",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            filled: true,
                            fillColor: Colors.grey[200],
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        String pin =
                        pinControllers.map((c) => c.text).join();
                        String email =
                        forgotEmailController.text.trim();
                        if (pin.length != 4) {
                          showAppNotification(
                              AppNotificationType.error,
                              "Gagal",
                              "PIN harus 4 digit"
                          );
                          return;
                        }
                        Navigator.pop(context);
                        _showResetPasswordDialog(email, pin);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        minimumSize: const Size(120, 42),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text("Oke",
                          style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------- RESET PASSWORD ----------------
  void _showResetPasswordDialog(String email, String pin) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    Future<void> resetPassword() async {
      final newPassword = newPasswordController.text.trim();
      final confirmPassword = confirmPasswordController.text.trim();

      if (newPassword.isEmpty || confirmPassword.isEmpty) {
        showAppNotification(
            AppNotificationType.error,
            "Gagal",
            "Semua field wajib diisi"
        );
        return;
      }
      if (newPassword != confirmPassword) {
        showAppNotification(
            AppNotificationType.error,
            "Gagal",
            "Password konfirmasi tidak sama"
        );
        return;
      }

      try {
        final response = await ApiClient.dio.post(
          "/admin/auth/reset-password",
          data: {
            "email": email,
            "pin": pin,
            "newPassword": newPassword,
            "confirmNewPassword": confirmPassword,
          },
        );
        if (!mounted) return;

        Navigator.pop(context); // tutup dialog
        showAppNotification(
            AppNotificationType.success,
            "Sukses",
            response.data["message"] ?? "Password berhasil direset"
        );

      } on DioException catch (e) {
        final message =
            e.response?.data["message"] ?? "Gagal mereset password";

        showAppNotification(
            AppNotificationType.error,
            "Error",
            message
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: 350),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Reset Password",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E2A01)),
                  ),
                  const SizedBox(height: 16),
                  const Text("Password"),
                  const SizedBox(height: 6),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Masukkan Password Baru",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("Konfirmasi Password"),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Konfirmasi Password Baru",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        minimumSize: const Size(120, 42),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text("Simpan",
                          style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF301D02),
      body: Center(
        child: Container(
          width: size.width > 950 ? 950 : size.width * 0.95,
          height: 570,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                spreadRadius: 5,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.08),
              )
            ],
          ),
          child: Row(
            children: [
              // KIRI – gambar dari assets
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // background + overlay gelap
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/login_bg.jpg',
                            fit: BoxFit.cover,
                          ),
                          Container(
                            color: Colors.black.withOpacity(0.25),
                          ),
                        ],
                      ),
                      // logo + teks
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/logo.png',
                                height: 40,
                                width: 40,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "ARIFTAMA TEKINDO",
                                style: TextStyle(
                                  color: Colors.white,   // lebih kontras di background gelap
                                  fontSize: 18,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),


              // KANAN – form login
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 32),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Selamat Datang. Silahkan login dengan akun anda.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 28),

                        const Text(
                          "Email",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            hintText: "Masukkan Email",
                            hintStyle: const TextStyle(fontSize: 15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          "Password",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: "Masukkan Password",
                            hintStyle: const TextStyle(fontSize: 15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: IconButton(
                                iconSize: 20,
                                splashRadius: 20,
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            // Checkbox(
                            //   value: rememberMe,
                            //   onChanged: (v) {
                            //     setState(() => rememberMe = v ?? false);
                            //   },
                            //   shape: RoundedRectangleBorder(
                            //     borderRadius: BorderRadius.circular(4),
                            //   ),
                            //   activeColor: const Color(0xFF7C3AED),
                            // ),
                            // const Text("Remember Me"),
                            const Spacer(),
                            GestureDetector(
                              onTap: _showForgotPasswordDialog,
                              child: const Text(
                                "Forget Password?",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF301D02),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                                : const Text(
                                  "Login",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

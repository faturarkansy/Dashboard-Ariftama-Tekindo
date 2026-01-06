import 'package:flutter/material.dart';
import '../widgets/custom_app_notification.dart';
import 'package:dio/dio.dart';
import '../api_client.dart';
import 'package:intl/intl.dart';

final _currencyFormatter = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0, // Menghilangkan angka di belakang koma/titik
);

class OrdersContent extends StatefulWidget {
  const OrdersContent({super.key});

  @override
  State<OrdersContent> createState() => _OrdersContentState();
}

class _OrdersContentState extends State<OrdersContent> {
  List<dynamic> orders = [];
  bool isLoading = true;

  // TAB
  int selectedTab = 0;
  final tabs = [
    "Semua",
    "Menunggu Pembayaran",
    "Belum Dikirim",
    "Dikirim",
    "Selesai"
  ];

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  void showAppNotification(AppNotificationType type, String title, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0, // Jarak dari atas
        left: 0,
        right: 0,
        child: CustomAppNotification(
          type: type,
          title: title,
          message: message,
          onClose: () {
            entry.remove();
          },
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  // ============================================================
  // FETCH ORDER DATA + ITEM DETAIL
  // ============================================================
  Future<void> fetchOrders() async {
    try {
      final response = await ApiClient.dio.get('/admin/orders');
      if (response.statusCode == 200) {
        final orderList = response.data as List;

        // fetch detail item
        for (var order in orderList) {
          final detailResponse =
          await ApiClient.dio.get('/admin/orders/${order['id']}');
          if (detailResponse.statusCode == 200) {
            order['items'] = detailResponse.data['items'];
          }
        }

        setState(() {
          orders = orderList;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching orders: $e");
      setState(() => isLoading = false);
    }
  }

  // ============================================================
  // STATUS TRANSLATION
  // ============================================================
  Map<String, dynamic> translateStatus(String raw) {
    switch (raw) {
      case "pending":
        return {
          "pay": "Belum Dibayar",
          "payColor": Colors.red,
          "order": "Menunggu Pembayaran",
          "orderColor": Colors.yellow[700],
        };

      case "confirmed":
        return {
          "pay": "Lunas",
          "payColor": Colors.green,
          "order": "Belum Dikirim",
          "orderColor": Colors.redAccent,
        };

      case "shipped":
        return {
          "pay": "Lunas",
          "payColor": Colors.green,
          "order": "Dikirim",
          "orderColor": Colors.black,
        };

      case "completed":
        return {
          "pay": "Lunas",
          "payColor": Colors.green,
          "order": "Sampai",
          "orderColor": Colors.green,
        };

      case "cancelled":
        return {
          "pay": "Belum Dibayar",
          "payColor": Colors.red,
          "order": "Dibatalkan",
          "orderColor": Colors.red,
        };

      default:
        return {
          "pay": "-",
          "payColor": Colors.black,
          "order": raw,
          "orderColor": Colors.grey,
        };
    }
  }

  // ============================================================
  // FILTER LIST BERDASARKAN TAB
  // ============================================================
  List<dynamic> get filteredOrders {
    switch (selectedTab) {
      case 1:
        return orders.where((o) => o['status'] == 'pending').toList();
      case 2:
        return orders.where((o) => o['status'] == 'confirmed').toList();
      case 3:
        return orders.where((o) => o['status'] == 'shipped').toList();
      case 4:
        return orders.where((o) => o['status'] == 'completed').toList();
      default:
        return orders;
    }
  }

  Future<void> showDetailDialog(BuildContext context, int orderId) async {
    try {
      final response = await ApiClient.dio.get('/admin/orders/$orderId');
      if (response.statusCode == 200) {
        final data = response.data;
        final String rawStatus = data['status'] ?? 'default';
        final statusTranslation = translateStatus(rawStatus);

        showDialog(
          context: context,
          builder: (_) {
            return Dialog(
              // 🟢 1. Radius Pop Up 12
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: 500, // Lebar Fix
                // 🟢 2. Padding All 16
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🟢 3. Header Text Size 16
                    const Text(
                      'Detail Pesanan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // KONTEN SCROLLABLE
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow("ID Pesanan", "${data['id']}"),
                            _buildDetailRow("Pemesan", data['username'] ?? '-'),
                            _buildDetailRow(
                                "Alamat Tujuan", data['shipping_address'] ?? '-'),
                            _buildDetailRow("Metode Pengiriman",
                                data['shipping_method'] ?? '-'),
                            _buildDetailRow("Status Pembayaran", statusTranslation['pay']),
                            _buildDetailRow("Metode Pembayaran", "-"),
                            _buildDetailRow(
                                "Jumlah Harus Dibayar",
                                // 1. Akses data['total_amount'] (BUKAN order['total_amount'])
                                // 2. Konversi ke String, parse ke double, lalu format ke String
                                _currencyFormatter.format(
                                    double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0
                                ), // Menandai agar teks nominal dicetak tebal
                            ),
                            const SizedBox(height: 12),

                            // 🟢 4. Text Size 13 (Judul List)
                            const Text(
                              "List Produk:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),

                            // 🟢 4. Text Size 13 (Item Produk)
                            ...List.generate(
                              (data['items'] as List).length,
                                  (i) => Text(
                                "${data['items'][i]['quantity']}x ${data['items'][i]['product_name']}",
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // TOMBOL AKSI (Di kanan bawah)
                    Align(
                      alignment: Alignment.centerRight,
                      child:
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF301D02),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text("Tutup"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      debugPrint("Error fetching order detail: $e");
    }
  }

  Future<void> showShippingDialog(BuildContext context, int orderId) async {
    try {
      final response = await ApiClient.dio.get('/admin/orders/$orderId');
      if (response.statusCode == 200) {
        final data = response.data;
        final TextEditingController trackingNumberController =
        TextEditingController();

        showDialog(
          context: context,
          builder: (_) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Input Nomor Resi Pengiriman',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(
                                "Alamat Tujuan", data['shipping_address'] ?? '-'),
                            _buildDetailRow("Metode Pengiriman",
                                data['shipping_method'] ?? '-'),
                            const SizedBox(height: 16),

                            const Text(
                              "Nomor Resi",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),

                            TextField(
                              controller: trackingNumberController,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Masukkan nomor resi...',
                                hintStyle: const TextStyle(fontSize: 13),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF301D02),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text("Batal"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final trackingNumber = trackingNumberController.text.trim();
                            if (trackingNumber.isEmpty) {
                              showAppNotification(
                                AppNotificationType.warning,
                                "Peringatan",
                                "Nomor resi tidak boleh kosong",
                              );
                              return;
                            }

                            try {
                              // 1. Lakukan PATCH ke API
                              await ApiClient.dio.patch(
                                '/admin/orders/$orderId/ship',
                                data: {'trackingNumber': trackingNumber},
                              );

                              // 2. Tutup Dialog
                              if (mounted) Navigator.of(context).pop();

                              // 3. Tampilkan Notifikasi Sukses
                              showAppNotification(
                                AppNotificationType.success,
                                "Berhasil",
                                "Nomor resi berhasil dikirim!",
                              );

                              // 🟢 UPDATE: RE-FETCH DATA
                              // Memanggil fungsi fetchOrders() agar list pesanan diperbarui
                              // dan status berubah dari 'Belum Dikirim' menjadi 'Dikirim' secara otomatis
                              fetchOrders();

                            } catch (e) {
                              debugPrint("Error updating tracking number: $e");
                              showAppNotification(
                                AppNotificationType.error,
                                "Gagal",
                                "Gagal mengirim nomor resi",
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF301D02),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Buat', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      debugPrint("Error fetching shipping data: $e");
    }
  }

  Future<void> showCompleteDialog(BuildContext context, int orderId) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          // 1. STYLING RADIUS 12 (Sudah ada, tapi kita pastikan)
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,

          // 2. STYLING PADDING ALL 16
          // Karena AlertDialog memisahkan padding, kita atur Title dan Content Padding secara terpisah.
          titlePadding: const EdgeInsets.all(16),
          contentPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 0), // Atur padding konten
          actionsPadding: const EdgeInsets.all(16), // Atur padding tombol aksi

          // 3. TEXT TITLE/HEADER FONT SIZE 16
          title: const Text(
            "Konfirmasi Penyelesaian Pesanan",
            style: TextStyle(
              fontSize: 16, // Font size 16
              fontWeight: FontWeight.bold,
            ),
          ),

          // 4. TEXT BIASA FONT SIZE 13
          content: const Text(
            "Apakah anda yakin barang sudah benar-benar sampai di alamat tujuan pengiriman?",
            style: TextStyle(
              fontSize: 13, // Font size 13
            ),
          ),

          actions: [
            // Tombol TIDAK (diubah menjadi TextButton untuk styling yang lebih bersih)
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                "Tidak",
                style: TextStyle(color: Colors.black, fontSize: 13), // Font size 13
              ),
            ),

            // Tombol YA
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Tutup dialog dulu

                try {
                  // PATCH ke endpoint status
                  await ApiClient.dio.patch(
                    "/orders/$orderId/status",
                    data: {"status": "completed"},
                  );

                  // Notifikasi Sukses
                  showAppNotification(
                    AppNotificationType.success,
                    "Berhasil",
                    "Status pesanan berhasil diubah menjadi Selesai (Completed)",
                  );

                  // Re-fetch data untuk memperbarui tampilan
                  fetchOrders();

                } on DioException catch (e) {
                  String msg = "Terjadi kesalahan server";
                  if (e.response != null) {
                    msg = e.response?.data['message'] ?? e.message;
                  }
                  // Notifikasi Gagal
                  showAppNotification(AppNotificationType.error, "Gagal", msg);
                } catch (e) {
                  showAppNotification(AppNotificationType.error, "Error", e.toString());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF301D02),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                "Ya",
                style: TextStyle(fontSize: 13), // Font size 13
              ),
            ),
          ],
        );
      },
    );
  }

  int countByStatus(String status) {
    switch (status) {
      case "pending":
        return orders.where((o) => o['status'] == 'pending').length;
      case "confirmed":
        return orders.where((o) => o['status'] == 'confirmed').length;
      case "shipped":
        return orders.where((o) => o['status'] == 'shipped').length;
      case "completed":
        return orders.where((o) => o['status'] == 'completed').length;
      default:
        return orders.length; // Semua
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
      margin: const EdgeInsets.only(bottom: 16, right: 16, left: 16, top: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black,
          width: 1.0,
        ),
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------- TAB ----------------
          Row(
            children: List.generate(tabs.length, (i) {
              final isActive = selectedTab == i;

              // Hitung jumlah sesuai tab
              final count = [
                orders.length, // Semua
                countByStatus("pending"), // Menunggu Pembayaran
                countByStatus("confirmed"), // Belum Dikirim
                countByStatus("shipped"), // Dikirim
                countByStatus("completed"), // Selesai
              ][i];

              return GestureDetector(
                onTap: () => setState(() => selectedTab = i),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isActive ? Colors.brown : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    "${tabs[i]} ($count)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.brown : Colors.black,
                    ),
                  ),
                ),
              );
            }),
          ),

          const Divider(
            thickness: 1,
            height: 1,
            color: Colors.grey,
          ),

          const SizedBox(height: 14),

          // ==================== HEADER ABU-ABU ====================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    "Produk",
                    textAlign: TextAlign.left,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Jumlah Harus Dibayar",
                    textAlign: TextAlign.left,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Status",
                    textAlign: TextAlign.left,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    "Aksi",
                    textAlign: TextAlign.left,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ======================= LIST PESANAN =======================
          Expanded(
            child: ListView(
              children: filteredOrders.map((o) => _buildOrderCard(o)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ORDER CARD UI
  // ============================================================
  Widget _buildOrderCard(dynamic order) {
    final items = order['items'] ?? [];
    final rawStatus = order['status'] as String; // Ambil status mentah
    final statusTranslation = translateStatus(rawStatus);
    final orderId = order['id'] as int;

    // Logika Kondisional Tombol Aksi
    Widget actionButton = const SizedBox.shrink(); // Default kosong

    if (rawStatus == 'confirmed') {
      // Tombol Input Resi hanya muncul pada status Belum Dikirim (confirmed)
      actionButton = ElevatedButton(
        onPressed: () => showShippingDialog(context, orderId),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF301D02),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: const Text("Input Resi"),
      );
    } else if (rawStatus == 'shipped') {
      // Tombol Selesai hanya muncul pada status Dikirim (shipped)
      actionButton = ElevatedButton(
        onPressed: () => showCompleteDialog(context, orderId),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF301D02),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: const Text("Tandai Selesai"),
      );
    }


    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // BAGIAN ATAS (USERNAME)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black26)),
            ),
            child: Text(
              order['username'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),

          // BAGIAN BAWAH (FLEX LAYOUT)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PRODUK LIST
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items
                        .map<Widget>((i) =>
                        Text("${i['quantity']}x ${i['product_name']}"))
                        .toList(),
                  ),
                ),

                // TOTAL + PAYMENT + PAY STATUS
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_currencyFormatter.format(
                            // Coba parse ke double, jika gagal, gunakan 0 sebagai fallback
                              double.tryParse(order['total_amount'].toString()) ?? 0
                          ),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      Text(order['payment_method'] ?? "-",
                          style: const TextStyle(fontSize: 12)),
                      Text(
                        statusTranslation['pay'],
                        style: TextStyle(
                          fontSize: 12,
                          color: statusTranslation['pay'] == "Lunas"
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),

                // BADGE STATUS ORDER
                Expanded(
                  flex: 2,
                  child: Align(
                    // memastikan badge tidak memanjang
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusTranslation['orderColor'],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusTranslation['order'],
                        style: TextStyle(
                          color: statusTranslation['order'] == "Menunggu Pembayaran"
                              ? Colors.black
                              : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                // BUTTONS
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ElevatedButton(
                        onPressed: () => showDetailDialog(context, orderId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF301D02),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text("Lihat Detail"),
                      ),
                      const SizedBox(width: 6),
                      // 🌟 TAMPILKAN TOMBOL AKSI KONDISIONAL
                      actionButton,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DETAIL ROW WIDGET
  // ============================================================
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13), // Text 13
            ),
          ),
          const Text(": ", style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13), // Text 13
            ),
          ),
        ],
      ),
    );
  }
}
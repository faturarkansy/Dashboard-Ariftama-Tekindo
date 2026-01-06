import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../widgets/custom_app_notification.dart';
import '../api_client.dart';
import 'add_produk_screen.dart';

class ManagementProductContent extends StatefulWidget {
  const ManagementProductContent({super.key});

  @override
  State<ManagementProductContent> createState() => _ManagementProductContentState();
}

class _ManagementProductContentState extends State<ManagementProductContent> {
  List<dynamic> products = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    try {
      final response = await ApiClient.dio.get("/products");
      debugPrint("Response type: ${response.data.runtimeType}");
      debugPrint("Response data: ${response.data}");
      debugPrint("STATUS: ${response.statusCode}");
      debugPrint("HEADERS: ${response.headers}");
      debugPrint("DATA: ${response.data}");

      final List<dynamic> data = response.data;

      setState(() {
        products = data;
        isLoading = false;
      });
    } on DioException catch (e) {
      debugPrint("Error fetch products: ${e.response?.data ?? e.message}");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () {
              context.go('/manajemen-produk/add-produk');
            },
            icon: const Icon(Icons.add),
            label: const Text('Tambah'),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                ? const Center(child: Text("Tidak ada produk"))
                : LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount;

                if (constraints.maxWidth < 600) {
                  crossAxisCount = 2; // ukuran sangat kecil
                } else if (constraints.maxWidth < 900) {
                  crossAxisCount = 3; // tablet / window kecil
                } else {
                  crossAxisCount = 4; // layar normal
                }

                return GridView.builder(
                  itemCount: products.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ProductCard(
                      product: product,
                      // 🟢 BARU: Kita kirim fungsi fetchProducts agar bisa dipanggil ulang nanti
                      onRefresh: fetchProducts,
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

String formatHarga(dynamic harga) {
  if (harga == null) return "-";

  // Convert ke string
  String str = harga.toString();

  // Hilangkan desimal .00 atau .xx apapun
  if (str.contains(".")) {
    str = str.split(".")[0];
  }

  // Convert ke int
  int value = int.tryParse(str) ?? 0;

  // Format dengan pemisah ribuan menggunakan titik
  String formatted = value.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => "${m[1]}.",
  );

  return formatted;
}

Future<void> checkImageCors(String url) async {
  try {
    await Dio().head(url);
    debugPrint("CORS OK: $url");
  } catch (e) {
    debugPrint("=== CORS WARNING DETECTED ===");
    debugPrint("Gambar gagal dimuat karena kemungkinan CORS block.");
    debugPrint("URL: $url");
    debugPrint("Error: $e");
    debugPrint("""
      Penyebab umum:
      1. Backend tidak mengizinkan akses ke gambar (CORS headers tidak ada).
      2. Header berikut tidak diberikan oleh server:
         - Access-Control-Allow-Origin: *
         - Access-Control-Allow-Headers: Content-Type, Authorization
      3. File statis tidak lewat route storage/uploads yang benar.
      4. Flutter Web melakukan request gambar langsung, bukan via proxy.
      """);
  }
}

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onRefresh;
  const ProductCard({super.key, required this.product, this.onRefresh,});

  @override
  Widget build(BuildContext context) {
    const String BASE_IMAGE_DOMAIN = "https://api.cvariftamatekindo.my.id";

// Menggunakan BASE_IMAGE_DOMAIN secara langsung:
    final String imagePath = product["image_url"];

    final String imageUrl = imagePath != null
        ? "$BASE_IMAGE_DOMAIN/$imagePath"
        : "";

    debugPrint("Image URL for ${product['NAME']}: $imageUrl");

    // CORS detector khusus Flutter Web
    // if (kIsWeb && imageUrl.isNotEmpty) {
    //   checkImageCors(imageUrl);
    // }


    final screenWidth = MediaQuery.of(context).size.width;
    final double nameSize = (screenWidth > 714 && screenWidth < 850) ? 12 : 14;
    final double priceSize = (screenWidth > 714 && screenWidth < 850) ? 12 : 14;
    final double ratingSize = (screenWidth > 714 && screenWidth < 850) ? 12 : 14;
    final double stockSize = (screenWidth > 714 && screenWidth < 850) ? 12 : 14;
    final double iconSize = (screenWidth > 714 && screenWidth < 850) ? 12 : 14;


    return Card(
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bagian atas (gambar) -> Expanded agar setengah tinggi
          Expanded(
            flex: 1,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('=== IMAGE LOAD ERROR ===');
                  debugPrint('URL: $imageUrl');
                  debugPrint('Error: $error');
                  return const Icon(Icons.broken_image);
                },
              ),
            ),
          ),

          // Bagian bawah (informasi produk) -> Expanded agar setengah tinggi
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF301D02),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['NAME'] ?? "-",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: nameSize,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp. ${formatHarga(product['price'])}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: priceSize,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Row(
                        children: List.generate(
                          5,
                              (i) => Icon(
                            Icons.star,
                            size: iconSize,
                            color: double.tryParse(product['rating'].toString()) != null &&
                                i < double.parse(product['rating'].toString()).round()
                                ? Colors.amber[400]
                                : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${product['rating']}/5',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ratingSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tersisa ${product['stock']} pcs',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: stockSize,
                    ),
                  ),

                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: () async {
                        // 🟢 MODIFIKASI: Tambahkan 'await' untuk menunggu dialog ditutup
                        final bool? result = await showDialog(
                          context: context,
                          builder: (context) {
                            return ProductDetailDialog(product: product);
                          },
                        );

                        // 🟢 BARU: Cek jika result == true (artinya berhasil dihapus), maka refresh list
                        if (result == true && onRefresh != null) {
                          onRefresh!();
                        }
                      },
                      child: const Text('Detail'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReviewItemWidget extends StatefulWidget {
  final Map<String, dynamic> reviewData;
  final Function(String message, AppNotificationType type) onNotification;
  final VoidCallback onReplySuccess;

  const ReviewItemWidget({
    super.key,
    required this.reviewData,
    required this.onNotification,
    required this.onReplySuccess,
  });

  @override
  State<ReviewItemWidget> createState() => _ReviewItemWidgetState();
}

class _ReviewItemWidgetState extends State<ReviewItemWidget> {
  final TextEditingController _replyController = TextEditingController();
  bool isSending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) {
      widget.onNotification(
          "Gagal", AppNotificationType.error); // Validasi sederhana
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      final ratingId = widget.reviewData['id']; // Pastikan ID ada di response
      await ApiClient.dio.post(
        "/products/ratings/$ratingId/reply",
        data: {"reply": text},
      );

      widget.onNotification("Berhasil membalas ulasan", AppNotificationType.success);
      _replyController.clear();

      // Trigger parent refresh
      widget.onReplySuccess();

    } on DioException catch (e) {
      String msg = e.response?.data['message'] ?? e.message ?? "Terjadi kesalahan";
      widget.onNotification("Gagal: $msg", AppNotificationType.error);
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reviewData;
    final username = r['username'] ?? 'Username';
    final comment = r['review'] ?? '';
    final rating = r['rating'] ?? 0;
    final createdAt = r['created_at'] ?? '';
    // Ambil data admin_reply
    final adminReply = r['admin_reply']; // Bisa string atau null

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Ulasan User
          Row(
            children: [
              Text(username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  )),
              const SizedBox(width: 6),
              Row(
                children: List.generate(
                  5,
                      (i) => Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            createdAt.toString().split("T").first,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            comment,
            style: const TextStyle(fontSize: 13),
          ),

          const SizedBox(height: 2),
          const Divider(),
          const SizedBox(height: 4),

          // 🟢 LOGIKA TAMPILAN BALASAN
          if (adminReply != null && adminReply.toString().isNotEmpty) ...[
            // KONDISI 1: Sudah ada balasan -> Tampilkan Balasan
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Balasan Admin:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF301D02),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adminReply.toString(),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ] else ...[
            // KONDISI 2: Belum ada balasan -> Tampilkan Input Field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Tulis balasan...",
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: isSending ? null : sendReply,
                  child: isSending
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.send, size: 18),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ProductDetailDialog extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailDialog({super.key, required this.product});

  @override
  State<ProductDetailDialog> createState() => _ProductDetailDialogState();
}

class _ProductDetailDialogState extends State<ProductDetailDialog> {
  List<dynamic> ratings = [];
  double averageRating = 0.0;
  bool isLoadingRating = true;

  @override
  void initState() {
    super.initState();
    fetchProductRatings();
  }

  void showAppNotification(AppNotificationType type, String title, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0, // Posisi dari atas
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

    // Hapus otomatis setelah 3 detik
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  Future<void> fetchProductRatings() async {
    try {
      final response = await ApiClient.dio
          .get("/products/${widget.product['id']}/ratings");

      setState(() {
        ratings = response.data['ratings'] ?? [];
        averageRating =
            (response.data['summary']?['average_rating'] ?? 0).toDouble();
        isLoadingRating = false;
      });
    } catch (e) {
      debugPrint("Error fetch rating: $e");
      setState(() => isLoadingRating = false);
    }
  }



  Widget _buildReviewItem(Map<String, dynamic> r) {
    final username = r['username'] ?? 'Username';
    final comment = r['review'] ?? '';
    final rating = r['rating'] ?? 0;
    final createdAt = r['created_at'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  )),
              const SizedBox(width: 6),
              Row(
                children: List.generate(
                  5,
                      (i) => Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            createdAt.toString().split("T").first,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            comment,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  // 🟢 BARU: Fungsi untuk menghapus produk
  Future<void> _deleteProduct() async {
    // 1. Tampilkan Dialog Konfirmasi dengan Styling Custom
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white, // 🟢 Background Putih
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // 🟢 Radius 12
        ),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(16), // 🟢 Padding All 16
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Tinggi menyesuaikan konten
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🟢 Title Font Size 16
              const Text(
                "Konfirmasi Hapus",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),

              // 🟢 Content Text Size 13
              const Text(
                "Apakah Anda yakin ingin menghapus produk ini?",
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Tombol Aksi
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Batal"),
                  ),

                  const SizedBox(width: 12),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Hapus"),
                  ),


                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Jika user pilih batal, hentikan proses
    if (confirm != true) return;

    // 2. Lakukan Request API DELETE
    try {
      await ApiClient.dio.delete('/admin/products/${widget.product['id']}');

      if (mounted) {
        // 🟢 GANTI SNACKBAR DENGAN CUSTOM NOTIFICATION
        showAppNotification(
          AppNotificationType.success,
          "Berhasil",
          "Produk berhasil dihapus",
        );

        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      if (mounted) {
        // 🟢 GANTI SNACKBAR DENGAN CUSTOM NOTIFICATION
        showAppNotification(
          AppNotificationType.error,
          "Gagal",
          "Gagal menghapus: ${e.response?.data ?? e.message}",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    const String BASE_IMAGE_DOMAIN = "https://api.cvariftamatekindo.my.id";

// Menggunakan BASE_IMAGE_DOMAIN secara langsung:
    final String imagePath = product["image_url"];

    final String imageUrl = imagePath != null
        ? "$BASE_IMAGE_DOMAIN/$imagePath"
        : "";

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        // dialog dibuat lebih lebar
        constraints: const BoxConstraints(
          maxWidth: 750,
          maxHeight: 500, // tinggi fix supaya bisa dibagi 2 & scroll di dalam
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // === BAGIAN ATAS: isi 2 kolom ===
              Expanded(
                child: Row(
                  children: [
                    // ================== KOLOM KIRI: DETAIL PRODUK ==================
                    Expanded(
                      flex: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // GAMBAR
                            Container(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                                child: Image.network(
                                  imageUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, size: 120),
                                ),
                              ),
                            ),

                            // CARD INFO PRODUK
                            Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                color: Color(0xFF301D02),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['NAME'] ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rp. ${formatHarga(product['price'])}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                        fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      ...List.generate(
                                        5,
                                            (i) => Icon(
                                          Icons.star,
                                          size: 18,
                                          color: i <
                                              double
                                                  .parse(product['rating']?.toString() ??
                                                  "0")
                                                  .round()
                                              ? Colors.amber
                                              : Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "${product['rating']}/5",
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Tersisa ${product['stock']} pcs",
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                  Text(
                                    "Terjual ${product['sold'] ?? 0} produk",
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // SPESIFIKASI / DESKRIPSI
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Spesifikasi Produk:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 60, // agar tidak mepet tombol
                                    child: SingleChildScrollView(
                                      child: Text(
                                        product['description'] ?? "-",
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // === BAGIAN BAWAH: TOMBOL-TOMBOL ===
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Tutup"),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        context.push(
                                          '/manajemen-produk/edit-produk',
                                          extra: product['id'],
                                        );
                                      },
                                      child: const Text("Edit"),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      onPressed: _deleteProduct,
                                      child: const Text("Hapus"),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // ================== KOLOM KANAN: ULASAN ==================
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Ulasan Produk (${ratings.length})",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Rata-rata Rating: ${averageRating.toStringAsFixed(1)} / 5",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 12),

                          // area ulasan yang bisa discroll
                          Expanded(
                            child: isLoadingRating
                                ? const Center(
                              child: CircularProgressIndicator(),
                            )
                                : ratings.isEmpty
                                ? const Center(
                                  child: Text("Belum ada ulasan."),
                                )
                                : Scrollbar(
                                  thumbVisibility: true,
                                  child: ListView.builder(
                                    itemCount: ratings.length,
                                    padding:
                                    const EdgeInsets.only(right: 8),
                                    itemBuilder: (context, index) {
                                      return ReviewItemWidget(
                                        reviewData: ratings[index],
                                        // Callback untuk notifikasi
                                        onNotification: (message, type) {
                                          showAppNotification(
                                              type,
                                              type ==
                                                  AppNotificationType
                                                      .success
                                                  ? "Berhasil"
                                                  : "Gagal",
                                              message);
                                        },
                                        // Callback sukses -> Refetch data
                                        onReplySuccess: () {
                                          fetchProductRatings();
                                        },
                                      );
                                    },
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildReviewItem(Map<String, dynamic> r) {
  final username = r['username'] ?? 'Username';
  final comment = r['review'] ?? '';
  final rating = r['rating'] ?? 0;
  final createdAt = r['created_at'] ?? '';

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                )),
            const SizedBox(width: 6),
            Row(
              children: List.generate(
                5,
                    (i) => Icon(
                  i < rating ? Icons.star : Icons.star_border,
                  size: 14,
                  color: Colors.amber,
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 2),
        Text(
          createdAt.toString().split("T").first,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        Text(
          comment,
          style: const TextStyle(fontSize: 13),
        )
      ],
    ),
  );
}



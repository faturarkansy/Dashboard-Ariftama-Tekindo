import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart'; // 🟢 Import GoRouter
import '../widgets/custom_app_notification.dart'; // 🟢 Import Custom Notification
import '../api_client.dart';

class EditProductScreen extends StatefulWidget {
  final int productId;

  const EditProductScreen({super.key, required this.productId});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  final priceController = TextEditingController();
  final stockController = TextEditingController();
  final specController = TextEditingController();

  bool loading = true;
  bool showCategoryDropdown = false;
  bool isSubmitting = false; // 🟢 State untuk mencegah proses ganda

  final List<String> categoryOptions = [
    "Perabot",
    "Pencahayaan",
    "Peralatan Kelistrikan",
  ];

  String? hoveredCategory;

  // Error flags
  bool categoryError = false;
  bool imageError = false;

  File? imageFile;
  Uint8List? imageBytes;
  String? imageName;
  String? oldImageUrl;

  final categoryFieldKey = GlobalKey();
  double categoryFieldHeight = 0;
  double categoryFieldWidth = 0;
  double categoryFieldY = 0;
  double categoryFieldX = 0;

  final TextStyle _inputTextStyle = const TextStyle(fontSize: 13);

  // Helper untuk format currency saat Load Data
  final currencyFormatter =
  NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  // 🟢 Helper Notifikasi Custom
  void showAppNotification(
      AppNotificationType type, String title, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0, // Muncul dari atas
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

    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  Future<void> _getProductDetail() async {
    try {
      final res = await ApiClient.dio.get("/products/${widget.productId}");
      final data = res.data;

      nameController.text = data["NAME"] ?? "";
      categoryController.text = data["category"] ?? "";

      // Format Harga dari 450000.00 menjadi 450.000
      if (data["price"] != null) {
        double priceValue = double.tryParse(data["price"].toString()) ?? 0;
        priceController.text = currencyFormatter.format(priceValue).trim();
      } else {
        priceController.text = "";
      }

      stockController.text = data["stock"].toString();
      specController.text = data["description"] ?? "";

      oldImageUrl = data["image_url"];

      if (mounted) {
        setState(() => loading = false);
      }
    } catch (e) {
      showAppNotification(
        AppNotificationType.error,
        "Error",
        "Gagal mengambil data produk: $e",
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _getProductDetail();
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["png", "jpg", "jpeg"],
      withData: true,
    );

    if (result != null) {
      final ext = result.files.single.extension?.toLowerCase();
      final name = result.files.single.name;
      final bytes = result.files.single.bytes;

      if (["png", "jpg", "jpeg"].contains(ext)) {
        setState(() {
          imageName = name;
          imageBytes = bytes;
          imageFile = null;
        });
      } else {
        showAppNotification(
          AppNotificationType.error,
          "Format Salah",
          "Format harus png, jpg, atau jpeg",
        );
      }
    }
  }

  void _calculateCategoryFieldPosition() {
    final renderBox =
    categoryFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      setState(() {
        categoryFieldY = position.dy;
        categoryFieldX = position.dx;
        categoryFieldHeight = renderBox.size.height;
        categoryFieldWidth = renderBox.size.width;
      });
    }
  }

  Future<void> _submitForm() async {
    // 🟢 Cegah double submit
    if (isSubmitting) return;

    setState(() {
      categoryError = categoryController.text.isEmpty;
      imageError = false;
    });

    if (categoryError) return;
    if (!_formKey.currentState!.validate()) return;

    // 🟢 Aktifkan loading state
    setState(() {
      isSubmitting = true;
    });

    // Hilangkan titik sebelum kirim ke API (450.000 -> 450000)
    String cleanPrice = priceController.text.replaceAll('.', '');
    String cleanStock = stockController.text.replaceAll('.', '');

    try {
      final formData = FormData.fromMap({
        "name": nameController.text,
        "category": categoryController.text,
        "stock": cleanStock,
        "price": cleanPrice, // Gunakan harga yang sudah dibersihkan
        "description": specController.text,
        if (imageBytes != null)
          "image": MultipartFile.fromBytes(
            imageBytes!,
            filename: imageName,
          ),
      });

      final res = await ApiClient.dio.put(
        "/admin/products/${widget.productId}",
        data: formData,
        options: Options(
          method: 'PUT',
          contentType: 'multipart/form-data',
        ),
      );

      if (res.statusCode == 200) {
        // 🟢 Notifikasi Sukses
        showAppNotification(
          AppNotificationType.success,
          "Berhasil",
          "Produk berhasil diperbarui",
        );

        // 🟢 Redirect dan Refresh Halaman Manajemen
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go('/manajemen-produk');
        }
      } else {
        showAppNotification(
          AppNotificationType.error,
          "Gagal",
          "Kode status: ${res.statusCode}",
        );
      }
    } catch (e) {
      showAppNotification(
        AppNotificationType.error,
        "Gagal",
        "Error: $e",
      );
    } finally {
      // 🟢 Matikan loading state
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide:
        BorderSide(color: Colors.black.withOpacity(0.8), width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFDC143C), width: 1),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFDC143C), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // -----------------------------------------------------------
    // 1. DEFINISI KOMPONEN UI
    // -----------------------------------------------------------

    Widget fieldName = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Nama Produk", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: nameController,
          style: _inputTextStyle,
          decoration: _inputStyle("Masukkan Nama Produk"),
          validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
        ),
        const SizedBox(height: 16),
      ],
    );

    Widget fieldCategory = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Kategori Produk",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            _calculateCategoryFieldPosition();
            setState(() {
              showCategoryDropdown = !showCategoryDropdown;
            });
          },
          child: Container(
            key: categoryFieldKey,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(
                color: categoryError ? const Color(0xFFDC143C) : Colors.black,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  categoryController.text.isEmpty
                      ? "Pilih kategori"
                      : categoryController.text,
                  style: const TextStyle(fontSize: 13, color: Colors.black),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        if (categoryError)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text("Wajib diisi",
                style: TextStyle(color: Color(0xFFDC143C), fontSize: 12)),
          ),
        const SizedBox(height: 16),
      ],
    );

    Widget fieldPrice = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Harga Produk", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: priceController,
          style: _inputTextStyle,
          decoration: _inputStyle("Masukkan Harga Produk"),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CurrencyInputFormatter(),
          ],
          validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
        ),
        const SizedBox(height: 16),
      ],
    );

    Widget fieldSpec = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Spesifikasi Produk",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: specController,
          style: _inputTextStyle,
          decoration: _inputStyle("Masukkan Spesifikasi Produk"),
          validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
        ),
        const SizedBox(height: 16),
      ],
    );

    Widget fieldStock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Stok Produk", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: stockController,
          style: _inputTextStyle,
          decoration: _inputStyle("Masukkan Stok Produk"),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CurrencyInputFormatter(),
          ],
          validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
        ),
        const SizedBox(height: 16),
      ],
    );

    Widget fieldImage = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Gambar Produk", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 21),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text("Pilih Gambar"),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  imageName ??
                      (oldImageUrl != null
                          ? oldImageUrl!.split("/").last
                          : "Belum ada file"),
                  overflow: TextOverflow.ellipsis,
                  style: _inputTextStyle,
                ),
              )
            ],
          ),
        ),
        if (imageError)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              "Wajib memilih gambar",
              style: TextStyle(color: Color(0xFFDC143C), fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );

    Widget btnBack = ElevatedButton(
      onPressed: () {
        context.go('/manajemen-produk');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF301D02),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 21),
        side: const BorderSide(color: Color(0xFF301D02)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: const Text("Kembali"),
    );

    // 🟢 Widget Tombol Submit (Dengan Loading State)
    Widget btnSubmit = ElevatedButton(
      onPressed: isSubmitting ? null : _submitForm, // Disable saat loading
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF301D02),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 21),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: isSubmitting
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      )
          : const Text("Perbarui Produk"),
    );

    // -----------------------------------------------------------
    // 2. BUILD METHOD UTAMA
    // -----------------------------------------------------------
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black45),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: LayoutBuilder(builder: (context, constraints) {
                    bool isMobile = constraints.maxWidth < 800;

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          fieldName,
                          fieldCategory,
                          fieldPrice,
                          fieldSpec,
                          fieldStock,
                          fieldImage,
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              btnBack,
                              const SizedBox(width: 12),
                              btnSubmit,
                            ],
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    fieldName,
                                    fieldCategory,
                                    fieldPrice,
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        btnBack,
                                        const SizedBox(width: 12),
                                        btnSubmit,
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  children: [
                                    fieldSpec,
                                    fieldStock,
                                    fieldImage,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  }),
                ),
              ),
            ),
          ),

          // -----------------------------------------------------------
          // 3. DROPDOWN OVERLAY
          // -----------------------------------------------------------
          if (showCategoryDropdown)
            Positioned(
              left: categoryFieldX,
              top: categoryFieldY + categoryFieldHeight,
              width: categoryFieldWidth,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white,
                  ),
                  child: Column(
                    children: categoryOptions.map((cat) {
                      final isFirst = categoryOptions.first == cat;
                      final isLast = categoryOptions.last == cat;

                      return MouseRegion(
                        onEnter: (_) => setState(() => hoveredCategory = cat),
                        onExit: (_) => setState(() => hoveredCategory = null),
                        cursor: SystemMouseCursors.click,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              categoryController.text = cat;
                              showCategoryDropdown = false;
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: hoveredCategory == cat
                                  ? Colors.brown.shade100
                                  : Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: isFirst
                                    ? const Radius.circular(6)
                                    : Radius.zero,
                                bottom: isLast
                                    ? const Radius.circular(6)
                                    : Radius.zero,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            alignment: Alignment.centerLeft,
                            child: Text(cat),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Class Formatter untuk ribuan
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    double value = double.parse(newValue.text);
    final formatter = NumberFormat('#,###', 'id_ID');
    String newText = formatter.format(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
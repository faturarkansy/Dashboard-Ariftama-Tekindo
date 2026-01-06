import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:quickalert/quickalert.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../widgets/custom_app_notification.dart';
import '../api_client.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  final priceController = TextEditingController();
  final stockController = TextEditingController();
  final specController = TextEditingController();

  bool showCategoryDropdown = false;
  // 🟢 State untuk mencegah double submit
  bool isSubmitting = false;

  final List<String> categoryOptions = [
    "Perabot",
    "Pencahayaan",
    "Peralatan Kelistrikan",
  ];

  final categoryFieldKey = GlobalKey();
  double categoryFieldHeight = 0;
  double categoryFieldWidth = 0;
  double categoryFieldY = 0;
  double categoryFieldX = 0;
  String? hoveredCategory;
  bool categoryError = false;
  bool imageError = false;

  File? image1;
  String? image1Name;
  Uint8List? image1Bytes;

  // DEFINISI STYLE TEKS INPUT (UKURAN KECIL)
  final TextStyle _inputTextStyle = const TextStyle(fontSize: 13);

  void showAppNotification(
      AppNotificationType type, String title, String message) {
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

    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
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

      if (ext == "png" || ext == "jpg" || ext == "jpeg") {
        setState(() {
          image1Name = name;
          image1 = null;
          image1Bytes = bytes;
        });
      } else {
        showAppNotification(
          AppNotificationType.error,
          "Format Salah",
          "Hanya bisa menginputkan format png, jpg, atau jpeg saja",
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
    // 🛑 Jika sedang proses, hentikan agar tidak double click
    if (isSubmitting) return;

    final textFieldValid = _formKey.currentState!.validate();

    setState(() {
      categoryError = categoryController.text.isEmpty;
      imageError = image1Name == null;
    });

    if (!textFieldValid || categoryError || imageError) {
      return;
    }

    // 🟢 Mulai loading state
    setState(() {
      isSubmitting = true;
    });

    // Bersihkan format titik sebelum kirim ke API
    String cleanPrice = priceController.text.replaceAll('.', '');
    String cleanStock = stockController.text.replaceAll('.', '');

    try {
      FormData formData = FormData.fromMap({
        "name": nameController.text,
        "category": categoryController.text,
        "price": cleanPrice, // Kirim angka murni
        "stock": cleanStock, // Kirim angka murni
        "description": specController.text,
        if (image1Bytes != null)
          "image": MultipartFile.fromBytes(
            image1Bytes!,
            filename: image1Name,
          ),
      });

      final response = await ApiClient.dio.post(
        "/admin/products",
        data: formData,
        options: Options(contentType: "multipart/form-data"),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        showAppNotification(
          AppNotificationType.success,
          "Berhasil",
          "Produk berhasil ditambahkan",
        );

        _formKey.currentState?.reset();
        setState(() {
          image1 = null;
          image1Name = null;
          categoryController.clear();
          nameController.clear();
          priceController.clear();
          stockController.clear();
          specController.clear();
        });

        // 🟢 Redirect ke halaman manajemen produk
        // Delay sedikit agar notifikasi terbaca sekilas
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go('/manajemen-produk');
        }
      }
    } catch (e) {
      showAppNotification(
        AppNotificationType.error,
        "Gagal",
        "Terjadi kesalahan saat menambahkan produk: $e",
      );
    } finally {
      // 🟢 Matikan loading state apapun hasilnya
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Widget: Nama Produk
    Widget fieldName = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Nama Produk", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: nameController,
          style: _inputTextStyle,
          decoration: _commonInputDecoration("Masukkan Nama Produk"),
          validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
        ),
        const SizedBox(height: 16),
      ],
    );

    // Widget: Kategori Produk
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
                width: categoryError ? 1 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  categoryController.text.isEmpty
                      ? "Pilih Kategori Produk"
                      : categoryController.text,
                  style: const TextStyle(fontSize: 13),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        if (categoryError)
          const Padding(
            padding: EdgeInsets.only(top: 3, left: 12),
            child: Text(
              "Wajib diisi",
              style: TextStyle(color: Color(0xFFDC143C), fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );

    // Widget: Harga Produk
    Widget fieldPrice = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Harga Produk",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: priceController,
          style: _inputTextStyle,
          decoration: _commonInputDecoration("Masukkan Harga Produk"),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CurrencyInputFormatter(),
          ],
          validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
        ),
        const SizedBox(height: 16),
      ],
    );

    // Widget: Spesifikasi Produk
    Widget fieldSpec = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Spesifikasi Produk",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: specController,
          style: _inputTextStyle,
          decoration: _commonInputDecoration("Masukkan Spesifikasi Produk"),
          validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
        ),
        const SizedBox(height: 16),
      ],
    );

    // Widget: Stok Produk
    Widget fieldStock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Stok Produk", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: stockController,
          style: _inputTextStyle,
          decoration: _commonInputDecoration("Masukkan Stok Produk"),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CurrencyInputFormatter(),
          ],
          validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
        ),
        const SizedBox(height: 16),
      ],
    );

    // Widget: Gambar Produk
    Widget fieldImage = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text("Gambar Produk",
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Text("*Disarankan foto dengan background putih",
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: imageError ? const Color(0xFFDC143C) : Colors.black,
              width: imageError ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(5),
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
                  image1Name ?? "Belum ada file terpilih",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: imageError ? const Color(0xFFDC143C) : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (imageError)
          const Padding(
            padding: EdgeInsets.only(top: 3, left: 12),
            child: Text(
              "Wajib diisi",
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

    // Widget: Tombol Submit (Disable jika isSubmitting)
    Widget btnSubmit = ElevatedButton(
      onPressed: isSubmitting ? null : _submitForm, // 🟢 Disable saat loading
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF301D02),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 21),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: isSubmitting
          ? const SizedBox( // 🟢 Tampilkan loading saat proses
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      )
          : const Text("Tambah Produk"),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Form(
                key: _formKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
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
                            const SizedBox(height: 16),
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
                                      const SizedBox(height: 4),
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
                    },
                  ),
                ),
              ),
            ),
          ),
          if (showCategoryDropdown)
            Positioned(
              left: 41,
              top: 214,
              width: categoryFieldWidth,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(6),
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
                            width: double.infinity,
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

  InputDecoration _commonInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black, width: 1),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFDC143C), width: 1),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFDC143C), width: 1.5),
      ),
    );
  }
}

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
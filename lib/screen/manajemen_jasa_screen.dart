import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:typed_data';              // <- untuk Uint8List
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../widgets/custom_app_notification.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;
import '../api_client.dart';

// ------------ status untuk konsultasi ---------------
String translateStatus(String raw) {
  const contractStatuses = [
    "timeline_in_progress",
    "awaiting_payment",
    "in_progress",
    "completed",
    "finalized",
    "contract_uploaded",
  ];

  if (contractStatuses.contains(raw)) {
    return "Memiliki Kontrak";
  }

  switch (raw) {
    case "pending":
      return "Menunggu";
    case "cancelled":
      return "Batal";
    case "confirmed":
      return "Diterima";
    default:
      return raw;
  }
}

Color statusColor(String raw) {
  const contractStatuses = [
    "timeline_in_progress",
    "awaiting_payment",
    "in_progress",
    "completed",
    "finalized",
    "contract_uploaded",
  ];

  if (contractStatuses.contains(raw)) {
    return Colors.black; // Sama seperti contract_uploaded
  }

  switch (raw) {
    case "pending":
      return Colors.yellow[700]!;
    case "cancelled":
      return Colors.red;
    case "confirmed":
      return Colors.green;
    default:
      return Colors.grey;
  }
}

Color statusTextColor(String raw) {
  const contractStatuses = [
    "timeline_in_progress",
    "awaiting_payment",
    "in_progress",
    "completed",
    "finalized",
    "contract_uploaded",
  ];

  if (contractStatuses.contains(raw)) {
    return Colors.white; // Sama seperti contract_uploaded
  }

  switch (raw) {
    case "cancelled":
      return Colors.white;
    case "confirmed":
      return Colors.white;
    case "pending":
    default:
      return Colors.black;
  }
}

// ------------ status untuk kontrak ---------------
String translateStatusContract(Map<String, dynamic> item) {
  String raw = item['status'] ?? '';
  String paymentStatus = item['payment_status'] ?? '';

  // 🟢 LOGIKA AWAITING PAYMENT
  if (raw == 'awaiting_payment') {
    if (paymentStatus == 'awaiting_payment') {
      return "Menunggu Pembayaran DP";
    } else if (paymentStatus == 'not_ready_final') {
      return "Pembayaran DP Lunas";
    } else if (paymentStatus == 'awaiting_final_payment') {
      return "Menunggu Pembayaran Akhir";
    } else if (paymentStatus == 'paid') {
      return "Pembayaran Akhir Lunas";
    } return "Menunggu Pembayaran";
  }

  switch (raw) {
    case "timeline_in_progress":
      return "Dalam Pengerjaan";
    case "in_progress":
      return "Menunggu Pelunasan";
    case "completed":
      return "Selesai";
    case "finalized":
      return "Finalisasi";
    case "contract_uploaded":
      return "Memiliki Kontrak";

  // STATUS UMUM
    case "pending":
      return "Menunggu";
    case "cancelled":
      return "Batal";
    case "confirmed":
      return "Diterima";

    default:
      return raw;
  }
}

Color statusColorContract(Map<String, dynamic> item) {
  String raw = item['status'] ?? '';
  String paymentStatus = item['payment_status'] ?? '';

  // 🟢 LOGIKA KHUSUS WARNA HITAM UNTUK PEMBAYARAN LUNAS
  if (raw == 'awaiting_payment') {
    if (paymentStatus == 'not_ready_final' || paymentStatus == 'paid') {
      return Colors.green; // Hitam jika DP Lunas atau Akhir Lunas
    }
    return Colors.yellow[700]!; // Kuning untuk yang masih menunggu
  }

  switch (raw) {
    case "timeline_in_progress": return Colors.black;
    case "in_progress": return Colors.yellow[700]!;
    case "completed": return Colors.green;
    case "finalized": return Colors.black;
    case "contract_uploaded": return Colors.black;
    case "pending": return Colors.yellow[700]!;
    case "cancelled": return Colors.red;
    case "confirmed": return Colors.green;
    default: return Colors.grey;
  }
}

Color statusTextColorContract(Map<String, dynamic> item) {
  String raw = item['status'] ?? '';
  String paymentStatus = item['payment_status'] ?? '';

  // 🟢 LOGIKA TEXT COLOR
  if (raw == 'awaiting_payment') {
    if (paymentStatus == 'not_ready_final' || paymentStatus == 'paid') {
      return Colors.white; // Putih karena backgroundnya Hitam
    }
    return Colors.black; // Hitam karena backgroundnya Kuning
  }

  switch (raw) {
    case "completed":
    case "finalized":
    case "timeline_in_progress":
    case "contract_uploaded":
    case "cancelled":
    case "confirmed":
      return Colors.white;

    case "pending":
    case "in_progress":
      return Colors.black;

    default:
      return Colors.white;
  }
}

// ------------ status untuk timeline ---------------
String translateStatusTimeline(String raw) {
  switch (raw) {
  // === MENUNGGU ===
    case "pending":
      return "Sedang Dikerjakan";
    case "in_progress":
      return "Progress Selesai";
    case "completed":
      return "Progress Selesai";
    case "cancel":
      return "Batal";
    default:
      return raw;
  }
}

Color statusColorTimeline(String raw) {
  switch (raw) {
    case "pending":
      return Colors.black;
    case "in_progress":
      return Colors.green;
    case "completed":
      return Colors.green;
    case "cancel":
      return Colors.red;
    default:
      return Colors.grey;
  }
}

Color statusTextColorTimeline(String raw) {
  switch (raw) {
    case "cancel":
    case "completed":
    case "in_progress":
    case "pending":
      return Colors.white;
    default:
      return Colors.white;
  }
}

final _rupiahFormatter = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

// 🟢 CLASS BARU UNTUK DIALOG DETAIL TIMELINE (StatefulWidget untuk mengelola komentar)
class TimelineDetailDialog extends StatefulWidget {
  final Map<String, dynamic> item;

  // ID yang diperlukan untuk API Comment
  final int timelineId;
  final int consultationId;
  final int contractId;

  const TimelineDetailDialog({
    super.key,
    required this.item,
    required this.timelineId,
    required this.consultationId,
    required this.contractId,
  });

  @override
  State<TimelineDetailDialog> createState() => _TimelineDetailDialogState();
}

class _TimelineDetailDialogState extends State<TimelineDetailDialog> {
  List<dynamic> comments = [];
  bool isLoadingComments = true;
  final TextEditingController commentController = TextEditingController();
  bool isSubmittingComment = false;
  // Kunci Utama untuk logika: Apakah customer/user sudah pernah kirim komentar?
  bool hasCustomerCommented = false;

  @override
  void initState() {
    super.initState();
    fetchComments();
  }

  // 🟢 FUNGSI FETCH COMMENTS
  Future<void> fetchComments() async {
    setState(() => isLoadingComments = true);
    try {
      final response = await ApiClient.dio.get(
        "/consultations/${widget.consultationId}/contracts/${widget.contractId}/timeline/${widget.timelineId}/comments",
      );

      final List<dynamic> fetchedComments = response.data['comments'] ?? [];

      // 🟢 LOGIKA PENGECEKAN KOMENTAR CUSTOMER PERTAMA
      // Cek apakah ada komentar dari user (customer)
      final bool customerExists = fetchedComments.any((c) => c['author_type'] == 'user');

      setState(() {
        // **[PERUBAHAN DISINI]**: Hapus .reversed.toList()
        // Komentar akan diurutkan berdasarkan urutan dari backend (yang diasumsikan kronologis lama ke baru jika tidak ada field sort)
        comments = fetchedComments;
        isLoadingComments = false;
        hasCustomerCommented = customerExists;
      });

    } on DioException catch (e) {
      print("Gagal memuat komentar: ${e.message}");
      if (mounted) {
        // Gunakan fungsi showAppNotification untuk konsistensi
        final msg = e.response?.data['message'] ?? 'Gagal memuat komentar.';
        (context as Element).findAncestorStateOfType<_ServiceManagementContentState>()?.showAppNotification(
          AppNotificationType.error, "Gagal", msg,
        );
      }
      setState(() => isLoadingComments = false);
    } catch (e) {
      setState(() => isLoadingComments = false);
    }
  }

  // 🟢 FUNGSI SUBMIT KOMENTAR
  Future<void> submitComment() async {
    final message = commentController.text.trim();
    if (message.isEmpty) return;

    setState(() => isSubmittingComment = true);

    try {
      await ApiClient.dio.post(
        "/consultations/${widget.consultationId}/contracts/${widget.contractId}/timeline/${widget.timelineId}/comments",
        data: {
          "message": message,
        },
      );

      commentController.clear();
      // Tampilkan notifikasi sukses
      (context as Element).findAncestorStateOfType<_ServiceManagementContentState>()?.showAppNotification(
        AppNotificationType.success, "Berhasil", "Komentar terkirim.",
      );

      await fetchComments(); // Refresh daftar komentar

    } on DioException catch (e) {
      String msg = "Gagal mengirim komentar";
      if (e.response?.data is Map) {
        msg = e.response?.data['message']?.toString() ?? e.message ?? msg;
      }
      if (mounted) {
        (context as Element).findAncestorStateOfType<_ServiceManagementContentState>()?.showAppNotification(
          AppNotificationType.error, "Gagal", msg,
        );
      }
    } finally {
      setState(() => isSubmittingComment = false);
    }
  }


  // 🟢 WIDGET KOMENTAR ITEM
  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final isCustomer = comment['author_type'] == 'user';

    // 💡 PERBAIKAN: Ganti 'final' menjadi 'String' atau 'var'
    String name = comment['author_name'] ?? (isCustomer ? 'Customer' : 'Admin');

    if (name == "System Administrator") {
      name = "Admin"; // OK, karena 'name' sekarang bukan 'final'
    }

    final message = comment['message'] ?? 'Tidak ada pesan';
    final timeRaw = comment['created_at'];
    String formattedTime = '';

    if (timeRaw != null) {
      try {
        final dt = DateTime.parse(timeRaw).toLocal();
        formattedTime = DateFormat('HH:mm, d MMM').format(dt);
      } catch (_) {
        formattedTime = '-';
      }
    }

    return Align(
      alignment: isCustomer ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: isCustomer ? Colors.white : const Color(0xFF301D02), // Admin berwarna gelap
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isCustomer ? Colors.grey.shade300 : const Color(0xFF301D02))
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isCustomer ? Colors.black : Colors.white,
                  ),
                ),
                Text(
                  formattedTime,
                  style: TextStyle(fontSize: 10, color: isCustomer ? Colors.grey : Colors.grey[300]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(message, style: TextStyle(fontSize: 13, color: isCustomer ? Colors.black : Colors.white)),
          ],
        ),
      ),
    );
  }

  // 🟢 WIDGET SECTION KOMENTAR
  Widget _buildCommentSection() {

    // 1. Tentukan apakah input harus dinonaktifkan
    final bool isInputDisabled = !hasCustomerCommented && comments.isEmpty;

    // 2. Kustomisasi input decoration
    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: isInputDisabled ? BorderSide.none : const BorderSide(color: Colors.black, width: 1),
      ),
      // Atur padding content agar input terlihat lebih tinggi
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      hintText: isInputDisabled ? "Tunggu customer mengirim komentar pertama..." : "Ketik disini ...",
      hintStyle: const TextStyle(fontSize: 13),
      fillColor: isInputDisabled ? Colors.grey[300] : Colors.white,
      filled: true,
      enabled: !isInputDisabled,
      isDense: true,
    );

    // 3. Konten Daftar Komentar
    Widget commentListContent;
    if (isLoadingComments) {
      commentListContent = const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(strokeWidth: 2)));
    } else {
      commentListContent = ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: comments.length,
        itemBuilder: (context, index) => _buildCommentItem(comments[index]),
      );
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Komentar Customer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),

        // Daftar Komentar (menggunakan widget yang menampilkan daftar komentar)
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: comments.isEmpty ? Colors.grey[200] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: comments.isNotEmpty ? Border.all(color: Colors.black) : null,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: comments.isNotEmpty ? commentListContent : const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Belum ada komentar",
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ),
          ),
        ),

        // Input Balasan - Bagian yang dirapikan
        const SizedBox(height: 12), // Jarak yang cukup dari daftar komentar di atas
        Row(
          crossAxisAlignment: CrossAxisAlignment.center, // Pastikan input dan tombol sejajar di tengah secara vertikal
          children: [
            Expanded(
              child: TextField(
                controller: commentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                enabled: !isInputDisabled,
                style: const TextStyle(fontSize: 13),
                decoration: inputDecoration,
              ),
            ),
            const SizedBox(width: 8),

            // Hapus Container(height: 50) yang membungkus ElevatedButton
            ElevatedButton(
              onPressed: isInputDisabled || isSubmittingComment ? null : submitComment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF301D02),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                disabledBackgroundColor: Colors.grey,
              ),
              child: isSubmittingComment
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Balas", style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }

  // 🟢 WIDGET BUILDER UTAMA UNTUK DIALOG (Tidak Berubah dari logika sebelumnya)
  @override
  Widget build(BuildContext context) {
    // Parsing Data Dasar sesuai respon JSON
    final String title = widget.item['title'] ?? '-';
    final String description = widget.item['description'] ?? '-';
    final String activityType = widget.item['activity_type'] ?? 'progress';
    final String status = widget.item['status'] ?? 'pending';
    final String dueDateRaw = widget.item['due_date'] ?? '';

    // Parsing Data Meeting & File
    final String? meetingTimeRaw = widget.item['meeting_datetime'];
    final String? meetingLink = widget.item['meeting_link'];
    final String? resultFilePath = widget.item['result_file_path'];

    // Helper Format Tanggal
    String formatFullDate(String? raw) {
      if (raw == null || raw.isEmpty) return "-";
      try {
        final dt = DateTime.parse(raw);
        return DateFormat("d MMMM yyyy", "id_ID").format(dt);
      } catch (_) {
        return raw;
      }
    }

    String formatDateTimeStr(String? raw) {
      if (raw == null || raw.isEmpty) return "-";
      try {
        final dt = DateTime.parse(raw);
        return DateFormat("d MMMM yyyy, HH:mm", "id_ID").format(dt);
      } catch (_) {
        return raw;
      }
    }

    // Styles
    const TextStyle labelStyle = TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold);
    const TextStyle valueStyle = TextStyle(fontSize: 14, color: Colors.black);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // === HEADER ===
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Detail Timeline", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 10),

              // 1. Judul & Badge Tipe
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Judul Kegiatan", style: labelStyle),
                        const SizedBox(height: 2),
                        Text(title, style: valueStyle),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      activityType.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Deskripsi
              const Text("Deskripsi", style: labelStyle),
              const SizedBox(height: 2),
              Text(description, style: valueStyle),
              const SizedBox(height: 12),

              // 3. Status & Deadline
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Status", style: labelStyle),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColorTimeline(status),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            translateStatusTimeline(status),
                            style: TextStyle(
                              fontSize: 10,
                              color: statusTextColorTimeline(status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Deadline", style: labelStyle),
                        const SizedBox(height: 2),
                        Text(formatFullDate(dueDateRaw), style: valueStyle),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 4),

              // === BAGIAN BUKTI KERJA / MEETING ===

              // KONDISI A: Jika Tipe Meeting -> Tampilkan Link & Waktu (Tanpa Gambar)
              if (activityType == 'meeting') ...[
                const Text("Informasi Meeting", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),

                const Text("Waktu Meeting", style: labelStyle),
                Text(formatDateTimeStr(meetingTimeRaw), style: valueStyle),
                const SizedBox(height: 8),

                const Text("Link Meeting", style: labelStyle),
                InkWell(
                  onTap: () {
                    if (meetingLink != null && meetingLink.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: meetingLink));
                      (context as Element).findAncestorStateOfType<_ServiceManagementContentState>()?.showAppNotification(
                        AppNotificationType.success, "Berhasil", "Link disalin",
                      );
                    }
                  },
                  child: Text(
                    (meetingLink == null || meetingLink.isEmpty) ? "-" : meetingLink,
                    style: const TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
              ]
              // KONDISI B: Jika Progress/Finalization & Status Completed -> Tampilkan Gambar
              else if (status == 'completed') ...[
                const Text("Bukti Pekerjaan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                if (resultFilePath != null && resultFilePath.isNotEmpty)
                  _buildImageBoxFromAdmin(resultFilePath)
                else
                  const Text("Tidak ada file bukti yang diunggah.", style: TextStyle(fontSize: 12, color: Colors.grey)),

                const SizedBox(height: 8),
                const Divider(),
              ]
              // KONDISI C: Lainnya
              else ...[
                  const Center(
                    child: Text("Belum ada data tambahan.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                ],

              const SizedBox(height: 8),

              // === BAGIAN KOMENTAR BARU ===
              _buildCommentSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class ServiceManagementContent extends StatefulWidget {
  const ServiceManagementContent({super.key});

  @override
  State<ServiceManagementContent> createState() =>
      _ServiceManagementContentState();
}

class _ServiceManagementContentState extends State<ServiceManagementContent> {
  int _selectedTabIndex = 0;
  //💡 STATE BARU UNTUK KONSULTASI (ID yang sedang expand)
  int? _expandedKonsultasiId;

  // 💡 STATE BARU UNTUK TIMELINE (ID Konsultasi yang sedang expand)
  int? _expandedTimelineConsultationId;

  final List<String> tabs = ['Konsultasi', 'Timeline'];

  // 🟩 Tambahkan variabel untuk data konsultasi dari API
  List<dynamic> konsultasiData = [];
  bool isLoading = false;
  String? errorMessage;
  File? selectedPdf;
  String? pdfName;
  bool pdfError = false;
  Uint8List? selectedPdfBytes;
  Map<int, int> _consultationContractIds = {};

  final TextEditingController projectCostController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchConsultations(); // 🟩 Panggil saat initState
  }

  void showAppNotification(AppNotificationType type, String title, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;   // ← deklarasi dulu

    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: CustomAppNotification(
          type: type,
          title: title,
          message: message,
          onClose: () => entry.remove(),   // ← sekarang sudah aman
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 3), () {
      entry.remove();
    });
  }

  Future<void> _pickPdf(StateSetter dialogSetState) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["pdf"],
      withData: true,
    );

    if (result != null) {
      final file = result.files.single;

      dialogSetState(() {
        pdfName = file.name;
        selectedPdfBytes = file.bytes;
        pdfError = false;
      });
    }
  }

  void _showSetPaymentDialog(BuildContext context, int consultationId, String username) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("Konfirmasi Pembayaran DP"),
          content: Text(
            "Apakah anda yakin mau mensetting pembayaran DP untuk customer atas nama $username?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Tutup dialog
              child: const Text("Tidak", style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Tutup dialog dulu

                try {
                  // PATCH ke endpoint status
                  await ApiClient.dio.patch(
                    "/consultations/$consultationId/status",
                    data: {"status": "awaiting_payment"},
                  );

                  showAppNotification(
                    AppNotificationType.success,
                    "Berhasil",
                    "Status berhasil diubah menjadi Menunggu Pembayaran",
                  );

                  // Refresh Data List
                  fetchConsultations();

                } on DioException catch (e) {
                  String msg = "Terjadi kesalahan server";
                  if (e.response != null) {
                    msg = e.response?.data['message'] ?? e.message;
                  }
                  showAppNotification(AppNotificationType.error, "Gagal", msg);
                } catch (e) {
                  showAppNotification(AppNotificationType.error, "Error", e.toString());
                }
              },
              child: const Text("Ya", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 🟢 FUNGSI BARU: Menampilkan Dialog Input Link Meet & Eksekusi API
  void _showAcceptConsultationDialog(int consultationId) {
    final TextEditingController meetLinkController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 500, // Lebar Fix
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Terima Konsultasi",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  "Link Meeting Konsultasi Online",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),

                TextField(
                  controller: meetLinkController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    hintText: "Contoh: https://meet.google.com/abc-defg-hij",
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final link = meetLinkController.text.trim();

                      // 1. Validasi Input Kosong
                      if (link.isEmpty) {
                        showAppNotification(
                          AppNotificationType.error,
                          "Gagal",
                          "Link Google Meet harus diisi",
                        );
                        return;
                      }

                      // 2. Validasi Format URL (Opsional tapi disarankan)
                      if (!link.startsWith("http")) {
                        showAppNotification(
                          AppNotificationType.warning,
                          "Format Salah",
                          "Link harus diawali dengan https://",
                        );
                        return;
                      }

                      try {
                        // 🟢 REQUEST 1: Kirim Link Meet (Key: meetLink)
                        await ApiClient.dio.patch(
                          "/consultations/$consultationId/pre-contract-meeting",
                          data: {
                            "meetLink": link // ✅ SUDAH DIPERBAIKI (camelCase)
                          },
                        );

                        // 🟢 REQUEST 2: Update Status jadi 'confirmed'
                        await ApiClient.dio.patch(
                          "/consultations/$consultationId/status",
                          data: {
                            "status": "confirmed"
                          },
                        );

                        // Jika sukses
                        Navigator.pop(context);

                        showAppNotification(
                          AppNotificationType.success,
                          "Berhasil",
                          "Konsultasi diterima & Link meet terkirim",
                        );

                        // Refresh data list
                        fetchConsultations();

                      } on DioException catch (e) {
                        Navigator.pop(context);

                        String errorMessage = "Terjadi kesalahan koneksi";

                        // Cek pesan error spesifik dari backend
                        if (e.response != null && e.response?.data != null) {
                          if (e.response!.data is Map && e.response!.data['message'] != null) {
                            errorMessage = e.response!.data['message'];
                          } else {
                            errorMessage = "Error ${e.response!.statusCode}";
                          }
                        }

                        showAppNotification(
                          AppNotificationType.error,
                          "Gagal",
                          errorMessage,
                        );

                        // Debug print untuk melihat detail error di konsol
                        print("Full Error Log: ${e.response?.data}");
                      } catch (e) {
                        Navigator.pop(context);
                        showAppNotification(
                          AppNotificationType.error,
                          "Gagal",
                          "Error tidak diketahui: $e",
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF301D02),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text("Kirim & Terima"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _createContract(int consultationId) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Container(
                width: 500,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Upload Kontrak",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ... (Bagian UI Upload File dan Input Biaya Proyek TETAP SAMA) ...
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: pdfError ? const Color(0xFFDC143C) : Colors.black,
                          width: pdfError ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => _pickPdf(setState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 21),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text("Pilih PDF"),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              pdfName ?? "Belum ada file terpilih",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: pdfError ? const Color(0xFFDC143C) : Colors.black, fontSize: 13
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (pdfError)
                      const Padding(
                        padding: EdgeInsets.only(top: 3, left: 12),
                        child: Text("Wajib diisi", style: TextStyle(color: Color(0xFFDC143C), fontSize: 13)),
                      ),
                    const SizedBox(height: 16),
                    const Text("Biaya Proyek", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: projectCostController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        hintText: "Masukkan biaya proyek",
                        hintStyle: const TextStyle(fontSize: 13),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CurrencyInputFormatter(),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // --- TOMBOL UPLOAD ---
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (pdfName == null) {
                            setState(() => pdfError = true);
                            return;
                          }

                          if (projectCostController.text.isEmpty) {
                            showAppNotification(
                              AppNotificationType.error,
                              "Gagal",
                              "Biaya proyek harus diisi",
                            );
                            return;
                          }

                          String cleanCost = projectCostController.text.replaceAll('.', '');

                          // 1. Eksekusi Upload
                          bool isUploaded = await uploadContract(
                            consultationId,
                            selectedPdfBytes,
                            cleanCost,
                          );

                          // 2. Jika Upload Sukses, Lanjut Update Status
                          if (isUploaded) {
                            try {
                              // PATCH status menjadi awaiting_payment
                              await ApiClient.dio.patch(
                                "/consultations/$consultationId/status",
                                data: {"status": "awaiting_payment"},
                              );

                              // Tutup dialog
                              if (mounted) Navigator.pop(context);

                              showAppNotification(
                                AppNotificationType.success,
                                "Berhasil",
                                "Kontrak berhasil diupload & Status diperbarui ke Menunggu Pembayaran",
                              );

                              // Refresh Data
                              fetchConsultations();

                            } on DioException catch (e) {
                              // Jika upload sukses tapi update status gagal
                              String msg = "Kontrak terupload tapi gagal update status";
                              if (e.response != null) {
                                msg = e.response?.data['message'] ?? e.message;
                              }
                              showAppNotification(AppNotificationType.warning, "Perhatian", msg);
                              fetchConsultations(); // Tetap refresh
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF301D02),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text("Upload Kontrak"),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
  // Mengubah return type menjadi Future<bool> agar bisa di-chaining
  // ------------------------------------------------------------------------
  Future<bool> uploadContract(
      int consultationId,
      Uint8List? pdfBytes,
      String projectCost,
      ) async {
    if (pdfBytes == null) {
      print("PDF belum dipilih");
      return false;
    }

    final formData = FormData.fromMap({
      "contract": MultipartFile.fromBytes(
        pdfBytes,
        filename: pdfName,
        contentType: MediaType("application", "pdf"),
      ),
      "projectCost": projectCost,
    });

    try {
      final response = await ApiClient.dio.post(
        "/consultations/$consultationId/contracts",
        data: formData,
      );

      print("Upload sukses: ${response.data}");
      // Notifikasi sukses upload dipindah ke flow utama agar tidak double notif
      return true;
    } catch (e) {
      print("Upload gagal: $e");
      showAppNotification(AppNotificationType.error, "Gagal", "Tidak dapat mengupload kontrak");
      return false;
    }
  }

  // 🟩 Tambahkan fungsi ambil data dari endpoint langsung di sini
  Future<void> fetchConsultations() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await ApiClient.dio.get("/consultations/admin/all");
      if (response.statusCode == 200) {
        setState(() {
          konsultasiData = response.data as List<dynamic>;
          isLoading = false;
        });
        _fetchContractIdsForTimeline();
      } else {
        setState(() {
          errorMessage =
          "Gagal mengambil data konsultasi (${response.statusCode})";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Terjadi kesalahan: $e";
        isLoading = false;
      });
    }
  }

  // 🟩 FUNGSI BARU: Terima Konsultasi (PATCH status)
  Future<void> _acceptConsultation(int consultationId) async {
    try {
      // Melakukan request PATCH ke endpoint
      final response = await ApiClient.dio.patch(
        "/consultations/$consultationId/status",
        data: {
          "status": "confirmed"
        },
      );

      // Cek response
      if (response.statusCode == 200) {
        showAppNotification(
          AppNotificationType.success,
          "Berhasil",
          "Konsultasi berhasil diterima.",
        );

        // Refresh data agar tampilan berubah (misal tombol jadi 'Buat Kontrak')
        fetchConsultations();
      }
    } catch (e) {
      // Error handling
      print("Error accepting consultation: $e");
      showAppNotification(
        AppNotificationType.error,
        "Gagal",
        "Gagal menerima konsultasi: $e",
      );
    }
  }

  Future<void> _showContractDialog(int consultationId) async {
    try {
      final response = await ApiClient.dio.get(
        "/consultations/$consultationId/contracts",
      );

      final contract = response.data['contract'];
      if (contract == null) {
        showAppNotification(AppNotificationType.error, "Gagal", "Kontrak tidak ditemukan");
        return;
      }

      final String filePath = contract['filePath'] ?? '';
      final int projectCost = contract['projectCost'] ?? 0;
      // 🟢 1. AMBIL ID KONTRAK
      final int contractId = contract['id'] ?? 0;

      // baseUrl dari dio lalu hilangkan /api
      const String BASE_IMAGE_DOMAIN = "https://api.cvariftamatekindo.my.id";

      final String pdfUrl = Uri.parse(BASE_IMAGE_DOMAIN).resolve(filePath).toString();
      print("DEBUG PDF URL: $pdfUrl");

      final String formattedCost = _rupiahFormatter.format(projectCost);

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 500,
                maxHeight: 500,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // header
                    Row( // 🟢 Hapus keyword 'const' karena ada variabel di dalamnya
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 🟢 2. TAMPILKAN TEXT DAN ID SEJAJAR
                        Row(
                          children: [
                            const Text(
                              "Kontrak Kerja",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8), // Jarak spasi
                            Text(
                              "ID Kontrak : $contractId", // Menampilkan ID
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54, // Warna abu agar sedikit beda
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // area PDF (besar di kiri)
                          Expanded(
                            flex: 5,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black54),
                              ),
                              child: ClipRRect(
                                child: Scrollbar(
                                  child: SfPdfViewer.network(
                                    pdfUrl,
                                    onDocumentLoadFailed: (details) {
                                      print("PDF VIEWER LOAD ERROR: ${details.description}");
                                      // Tambahkan Icon/Text fallback di sini jika perlu
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 15),

                          // sisi kanan: tombol unduh + cost
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await _downloadPdf(pdfUrl);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B2504),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: const Text("Unduh"),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  "Biaya Proyek : ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formattedCost,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
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
        },
      );
    } catch (e) {
      showAppNotification(AppNotificationType.error, "Error", "Gagal memuat kontrak: $e");
    }
  }

  Future<void> _downloadPdf(String url) async {
    // cara simple untuk Flutter Web

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '')
      ..target = 'blank';
    html.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
  }

  // ... variabel yang sudah ada sebelumnya ...

  // 🟩 STATE BARU UNTUK TIMELINE
  // Menyimpan status expand berdasarkan ID Konsultasi
  Set<int> _expandedTimelineIds = {};
  // Menyimpan data timeline. Key: Consultation ID, Value: List Timeline
  Map<int, List<dynamic>> _timelineDataMap = {};
  // Menyimpan status loading per item. Key: Consultation ID
  Map<int, bool> _timelineLoadingMap = {};

  // 🟩 FUNGSI FETCH TIMELINE (NESTED REQUEST)
  Future<void> _fetchTimelineForConsultation(int consultationId) async {
    // Jangan fetch lagi jika data sudah ada
    if (_timelineDataMap.containsKey(consultationId)) return;

    setState(() {
      _timelineLoadingMap[consultationId] = true;
    });

    try {
      // 1. Ambil Data Contract dulu untuk dapat ID Contract
      final contractRes = await ApiClient.dio.get(
        "/consultations/$consultationId/contracts",
      );

      final contractData = contractRes.data['contract'];
      if (contractData == null) throw Exception("Data kontrak tidak ditemukan");

      final int contractId = contractData['id'];

      // 2. Ambil Data Timeline menggunakan ID Contract
      final timelineRes = await ApiClient.dio.get(
        "/consultations/$consultationId/contracts/$contractId/timeline",
      );

      // Sesuai struktur JSON pada gambar: response.data['timeline']
      final List<dynamic> timelineList = timelineRes.data['timeline'] ?? [];

      setState(() {
        _timelineDataMap[consultationId] = timelineList;
      });

    } catch (e) {
      showAppNotification(AppNotificationType.error, "Error", "Gagal memuat timeline: $e");
    } finally {
      setState(() {
        _timelineLoadingMap[consultationId] = false;
      });
    }
  }

  Future<void> _fetchContractIdsForTimeline() async {
    // 1. Filter hanya status yang relevan dengan timeline
    final allowedStatuses = [
      'timeline_in_progress',
      'awaiting_payment',
      'in_progress',
      'completed',
      'finalized',
      'contract_uploaded',
    ];

    final timelineCandidates = konsultasiData.where((item) {
      return allowedStatuses.contains(item['status']);
    }).toList();

    // 2. Loop setiap item dan request ke endpoint contract
    for (var item in timelineCandidates) {
      final int consultationId = item['id'];

      // Cek apakah kita sudah punya ID kontraknya? Jika belum, fetch.
      if (!_consultationContractIds.containsKey(consultationId)) {
        try {
          final response = await ApiClient.dio.get(
            "/consultations/$consultationId/contracts",
          );

          // Sesuai struktur JSON pada gambar Anda: { "contract": { "id": 9, ... } }
          final contractData = response.data['contract'];

          if (contractData != null && contractData['id'] != null) {
            final int fetchedContractId = contractData['id'];

            if (mounted) {
              setState(() {
                _consultationContractIds[consultationId] = fetchedContractId;
              });
            }
          }
        } catch (e) {
          print("Gagal ambil kontrak untuk konsultasi $consultationId: $e");
        }
      }
    }
  }

  // 🟢 FUNGSI BARU: Dialog Input Timeline + Logic API
  void _showCreateTimelineDialog(BuildContext context, int consultationId, int contractId) {
    final _formKey = GlobalKey<FormState>();

    // Controllers
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final TextEditingController linkController = TextEditingController();

    // State Variables
    String? selectedActivityType;
    DateTime? selectedDueDate;
    DateTime? selectedMeetingDate;
    TimeOfDay? selectedMeetingTime;

    bool isSubmitting = false;

    // Helper Format
    String formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
    String formatDateTime(DateTime date, TimeOfDay time) {
      final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    }

    // Styles
    const double contentPadding = 16.0;
    const TextStyle headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 16);
    const TextStyle labelStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
    const TextStyle inputTextStyle = TextStyle(fontSize: 13);

    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      isDense: true,
    );

    showDialog(
      context: context,
      barrierDismissible: true, // 🟢 UBAH KE TRUE: Klik luar untuk tutup
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {

            Future<void> _pickDate({required bool isMeeting}) async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setStateDialog(() {
                  if (isMeeting) selectedMeetingDate = picked;
                  else selectedDueDate = picked;
                });
              }
            }

            Future<void> _pickTime() async {
              final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
              if (picked != null) {
                setStateDialog(() => selectedMeetingTime = picked);
              }
            }

            Future<void> _submitTimeline() async {
              if (!_formKey.currentState!.validate()) return;
              // ... (validasi lainnya)

              setStateDialog(() => isSubmitting = true);

              try {
                Map<String, dynamic> itemData = {
                  "title": titleController.text,
                  "description": descController.text,
                  "activityType": selectedActivityType,
                  "dueDate": formatDate(selectedDueDate!),
                };

                if (selectedActivityType == 'meeting') {
                  itemData["meetingDatetime"] = formatDateTime(selectedMeetingDate!, selectedMeetingTime!);
                  itemData["meetingLink"] = linkController.text;
                }

                // 🌟 LANGKAH 1: Tambahkan Logging Payload sebelum POST
                print('--- POST /consultations/$consultationId/contracts/$contractId/timeline ---');
                print('Payload Item: ${itemData.toString()}');


                // 1. POST Item Timeline
                await ApiClient.dio.post(
                  "/consultations/$consultationId/contracts/$contractId/timeline",
                  data: {"items": [itemData]},
                );

                // 2. Cek Activity Type dan Lakukan PATCH Status Kontrak
                if (selectedActivityType == 'finalization') {
                  // 🌟 LOGIKA BARU UNTUK FINALIZATION

                  // 🌟 Logging PATCH
                  print('Activity is FINALIZATION. Initiating PATCH status to awaiting_payment...');

                  await ApiClient.dio.patch(
                    "/consultations/$consultationId/status",
                    data: {"status": "awaiting_payment"},
                  );

                  print('PATCH status to awaiting_payment SUCCESS.');
                }

                if (mounted) Navigator.pop(context);
                showAppNotification(AppNotificationType.success, "Berhasil", "Timeline berhasil dibuat" + (selectedActivityType == 'finalization' ? " & Status Kontrak diperbarui ke Menunggu Pembayaran." : "."));

                // Refresh data setelah semua operasi selesai
                _fetchTimelineForConsultation(consultationId);

              } on DioException catch (e) {
                // ... (Penanganan error Dio)
                setStateDialog(() => isSubmitting = false);
                String msg = "Terjadi kesalahan server";
                if (e.response != null) msg = e.response?.data['message'] ?? e.message;
                showAppNotification(AppNotificationType.error, "Gagal", msg);
              } catch (e) {
                // ... (Penanganan error umum)
                setStateDialog(() => isSubmitting = false);
                showAppNotification(AppNotificationType.error, "Error", e.toString());
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(contentPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header (Tanpa Tombol Close)
                        const Text("Buat Timeline", style: headerStyle),
                        const SizedBox(height: 16),

                        // Input Judul
                        const Text("Judul Kegiatan", style: labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: titleController,
                          style: inputTextStyle,
                          decoration: inputDecoration.copyWith(hintText: "Masukkan judul"),
                          validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                        ),
                        const SizedBox(height: 12),

                        // Input Deskripsi
                        const Text("Deskripsi Kegiatan", style: labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: descController,
                          maxLines: 3,
                          style: inputTextStyle,
                          decoration: inputDecoration.copyWith(hintText: "Masukkan deskripsi"),
                          validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                        ),
                        const SizedBox(height: 12),

                        // Dropdown Jenis Kegiatan
                        const Text("Jenis Kegiatan", style: labelStyle),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          style: const TextStyle(fontSize: 13, color: Colors.black),
                          decoration: inputDecoration.copyWith(hintText: "Pilih jenis"),
                          value: selectedActivityType,
                          items: const [
                            DropdownMenuItem(value: 'progress', child: Text("Progress")),
                            DropdownMenuItem(value: 'meeting', child: Text("Meeting")),
                            DropdownMenuItem(value: 'finalization', child: Text("Finalization")),
                          ],
                          onChanged: (val) => setStateDialog(() => selectedActivityType = val),
                        ),
                        const SizedBox(height: 12),

                        // Input Deadline
                        const Text("Deadline (Due Date)", style: labelStyle),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _pickDate(isMeeting: false),
                          child: InputDecorator(
                            decoration: inputDecoration.copyWith(
                              suffixIcon: const Icon(Icons.calendar_today, size: 20),
                            ),
                            child: Text(
                              selectedDueDate == null ? "Pilih Tanggal" : DateFormat('d MMMM yyyy', 'id_ID').format(selectedDueDate!),
                              style: TextStyle(color: selectedDueDate == null ? Colors.grey : Colors.black, fontSize: 13),
                            ),
                          ),
                        ),

                        if (selectedActivityType == 'meeting') ...[
                          const SizedBox(height: 20),
                          const Text("Detail Meeting", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                          const Divider(color: Colors.blue),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Tanggal Meeting", style: labelStyle),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _pickDate(isMeeting: true),
                                      child: InputDecorator(
                                        decoration: inputDecoration.copyWith(suffixIcon: const Icon(Icons.event, size: 20)),
                                        child: Text(
                                          selectedMeetingDate == null ? "-" : DateFormat('d MMM yyyy', 'id_ID').format(selectedMeetingDate!),
                                          style: inputTextStyle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Jam Meeting", style: labelStyle),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: _pickTime,
                                      child: InputDecorator(
                                        decoration: inputDecoration.copyWith(suffixIcon: const Icon(Icons.access_time, size: 20)),
                                        child: Text(
                                          selectedMeetingTime == null ? "-" : selectedMeetingTime!.format(context),
                                          style: inputTextStyle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          const Text("Link Meeting", style: labelStyle),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: linkController,
                            style: inputTextStyle,
                            decoration: inputDecoration.copyWith(hintText: "https://meet.google.com/..."),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Tombol Aksi
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : _submitTimeline,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF301D02),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: isSubmitting
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Buat Timeline", style: TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditTimelineDialog(
      BuildContext context,
      int consultationId,
      int contractId,
      Map<String, dynamic> initialData,
      ) {
    final _formKey = GlobalKey<FormState>();

    // Controllers (diisi dengan initialData)
    final TextEditingController titleController = TextEditingController(text: initialData['title'] ?? '');
    final TextEditingController descController = TextEditingController(text: initialData['description'] ?? '');
    final TextEditingController linkController = TextEditingController(text: initialData['meeting_link'] ?? '');

    // Parsing data awal
    final String initialActivityType = initialData['activity_type'] ?? 'progress';
    final String? initialDueDateRaw = initialData['due_date'];
    final String? initialMeetingTimeRaw = initialData['meeting_datetime'];

    // State Variables - Menggunakan variable non-late di luar builder untuk initial value
    String? initialSelectedActivityType = initialActivityType;
    DateTime? initialSelectedDueDate = initialDueDateRaw != null ? DateTime.tryParse(initialDueDateRaw) : null;
    DateTime? initialSelectedMeetingDate = initialMeetingTimeRaw != null ? DateTime.tryParse(initialMeetingTimeRaw) : null;
    TimeOfDay? initialSelectedMeetingTime = initialMeetingTimeRaw != null
        ? TimeOfDay.fromDateTime(DateTime.parse(initialMeetingTimeRaw))
        : null;

    bool isSubmitting = false;
    final String? initialResultFilePath = initialData['result_file_path']; // Path file yang sudah ada

    // 🌟 STATE BARU UNTUK FILE UPLOAD
    String? newFileName;
    Uint8List? newSelectedFileBytes;
    bool isFileError = false;


    // Helper Format
    String formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
    String formatDateTime(DateTime date, TimeOfDay time) {
      final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    }

    // Styles
    const double contentPadding = 16.0;
    const TextStyle headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 16);
    const TextStyle labelStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
    const TextStyle inputTextStyle = TextStyle(fontSize: 13);

    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      isDense: true,
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        // State lokal dalam StatefulBuilder
        String? selectedActivityType = initialSelectedActivityType;
        DateTime? selectedDueDate = initialSelectedDueDate;
        DateTime? selectedMeetingDate = initialSelectedMeetingDate;
        TimeOfDay? selectedMeetingTime = initialSelectedMeetingTime;
        String? selectedStatus = initialData['status'] ?? 'pending'; // Tambah status


        return StatefulBuilder(
          builder: (context, setStateDialog) {

            // 🌟 HELPER UNTUK PICK FILE BARU
            Future<void> _pickFile() async {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ["jpg", "png", "jpeg"],
                withData: true,
              );

              if (result != null) {
                final file = result.files.single;
                setStateDialog(() {
                  newFileName = file.name;
                  newSelectedFileBytes = file.bytes;
                  isFileError = false;
                });
              }
            }


            Future<void> _pickDate({required bool isMeeting}) async {
              final picked = await showDatePicker(
                context: context,
                initialDate: (isMeeting ? selectedMeetingDate : selectedDueDate) ?? DateTime.now(),
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setStateDialog(() {
                  if (isMeeting) selectedMeetingDate = picked;
                  else selectedDueDate = picked;
                });
              }
            }

            Future<void> _pickTime() async {
              final picked = await showTimePicker(
                  context: context,
                  initialTime: selectedMeetingTime ?? TimeOfDay.now()
              );
              if (picked != null) {
                setStateDialog(() => selectedMeetingTime = picked);
              }
            }

            Future<void> _submitTimeline() async {
              if (!_formKey.currentState!.validate()) return;
              if (selectedActivityType == null) {
                showAppNotification(AppNotificationType.warning, "Perhatian", "Pilih jenis kegiatan");
                return;
              }
              if (selectedDueDate == null) {
                showAppNotification(AppNotificationType.warning, "Perhatian", "Tentukan deadline");
                return;
              }

              // Validasi Meeting
              if (selectedActivityType == 'meeting') {
                if (selectedMeetingDate == null || selectedMeetingTime == null) {
                  showAppNotification(AppNotificationType.warning, "Perhatian", "Tentukan tanggal & jam meeting");
                  return;
                }
                if (linkController.text.isEmpty) {
                  showAppNotification(AppNotificationType.warning, "Perhatian", "Link meeting wajib diisi");
                  return;
                }
              }

              // Validasi File jika statusnya complete dan bukan meeting
              bool isProgressOrFinalization = selectedActivityType == 'progress' || selectedActivityType == 'finalization';
              bool isCompletedStatus = selectedStatus == 'completed';

              if (isProgressOrFinalization && isCompletedStatus && initialResultFilePath == null && newSelectedFileBytes == null) {
                setStateDialog(() => isFileError = true);
                showAppNotification(AppNotificationType.warning, "Perhatian", "Bukti pekerjaan wajib diunggah untuk status Completed.");
                return;
              }


              setStateDialog(() => isSubmitting = true);

              try {
                final int timelineId = initialData['id'];

                // 1. Buat Body Data Dasar (Hanya data non-meeting)
                Map<String, dynamic> itemData = {
                  "title": titleController.text,
                  "description": descController.text,
                  "activityType": selectedActivityType,
                  "dueDate": formatDate(selectedDueDate!),
                  "status": selectedStatus, // Tambahkan status
                };

                if (selectedActivityType == 'meeting') {
                  // Tambahkan data meeting jika aktivitasnya meeting
                  itemData["meetingDatetime"] = formatDateTime(selectedMeetingDate!, selectedMeetingTime!);
                  itemData["meetingLink"] = linkController.text;
                }
                // TIDAK PERLU ELSE: Karena jika bukan meeting, itemData tidak memiliki keys meetingDatetime/meetingLink.

                // 2. Tentukan Mode Pengiriman: JSON atau Multipart
                if (newSelectedFileBytes != null) {
                  // ... (Logika FormData untuk file baru - TIDAK BERUBAH)

                  final formData = FormData.fromMap(itemData); // Masukkan JSON data dulu

                  String mimeSubtype = 'jpeg';
                  final ext = newFileName!.split('.').last.toLowerCase();
                  if (ext == 'png') mimeSubtype = 'png';

                  formData.files.add(MapEntry(
                    "resultFile",
                    MultipartFile.fromBytes(
                      newSelectedFileBytes!,
                      filename: newFileName,
                      contentType: MediaType("image", mimeSubtype),
                    ),
                  ));

                  await ApiClient.dio.patch(
                    "/consultations/$consultationId/contracts/$contractId/timeline/$timelineId",
                    data: formData, // Kirim FormData
                  );
                } else {
                  if (initialResultFilePath != null && initialResultFilePath.isNotEmpty) {
                    itemData["resultFilePath"] = initialResultFilePath;
                  }
                  await ApiClient.dio.patch(
                    "/consultations/$consultationId/contracts/$contractId/timeline/$timelineId",
                    data: itemData, // Kirim JSON (hanya keys yang dibutuhkan)
                  );
                }

                if (mounted) Navigator.pop(context);
                showAppNotification(AppNotificationType.success, "Berhasil", "Timeline berhasil diperbarui");

                // Refresh Data
                setState(() => _timelineDataMap.remove(consultationId));
                _fetchTimelineForConsultation(consultationId);

              } on DioException catch (e) {
                setStateDialog(() => isSubmitting = false);

                String msg;
                if (e.response?.data is Map) {
                  msg = e.response?.data['message']?.toString() ?? e.response?.data['error']?.toString() ?? "Error ${e.response?.statusCode ?? 'Unknown'}";
                } else {
                  msg = e.message ?? "Terjadi kesalahan server";
                }

                showAppNotification(AppNotificationType.error, "Gagal", msg);
              } catch (e) {
                setStateDialog(() => isSubmitting = false);
                showAppNotification(AppNotificationType.error, "Error", e.toString());
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(contentPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        const Text("Edit Timeline", style: headerStyle),
                        const SizedBox(height: 16),

                        // Input Judul
                        const Text("Judul Kegiatan", style: labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: titleController,
                          style: inputTextStyle,
                          decoration: inputDecoration.copyWith(hintText: "Masukkan judul"),
                          validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                        ),
                        const SizedBox(height: 12),

                        // Input Deskripsi
                        const Text("Deskripsi Kegiatan", style: labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: descController,
                          maxLines: 3,
                          style: inputTextStyle,
                          decoration: inputDecoration.copyWith(hintText: "Masukkan deskripsi"),
                          validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                        ),
                        const SizedBox(height: 12),

                        // Dropdown Jenis Kegiatan
                        const Text("Jenis Kegiatan", style: labelStyle),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          style: const TextStyle(fontSize: 13, color: Colors.black),
                          decoration: inputDecoration.copyWith(hintText: "Pilih jenis"),
                          value: selectedActivityType,
                          items: const [
                            DropdownMenuItem(value: 'progress', child: Text("Progress")),
                            DropdownMenuItem(value: 'meeting', child: Text("Meeting")),
                            DropdownMenuItem(value: 'finalization', child: Text("Finalization")),
                          ],
                          onChanged: (val) => setStateDialog(() {
                            selectedActivityType = val;
                            // Logika reset fields meeting
                            if (val != 'meeting') {
                              selectedMeetingDate = null;
                              selectedMeetingTime = null;
                              linkController.clear();
                            } else if (initialActivityType != 'meeting' && val == 'meeting') {
                              // Jika diubah ke meeting, set default (jika sebelumnya tidak ada data meeting)
                              selectedMeetingDate = DateTime.now();
                              selectedMeetingTime = TimeOfDay.now();
                            }
                          }),
                        ),
                        const SizedBox(height: 12),

                        // Dropdown Status
                        const Text("Status", style: labelStyle),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          style: const TextStyle(fontSize: 13, color: Colors.black),
                          decoration: inputDecoration.copyWith(hintText: "Pilih Status"),
                          value: selectedStatus,
                          items: const [
                            DropdownMenuItem(value: 'pending', child: Text("Sedang Dikerjakan")),
                            DropdownMenuItem(value: 'in_progress', child: Text("Progress Selesai (Tanpa File)")),
                            DropdownMenuItem(value: 'completed', child: Text("Progress Selesai (Dengan File)")),
                            // Asumsi 'cancel' bisa juga dipilih
                          ],
                          onChanged: (val) => setStateDialog(() {
                            selectedStatus = val;
                            isFileError = false; // Reset error ketika status berubah
                          }),
                          validator: (v) => v == null ? "Wajib dipilih" : null,
                        ),
                        const SizedBox(height: 12),


                        // Input Deadline
                        const Text("Deadline (Due Date)", style: labelStyle),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _pickDate(isMeeting: false),
                          child: InputDecorator(
                            decoration: inputDecoration.copyWith(
                              suffixIcon: const Icon(Icons.calendar_today, size: 20),
                            ),
                            child: Text(
                              selectedDueDate == null ? "Pilih Tanggal" : DateFormat('d MMMM yyyy', 'id_ID').format(selectedDueDate!),
                              style: TextStyle(color: selectedDueDate == null ? Colors.grey : Colors.black, fontSize: 13),
                            ),
                          ),
                        ),

                        // BLOK DETAIL MEETING
                        if (selectedActivityType == 'meeting') ...[
                          const SizedBox(height: 20),
                          const Text("Detail Meeting", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                          const Divider(color: Colors.blue),
                          const SizedBox(height: 8),
                          // ... (Input Tanggal Meeting, Jam Meeting, Link Meeting)
                          // Menggunakan selectedMeetingDate dan selectedMeetingTime untuk display/input
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Tanggal Meeting", style: labelStyle),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _pickDate(isMeeting: true),
                                      child: InputDecorator(
                                        decoration: inputDecoration.copyWith(suffixIcon: const Icon(Icons.event, size: 20)),
                                        child: Text(
                                          selectedMeetingDate == null ? "-" : DateFormat('d MMM yyyy', 'id_ID').format(selectedMeetingDate!),
                                          style: inputTextStyle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Jam Meeting", style: labelStyle),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: _pickTime,
                                      child: InputDecorator(
                                        decoration: inputDecoration.copyWith(suffixIcon: const Icon(Icons.access_time, size: 20)),
                                        child: Text(
                                          selectedMeetingTime == null ? "-" : selectedMeetingTime!.format(context),
                                          style: inputTextStyle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          const Text("Link Meeting", style: labelStyle),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: linkController,
                            style: inputTextStyle,
                            decoration: inputDecoration.copyWith(hintText: "https://meet.google.com/..."),
                          ),
                        ],

                        // 🌟 INPUT FILE BARU HANYA JIKA BUKAN MEETING
                        if (selectedActivityType != 'meeting') ...[
                          const SizedBox(height: 20),
                          const Text("Unggah Bukti Baru (Progress/Finalisasi)", style: labelStyle),
                          const SizedBox(height: 8),

                          // Display Gambar Lama (jika ada)
                          if (initialResultFilePath != null && initialResultFilePath.isNotEmpty) ...[
                            const Text("Bukti Saat Ini (Akan diganti jika upload baru)", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            _buildImageBoxFromAdmin(initialResultFilePath),
                          ],

                          const SizedBox(height: 12),

                          // Input File Baru
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isFileError ? Colors.red : Colors.black,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              children: [
                                ElevatedButton(
                                  onPressed: _pickFile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 21),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  child: const Text("Pilih Gambar Baru", style: TextStyle(fontSize: 13)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    newFileName ?? (newSelectedFileBytes == null ? "Tidak ada file baru dipilih" : newFileName!),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isFileError ? Colors.red : Colors.black,
                                    ),
                                  ),
                                ),
                                if (newSelectedFileBytes != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.red, size: 20),
                                    onPressed: () => setStateDialog(() { newFileName = null; newSelectedFileBytes = null; isFileError = false; }),
                                  )
                              ],
                            ),
                          ),
                          if (isFileError)
                            const Padding(
                              padding: EdgeInsets.only(top: 3, left: 12),
                              child: Text("Bukti pekerjaan wajib diunggah.", style: TextStyle(color: Colors.red, fontSize: 13)),
                            ),
                        ], // End if selectedActivityType != 'meeting'

                        const SizedBox(height: 24),

                        // Tombol Aksi
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : _submitTimeline,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF301D02),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: isSubmitting
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Simpan Perubahan", style: TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _fetchTimelineItemAndShowEdit(
      int consultationId, int contractId, int timelineId) async {
    // Tampilkan loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiClient.dio.get(
        "/consultations/$consultationId/contracts/$contractId/timeline/$timelineId",
      );

      // Tutup loading
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200 && response.data['timelineItem'] != null) {
        final data = response.data['timelineItem'] as Map<String, dynamic>;
        _showEditTimelineDialog(context, consultationId, contractId, data);
      } else {
        showAppNotification(
            AppNotificationType.error, "Gagal", "Data timeline tidak ditemukan.");
      }
    } on DioException catch (e) {
      if (mounted) Navigator.pop(context);

      // 🌟 PERBAIKAN ERROR TYPEDART: Pastikan semua output adalah String.
      String msg;

      if (e.response?.data is Map) {
        // Coba ambil pesan error dari body response (misal: {'message': 'Not Found'})
        // Menggunakan .toString() untuk memastikan nilai yang diambil adalah string
        msg = e.response?.data['message']?.toString() ?? e.response?.data['error']?.toString() ?? "Error ${e.response?.statusCode ?? 'Unknown'}";
      } else {
        // Fallback ke pesan Dio atau pesan default
        msg = e.message ?? "Terjadi kesalahan koneksi";
      }

      showAppNotification(AppNotificationType.error, "Gagal", msg);

    } catch (e) {
      if (mounted) Navigator.pop(context);
      showAppNotification(AppNotificationType.error, "Error", e.toString());
    }
  }

  void _showUpdateTimelineStatusDialog(
      BuildContext context,
      int consultationId,
      int contractId,
      int timelineId,
      Map<String, dynamic> itemData, // <-- DATA ITEM DITAMBAHKAN
      ) {
    final _formKey = GlobalKey<FormState>();

    // State Variables
    bool isCompleted = itemData['status'] == 'completed';
    String? fileName;
    Uint8List? selectedFileBytes;
    bool isSubmitting = false;

    // Ambil tipe aktivitas untuk validasi dan tampilan
    final activityType = itemData['activity_type'];
    final bool isMeeting = activityType == 'meeting'; // Flag baru

    // Styles (tidak berubah)
    const double contentPadding = 16.0;
    const TextStyle headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 16);
    const TextStyle labelStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);

    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      isDense: true,
    );


    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {

            Future<void> _pickFile() async {
              // ... (Logika pick file tetap sama) ...
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ["jpg", "png", "jpeg"],
                withData: true,
              );

              if (result != null) {
                final file = result.files.single;
                setStateDialog(() {
                  fileName = file.name;
                  selectedFileBytes = file.bytes;
                });
              }
            }

            Future<void> _submitUpdate() async {

              final String statusToSend;
              // Tentukan status yang akan dikirim berdasarkan checkbox
              statusToSend = isCompleted ? "completed" : "pending";

              // 💡 VALIDASI FILE: File hanya wajib jika statusnya 'completed' DAN BUKAN 'meeting'.
              final bool needsFileValidation = isCompleted && !isMeeting;

              if (needsFileValidation && selectedFileBytes == null) {
                showAppNotification(
                    AppNotificationType.warning,
                    "Perhatian",
                    "Bukti Gambar wajib diunggah untuk menandai ${activityType == 'finalization' ? 'Finalisasi' : 'Progress'} sebagai Selesai."
                );
                return;
              }

              setStateDialog(() => isSubmitting = true);

              try {
                // 1. Gunakan FormData
                final formData = FormData.fromMap({
                  "status": statusToSend,
                });

                // 2. Tambahkan File jika user memilihnya DAN activityType BUKAN meeting
                // File tidak dikirim sama sekali jika itu adalah meeting
                if (selectedFileBytes != null && fileName != null && !isMeeting) {
                  String mimeSubtype = 'jpeg';
                  final ext = fileName!.split('.').last.toLowerCase();
                  if (ext == 'png') mimeSubtype = 'png';

                  formData.files.add(MapEntry(
                    "resultFile",
                    MultipartFile.fromBytes(
                      selectedFileBytes!,
                      filename: fileName,
                      contentType: MediaType("image", mimeSubtype),
                    ),
                  ));
                }

                // 3. Gunakan dio.patch
                await ApiClient.dio.patch(
                  "/consultations/$consultationId/contracts/$contractId/timeline/$timelineId",
                  data: formData,
                );

                if (mounted) Navigator.pop(context);
                showAppNotification(AppNotificationType.success, "Berhasil", "Status timeline diperbarui");

                // Refresh Data
                setState(() => _timelineDataMap.remove(consultationId));
                _fetchTimelineForConsultation(consultationId);

              } on DioException catch (e) {
                setStateDialog(() => isSubmitting = false);

                String errorMessage = "Terjadi kesalahan server";
                if (e.response != null && e.response?.data is Map) {
                  final data = e.response?.data;
                  errorMessage = data['message'] ?? data['error'] ?? errorMessage;
                } else if (e.message != null) {
                  errorMessage = e.message!;
                }

                showAppNotification(AppNotificationType.error, "Gagal", errorMessage);
              } catch (e) {
                setStateDialog(() => isSubmitting = false);
                showAppNotification(AppNotificationType.error, "Error", e.toString());
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: 450,
                padding: const EdgeInsets.all(contentPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      const Text("Pembaruan Status Timeline", style: headerStyle),
                      const SizedBox(height: 20),

                      // 1. Checkbox Status Kegiatan
                      const Text("Status Kegiatan", style: labelStyle),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 1),
                          borderRadius: BorderRadius.circular(6),
                          color: isCompleted ? Colors.green.shade50 : null,
                        ),
                        child: CheckboxListTile(
                          dense: true,
                          title: const Text("Tandai aktivitas sebagai selesai", style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal)),
                          value: isCompleted,
                          onChanged: (bool? newValue) {
                            setStateDialog(() {
                              isCompleted = newValue ?? false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Input File (Hanya Tampil Jika BUKAN MEETING)
                      if (!isMeeting) ...[
                        const Text("Bukti Gambar (Wajib jika selesai)", style: labelStyle),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black, width: 1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: _pickFile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 21),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                child: const Text("Pilih Gambar", style: TextStyle(fontSize: 13)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  fileName ?? "Tidak ada gambar dipilih",
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              if (fileName != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.red, size: 20),
                                  onPressed: () => setStateDialog(() { fileName = null; selectedFileBytes = null; }),
                                )
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        const Text("Aktivitas meeting hanya memerlukan perubahan status.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 16),
                      ],

                      // Tombol Submit
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : _submitUpdate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF301D02),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Perbarui", style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🟢 FUNGSI 1: Fetch Data Detail dari API
  // 🟢 FUNGSI 1: Fetch Data Detail dari API (Diperbarui)
  Future<void> _fetchAndShowTimelineDetail(
      int consultationId, int contractId, int timelineId) async {
    // Tampilkan loading indicator sementara
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // GET /consultations/:id/contracts/:id/timeline/:id
      final response = await ApiClient.dio.get(
        "/consultations/$consultationId/contracts/$contractId/timeline/$timelineId",
      );

      // Tutup loading
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = response.data['timelineItem'];
        if (data != null) {
          // Panggil DIALOG BARU (StatefulWidget)
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) {
              return TimelineDetailDialog(
                item: data,
                timelineId: timelineId,
                consultationId: consultationId,
                contractId: contractId,
              );
            },
          );
        }
      }
    } catch (e) {
      // Tutup loading jika error
      if (mounted) Navigator.pop(context);
      String msg = "Gagal memuat detail: $e";
      if (e is DioException && e.response?.data is Map) {
        msg = e.response?.data['message']?.toString() ?? msg;
      }
      showAppNotification(AppNotificationType.error, "Error", msg);
    }
  }

  void _showDetailDialog(Map<String, dynamic> item) {
    // Parsing Data Dasar sesuai respon JSON
    final String title = item['title'] ?? '-';
    final String description = item['description'] ?? '-';
    final String activityType = item['activity_type'] ?? 'progress';
    final String status = item['status'] ?? 'pending';
    final String dueDateRaw = item['due_date'] ?? '';

    // Parsing Data Meeting & File
    final String? meetingTimeRaw = item['meeting_datetime'];
    final String? meetingLink = item['meeting_link'];
    final String? resultFilePath = item['result_file_path'];

    // Helper Format Tanggal
    String formatFullDate(String? raw) {
      if (raw == null || raw.isEmpty) return "-";
      try {
        final dt = DateTime.parse(raw);
        return DateFormat("d MMMM yyyy", "id_ID").format(dt);
      } catch (_) {
        return raw;
      }
    }

    String formatDateTimeStr(String? raw) {
      if (raw == null || raw.isEmpty) return "-";
      try {
        final dt = DateTime.parse(raw);
        return DateFormat("d MMMM yyyy, HH:mm", "id_ID").format(dt);
      } catch (_) {
        return raw;
      }
    }

    // Styles
    const TextStyle labelStyle = TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold);
    const TextStyle valueStyle = TextStyle(fontSize: 14, color: Colors.black);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // === HEADER ===
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Detail Timeline", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 1. Judul & Badge Tipe
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Judul Kegiatan", style: labelStyle),
                            const SizedBox(height: 2),
                            Text(title, style: valueStyle),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          activityType.toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Deskripsi
                  const Text("Deskripsi", style: labelStyle),
                  const SizedBox(height: 2),
                  Text(description, style: valueStyle),
                  const SizedBox(height: 12),

                  // 3. Status & Deadline
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Status", style: labelStyle),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColorTimeline(status),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                translateStatusTimeline(status),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: statusTextColorTimeline(status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Deadline", style: labelStyle),
                            const SizedBox(height: 2),
                            Text(formatFullDate(dueDateRaw), style: valueStyle),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 4),

                  // === LOGIKA KONDISIONAL TAMPILAN ===

                  // KONDISI A: Jika Tipe Meeting -> Tampilkan Link & Waktu (Tanpa Gambar)
                  if (activityType == 'meeting') ...[
                    const Text("Informasi Meeting", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),

                    const Text("Waktu Meeting", style: labelStyle),
                    Text(formatDateTimeStr(meetingTimeRaw), style: valueStyle),
                    const SizedBox(height: 8),

                    const Text("Link Meeting", style: labelStyle),
                    InkWell(
                      onTap: () {
                        if (meetingLink != null && meetingLink.isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: meetingLink));
                          showAppNotification(AppNotificationType.success, "Berhasil", "Link disalin");
                        }
                      },
                      child: Text(
                        (meetingLink == null || meetingLink.isEmpty) ? "-" : meetingLink,
                        style: const TextStyle(color: Colors.blue, fontSize: 13, decoration: TextDecoration.underline),
                      ),
                    ),
                  ]
                  // KONDISI B: Jika Progress & Status Completed -> Tampilkan Gambar
                  else if (status == 'completed') ...[
                    const Text("Bukti Pekerjaan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),

                    if (resultFilePath != null && resultFilePath.isNotEmpty)
                      _buildImageBoxFromAdmin(resultFilePath) // Menggunakan widget gambar yang sudah ada
                    else
                      const Text("Tidak ada file bukti yang diunggah.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]
                  // KONDISI C: Lainnya (In Progress / Cancel) -> Tidak tampil apa-apa
                  else ...[
                      const Center(
                        child: Text("Belum ada data tambahan.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                    ]

                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext uid) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tabs
          Row(
            children: [
              // Tombol tab
              ...List.generate(tabs.length, (index) {
                final isActive = _selectedTabIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isActive ? Colors.black : Colors.white,
                      foregroundColor: isActive ? Colors.white : Colors.black,
                      side: const BorderSide(color: Colors.black),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        // 💡 LOGIKA: TUTUP EXPAND SAAT BERPINDAH TAB
                        if (_selectedTabIndex != index) {
                          // Reset ID expand pada kedua tab
                          _expandedKonsultasiId = null;
                          _expandedTimelineConsultationId = null;
                        }
                        _selectedTabIndex = index;
                      });
                    },
                    child: Text(tabs[index]),
                  ),
                );
              }),

              // Spacer untuk mendorong tombol ke kanan
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),

          // Tab content
          Expanded(
            child: IndexedStack(
              index: _selectedTabIndex,
              children: [
                _buildKonsultasiTab(),
                _buildTimelineTab(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildKonsultasiTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    if (konsultasiData.isEmpty) {
      return const Center(child: Text("Belum ada data konsultasi."));
    }

    return ListView.builder(
      itemCount: konsultasiData.length,
      itemBuilder: (context, index) {
        final item = konsultasiData[index];
        final int consultationId = item['id'];
        final String nama = item['username'] ?? 'Tanpa Nama';
        final rawDate = item["consultation_date"]?.toString() ?? "";
        final dateTime = DateTime.tryParse(rawDate);


        final String tanggal = dateTime != null
            ? DateFormat("d MMM yyyy", "id_ID").format(dateTime)
            : "-";

        final String hari = dateTime != null
            ? DateFormat("EEEE", "id_ID").format(dateTime)
            : "-";

        final rawTime = item["consultation_time"];
        final DateTime? parsedTime =
        rawTime != null ? DateFormat("HH:mm:ss").parse(rawTime) : null;

        final String waktu = parsedTime != null
            ? DateFormat("HH:mm").format(parsedTime)
            : "-";

        final String notes = item['notes'] ?? "Tidak ada catatan";
        final String serviceName = item['service_name'] ?? "-";

        final String? img1 = item["reference_image_primary"];
        final String? img2 = item["reference_image_secondary"];

        final String status = (item['status'] ?? '-').toString();
        final String email = item['email'] ?? 'email';

        final int idKonsultasi = item['id']; // Ambil ID untuk digunakan di state
        final bool isExpanded = _expandedKonsultasiId == idKonsultasi; // 💡 Gunakan state terpusat

        // 🟢 1. Ambil Tipe Konsultasi & Link
        final String consultationType = item['consultation_type_name'] ?? '-';
        final String? preContractLink = item['pre_contract_meet_link'];

        // 🟢 2. Logika Tampilan Teks (Link / Address / Kosong)
        String? displayInfo;

        if (consultationType == "Konsultasi Langsung di CV. Ariftama Tekindo") {
          // Jika Konsultasi Langsung -> Kosongkan (null)
          displayInfo = null;
        } else {
          // Jika Online -> Cek Link
          if (preContractLink != null && preContractLink.isNotEmpty) {
            displayInfo = preContractLink;
          } else {
            displayInfo = "Belum ada link meeting";
          }
        }

        // design category & style
        final String designCategory = item['design_category_name'] ?? '';
        final String designStyle = item['design_style_name'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: Column(
            children: [
              // ------------------------- BAGIAN ATAS --------------------------
              InkWell(
                onTap: () {
                  setState(() {
                    // 💡 LOGIKA TOGGLE & CLOSE OTHERS
                    if (isExpanded) {
                      _expandedKonsultasiId = null; // Tutup jika ID sudah terbuka
                    } else {
                      _expandedKonsultasiId = idKonsultasi; // Buka ID yang baru
                    }
                  });
                },
                child: Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ───── KIRI: BOX HARI/TANGGAL/JAM ─────
                      Expanded(
                        flex: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF301D02),
                            borderRadius: isExpanded
                                ? const BorderRadius.only(
                              topLeft: Radius.circular(15),
                              topRight: Radius.circular(15),
                              bottomRight: Radius.circular(15),
                              bottomLeft: Radius.circular(0),
                            )
                                : BorderRadius.circular(15),
                          ),
                          padding: const EdgeInsets.only(
                              top: 15, bottom: 15, right: 30, left: 18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: Colors.white,
                                size: 26,
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    hari,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "Tanggal : $tanggal",
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11),
                                  ),
                                  Text(
                                    "Pukul : $waktu",
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // ───── TENGAH: STATUS + USER INFO ─────
                      Expanded(
                        child: Row(
                          children: [
                            // kiri: badge + username + email
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor(status),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      translateStatus(status),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: statusTextColor(status),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    nama,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // kanan: consultation type + Link/Address
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  consultationType,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.right,
                                ),

                                // 🟢 3. Tampilkan teks HANYA JIKA displayInfo tidak null
                                if (displayInfo != null) ...[
                                  const SizedBox(height: 2),
                                  SizedBox(
                                    width: 180,
                                    child: Text(
                                      displayInfo,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 12,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // ───── KANAN: LAYANAN ─────
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 220,
                            height: 68,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B6A3B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  serviceName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                if (designCategory.isNotEmpty)
                                  Text(
                                    designCategory,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (designStyle.isNotEmpty)
                                  Text(
                                    designStyle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 22,
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (isExpanded)
                const Divider(
                  color: Colors.black,
                  height: 0,
                  thickness: 1,
                ),

              if (isExpanded)
                _buildExpandedSection(
                    notes, img1, img2, status, idKonsultasi),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpandedSection(String notes, String? img1, String? img2, String status, int consultationId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ───── KIRI: REFERENSI GAMBAR ─────
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Referensi :",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildImageBoxFromAdmin(img1)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildImageBoxFromAdmin(img2)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 24),

          // ───── KANAN: CATATAN + TOMBOL ─────
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Catatan :",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notes,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 72),

                if (
                    status == 'contract_uploaded' ||
                    status == 'timeline_in_progress' ||
                    status == 'awaiting_payment' ||
                    status == 'in_progress' ||
                    status == 'completed' ||
                    status == 'finalized'
                ) ...[
                  // 👉 Kalau sudah punya kontrak: hanya tombol "Lihat Kontrak" yang melebar
                  Row(
                    children: [
                      const Text(
                        "Anda sudah memiliki kontrak",
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _showContractDialog(consultationId);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B2504),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                          child: const Text("Lihat Kontrak"),
                        ),
                      ),
                    ],
                  ),
                ] else if (status == 'confirmed') ...[
                  // 👉 Status confirmed → Buat kontrak
                  Row(
                    children: [
                      const Text(
                        "Ingin membuat kontrak?",
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Aksi membuat kontrak
                            _createContract(consultationId);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B2504),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text("Buat Kontrak"),
                        ),
                      ),
                    ],
                  ),
                ] else if (
                status == 'cancelled' || status == 'confirmed'
                ) ...[
                    // 👉 Status dibatalkan atau sudah dikonfirmasi → tidak tampil apa pun
                  ] else ...[
                    // 👉 Untuk status lain → tampilkan tombol "Terima Konsultasi"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const Text(
                          "Terima Jadwal Konsultasi?",
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _showAcceptConsultationDialog(consultationId);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B2504), // cokelat tua
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            child: const Text("Terima Konsultasi"),
                          ),
                        ),
                      ],
                    ),
                  ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  String formatActivityType(String rawType) {
    String formatted = rawType.toLowerCase();

    // Mengganti 'finalization' menjadi 'Finalisasi'
    if (formatted == 'finalization') {
      formatted = 'Finalisasi';
    } else {
      // Kapitalisasi huruf pertama untuk 'progress' dan 'meeting'
      formatted = formatted[0].toUpperCase() + formatted.substring(1);
    }

    return formatted;
  }

  Widget _buildTimelineTab() {
    // 1. Filter data konsultasi: hanya yang statusnya 'contract_uploaded'
    final allowedStatuses = [
      'contract_uploaded',
      'timeline_in_progress',
      'awaiting_payment',
      'in_progress',
      'completed',
      'finalized',
    ];

    final timelineCandidates = konsultasiData.where((item) {
      return allowedStatuses.contains(item['status']);
    }).toList();

    if (timelineCandidates.isEmpty) {
      return const Center(
        child: Text("Belum ada konsultasi yang memiliki kontrak."),
      );
    }

    return ListView.separated(
      itemCount: timelineCandidates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = timelineCandidates[index];

        final int idKonsultasi = item['id']; // Ambil ID untuk digunakan di state
        final bool isExpanded = _expandedTimelineConsultationId == idKonsultasi; // 💡 Gunakan state terpusat
        final String username = item['username'] ?? 'Tanpa Nama';
        // Anda bisa menambahkan role/service name jika tersedia di endpoint ini
        final String serviceName = item['service_name'] ?? 'Layanan';
        final String status = item['status'];
        final String paymentStatus = item['payment_status'] ?? '';

        final bool isLoadingInner = _timelineLoadingMap[idKonsultasi] ?? false;
        final List<dynamic> timelineList = _timelineDataMap[idKonsultasi] ?? [];
        final String designCategory = item['design_category_name'] ?? '';
        final String designStyle = item['design_style_name'] ?? '';
        final int? fetchedContractId = _consultationContractIds[idKonsultasi];
        bool isAddTimelineDisabled = false;
        if (status == 'awaiting_payment') {
          if (paymentStatus == 'not_ready' || paymentStatus == 'awaiting_payment' ) {
            isAddTimelineDisabled = true;
          }
        }
        if (status == 'finalized') {
          isAddTimelineDisabled = true;
        }
        final int consultationId = item['id'];
        // final bool isExpanded = _expandedTimelineIds.contains(consultationId); // Hapus atau nonaktifkan baris ini
        return Column(
          children: [
            // === HEADER KONTAINER (Konsultasi) ===
            InkWell(
              onTap: () {
                setState(() {
                  // 💡 LOGIKA TOGGLE & CLOSE OTHERS
                  if (isExpanded) {
                    _expandedTimelineConsultationId = null;
                  } else {
                    _expandedTimelineConsultationId = idKonsultasi;

                    // Fetch data hanya saat dibuka
                    _fetchTimelineForConsultation(idKonsultasi);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(16),
                    bottom: Radius.circular(isExpanded ? 0 : 16),
                  ),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    // Nama User (Kiri)
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // === STATUS DI ATAS USERNAME ===
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColorContract(item),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              translateStatusContract(item),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusTextColorContract(item),
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // === USERNAME ===
                          Text(
                            username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),

                          // === ID KONTRAK + ID TIMELINE (Dibuat Horizontal) ===
                          Row(
                            children: [
                              // 🟩 UPDATE BAGIAN INI
                              Text(
                                "ID Kontrak: ${fetchedContractId ?? '-'}",
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _showContractDialog(consultationId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF301D02),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text("Lihat Kontrak"),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // ... kode sebelumnya di dalam _buildTimelineTab ...

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isAddTimelineDisabled
                                  ? null
                                  : () {
                                if (fetchedContractId != null) {
                                  _showCreateTimelineDialog(context, consultationId, fetchedContractId);
                                } else {
                                  showAppNotification(
                                      AppNotificationType.error,
                                      "Data Belum Siap",
                                      "ID Kontrak belum termuat, coba refresh halaman.");
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isAddTimelineDisabled ? Colors.grey : const Color(0xFF301D02),
                                disabledBackgroundColor: Colors.grey,
                                disabledForegroundColor: Colors.white,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text("Tambah Timeline"),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Service Name / Role (Tengah)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 220,
                          height: 68,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B6A3B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                serviceName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),

                              // 🔥 PERBAIKAN: Hapus 'if (designCategory.isNotEmpty)'
                              Text(
                                (designCategory == null || designCategory.isEmpty) ? "-" : designCategory,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),

                              // 🔥 PERBAIKAN: Hapus 'if (designStyle.isNotEmpty)'
                              Text(
                                (designStyle == null || designStyle.isEmpty) ? "-" : designStyle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 16),
                    Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 22,),
                  ],
                ),
              ),
            ),

            // === ISI TIMELINE (Expanded) ===
            if (isExpanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(
                    left: BorderSide(color: Colors.black),
                    right: BorderSide(color: Colors.black),
                    bottom: BorderSide(color: Colors.black),
                  ),
                ),
                child: isLoadingInner
                    ? const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ))
                    : timelineList.isEmpty
                    ? const Center(child: Text("Belum ada data timeline."))
                    : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: timelineList.length,
                  separatorBuilder: (ctx, i) => const Divider(color: Colors.grey),
                  itemBuilder: (ctx, i) {
                    final tData = timelineList[i];

                    // Parsing Data
                    final String title = tData['title'] ?? '-';
                    final String desc = tData['description'] ?? '-';
                    final String tStatus = tData['status'] ?? 'pending';
                    final String rawDueDate = tData['due_date'] ?? '';
                    final int timelineId = tData['id'];
                    final String activityType = tData['activity_type'] ?? '-';

                    // Format Tanggal
                    String formattedDate = "-";
                    if (rawDueDate.isNotEmpty) {
                      try {
                        final dt = DateTime.parse(rawDueDate);
                        formattedDate = DateFormat("d MMMM yyyy", "id_ID").format(dt);
                      } catch (_) {
                        formattedDate = rawDueDate;
                      }
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- KOLOM KIRI: INFORMASI ---
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center, // Agar sejajar
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),

                                  // 🌟 Perubahan: Teks biasa "- Activity Type"
                                  Text(
                                    " - ${formatActivityType(activityType)}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black, // Agar sedikit kontras dengan title
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                desc,
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Badge Status
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColorTimeline(tStatus),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      translateStatusTimeline(tStatus),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: statusTextColorTimeline(tStatus),
                                          fontWeight: FontWeight.bold
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Deadline: $formattedDate",
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),

                        // --- KOLOM KANAN: TOMBOL AKSI ---
                        // "disusun menyamping di sebelah kanan"
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Tombol Detail
                            ElevatedButton(
                              onPressed: () {
                                if (fetchedContractId != null) {
                                  // 💡 ALTERNATIF: Langsung tampilkan dialog dengan data lokal (tData)
                                  showDialog(
                                    context: context,
                                    barrierDismissible: true,
                                    builder: (context) {
                                      return TimelineDetailDialog(
                                        item: tData as Map<String, dynamic>, // Menggunakan data lokal
                                        timelineId: timelineId,
                                        consultationId: consultationId,
                                        contractId: fetchedContractId,
                                      );
                                    },
                                  );
                                } else {
                                  showAppNotification(
                                    AppNotificationType.warning,
                                    "Gagal",
                                    "ID Kontrak belum termuat.",
                                  );
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
                              child: const Text("Detail"),
                            ),
                            const SizedBox(width: 8),

                            ElevatedButton(
                              onPressed: () {
                                if (fetchedContractId != null) {
                                  // 🌟 REVISI: Panggil _showEditTimelineDialog langsung
                                  // menggunakan data tData yang sudah di-fetch (cache lokal)
                                  _showEditTimelineDialog(
                                      context,
                                      consultationId,
                                      fetchedContractId,
                                      tData as Map<String, dynamic>
                                  );
                                } else {
                                  showAppNotification(
                                      AppNotificationType.error,
                                      "Error",
                                      "ID Kontrak tidak ditemukan"
                                  );
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
                              child: const Text("Edit"),
                            ),

                            const SizedBox(width: 8),

                            // Tombol Perbarui Status
                            ElevatedButton(
                              onPressed: () {
                                // Pastikan contractId tersedia
                                if (fetchedContractId != null) {
                                  _showUpdateTimelineStatusDialog(
                                      context,
                                      consultationId,
                                      fetchedContractId,
                                      timelineId,
                                      tData as Map<String, dynamic>
                                  );
                                } else {
                                  showAppNotification(
                                      AppNotificationType.error,
                                      "Error",
                                      "ID Kontrak tidak ditemukan"
                                  );
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
                              child: const Text("Perbarui Status"),
                            ),
                          ],
                        )
                      ],
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _showAddTimelineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400, // biar tidak terlalu melebar
              maxHeight: 600, // biar memanjang ke atas tapi ada batas
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Add Timeline",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Aktivitas
                    const TextField(
                      decoration: InputDecoration(
                        labelText: "Aktivitas",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tanggal
                    const TextField(
                      decoration: InputDecoration(
                        labelText: "Tanggal",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Jenis Timeline
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Jenis Timeline",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Progress', child: Text("Progress")),
                        DropdownMenuItem(value: 'Meeting', child: Text("Meeting")),
                        DropdownMenuItem(value: 'Finalisasi', child: Text("Finalisasi")),
                      ],
                      onChanged: (v) {},
                    ),
                    const SizedBox(height: 16),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Text("Add"),
                      ),
                    ),

                    // Note section mirip gambar
                    const Text(
                      "Note",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Sebelum melakukan finalisasi tunggu pelanggan melakukan pelunasan",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text(
                                "Status Pelunasan : ",
                                style: TextStyle(fontSize: 13),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.yellow,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "Pending",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
Widget _buildImageBoxFromAdmin(String? url) {
  if (url == null) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: Text("Tidak ada gambar")),
    );
  }

  const String BASE_IMAGE_DOMAIN = "https://api.cvariftamatekindo.my.id";

  // Gunakan Uri.resolve untuk penggabungan yang aman (mengatasi double slash atau slash yang hilang)
  try {
    final Uri baseUri = Uri.parse(BASE_IMAGE_DOMAIN);

    // Path gambar dari API: "uploads/consultations/..."
    final Uri finalUri = baseUri.resolve(url);

    final String fullImageUrl = finalUri.toString();

    // DEBUGGING: Anda dapat mencetak URL yang terbentuk untuk memastikannya sudah benar
    // debugPrint("FINAL HARDCODE IMAGE URL: $fullImageUrl");

    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: NetworkImage(fullImageUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  } catch (e) {
    // Penanganan jika terjadi error saat parsing URL
    print("Error building image URL: $e for path: $url");
    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: Text("URL Error")),
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
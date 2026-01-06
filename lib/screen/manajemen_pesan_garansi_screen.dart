import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../widgets/custom_app_notification.dart';
import '../api_client.dart';

String translateStatus(String raw) {
  switch (raw) {
    case "pending": return "Menunggu";
    case "cancelled": return "Batal";
    case "resolved": return "Selesai";
    case "rejected": return "Ditolak"; // Tambahan
    case "accepted": return "Diterima"; // Tambahan
    default: return raw;
  }
}

Color statusColor(String raw) {
  switch (raw) {
    case "pending": return Colors.yellow[700]!;
    case "cancelled": return Colors.red;
    case "resolved": return Colors.green;
    case "accepted": return Colors.black;
    case "rejected": return Colors.red;
    default: return Colors.grey;
  }
}

Color statusTextColor(String raw) {
  switch (raw) {
    case "cancelled": case "confirmed": case "accepted": case "rejected":case "resolved":
    return Colors.white;
    case "pending": default:
    return Colors.black;
  }
}

// 🟢 HELPER BARU: Translate Status User
String translateStatusUser(String tag) {
  switch (tag) {
    case "loyal": return "Loyal";
    case "prospect_new": return "Prospek Baru";
    case "needs_attention": case "need_attention": return "Bermasalah";
    default: return tag;
  }
}

// 🟢 HELPER BARU: Warna Badge User
Color _getTagColor(String tag) {
  switch (tag) {
    case "loyal": return Colors.green;
    case "prospect_new": return Colors.blue;
    case "needs_attention": case "need_attention": return Colors.red;
    default: return Colors.grey;
  }
}

class GuaranteeManagementContent extends StatefulWidget {
  const GuaranteeManagementContent({super.key});

  @override
  State<GuaranteeManagementContent> createState() =>
      _GuaranteeManagementContentState();
}

Widget _buildImage(String? relativePath) {
  if (relativePath == null || relativePath.isEmpty) {
    return const Center(
      child: Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
    );
  }

  const String BASE_IMAGE_DOMAIN = "https://api.cvariftamatekindo.my.id";
  String cleanPath = relativePath.replaceAll('\\', '/');

  String fullImageUrl;
  try {
    fullImageUrl = Uri.parse(BASE_IMAGE_DOMAIN).resolve(cleanPath).toString();
  } catch (e) {
    return const Center(child: Icon(Icons.error_outline, size: 20, color: Colors.red));
  }

  return Image.network(
    fullImageUrl,
    fit: BoxFit.cover,
    // Menangani indikator loading
    loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
      if (loadingProgress == null) {
        // Jika loadingProgress null, artinya gambar sudah selesai diunduh
        return child;
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircularProgressIndicator(
            // Menghitung persentase loading jika tersedia dari server
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
            strokeWidth: 2,
            color: const Color(0xFF301D02), // Menyesuaikan tema warna admin Anda
          ),
        ),
      );
    },
    // Menangani error jika gambar gagal dimuat
    errorBuilder: (context, error, stackTrace) {
      return const Center(
        child: Icon(Icons.broken_image, size: 20, color: Colors.red),
      );
    },
  );
}

class _GuaranteeManagementContentState extends State<GuaranteeManagementContent> {
  int _selectedTabIndex = 0;

  final ScrollController _chatController = ScrollController();
  String? selectedContact;
  String keputusanKlaim = "Diterima";

  String adminToken = "";
  IO.Socket? socket;
  List rooms = [];
  List messages = [];
  int? selectedRoomId;
  bool loadingMessages = false;
  List complaints = [];
  bool loadingComplaints = false;
  int? expandedTicketIndex;
  TextEditingController msgController = TextEditingController();
  final Map<int, TextEditingController> _rejectControllers = {};
  Map<String, String> customerTags = {};

  @override
  void initState() {
    super.initState();
    loadTokenAndInitSocket();
    fetchComplaints();
    fetchCustomerSegments();
  }

  @override
  void dispose() {
    // Bersihkan controller
    _chatController.dispose();
    msgController.dispose();

    // Bersihkan semua controller reject yang ada di map
    for (var controller in _rejectControllers.values) {
      controller.dispose();
    }

    // Putuskan koneksi socket agar tidak memory leak
    socket?.disconnect();
    socket?.dispose();

    super.dispose();
  }

  void loadTokenAndInitSocket() async {
    final prefs = await SharedPreferences.getInstance();
    adminToken = prefs.getString("ACCESS_TOKEN") ?? "";

    print("TOKEN ADMIN = $adminToken");

    initSocket();  // ⬅️ pastikan dipanggil setelah token terisi
  }

  void showAppNotification(AppNotificationType type, String title, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0, left: 0, right: 0,
        child: CustomAppNotification(
          type: type, title: title, message: message,
          onClose: () => entry.remove(),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  // ============================= SOCKET =============================
  // ============================= SOCKET (LENGKAP & DIPERBARUI) =============================
  void initSocket() {
    // 1. Ambil URL Dasar dari ApiClient dan bersihkan suffix "/api"
    String rawBaseUrl = ApiClient.dio.options.baseUrl;
    String socketBaseUrl = rawBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');

    // print("SOCKET URL: $socketBaseUrl"); // Debugging opsional

    // 2. Cek apakah socket sudah ada & terkoneksi (Solusi agar tidak perlu refresh)
    if (socket != null && socket!.connected) {
      print("Socket already connected. Fetching rooms immediately...");

      // Langsung minta data room terbaru
      socket!.emit("get_active_rooms");

      // Pasang ulang listener untuk menangani responnya
      _setupSocketListeners();
      return;
    }

    // 3. Jika belum terkoneksi, inisialisasi Socket.IO baru
    socket = IO.io(
      socketBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({"token": adminToken}) // Pastikan token admin terkirim
          .disableAutoConnect() // Kita connect manual di bawah
          .build(),
    );

    // 4. Pasang listener
    _setupSocketListeners();

    // 5. Lakukan koneksi
    socket!.connect();
  }

  void _setupSocketListeners() {
    if (socket == null) return;

    socket!.off("connect");
    socket!.off("active_rooms");
    socket!.off("new_message");
    socket!.off("joined_room");

    socket!.onConnect((_) {
      print("Socket connected as admin");
      socket!.emit("get_active_rooms");
    });

    socket!.on("active_rooms", (data) {
      print("ACTIVE ROOMS UPDATED: ${data.length} rooms");
      if (mounted) {
        setState(() {
          rooms = List<Map<String, dynamic>>.from(data);
        });
      }
    });

    socket!.on("joined_room", (data) {
      print("Joined room event: $data");
    });

    // 🟢 BAGIAN YANG DIPERBAIKI
    socket!.on("new_message", (msg) {
      print("Realtime message received: $msg");

      // 1. Ambil ID dari Socket dan ID yang sedang dipilih
      // Konversi keduanya ke String untuk menghindari masalah tipe data (Int vs String)
      String incomingRoomId = msg["roomId"].toString();
      String? currentRoomId = selectedRoomId?.toString();

      // 2. Bandingkan String vs String
      if (currentRoomId != null && incomingRoomId == currentRoomId) {
        if (mounted) {
          setState(() {
            messages.add({
              "text": msg["text"] ?? msg["message"] ?? "",
              // Pastikan sender sesuai logika UI Anda (jika dari user, UI akan di kiri)
              "sender": msg["sender"] ?? msg["sender_type"] ?? "user",
              "created_at": DateTime.now().toIso8601String(),
            });
          });
          scrollToBottom();
        }
      }

      // 3. Update Panel Kiri (Kontak)
      socket!.emit("get_active_rooms");
    });
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_chatController.hasClients) {
        _chatController.jumpTo(_chatController.position.maxScrollExtent);
      }
    });
  }

  Future<void> closeRoom(int roomId) async {
    try {
      await ApiClient.dio.patch(
        "/chat/rooms/$roomId/close",
        options: Options(headers: {"Authorization": "Bearer $adminToken"}),
      );

      showAppNotification(AppNotificationType.success, "Berhasil", "Room chat ditutup.");

      socket?.emit("get_active_rooms");

      // Jika room yang ditutup sedang dibuka, reset view chat kanan
      if (selectedRoomId == roomId) {
        setState(() {
          selectedRoomId = null;
          selectedContact = null;
          messages = [];
        });
      }

    } on DioException catch (e) {
      // 🟢 UPDATE: Error Handling yang lebih rapi
      String msg = e.response?.data['message'] ?? "Gagal menutup room chat.";
      showAppNotification(AppNotificationType.error, "Gagal", msg);
    } catch (e) {
      print("Gagal tutup room: $e");
      showAppNotification(AppNotificationType.error, "Gagal", "Gagal menutup room chat.");
    }
  }

  // ============================= API =============================
  Future<void> fetchRooms() async {
    final res = await Dio().get(
      "https://servermu.com/api/chat/rooms",
      options: Options(headers: {"Authorization": "Bearer $adminToken"}),
    );

    setState(() => rooms = res.data);
  }

  Future<void> openRoom(int roomId, String userName) async {
    setState(() {
      selectedRoomId = roomId;
      selectedContact = userName;
      loadingMessages = true;
    });

    try {
      // 1) Emit join_chat
      socket?.emit("join_chat", {"roomId": roomId});

      // 2) Ambil histori pesan via REST
      final res = await ApiClient.dio.get(
        "/chat/rooms/$roomId/messages",
        options: Options(headers: {"Authorization": "Bearer $adminToken"}),
      );

      print("CHAT HISTORY: ${res.data}");

      setState(() {
        messages = res.data["messages"].map<Map<String, dynamic>>((m) {
          return {
            "text": m["message"] ?? "",
            "sender": m["sender_type"] == "admin" ? "admin" : "user",
            "created_at": m["created_at"], // ⬅️ WAJIB ADA
          };
        }).toList();
        loadingMessages = false;
      });

      // 3) Tandai pesan terbaca
      socket?.emit("mark_messages_read", {"roomId": roomId});

      scrollToBottom();
    } catch (e) {
      print("ERROR OPEN ROOM: $e");
      setState(() {
        loadingMessages = false;
      });
    }
  }

  Future<void> loadMessages(int roomId) async {
    setState(() {
      loadingMessages = true;
    });

    try {
      final response = await ApiClient.dio.get("/chat/rooms/$roomId/messages");

      print("CHAT HISTORY RESPONSE: ${response.data}");

      setState(() {
        messages = List<Map<String, dynamic>>.from(
          response.data["messages"] ?? [],
        );
        loadingMessages = false;
      });

      scrollToBottom();
    } catch (e) {
      print("ERROR LOAD CHAT HISTORY: $e");
      setState(() {
        loadingMessages = false;
      });
    }
  }


  Future<void> sendMessage() async {
    if (msgController.text.trim().isEmpty || selectedRoomId == null) return;

    final text = msgController.text.trim();

    // 1. Kirim realtime via socket
    socket?.emit("send_message", {
      "roomId": selectedRoomId,
      "message": text,
    });

    setState(() {
      // 2. Update tampilan Chat (Kanan)
      messages.add({
        "text": text,
        "sender": "admin",
        "created_at": DateTime.now().toIso8601String(),
      });

      // ---------------------------------------------------------
      // 🟢 3. LOGIKA BARU: Update List Kontak (Kiri)
      // ---------------------------------------------------------

      // Cari index room yang sedang dibuka
      final int index = rooms.indexWhere((r) => r["id"] == selectedRoomId);

      if (index != -1) {
        // Ambil data room tersebut
        var currentRoom = rooms[index];

        // Update last_message dengan pesan baru
        currentRoom["last_message"] = text;

        // Opsional: Update waktu agar konsisten
        currentRoom["last_message_time"] = DateTime.now().toIso8601String();

        // Hapus room dari posisi lama
        rooms.removeAt(index);

        // Masukkan room ke posisi paling atas (index 0)
        rooms.insert(0, currentRoom);
      }
      // ---------------------------------------------------------
    });

    msgController.clear();
    scrollToBottom();
  }

  Future<void> fetchCustomerSegments() async {
    try {
      final response = await ApiClient.dio.get('/admin/customers/segments');

      if (response.statusCode == 200) {
        final List customers = response.data['customers'] ?? [];
        Map<String, String> tagsMap = {};

        for (var cust in customers) {
          final username = cust['username'];
          final tag = cust['customer_tag'];
          if (username != null && tag != null) {
            tagsMap[username] = tag;
          }
        }

        if (mounted) {
          setState(() {
            customerTags = tagsMap;
            _sortComplaints(); // Panggil sorting setelah data tag tersedia
          });
        }
      }
    } catch (e) {
      print("Error fetching customer segments: $e");
    }
  }

  // 🟢 2. Fungsi Sorting Tiket (Prioritas User)
  void _sortComplaints() {
    int getPriority(String tag) {
      if (tag == 'loyal') return 1;
      if (tag == 'prospect_new') return 2;
      if (tag == 'needs_attention' || tag == 'need_attention') return 3;
      return 4;
    }

    complaints.sort((a, b) {
      final tagA = customerTags[a['username']] ?? '';
      final tagB = customerTags[b['username']] ?? '';

      int pA = getPriority(tagA);
      int pB = getPriority(tagB);

      if (pA != pB) {
        return pA.compareTo(pB);
      }
      // Jika prioritas sama, urutkan berdasarkan ID (terbaru di atas jika ID auto-increment)
      return (b['id'] ?? 0).compareTo(a['id'] ?? 0);
    });
  }

  // 🟢 3. Update Fetch Complaints untuk memanggil sorting
  Future<void> fetchComplaints() async {
    setState(() => loadingComplaints = true);
    try {
      final response = await ApiClient.dio.get(
        "/admin/complaints",
        queryParameters: {"status": "", "priority": "", "page": "", "limit": ""},
      );

      if (mounted) {
        setState(() {
          complaints = response.data["complaints"] ?? [];
          _sortComplaints(); // Panggil sorting saat data masuk
          loadingComplaints = false;
        });
      }
    } catch (e) {
      print("ERROR FETCH COMPLAINTS: $e");
      if (mounted) setState(() => loadingComplaints = false);
    }
  }

  Future<void> _acceptComplaint(int complaintId) async {
    try {
      await ApiClient.dio.patch("/admin/complaints/$complaintId/accept");

      showAppNotification(AppNotificationType.success, "Berhasil", "Klaim garansi diterima.");
      fetchComplaints(); // Refresh data
    } on DioException catch (e) {
      // 🟢 UPDATE: Error Handling yang lebih rapi
      String msg = e.response?.data['message'] ?? "Gagal menerima klaim.";
      showAppNotification(AppNotificationType.error, "Gagal", msg);
    } catch (e) {
      showAppNotification(AppNotificationType.error, "Gagal", "Gagal menerima klaim: $e");
    }
  }

  // 🟢 FUNGSI TOLAK KLAIM
  Future<void> _rejectComplaint(int complaintId) async {
    // Ambil controller berdasarkan ID
    final controller = _rejectControllers[complaintId];
    final reason = controller?.text.trim() ?? "";

    if (reason.isEmpty) {
      showAppNotification(AppNotificationType.warning, "Peringatan", "Alasan penolakan harus diisi pada kolom respon.");
      return;
    }

    try {
      await ApiClient.dio.patch(
        "/admin/complaints/$complaintId/reject",
        data: {"admin_comment": reason},
      );

      // Clear inputan setelah sukses
      controller?.clear();

      showAppNotification(AppNotificationType.success, "Berhasil", "Klaim garansi ditolak.");
      fetchComplaints(); // Refresh data
    } on DioException catch (e) {
      // 🟢 UPDATE: Error Handling yang lebih rapi
      String msg = e.response?.data['message'] ?? "Gagal menolak klaim.";
      showAppNotification(AppNotificationType.error, "Gagal", msg);
    } catch (e) {
      showAppNotification(AppNotificationType.error, "Gagal", "Gagal menolak klaim: $e");
    }
  }

  Future<void> _resolveComplaint(int complaintId) async {
    try {
      // Melakukan PATCH ke endpoint /resolve
      await ApiClient.dio.patch("/admin/complaints/$complaintId/resolve");

      showAppNotification(AppNotificationType.success, "Berhasil", "Klaim garansi telah diselesaikan.");

      // Refresh data agar status berubah di UI
      fetchComplaints();
    } on DioException catch (e) {
      // 🟢 UPDATE: Error Handling yang lebih rapi
      String msg = e.response?.data['message'] ?? "Gagal menyelesaikan klaim.";
      showAppNotification(AppNotificationType.error, "Gagal", msg);
    } catch (e) {
      showAppNotification(AppNotificationType.error, "Gagal", "Gagal menyelesaikan klaim: $e");
    }
  }

  void _showZoomedImage(BuildContext context, String? relativePath) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Gambar utama
            GestureDetector(
              onTap: () => Navigator.pop(context), // Klik luar/gambar untuk tutup
              child: InteractiveViewer( // Memungkinkan pinch-to-zoom
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImage(relativePath),
                ),
              ),
            ),
            // Tombol Tutup di pojok kanan atas
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================= UI =============================
  final List<String> tabs = ['Klaim Garansi', 'Pesan'];

  final List<Map<String, dynamic>> klaimList = [
    {"name": "ihsantriyadi", "date": "29 Maret 2025", "status": "Pengajuan Klaim"},
    {"name": "narutouzumaki", "date": "21 Maret 2025", "status": "Pengajuan Klaim"},
    {"name": "faturarkansyawalwa", "date": "8 Februari 2025", "status": "Diterima"},
    {"name": "sasukeuchiha", "date": "1 Januari 2025", "status": "Selesai"},
    {"name": "budiyono", "date": "30 Desember 2025", "status": "Ditolak"},
  ];

  Color _getStatusColor(String status) {
    switch (status) {
      case "Pengajuan Klaim":
        return Colors.blue;
      case "Diterima":
        return Colors.yellow.shade700;
      case "Selesai":
        return Colors.green;
      case "Ditolak":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String formatDateHeader(String rawDate) {
    DateTime dt = DateTime.parse(rawDate);
    return "${dt.day.toString().padLeft(2, '0')} "
        "${_monthName(dt.month)} "
        "${dt.year}";
  }

  String _monthName(int m) {
    const months = [
      "Jan","Feb","Mar","Apr","Mei","Jun",
      "Jul","Agu","Sep","Okt","Nov","Des"
    ];
    return months[m - 1];
  }

  Map<String, List<Map<String, dynamic>>> groupMessagesByDate() {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var msg in messages) {
      final rawDate = msg["created_at"];
      final dateKey = rawDate.split(" ")[0]; // contoh: 2025-11-15

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(msg);
    }

    return grouped;
  }

  // ============================= WIDGET ITEM TIKET BARU =============================
  Widget _buildTicketCard(Map<String, dynamic> item, int index) {
    final int complaintId = item['id'];
    final String status = (item['status'] ?? item['STATUS'] ?? 'pending').toString();
    final String reason = item['reason'] ?? '-';
    final String title = item['title'] ?? '-';
    final String productName = item['product_name'] ?? '-';
    final String userName = item['username'] ?? '-';
    final String userEmail = item['user_email'] ?? '-';
    final String? userTag = customerTags[userName];

    final String? evidencePhotoPath = item['evidence_photo'];
    final String? productImagePath = item['product_image'];

    if (!_rejectControllers.containsKey(complaintId)) {
      _rejectControllers[complaintId] = TextEditingController();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // BAGIAN ATAS (INFORMASI) - TIDAK ADA PERUBAHAN
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF301D02),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                        bottomRight: Radius.circular(15),
                      ),
                    ),
                    padding: const EdgeInsets.only(top: 15, bottom: 15, right: 30, left: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.confirmation_number_outlined,
                          color: Colors.white,
                          size: 35,
                        ),
                        const SizedBox(width: 18),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                            const SizedBox(height: 8),
                            Text(
                              "ID Tiket : ${item['ticket_id'] ?? '-'}",
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Nama Produk : ",
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildImage(productImagePath),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    productName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // KONTEN TENGAH & KANAN
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // KOLOM ALASAN & USER
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Alasan Klaim :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(reason, style: const TextStyle(fontSize: 13)),

                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      userName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (userTag != null && userTag.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getTagColor(userTag),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        translateStatusUser(userTag),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(userEmail, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        // KOLOM FOTO BUKTI (KANAN)
                        Expanded(
                          flex: 3,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                  "Foto Bukti : ",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector( // <--- Tambahkan ini
                                  onTap: () => _showZoomedImage(context, evidencePhotoPath),
                                  child: MouseRegion( // Opsional: Mengubah cursor menjadi pointer di Web/Desktop
                                    cursor: SystemMouseCursors.click,
                                    child: Container(
                                      height: 110,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.black),
                                        color: Colors.grey[100],
                                      ),
                                      child: _buildImage(evidencePhotoPath),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Colors.black),

          // ============================================================
          // 🟢 LOGIKA TAMPILAN TOMBOL BERDASARKAN STATUS
          // ============================================================

          // 1. KONDISI: PENDING / MENUNGGU (Hanya Tolak & Terima)
          if (status == 'pending' || status == 'Menunggu')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Ingin menolak klaim?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text("Beri respon penolakan", style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // INPUT RESPON (Untuk Tolak)
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TextField(
                        controller: _rejectControllers[complaintId],
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Ketik disini .....",
                          hintStyle: TextStyle(fontSize: 13),
                          contentPadding: EdgeInsets.only(bottom: 10),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // TOMBOL TOLAK
                  ElevatedButton(
                    onPressed: () => _rejectComplaint(complaintId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF301D02),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Tolak"),
                  ),

                  const SizedBox(width: 12), // Spacer antar tombol

                  // TOMBOL TERIMA
                  ElevatedButton(
                    onPressed: () => _acceptComplaint(complaintId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF301D02),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Terima"),
                  ),

                  // ❌ Tombol "Selesai" DIHAPUS dari sini
                ],
              ),
            )

          // 2. KONDISI: ACCEPTED / DITERIMA (Hanya Tombol Selesai)
          else if (status == 'accepted' || status == 'Diterima')
            Container(
              width: double.infinity, // Agar container selebar parent
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end, // Tombol di kanan
                children: [
                  const Text(
                    "Klaim sedang diproses. Klik selesai jika sudah tuntas.",
                    style: TextStyle(fontSize: 13),
                  ),
                  const Spacer(),
                  // ✅ Tombol "Selesai" HANYA ADA DISINI
                  ElevatedButton(
                    onPressed: () => _resolveComplaint(complaintId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF301D02),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Selesai"),
                  ),
                ],
              ),
            )

          // 3. KONDISI: LAINNYA (Resolved/Rejected) -> READ ONLY
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Respon Admin:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    item['admin_comment'] ?? "Tidak ada catatan.",
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  // ======================== BUILD ==============================
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(tabs.length, (index) {
                final isActive = _selectedTabIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isActive ? const Color(0xFF301D02) : Colors.white,
                      foregroundColor: isActive ? Colors.white : Colors.black,
                      side: const BorderSide(color: Colors.black),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => setState(() => _selectedTabIndex = index),
                    child: Text(tabs[index]),
                  ),
                );
              }),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: IndexedStack(
              index: _selectedTabIndex,
              children: [
                _buildKlaimGaransiTab(),
                _buildPesanTab(),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ============================= TAB KLAIM =============================
  Widget _buildKlaimGaransiTab() {
    if (loadingComplaints) {
      return const Center(child: CircularProgressIndicator());
    }

    if (complaints.isEmpty) {
      return const Center(child: Text("Belum ada data klaim."));
    }

    return ListView.builder(
      itemCount: complaints.length,
      itemBuilder: (context, index) {
        final item = complaints[index];
        return _buildTicketCard(item, index); // ⬅️ pakai card baru
      },
    );
  }

  // ============================= TAB PESAN =============================
  Widget _buildPesanTab() {
    return Row(
      children: [
        // ======================= PANEL KONTAK =======================
        Container(
          width: 250,
          decoration: const BoxDecoration(
            color: Color(0xFF301D02),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
          child: Column(
            children: [
              // header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF301D02),
                  border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
                ),
                child: const Center(
                  child: Text(
                    "Kontak",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              // ===== LIST ROOM =====
              Expanded(
                child: ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, i) {
                    final room = rooms[i];

                    final roomId = room["id"];
                    final username = room["username"] ?? "-";
                    final lastMsg = room["last_message"] ?? "";
                    final unread = room["unread_count"] ?? 0;
                    final lastTime = room["last_message_time"];

                    return ListTile(
                      onTap: () {
                        selectedRoomId = roomId;

                        // ⬅️ EMIT JOIN CHAT
                        socket?.emit("join_chat", {
                          "roomId": roomId,
                        });

                        // Load pesan dari API
                        openRoom(roomId, username);
                      },

                      leading: CircleAvatar(
                        child: Text(username[0].toUpperCase()),
                      ),

                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis, // Tambahkan titik-titik jika kepanjangan
                              maxLines: 1, // Batasi 1 baris
                            ),
                          ),
                          if (unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unread.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            )
                        ],
                      ),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lastMsg,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),

                      trailing: IconButton(
                        icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
                        tooltip: "Tutup Room",
                        onPressed: () {
                          // Konfirmasi dulu biar aman (Opsional)
                          showDialog(
                            context: context,
                            barrierDismissible: true,
                            builder: (ctx) {
                              return Dialog(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12), // Radius 12
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(16), // Padding All 16
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header 16
                                      const Text(
                                        "Tutup Chat?",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Text 13
                                      Text(
                                        "Yakin ingin menutup chat dengan $username?",
                                        style: const TextStyle(fontSize: 13),
                                      ),

                                      const SizedBox(height: 20),

                                      // Action Buttons
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text(
                                              "Batal",
                                              style: TextStyle(fontSize: 13, color: Colors.black),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              closeRoom(roomId); // PANGGIL FUNGSI TUTUP
                                            },
                                            child: const Text(
                                              "Tutup",
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // 🔥 Lock mechanism removed completely
                    );
                  },
                ),
              )
            ],
          ),
        ),

        // ======================= PANEL CHAT =======================
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                // header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF301D02),
                    borderRadius: BorderRadius.only(topRight: Radius.circular(12)),
                  ),
                  child: Center(
                    child: Text(
                      selectedContact ?? "",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // ISI CHAT
                Expanded(
                  child: selectedContact == null
                      ? const Center(child: Text("Pilih kontak untuk melihat chat"))
                      : loadingMessages
                      ? const Center(child: CircularProgressIndicator())
                      : Builder(
                    builder: (context) {
                      final grouped = groupMessagesByDate();
                      final dateKeys = grouped.keys.toList()..sort();

                      return ListView.builder(
                        controller: _chatController,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        itemCount: dateKeys.length,
                        itemBuilder: (context, dateIndex) {
                          final dateKey = dateKeys[dateIndex];
                          final chatList = grouped[dateKey]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ===== HEADER TANGGAL =====
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  formatDateHeader(dateKey),
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                ),
                              ),

                              // ===== DAFTAR PESAN DARI TANGGAL INI =====
                              ...chatList.map((chat) {
                                final isAdmin = chat["sender"] == "admin";
                                return Align(
                                  alignment: isAdmin
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.all(12),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAdmin
                                          ? Colors.grey[300]
                                          : Colors.grey[400],
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(12),
                                        topRight: const Radius.circular(12),
                                        bottomLeft: isAdmin
                                            ? const Radius.circular(12)
                                            : Radius.zero,
                                        bottomRight: isAdmin
                                            ? Radius.zero
                                            : const Radius.circular(12),
                                      ),
                                    ),
                                    child: Text(chat["text"]),
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),

                // INPUT CHAT
                if (selectedContact != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: msgController,
                            decoration: InputDecoration(
                              hintText: "Ketik pesan di sini...",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        ElevatedButton(
                          onPressed: sendMessage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF301D02),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text("Balas"),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}




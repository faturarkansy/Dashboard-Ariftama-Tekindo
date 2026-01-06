import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:dio/dio.dart';

class GuaranteeManagementContent extends StatefulWidget {
  const GuaranteeManagementContent({super.key});

  @override
  State<GuaranteeManagementContent> createState() =>
      _GuaranteeManagementContentState();
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
  TextEditingController msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initSocket();
    fetchRooms();
  }

  // ============================= SOCKET =============================
  void initSocket() {
    socket = IO.io(
      "https://servermu.com",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({"token": adminToken})
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      print("Socket connected as admin");
    });

    socket!.on("new_message", (data) {
      if (data["roomId"] == selectedRoomId) {
        setState(() => messages.add(data));
        scrollToBottom();
      }
    });
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_chatController.hasClients) {
        _chatController.jumpTo(_chatController.position.maxScrollExtent);
      }
    });
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

    final res = await Dio().get(
      "https://servermu.com/api/chat/rooms/$roomId/messages",
      options: Options(headers: {"Authorization": "Bearer $adminToken"}),
    );

    setState(() {
      messages = res.data;
      loadingMessages = false;
    });

    socket?.emit("read_messages", {"roomId": roomId});
    scrollToBottom();
  }

  Future<void> sendMessage() async {
    if (msgController.text.trim().isEmpty || selectedRoomId == null) return;

    final text = msgController.text.trim();

    // Kirim via API (opsional jika backend membutuhkan)
    await Dio().post(
      "https://servermu.com/api/chat/send",
      data: {
        "room_id": selectedRoomId,
        "message": text,
      },
      options: Options(headers: {"Authorization": "Bearer $adminToken"}),
    );

    // Kirim realtime via socket
    socket?.emit("send_message", {
      "roomId": selectedRoomId,
      "text": text,
      "sender": "admin",
    });

    setState(() {
      messages.add({"text": text, "sender": "admin"});
    });

    msgController.clear();
    scrollToBottom();
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
    return ListView.separated(
      itemCount: klaimList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = klaimList[index];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text("Dibuat pada : ${item['date']}"),
                ],
              ),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(item['status']).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item['status'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(item['status']),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Lihat Chat"),
                  )
                ],
              )
            ],
          ),
        );
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
                  itemBuilder: (context, index) {
                    final room = rooms[index];

                    return InkWell(
                      onTap: () => openRoom(room['id'], room['user_name']),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        color: selectedRoomId == room['id']
                            ? Colors.brown.withValues(alpha: 0.3)
                            : Colors.transparent,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(room['user_name'], style: const TextStyle(color: Colors.white)),
                            if (room['unread_count'] > 0)
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: Text(
                                  room['unread_count'].toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
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
                      : ListView.builder(
                    controller: _chatController,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final chat = messages[index];
                      final isAdmin = chat["sender"] == "admin";

                      return Align(
                        alignment:
                        isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin:
                          const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth:
                            MediaQuery.of(context).size.width *
                                0.6,
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        ElevatedButton(
                          onPressed: sendMessage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          ),
                          child: const Text("Balas"),
                        ),

                        const SizedBox(width: 12),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black, width: 1),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: keputusanKlaim,
                              items: ["Diterima", "Ditolak"]
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (val) => setState(() => keputusanKlaim = val!),
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
    );
  }
}

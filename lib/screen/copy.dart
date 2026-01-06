import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    // Scroll otomatis ke bawah setelah frame build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatController.hasClients) {
        _chatController.jumpTo(_chatController.position.maxScrollExtent);
      }
    });
  }


  final List<String> tabs = ['Klaim Garansi', 'Pesan'];

  // Dummy data klaim garansi
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tabs
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
                    onPressed: () {
                      setState(() {
                        _selectedTabIndex = index;
                      });
                    },
                    child: Text(tabs[index]),
                  ),
                );
              }),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),

          // Tab content
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
              // Kolom kiri: nama + tanggal
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text("Dibuat pada : ${item['date']}"),
                ],
              ),

              // Status + tombol chat
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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

  Widget _buildPesanTab() {
    // Dummy data kontak
    final List<Map<String, dynamic>> kontakList = [
      {"name": "faturarkansyawalwa", "priority": "Pilih ..."},
      {"name": "ihsantriyadi", "priority": "Pilih ..."},
      {"name": "narutouzumaki", "priority": "Sedang"},
      {"name": "sasukeuchiha", "priority": "Rendah"},
    ];

    // Dummy chat untuk setiap kontak
    final Map<String, List<Map<String, dynamic>>> chatData = {
      "faturarkansyawalwa": [
        {
          "date": "29/3/2025",
          "messages": [
            {"sender": "pelanggan", "text": "Halo Admin, barang saya rusak."},
            {"sender": "admin", "text": "Baik, bisa kirimkan foto kerusakan?"}
          ]
        }
      ],
      "ihsantriyadi": [
        {
          "date": "30/3/2025",
          "messages": [
            {"sender": "pelanggan", "text": "Apakah klaim saya diterima?"},
            {"sender": "admin", "text": "Kami sedang memproses klaim Anda."}
          ]
        }
      ],
      "narutouzumaki": [
        {
          "date": "31/3/2025",
          "messages": [
            {"sender": "pelanggan", "text": "Kursi saya patah, bisa diganti?"},
            {"sender": "admin", "text": "Ya, silakan isi form klaim."}
          ]
        }
      ],
      "sasukeuchiha": [
        {
          "date": "1/4/2025",
          "messages": [
            {"sender": "pelanggan", "text": "Kenapa klaim saya ditolak?"},
            {"sender": "admin", "text": "Karena tidak sesuai dengan syarat garansi."}
          ]
        }
      ],
    };

    // 👉 Tambahkan state selectedContact
    String? selectedContact;

    return StatefulBuilder(
      builder: (context, setInnerState) {
        return Row(
          children: [
            // === Panel Kontak ===
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
                  // Header Kontak
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF301D02),
                      border: Border(
                        bottom: BorderSide(color: Colors.black, width: 1),
                      ),
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

                  // Daftar kontak
                  Expanded(
                    child: ListView.builder(
                      itemCount: kontakList.length,
                      itemBuilder: (context, index) {
                        final item = kontakList[index];
                        final isSelected = selectedContact == item['name'];

                        return InkWell(
                          onTap: () {
                            setInnerState(() {
                              selectedContact = item['name'];
                            });
                          },
                          child: Container(
                            color: isSelected
                                ? Colors.brown.withValues(alpha:0.3)
                                : Colors.transparent,
                            child: ListTile(
                              title: Text(
                                item['name'],
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Row(
                                children: [
                                  const Text("Prioritas: ",
                                      style: TextStyle(color: Colors.white70)),
                                  Container(
                                    height: 25,
                                    padding: const EdgeInsets.only(left: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: Colors.black, width: 1),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: item['priority'],
                                        style: const TextStyle(
                                            color: Colors.black, fontSize: 14),
                                        dropdownColor: Colors.white,
                                        items: ["Pilih ...", "Tinggi", "Sedang", "Rendah"]
                                            .map((e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ))
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            kontakList[index]['priority'] = value!;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // === Panel Chat ===
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  border: Border(
                    right: BorderSide(color: Colors.black, width: 1),
                    bottom: BorderSide(color: Colors.black, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Header nama kontak SELALU ada
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF301D02),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          selectedContact ?? "", // teks kosong jika belum dipilih
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Isi chat
                    Expanded(
                      child: selectedContact == null
                          ? const Center(
                        child: Text("Pilih kontak untuk melihat chat"),
                      )
                          : ListView.builder(
                        controller: _chatController,
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        itemCount: chatData[selectedContact]!.length,
                        itemBuilder: (context, groupIndex) {
                          final group = chatData[selectedContact]![groupIndex];
                          final date = group['date'];
                          final messages = group['messages'] as List;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Divider tanggal
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  date,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 10),
                                ),
                              ),

                              // Bubble chat
                              ...messages.map((chat) {
                                final isAdmin = chat['sender'] == "admin";
                                return Align(
                                  alignment: isAdmin
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin:
                                    const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.all(12),
                                    constraints: BoxConstraints(
                                      maxWidth:
                                      MediaQuery.of(context).size.width * 0.6,
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
                                    child: Text(chat['text']),
                                  ),
                                );
                              })
                            ],
                          );
                        },
                      ),
                    ),

                    if (selectedContact != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Textfield
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: "Ketik pesan disini...",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Tombol Balas
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.brown[800],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              child: const Text("Balas"),
                            ),

                            const SizedBox(width: 12),

                            // Dropdown keputusan
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: keputusanKlaim,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                  ),
                                  dropdownColor: Colors.white,
                                  items: ["Diterima", "Ditolak"]
                                      .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ))
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      keputusanKlaim = val!;
                                    });
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
            ),
          ],
        );
      },
    );
  }
}

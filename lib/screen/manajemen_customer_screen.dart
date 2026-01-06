import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../api_client.dart';

class CustomerManagementContent extends StatefulWidget {
  const CustomerManagementContent({super.key});

  @override
  State<CustomerManagementContent> createState() =>
      _CustomerManagementContentState();
}

class _CustomerManagementContentState extends State<CustomerManagementContent> {
  List<dynamic> customers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCustomers();
  }

  Future<void> fetchCustomers() async {
    try {
      final response = await ApiClient.dio.get('/admin/customers/segments');

      if (response.statusCode == 200) {
        setState(() {
          customers = response.data['customers'];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching customers: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Color _getLabelColor(String? tag) {
    switch (tag) {
      case 'loyal':
        return Colors.green;
      case 'prospect_new':
        return Colors.black;
      case 'needs_attention':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatLabel(String? tag) {
    if (tag == null) return "-";
    if (tag == 'prospect_new') return "Prospek Baru";
    if (tag == 'loyal') return "Loyal";
    if (tag == 'needs_attention') return "Bermasalah";

    return tag[0].toUpperCase() + tag.substring(1).replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(14),
          // 🟢 CONTAINER PUTIH PEMBUNGKUS UTAMA
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.black,
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Container (Abu-abu)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          "Username",
                          textAlign: TextAlign.left,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          "Email",
                          textAlign: TextAlign.left,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "Label",
                          textAlign: TextAlign.left,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          "Aktivitas",
                          textAlign: TextAlign.left,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 2. List Data Customer (Card Style)
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 1),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      return _buildCustomerCard(customers[index]);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerCard(dynamic cust) {
    final tag = cust["customer_tag"] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // BAGIAN BAWAH (FLEX LAYOUT)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KOLOM 1: USERNAME
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () {},
                    child: Text(
                      cust["username"] ?? "-",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),

                // KOLOM 2: EMAIL
                Expanded(
                  flex: 4,
                  child: InkWell(
                    onTap: () {},
                    child: Text(
                      cust["email"] ?? "-",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),

                // KOLOM 3: LABEL (BADGE STYLING)
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getLabelColor(tag),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatLabel(tag),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                // KOLOM 4: AKTIVITAS
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pembelian : ${cust["completed_orders"] ?? 0} kali",
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Klaim Garansi : ${cust["warranty_claims"] ?? 0} kali",
                        style: const TextStyle(fontSize: 13),
                      ),
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
}
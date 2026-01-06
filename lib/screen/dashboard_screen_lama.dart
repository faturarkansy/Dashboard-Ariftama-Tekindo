import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart'; // Pastikan import ini ada
import '../api_client.dart';

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  // State: Customers, Orders, Rating
  String totalCustomers = "-";
  bool isLoadingCustomers = true;
  String totalCompletedOrders = "-";
  bool isLoadingOrders = true;
  String averageRating = "-";
  bool isLoadingRating = true;

  // State: Layanan Jasa Favorit
  bool isLoadingServices = true;
  Map<String, int> serviceCounts = {
    "Konstruksi Profesional": 0,
    "Designer Interior Profesional": 0,
    "Instalasi Elektrik": 0,
  };

  // State: Pendapatan Bulanan (Line Chart)
  bool isLoadingRevenue = true;
  List<FlSpot> revenueSpots = [];
  List<String> monthLabels = [];
  double maxRevenueY = 0;
  bool isLoadingTopProducts = true;
  List<Map<String, dynamic>> topProductsList = [];

  @override
  void initState() {
    super.initState();
    fetchTotalCustomers();
    fetchTotalOrders();
    fetchGlobalAverageRating();
    fetchFavoriteServices();
    fetchMonthlyRevenue();
    fetchTopSellingProducts();
  }

  // --- API FETCHING FUNCTIONS ---

  Future<void> fetchTotalCustomers() async {
    try {
      final response = await ApiClient.dio.get('/admin/customers/segments');
      if (response.statusCode == 200) {
        final List customers = response.data['customers'] ?? [];
        if (mounted) setState(() { totalCustomers = customers.length.toString(); isLoadingCustomers = false; });
      }
    } catch (e) {
      if (mounted) setState(() { totalCustomers = "0"; isLoadingCustomers = false; });
    }
  }

  Future<void> fetchTotalOrders() async {
    try {
      final response = await ApiClient.dio.get('/admin/orders');
      if (response.statusCode == 200) {
        final List orders = response.data as List;
        final completedCount = orders.where((order) => order['status'] == 'completed').length;
        if (mounted) setState(() { totalCompletedOrders = completedCount.toString(); isLoadingOrders = false; });
      }
    } catch (e) {
      if (mounted) setState(() { totalCompletedOrders = "0"; isLoadingOrders = false; });
    }
  }

  Future<void> fetchGlobalAverageRating() async {
    try {
      final productResponse = await ApiClient.dio.get('/products');
      final List products = productResponse.data as List;
      if (products.isEmpty) {
        if (mounted) setState(() { averageRating = "0.0"; isLoadingRating = false; });
        return;
      }
      List<Future<Response>> ratingRequests = products.map((product) {
        return ApiClient.dio.get('/products/${product['id']}/ratings');
      }).toList();
      final responses = await Future.wait(ratingRequests);
      double totalSumOfAverages = 0.0;
      int validProductCount = 0;
      for (var res in responses) {
        if (res.statusCode == 200) {
          final summary = res.data['summary'];
          if (summary != null) {
            int totalRatings = (summary['total_ratings'] ?? 0) as int;
            if (totalRatings > 0) {
              double pRating = (summary['average_rating'] as num).toDouble();
              totalSumOfAverages += pRating;
              validProductCount++;
            }
          }
        }
      }
      double finalAvg = validProductCount == 0 ? 0.0 : totalSumOfAverages / validProductCount;
      if (mounted) setState(() { averageRating = finalAvg.toStringAsFixed(1); isLoadingRating = false; });
    } catch (e) {
      if (mounted) setState(() { averageRating = "0.0"; isLoadingRating = false; });
    }
  }

  Future<void> fetchFavoriteServices() async {
    try {
      final response = await ApiClient.dio.get('/consultations/admin/all');
      if (response.statusCode == 200) {
        final List data = response.data;
        const allowedStatuses = [
          "contract_uploaded", "timeline_in_progress", "awaiting_payment",
          "in_progress", "completed", "finalized"
        ];
        int c1 = 0, c2 = 0, c3 = 0;
        for (var item in data) {
          if (allowedStatuses.contains(item['status'])) {
            if (item['service_name'] == "Konstruksi Profesional") c1++;
            else if (item['service_name'] == "Designer Interior Profesional") c2++;
            else if (item['service_name'] == "Instalasi Elektrik") c3++;
          }
        }
        if (mounted) setState(() {
          serviceCounts["Konstruksi Profesional"] = c1;
          serviceCounts["Designer Interior Profesional"] = c2;
          serviceCounts["Instalasi Elektrik"] = c3;
          isLoadingServices = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingServices = false);
    }
  }

  Future<void> fetchMonthlyRevenue() async {
    try {
      final response = await ApiClient.dio.get('/admin/orders');
      if (response.statusCode == 200) {
        final List orders = response.data as List;
        Map<int, double> monthlyData = {};
        final now = DateTime.now();

        for (int i = 5; i >= 0; i--) {
          int monthIndex = now.month - i;
          if (monthIndex <= 0) monthIndex += 12;
          monthlyData[monthIndex] = 0.0;
        }

        for (var order in orders) {
          String? createdAtRaw = order['created_at'];
          double amount = double.tryParse(order['total_amount'].toString()) ?? 0.0;
          if (createdAtRaw != null) {
            DateTime date = DateTime.parse(createdAtRaw);
            if (monthlyData.containsKey(date.month)) {
              monthlyData[date.month] = monthlyData[date.month]! + amount;
            }
          }
        }

        List<FlSpot> spots = [];
        List<String> labels = [];
        double tempMax = 0;
        int indexX = 0;

        monthlyData.forEach((month, total) {
          spots.add(FlSpot(indexX.toDouble(), total));
          String monthName = DateFormat('MMM', 'id_ID').format(DateTime(2024, month));
          labels.add(monthName);
          if (total > tempMax) tempMax = total;
          indexX++;
        });

        if (mounted) {
          setState(() {
            revenueSpots = spots;
            monthLabels = labels;
            maxRevenueY = tempMax * 1.2;
            isLoadingRevenue = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching revenue: $e");
      if (mounted) setState(() => isLoadingRevenue = false);
    }
  }

  Future<void> fetchTopSellingProducts() async {
    try {
      // 1. Ambil Data Master Produk (untuk cek Stok & Nama/Gambar)
      final productRes = await ApiClient.dio.get('/products');
      List allProducts = productRes.data ?? [];
      // Buat Map agar pencarian data produk berdasarkan ID lebih cepat
      Map<int, dynamic> productMap = {
        for (var p in allProducts) p['id']: p
      };

      // 2. Ambil List Semua Orders
      final ordersRes = await ApiClient.dio.get('/admin/orders');
      List orders = ordersRes.data ?? [];

      // 3. Siapkan Request Detail untuk Setiap Order ID
      // Kita pakai Future.wait agar request berjalan paralel (tidak antri satu-satu)
      List<Future<Response>> detailRequests = orders.map((order) {
        return ApiClient.dio.get('/orders/${order['id']}');
      }).toList();

      final detailsResponses = await Future.wait(detailRequests);

      // 4. Akumulasi Quantity per Product ID
      Map<int, int> productSalesCount = {}; // Key: ProductID, Value: Total Qty

      for (var res in detailsResponses) {
        if (res.statusCode == 200) {
          // Struktur: res.data['items'] adalah List
          List items = res.data['items'] ?? [];

          for (var item in items) {
            int pId = item['product_id'];
            int qty = item['quantity'] ?? 0;

            if (productSalesCount.containsKey(pId)) {
              productSalesCount[pId] = productSalesCount[pId]! + qty;
            } else {
              productSalesCount[pId] = qty;
            }
          }
        }
      }

      // 5. Gabungkan Data Penjualan dengan Data Stok Produk
      List<Map<String, dynamic>> resultList = [];

      productSalesCount.forEach((pId, totalQty) {
        // Ambil info produk dari Map yang dibuat di langkah 1
        var productInfo = productMap[pId];

        if (productInfo != null) {
          resultList.add({
            'name': productInfo['NAME'] ?? productInfo['name'] ?? 'Unknown',
            'image': productInfo['image_url'], // URL gambar
            'sold': totalQty,
            'stock': productInfo['stock'] ?? 0,
          });
        }
      });

      // 6. Urutkan dari Penjualan Terbanyak (Descending)
      resultList.sort((a, b) => b['sold'].compareTo(a['sold']));

      // 7. Update State (Ambil Top 5 saja agar tidak kepanjangan)
      if (mounted) {
        setState(() {
          topProductsList = resultList.take(5).toList();
          isLoadingTopProducts = false;
        });
      }

    } catch (e) {
      debugPrint("Error fetching top products: $e");
      if (mounted) setState(() => isLoadingTopProducts = false);
    }
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE').format(now);
    final formattedTime = DateFormat('HH:mm').format(now);
    final Color solidColor = const Color(0xFF301D02);
// Definisi Gradien (#7C684C kiri-bawah ke #6A573D kanan-atas)
    final Gradient gradientColor = const LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [
        Color(0xFF7C684C),
        Color(0xFF6A573D),
      ],
    );

    return SingleChildScrollView(
      // 🟢 PERBAIKAN 1: Tambahkan physics agar scroll smooth
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // ===== Atas =====
          Row(
            children: [
              Expanded(child: InfoCard(title: 'Total Customers', value: isLoadingCustomers ? "..." : totalCustomers, height: 100, backgroundColor: solidColor,)),
              const SizedBox(width: 12),
              Expanded(child: InfoCard(title: 'Total Pesanan Selesai', value: isLoadingOrders ? "..." : totalCompletedOrders, height: 100, backgroundGradient: gradientColor,)),
              const SizedBox(width: 12),
              Expanded(child: InfoCard(title: 'Rata-rata Rating Produk', value: isLoadingRating ? "..." : averageRating, height: 100, backgroundColor: solidColor,)),
              const SizedBox(width: 12),
              Expanded(child: InfoCard(title: 'Jumlah tiket selesai', value: '30', height: 100, backgroundGradient: gradientColor)),
            ],
          ),
          const SizedBox(height: 16),

          // ===== Tengah =====
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: DashboardBox(
                  title: 'Pendapatan Penjualan Produk',
                  child: isLoadingRevenue
                      ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                      : _buildRevenueLineChart(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: DashboardBox(
                  title: 'Layanan Jasa Favorit',
                  child: isLoadingServices
                      ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                      : _buildServicePieChart(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ===== Bawah (Staggered Grid) =====
          StaggeredGrid.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              StaggeredGridTile.count(
                crossAxisCellCount: 2,
                mainAxisCellCount: 2, // Sesuaikan tinggi jika perlu
                child: DashboardBox(
                  title: 'Top produk penjualan tertinggi',
                  // Panggil widget tabel disini
                  child: isLoadingTopProducts
                      ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                      : _buildTopSellingTable(),
                ),
              ),

              const StaggeredGridTile.count(
                crossAxisCellCount: 1,
                mainAxisCellCount: 1,
                child: DashboardBox(title: 'Top produk yang sering dikeluhkan'),
              ),

              // 🟢 PERBAIKAN 2: Widget Kalender tanpa LayoutBuilder
              StaggeredGridTile.count(
                crossAxisCellCount: 1,
                mainAxisCellCount: 1,
                child: DashboardBox(
                  title: 'Hari ini',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formattedDate, style: const TextStyle(fontSize: 16)),
                      Text(formattedTime, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      // Gunakan SizedBox dengan tinggi fix agar Grid bisa menghitung ukuran
                      const SizedBox(
                        height: 280,
                        child: CalendarWidget(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16), // Padding bawah agar tidak mentok
        ],
      ),
    );
  }

  // 🟢 Widget Line Chart
  Widget _buildRevenueLineChart() {
    if (revenueSpots.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("Belum ada data transaksi")),
      );
    }

    return SizedBox(
      height: 250,
      child: Padding(
        padding: const EdgeInsets.only(top: 24, right: 12, left: 6),
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (touchedSpot) => Colors.black,
                tooltipRoundedRadius: 8,
                getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                  return touchedBarSpots.map((barSpot) {
                    final flSpot = barSpot;
                    final formatter = NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    );
                    return LineTooltipItem(
                      formatter.format(flSpot.y),
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                    );
                  }).toList();
                },
              ),
            ),
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index >= 0 && index < monthLabels.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          monthLabels[index],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                    return const Text('');
                  },
                  interval: 1,
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: const Border(bottom: BorderSide(color: Colors.grey, width: 1)),
            ),
            minX: 0,
            maxX: (monthLabels.length - 1).toDouble(),
            minY: 0,
            maxY: maxRevenueY,
            lineBarsData: [
              LineChartBarData(
                spots: revenueSpots,
                isCurved: false,
                color: Colors.lightBlueAccent,
                barWidth: 0,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 6,
                      color: const Color(0xFF0288D1),
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFFB3E5FC).withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🟢 Widget Pie Chart
  Widget _buildServicePieChart() {
    int konstruksi = serviceCounts["Konstruksi Profesional"]!;
    int interior = serviceCounts["Designer Interior Profesional"]!;
    int elektrik = serviceCounts["Instalasi Elektrik"]!;
    int total = konstruksi + interior + elektrik;

    if (total == 0) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("Belum ada data layanan aktif/selesai")),
      );
    }

    return SizedBox(
      height: 250,
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  if (konstruksi > 0)
                    PieChartSectionData(
                      color: const Color(0xFF10b982),
                      value: konstruksi.toDouble(),
                      title: '${((konstruksi / total) * 100).toStringAsFixed(0)}%',
                      radius: 45,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  if (interior > 0)
                    PieChartSectionData(
                      color: const Color(0xFFf49204),
                      value: interior.toDouble(),
                      title: '${((interior / total) * 100).toStringAsFixed(0)}%',
                      radius: 45,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  if (elektrik > 0)
                    PieChartSectionData(
                      color: const Color(0xFF6365ef),
                      value: elektrik.toDouble(),
                      title: '${((elektrik / total) * 100).toStringAsFixed(0)}%',
                      radius: 45,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12.0,
            runSpacing: 0.0,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendItem(const Color(0xFFf49204), "Desainer Interior Profesional"),
              _buildLegendItem(const Color(0xFF10b982), "Konstruksi Profesional"),
              _buildLegendItem(const Color(0xFF6365ef), "Instalasi Elektrik"),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTopSellingTable() {
    if (topProductsList.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(child: Text("Belum ada data penjualan.")),
      );
    }

    return Column(
      children: [
        // Header
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text("Nama Produk", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 1, child: Text("Jumlah Terjual", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 1, child: Text("Status Stok", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),
        const Divider(),

        // List Item
        ...topProductsList.map((item) {
          // Bersihkan URL gambar (hapus duplikat /api atau base url jika perlu)
          String rawUrl = item['image'] ?? '';
          String imageUrl = "";
          if (rawUrl.isNotEmpty) {
            // Asumsi ApiClient.dio.options.baseUrl sudah benar
            // Hapus '/api' jika backend menyimpannya dengan path relatif
            String baseUrl = ApiClient.dio.options.baseUrl.replaceAll('/api', '');
            // Jika rawUrl sudah http, pakai itu, jika tidak gabung dengan base
            imageUrl = rawUrl.startsWith('http') ? rawUrl : "$baseUrl/$rawUrl";
          }

          int stock = int.tryParse(item['stock'].toString()) ?? 0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                // Kolom 1: Gambar & Nama
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.grey[200],
                        ),
                        child: imageUrl.isNotEmpty
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(imageUrl, fit: BoxFit.cover,
                            errorBuilder: (c, o, s) => const Icon(Icons.broken_image, size: 15),
                          ),
                        )
                            : const Icon(Icons.image, size: 15),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['name'],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Kolom 2: Jumlah Terjual
                Expanded(
                  flex: 1,
                  child: Text(
                    "${item['sold']} pcs",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),

                // Kolom 3: Status Stok (Badge)
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildStockBadge(stock),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // Helper Badge Warna Stok
  Widget _buildStockBadge(int stock) {
    Color bgColor;
    String text;

    if (stock == 0) {
      bgColor = Colors.red;
      text = "Habis";
    } else if (stock < 10) {
      bgColor = Colors.amber;
      text = "Tersisa $stock pcs";
    } else {
      bgColor = Colors.blue;
      text = "Cukup";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// --- Reusable Components ---

class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final double height;
  final Color? backgroundColor; // Tambahan: untuk warna solid
  final Gradient? backgroundGradient; // Tambahan: untuk warna gradien

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    this.height = 100,
    this.backgroundColor, // Opsional
    this.backgroundGradient, // Opsional
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          // Gunakan warna jika ada, jika tidak gunakan null
          color: backgroundColor,
          // Gunakan gradien jika ada
          gradient: backgroundGradient,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class DashboardBox extends StatelessWidget {
  final String title;
  final Widget? child;

  const DashboardBox({super.key, required this.title, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class CalendarWidget extends StatelessWidget {
  const CalendarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CalendarDatePicker(
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      onDateChanged: (date) {},
    );
  }
}
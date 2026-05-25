import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/dashboard_service.dart';

class PhHistoryScreen extends StatefulWidget {
  final int idKolam;

  const PhHistoryScreen({super.key, required this.idKolam});

  @override
  State<PhHistoryScreen> createState() => _PhHistoryScreenState();
}

class _PhHistoryScreenState extends State<PhHistoryScreen>
    with SingleTickerProviderStateMixin {
  final _dashboardService = DashboardService();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Light Theme Color Palette ──────────────────────────────────────────────
  static const _bgPage = Color(0xFFF4F7FA);
  static const _bgCard = Color(0xFFFFFFFF);
  static const _bgSubtle = Color(0xFFF0F4F8);
  static const _borderColor = Color(0xFFE2E8F0);
  static const _accent = Color(0xFF0891B2); // teal-600
  static const _accentLight = Color(0xFFE0F2FE); // sky-100
  static const _textPrimary = Color(0xFF0F172A); // slate-900
  static const _textSecondary = Color(0xFF64748B); // slate-500
  static const _textMuted = Color(0xFFCBD5E1); // slate-300
  static const _danger = Color(0xFFDC2626); // red-600
  static const _warning = Color(0xFFD97706); // amber-600
  static const _success = Color(0xFF059669); // emerald-600

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Map<String, double> _kalkulasiStatistik(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return {'max': 0.0, 'min': 0.0, 'avg': 0.0};

    double sum = 0;
    double maxPh = -double.infinity;
    double minPh = double.infinity;

    for (var row in data) {
      final ph = (row['ph_level'] as num).toDouble();
      sum += ph;
      if (ph > maxPh) maxPh = ph;
      if (ph < minPh) minPh = ph;
    }

    return {'max': maxPh, 'min': minPh, 'avg': sum / data.length};
  }

  List<FlSpot> _generateChartSpots(List<Map<String, dynamic>> data) {
    final reversedData = data.reversed.toList();
    return reversedData.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        (entry.value['ph_level'] as num).toDouble(),
      );
    }).toList();
  }

  String _formatWaktu(String isoString) {
    final dateTime = DateTime.parse(isoString).toLocal();
    return DateFormat('HH:mm').format(dateTime);
  }

  String _formatWaktuLengkap(String isoString) {
    final dateTime = DateTime.parse(isoString).toLocal();
    return DateFormat('dd MMM, HH:mm:ss').format(dateTime);
  }

  Color _getPhColor(double ph) {
    if (ph < 6.5 || ph > 8.5) return _danger;
    if (ph < 7.0 || ph > 8.0) return _warning;
    return _success;
  }

  String _getPhStatus(double ph) {
    if (ph < 6.5 || ph > 8.5) return 'ANOMALI';
    if (ph < 7.0 || ph > 8.0) return 'WASPADA';
    return 'OPTIMAL';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        backgroundColor: _bgCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(8),
              color: _bgSubtle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _accent,
              size: 14,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                border: Border.all(color: _accent.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
                color: _accentLight,
              ),
              child: const Icon(
                Icons.science_outlined,
                color: _accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ANALITIK HIDROLOGI',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
                Text(
                  'Rekam jejak 24 jam sesi terakhir',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, _accent, Colors.transparent],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _dashboardService.streamRiwayatPh(widget.idKolam),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: _accent, strokeWidth: 2),
                      SizedBox(height: 16),
                      Text(
                        'MEMUAT DATA HIDROLOGI...',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 11,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(color: _borderColor),
                          borderRadius: BorderRadius.circular(16),
                          color: _bgCard,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.science_outlined,
                          size: 40,
                          color: _textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'TIDAK ADA DATA',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Data hidrologi belum tersedia.',
                        style: TextStyle(color: _textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              final rawData = snapshot.data!;
              final stats = _kalkulasiStatistik(rawData);
              final chartSpots = _generateChartSpots(rawData);
              final reversedDataForLabels = rawData.reversed.toList();

              if (!_fadeController.isCompleted) _fadeController.forward();

              return FadeTransition(
                opacity: _fadeAnimation,
                child: RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  color: _accent,
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatsRow(stats),
                        const SizedBox(height: 16),
                        _buildChartCard(
                          chartSpots: chartSpots,
                          reversedData: reversedDataForLabels,
                          stats: stats,
                        ),
                        const SizedBox(height: 16),
                        _buildLogTable(rawData),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Stats Row ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow(Map<String, double> stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'TERTINGGI',
            value: stats['max']!.toStringAsFixed(2),
            icon: Icons.arrow_upward_rounded,
            color: _getPhColor(stats['max']!),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: 'RATA-RATA',
            value: stats['avg']!.toStringAsFixed(2),
            icon: Icons.data_usage_rounded,
            color: _getPhColor(stats['avg']!),
            isHighlighted: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: 'TERENDAH',
            value: stats['min']!.toStringAsFixed(2),
            icon: Icons.arrow_downward_rounded,
            color: _getPhColor(stats['min']!),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withOpacity(0.06) : _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? color.withOpacity(0.3) : _borderColor,
          width: isHighlighted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 9,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getPhStatus(double.tryParse(value) ?? 7.0),
              style: TextStyle(
                color: color,
                fontSize: 8,
                letterSpacing: 1,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chart Card ─────────────────────────────────────────────────────────────

  Widget _buildChartCard({
    required List<FlSpot> chartSpots,
    required List<Map<String, dynamic>> reversedData,
    required Map<String, double> stats,
  }) {
    final minY = (stats['min']! - 0.5).clamp(0.0, double.infinity);
    final maxY = stats['max']! + 0.5;
    final totalPoints = reversedData.length;
    final labelStep = (totalPoints / 5).ceil().clamp(1, totalPoints);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'GRAFIK TREN pH',
                style: TextStyle(
                  color: _accent,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 2,
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Nilai pH',
                    style: TextStyle(color: _textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.5,
                  getDrawingHorizontalLine: (value) {
                    if (value == 6.5 || value == 8.5) {
                      return FlLine(
                        color: _accent.withOpacity(0.3),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      );
                    }
                    return const FlLine(
                      color: Color(0xFFE2E8F0),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 0.5,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(1),
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: labelStep.toDouble(),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= reversedData.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _formatWaktu(reversedData[idx]['waktu_rekam']),
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: chartSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: _accent,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) =>
                          spot.y < 6.5 || spot.y > 8.5,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 4,
                            color: _danger,
                            strokeWidth: 2,
                            strokeColor: _bgCard,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _accent.withOpacity(0.12),
                          _accent.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Titik anomali pH (< 6.5 atau > 8.5)',
                style: TextStyle(color: _textSecondary, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Log Table ──────────────────────────────────────────────────────────────

  Widget _buildLogTable(List<Map<String, dynamic>> rawData) {
    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'LOG REKAM DATA',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _bgSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Text(
                    '${rawData.length} rekaman',
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Column Labels
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: _bgSubtle,
              border: Border(
                top: BorderSide(color: _borderColor),
                bottom: BorderSide(color: _borderColor),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'WAKTU',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 9,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'NILAI pH',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 9,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'STATUS',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 9,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rawData.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: _borderColor),
            itemBuilder: (context, index) {
              final row = rawData[index];
              final ph = (row['ph_level'] as num).toDouble();
              final color = _getPhColor(ph);
              final status = _getPhStatus(ph);
              final waktu = _formatWaktuLengkap(row['waktu_rekam']);
              final isFirst = index == 0;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: isFirst
                    ? _accentLight.withOpacity(0.5)
                    : Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          if (isFirst) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: _accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ] else
                            const SizedBox(width: 14),
                          Text(
                            waktu,
                            style: TextStyle(
                              color: isFirst ? _textPrimary : _textSecondary,
                              fontSize: 12,
                              fontWeight: isFirst
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        ph.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: color.withOpacity(0.25)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              letterSpacing: 1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// Grid background painter — light theme version
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0891B2).withOpacity(0.04)
      ..strokeWidth = 1;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

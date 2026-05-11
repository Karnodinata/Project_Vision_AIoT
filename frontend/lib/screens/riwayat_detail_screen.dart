import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'riwayat_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _teal50   = Color(0xFFEFFCF9);
const _teal100  = Color(0xFFCCF5EC);
const _teal400  = Color(0xFF2CB89E);
const _teal500  = Color(0xFF14A085);
const _teal600  = Color(0xFF0E8A72);
const _teal700  = Color(0xFF0A6E5B);
const _bgPage   = Color(0xFFF2F6F5);
const _slate200 = Color(0xFFE2E8F0);
const _slate400 = Color(0xFF94A3B8);
const _slate600 = Color(0xFF475569);
const _slate700 = Color(0xFF334155);
const _slate900 = Color(0xFF0F172A);

const _purple    = Color(0xFF7C3AED);
const _purpleBg  = Color(0xFFF5F3FF);
const _purple100 = Color(0xFFEDE9FE);
const _blue      = Color(0xFF0284C7);
const _blueBg    = Color(0xFFEFF6FF);
const _blue100   = Color(0xFFBAE6FD);

class RiwayatDetailScreen extends StatefulWidget {
  final HistoryDailyData dayData;
  const RiwayatDetailScreen({super.key, required this.dayData});

  @override
  State<RiwayatDetailScreen> createState() => _RiwayatDetailScreenState();
}

class _RiwayatDetailScreenState extends State<RiwayatDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get phCount => widget.dayData.phLogs.length;
  int get pakanCount => widget.dayData.pakanLogs.length;
  int get sesiCount => widget.dayData.sesiLogs.length;

  @override
  Widget build(BuildContext context) {
    final date = widget.dayData.date;

    return Scaffold(
      backgroundColor: _bgPage,
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, _) => [
          _buildAppBar(date),
          _buildSummaryBar(),
          _buildTabBar(),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _PhTab(logs: widget.dayData.phLogs),
            _PakanTab(logs: widget.dayData.pakanLogs),
            _SesiTab(logs: widget.dayData.sesiLogs),
          ],
        ),
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar(DateTime date) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: _teal700,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE').format(date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            DateFormat('dd MMMM yyyy').format(date),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.analytics_rounded, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text(
                'Detail',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Summary Bar ───────────────────────────────────────────────────────────
  Widget _buildSummaryBar() {
    final d = widget.dayData;
    return SliverToBoxAdapter(
      child: Container(
        color: _teal700,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Row(
          children: [
            _SummaryBadge(
              icon: Icons.water_drop_rounded,
              label: 'Rata pH',
              value: d.rataRataPh > 0
                  ? d.rataRataPh.toStringAsFixed(2)
                  : '--',
              count: '$phCount log',
              color: _teal400,
            ),
            const SizedBox(width: 8),
            _SummaryBadge(
              icon: Icons.set_meal_rounded,
              label: 'Sisa Pakan',
              value: d.sisaPakan > 0
                  ? '${d.sisaPakan.toStringAsFixed(1)}%'
                  : '--',
              count: '$pakanCount log',
              color: const Color(0xFFA78BFA),
            ),
            const SizedBox(width: 8),
            _SummaryBadge(
              icon: Icons.smart_toy_rounded,
              label: 'Auto Feeder',
              value: '${d.jumlahAutoFeeder}×',
              count: '$sesiCount sesi',
              color: const Color(0xFF38BDF8),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: _teal600,
          unselectedLabelColor: _slate400,
          labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          unselectedLabelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500),
          indicator: BoxDecoration(
            color: _teal50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _teal100),
          ),
          indicatorPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          dividerColor: Colors.transparent,
          tabs: [
            _buildTab(Icons.water_drop_rounded, 'pH Air', phCount),
            _buildTab(Icons.set_meal_rounded, 'Pakan', pakanCount),
            _buildTab(Icons.smart_toy_rounded, 'Feeder', sesiCount),
          ],
        ),
      ),
    );
  }

  Tab _buildTab(IconData icon, String label, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: _teal500,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab Bar Delegate ──────────────────────────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: _bgPage,
          borderRadius: BorderRadius.circular(12),
        ),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// ── Summary Badge ─────────────────────────────────────────────────────────────
class _SummaryBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String count;
  final Color color;

  const _SummaryBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                count,
                style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── pH Tab ────────────────────────────────────────────────────────────────────
class _PhTab extends StatelessWidget {
  final List<dynamic> logs;
  const _PhTab({required this.logs});

  Color _phColor(double ph) {
    if (ph < 6.0) return const Color(0xFFEF4444);
    if (ph < 6.5) return const Color(0xFFF97316);
    if (ph <= 8.0) return _teal500;
    if (ph <= 8.5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _phStatus(double ph) {
    if (ph < 6.0) return 'Sangat Asam';
    if (ph < 6.5) return 'Asam';
    if (ph <= 7.5) return 'Optimal';
    if (ph <= 8.0) return 'Normal';
    if (ph <= 8.5) return 'Basa';
    return 'Sangat Basa';
  }

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const _EmptyTabState(message: 'Tidak ada data pH tercatat');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final row = logs[index];
        final waktu = DateTime.parse(row['waktu_rekam']).toLocal();
        final ph = (row['ph_level'] as num?)?.toDouble() ?? 0;
        final color = _phColor(ph);
        final status = _phStatus(ph);
        final progress = ((ph - 4.0) / 6.0).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _slate200.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // pH value circle
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: color.withOpacity(0.3), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      ph.toStringAsFixed(1),
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  color: _slate400, size: 12),
                              const SizedBox(width: 3),
                              Text(
                                DateFormat('HH:mm:ss').format(waktu),
                                style: const TextStyle(
                                    color: _slate600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // pH bar
                      Stack(
                        children: [
                          Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: _slate200,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(
                              height: 5,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('4.0',
                              style:
                                  TextStyle(color: _slate400, fontSize: 9)),
                          Text('7.0',
                              style:
                                  TextStyle(color: _slate400, fontSize: 9)),
                          Text('10.0',
                              style:
                                  TextStyle(color: _slate400, fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Pakan Tab ─────────────────────────────────────────────────────────────────
class _PakanTab extends StatelessWidget {
  final List<dynamic> logs;
  const _PakanTab({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const _EmptyTabState(message: 'Tidak ada data pakan tercatat');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final row = logs[index];
        final waktu = DateTime.parse(row['created_at']).toLocal();
        final persen = (row['persen'] as num?)?.toDouble() ?? 0;
        final jarak = (row['jarak'] as num?)?.toDouble() ?? 0;
        final ket = row['keterangan'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _slate200.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _purpleBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.set_meal_rounded,
                          color: _purple, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rekaman #${index + 1}',
                            style: const TextStyle(
                              color: _slate900,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  color: _slate400, size: 11),
                              const SizedBox(width: 3),
                              Text(
                                DateFormat('HH:mm:ss').format(waktu),
                                style: const TextStyle(
                                    color: _slate400, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Persen badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _purpleBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFDDD6FE).withOpacity(0.8)),
                      ),
                      child: Text(
                        '${persen.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: _purple,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: _slate200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (persen / 100).clamp(0.0, 1.0),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_purple, Color(0xFFA78BFA)],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Chips row
                Wrap(
                  spacing: 6,
                  children: [
                    _InfoChip(
                      icon: Icons.straighten_rounded,
                      label: '${jarak.toStringAsFixed(0)} cm',
                      color: _blue,
                      bgColor: _blueBg,
                    ),
                    if (ket.isNotEmpty)
                      _InfoChip(
                        icon: Icons.notes_rounded,
                        label: ket,
                        color: _slate600,
                        bgColor: _bgPage,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Sesi Tab ──────────────────────────────────────────────────────────────────
class _SesiTab extends StatelessWidget {
  final List<dynamic> logs;
  const _SesiTab({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const _EmptyTabState(message: 'Tidak ada sesi feeder tercatat');
    }

    final sukses = logs.where((r) => r['status_eksekusi'] == true).length;
    final gagal = logs.length - sukses;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // Summary row
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF22C55E), size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$sukses Sukses',
                          style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text('berhasil dijalankan',
                            style:
                                TextStyle(color: _slate400, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: gagal > 0
                          ? const Color(0xFFFECACA)
                          : _slate200),
                ),
                child: Row(
                  children: [
                    Icon(
                      gagal > 0
                          ? Icons.cancel_rounded
                          : Icons.remove_circle_outline_rounded,
                      color: gagal > 0
                          ? const Color(0xFFEF4444)
                          : _slate400,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$gagal Gagal',
                          style: TextStyle(
                            color: gagal > 0
                                ? const Color(0xFFDC2626)
                                : _slate400,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text('tidak berhasil',
                            style:
                                TextStyle(color: _slate400, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...logs.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final mulai = DateTime.parse(row['waktu_mulai']).toLocal();
          final selesai = row['waktu_selesai'] != null
              ? DateTime.parse(row['waktu_selesai']).toLocal()
              : null;
          final sukses = row['status_eksekusi'] == true;
          final duration = selesai != null
              ? selesai.difference(mulai).inSeconds
              : null;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sukses
                    ? const Color(0xFFBBF7D0).withOpacity(0.7)
                    : const Color(0xFFFECACA).withOpacity(0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Status icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sukses
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      sukses
                          ? Icons.smart_toy_rounded
                          : Icons.error_outline_rounded,
                      color: sukses
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Sesi #${index + 1}',
                              style: const TextStyle(
                                color: _slate900,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: sukses
                                    ? const Color(0xFFF0FDF4)
                                    : const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                sukses ? 'Sukses' : 'Gagal',
                                style: TextStyle(
                                  color: sukses
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Timeline row
                        Row(
                          children: [
                            _TimeChip(
                              label: 'Mulai',
                              time: DateFormat('HH:mm:ss').format(mulai),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 6),
                                color: _slate200,
                              ),
                            ),
                            _TimeChip(
                              label: 'Selesai',
                              time: selesai != null
                                  ? DateFormat('HH:mm:ss').format(selesai)
                                  : '--:--:--',
                            ),
                          ],
                        ),
                        if (duration != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.timer_rounded,
                                  color: _slate400, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'Durasi: ${duration}s',
                                style: const TextStyle(
                                    color: _slate600, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final String time;

  const _TimeChip({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: _slate400, fontSize: 9)),
        Text(
          time,
          style: const TextStyle(
            color: _slate700,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyTabState extends StatelessWidget {
  final String message;
  const _EmptyTabState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _teal50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_rounded, color: _teal400, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              color: _slate700,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Data akan muncul setelah sensor merekam',
            style: TextStyle(color: _slate400, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
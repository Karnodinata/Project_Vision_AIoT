import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'riwayat_detail_screen.dart';

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

const _purple   = Color(0xFF7C3AED);
const _purpleBg = Color(0xFFF5F3FF);
const _blue     = Color(0xFF0284C7);
const _blueBg   = Color(0xFFEFF6FF);

// ── Model ─────────────────────────────────────────────────────────────────────
class HistoryDailyData {
  final DateTime date;
  double rataRataPh;
  double sisaPakan;
  int jumlahAutoFeeder;
  List<dynamic> phLogs;
  List<dynamic> pakanLogs;
  List<dynamic> sesiLogs;

  HistoryDailyData({
    required this.date,
    this.rataRataPh = 0.0,
    this.sisaPakan = 0.0,
    this.jumlahAutoFeeder = 0,
    this.phLogs = const [],
    this.pakanLogs = const [],
    this.sesiLogs = const [],
  });
}

// ── Widget ────────────────────────────────────────────────────────────────────
class RiwayatScreen extends StatefulWidget {
  final int idKolam;
  const RiwayatScreen({super.key, required this.idKolam});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<HistoryDailyData> _historyList = [];

  late AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fetchDataFor10Days(_selectedDate);
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  // ── Data Fetching ─────────────────────────────────────────────────────────
  Future<void> _fetchDataFor10Days(DateTime endDate) async {
    setState(() => _isLoading = true);
    _listController.reset();

    try {
      final supabase = Supabase.instance.client;
      final startDate = endDate.subtract(const Duration(days: 9));
      final startStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(endDate.add(const Duration(days: 1)));

      final tempList = List.generate(
        10,
        (i) => HistoryDailyData(date: endDate.subtract(Duration(days: i))),
      );

      // 1. pH
      try {
        final phRes = await supabase
            .from('riwayat_ph')
            .select('waktu_rekam, ph_level')
            .eq('id_kolam', widget.idKolam)
            .gte('waktu_rekam', startStr)
            .lt('waktu_rekam', endStr);

        final Map<String, List<dynamic>> grouped = {};
        for (var row in phRes) {
          final key = DateFormat('yyyy-MM-dd')
              .format(DateTime.parse(row['waktu_rekam']).toLocal());
          grouped.putIfAbsent(key, () => []).add(row);
        }
        for (var d in tempList) {
          final key = DateFormat('yyyy-MM-dd').format(d.date);
          if (grouped.containsKey(key)) {
            final rows = grouped[key]!;
            d.rataRataPh = rows.fold<double>(0.0,
                    (s, r) => s + ((r['ph_level'] as num?)?.toDouble() ?? 0.0)) /
                rows.length;
            d.phLogs = rows;
          }
        }
      } catch (e) {
        debugPrint('Warning riwayat_ph: $e');
      }

      // 2. Pakan
      try {
        final pakanRes = await supabase
            .from('logs_pakan')
            .select('created_at, persen, jarak, keterangan')
            .eq('id_kolam', widget.idKolam)
            .gte('created_at', startStr)
            .lt('created_at', endStr);

        final Map<String, List<dynamic>> grouped = {};
        for (var row in pakanRes) {
          final key = DateFormat('yyyy-MM-dd')
              .format(DateTime.parse(row['created_at']).toLocal());
          grouped.putIfAbsent(key, () => []).add(row);
        }
        for (var d in tempList) {
          final key = DateFormat('yyyy-MM-dd').format(d.date);
          if (grouped.containsKey(key)) {
            final rows = grouped[key]!;
            d.sisaPakan = rows.fold<double>(0.0,
                    (s, r) => s + ((r['persen'] as num?)?.toDouble() ?? 0.0)) /
                rows.length;
            d.pakanLogs = rows;
          }
        }
      } catch (e) {
        debugPrint('Warning logs_pakan: $e');
      }

      // 3. Sesi
      try {
        final sesiRes = await supabase
            .from('sesi_pakan')
            .select('waktu_mulai, waktu_selesai, status_eksekusi')
            .eq('id_kolam', widget.idKolam)
            .gte('waktu_mulai', startStr)
            .lt('waktu_mulai', endStr);

        final Map<String, List<dynamic>> grouped = {};
        for (var row in sesiRes) {
          final key = DateFormat('yyyy-MM-dd')
              .format(DateTime.parse(row['waktu_mulai']).toLocal());
          grouped.putIfAbsent(key, () => []).add(row);
        }
        for (var d in tempList) {
          final key = DateFormat('yyyy-MM-dd').format(d.date);
          if (grouped.containsKey(key)) {
            d.jumlahAutoFeeder = grouped[key]!.length;
            d.sesiLogs = grouped[key]!;
          }
        }
      } catch (e) {
        debugPrint('Warning sesi_pakan: $e');
      }

      if (mounted) {
        setState(() => _historyList = tempList);
        _listController.forward();
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil data: $e'),
            backgroundColor: _slate700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _teal500,
            onPrimary: Colors.white,
            onSurface: _slate900,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: _teal500),
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchDataFor10Days(picked);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: RefreshIndicator(
        onRefresh: () => _fetchDataFor10Days(_selectedDate),
        color: _teal500,
        backgroundColor: Colors.white,
        displacement: 80,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildDatePickerBar()),
            if (_isLoading)
              const SliverFillRemaining(child: _LoadingState())
            else if (_historyList.isEmpty)
              const SliverFillRemaining(child: _EmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _AnimatedCard(
                      index: index,
                      controller: _listController,
                      child: _DailyCard(
                        dayData: _historyList[index],
                        index: index,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RiwayatDetailScreen(dayData: _historyList[index]),
                          ),
                        ),
                      ),
                    ),
                    childCount: _historyList.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      stretch: true,
      backgroundColor: _teal700,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient base
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_teal700, _teal500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Decorative circles
            Positioned(
              right: -40, top: -40,
              child: Container(
                width: 180, height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              right: 40, bottom: -20,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            // Content
            Positioned(
              bottom: 20, left: 20, right: 60,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.history_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '10 HARI TERAKHIR',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Riwayat Harian',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Date Picker Bar ───────────────────────────────────────────────────────
  Widget _buildDatePickerBar() {
    final bool isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _teal400.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: _teal500.withOpacity(0.07),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_teal500, _teal400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Menampilkan data s.d.',
                      style: TextStyle(
                          color: _slate400, fontSize: 10, letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMMM yyyy').format(_selectedDate),
                      style: const TextStyle(
                        color: _slate900,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (isToday)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _teal50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _teal400.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'HARI INI',
                    style: TextStyle(
                        color: _teal600,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1),
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _bgPage,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_calendar_rounded,
                    color: _slate400, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated Card Wrapper ─────────────────────────────────────────────────────
class _AnimatedCard extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;

  const _AnimatedCard({
    required this.index,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final delay = (index * 0.06).clamp(0.0, 0.6);
    final Animation<double> fade = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOut),
    );
    final Animation<Offset> slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    ));

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

// ── Daily Card ────────────────────────────────────────────────────────────────
class _DailyCard extends StatelessWidget {
  final HistoryDailyData dayData;
  final int index;
  final VoidCallback onTap;

  const _DailyCard({
    required this.dayData,
    required this.index,
    required this.onTap,
  });

  bool get hasData =>
      dayData.rataRataPh > 0 ||
      dayData.sisaPakan > 0 ||
      dayData.jumlahAutoFeeder > 0;

  bool get isToday {
    final now = DateTime.now();
    return dayData.date.year == now.year &&
        dayData.date.month == now.month &&
        dayData.date.day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dayData.date.year == yesterday.year &&
        dayData.date.month == yesterday.month &&
        dayData.date.day == yesterday.day;
  }

  String get dayLabel {
    if (isToday) return 'Hari Ini';
    if (isYesterday) return 'Kemarin';

    final now = DateTime.now();
    final dDate = DateTime(dayData.date.year, dayData.date.month, dayData.date.day);
    final dNow = DateTime(now.year, now.month, now.day);
    final diff = dNow.difference(dDate).inDays;

    if (diff > 0) return '$diff hari lalu';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isToday
              ? _teal400.withOpacity(0.4)
              : _slate200.withOpacity(0.7),
          width: isToday ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isToday
                ? _teal500.withOpacity(0.09)
                : Colors.black.withOpacity(0.03),
            blurRadius: isToday ? 20 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: hasData ? onTap : null,
          splashColor: _teal400.withOpacity(0.06),
          highlightColor: _teal50.withOpacity(0.5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(),
                if (hasData) ...[
                  const SizedBox(height: 14),
                  _buildStats(),
                ] else ...[
                  const SizedBox(height: 12),
                  _buildEmptyBody(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Date badge
        Container(
          width: 52, height: 56,
          decoration: BoxDecoration(
            gradient: isToday
                ? const LinearGradient(
                    colors: [_teal600, _teal400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isToday ? null : _bgPage,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('dd').format(dayData.date),
                style: TextStyle(
                  color: isToday ? Colors.white : _slate700,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM').format(dayData.date).toUpperCase(),
                style: TextStyle(
                  color: isToday ? Colors.white70 : _slate400,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        // Day info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    DateFormat('EEEE').format(dayData.date),
                    style: const TextStyle(
                      color: _slate900,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isToday ? _teal100 : _bgPage,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      dayLabel,
                      style: TextStyle(
                        color: isToday ? _teal700 : _slate400,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat('dd MMMM yyyy').format(dayData.date),
                style: const TextStyle(color: _slate400, fontSize: 12),
              ),
            ],
          ),
        ),
        // Right badge/icon
        if (!hasData)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFFD97706), size: 11),
                SizedBox(width: 4),
                Text(
                  'Kosong',
                  style: TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _teal50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded,
                color: _teal500, size: 13),
          ),
      ],
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        _StatChip(
          icon: Icons.water_drop_rounded,
          label: 'Rata-rata pH',
          value: dayData.rataRataPh > 0
              ? dayData.rataRataPh.toStringAsFixed(2)
              : '--',
          color: _teal500,
          bgColor: _teal50,
          borderColor: _teal100,
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.set_meal_rounded,
          label: 'Sisa Pakan',
          value: dayData.sisaPakan > 0
              ? '${dayData.sisaPakan.toStringAsFixed(1)}%'
              : '--',
          color: _purple,
          bgColor: _purpleBg,
          borderColor: const Color(0xFFDDD6FE),
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.smart_toy_rounded,
          label: 'Feeder',
          value: '${dayData.jumlahAutoFeeder}×',
          color: _blue,
          bgColor: _blueBg,
          borderColor: const Color(0xFFBAE6FD),
        ),
      ],
    );
  }

  Widget _buildEmptyBody() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _bgPage,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, color: _slate400, size: 16),
          SizedBox(width: 6),
          Text(
            'Belum ada data tercatat',
            style: TextStyle(color: _slate400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Stat Chip ─────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor.withOpacity(0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: color, size: 13),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  color: _slate600, fontSize: 9.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading State ─────────────────────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: _teal500,
              strokeWidth: 2.5,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Memuat riwayat...',
            style: TextStyle(
              color: _slate400,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _teal50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded,
                color: _teal400, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada riwayat',
            style: TextStyle(
              color: _slate700,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih tanggal lain untuk melihat riwayat',
            style: TextStyle(color: _slate400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart'; // <-- Tambahkan baris ini

// ---------------------------------------------------------------------------
// Warna konstanta — sama persis dengan DashboardScreen
// ---------------------------------------------------------------------------
const _kBg = Color(0xFFF0F4F3);
const _kWhite = Colors.white;
const _kTeal = Color(0xFF009E83);
const _kTealDeep = Color(0xFF006B58);
const _kBorder = Color(0xFFD5E5E2);
const _kSurface = Color(0xFFF5FAF9);
const _kRed = Color(0xFFE63946);
const _kTextPri = Color(0xFF0D1F1B);
const _kTextSec = Color(0xFF2E4F48);
const _kTextTer = Color(0xFF4A7A72);
const _kTextMuted = Color(0xFF6A9E97);

// ---------------------------------------------------------------------------
// JadwalScreen
// ---------------------------------------------------------------------------
class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen>
    with TickerProviderStateMixin {
  // final String baseUrl = "http://192.168.1.17:5001/api/jadwal";
  final String baseUrl = "${AppConfig.baseUrl}/api/jadwal";
  
  List daftarJadwal = [];
  bool isLoading = false;

  // State Multi-Select
  bool isSelectionMode = false;
  Set<int> selectedIds = {};

  // Animasi
  late AnimationController _fadeCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _fabCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _fabScaleAnim;
  late Animation<double> _fabRotateAnim;

  // Key untuk AnimatedList
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fabScaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _fabCtrl, curve: Curves.easeInOut));
    _fabRotateAnim = Tween<double>(
      begin: 0,
      end: 0.25,
    ).animate(CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOut));

    fetchJadwal();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _fabCtrl.dispose();
    super.dispose();
  }

  // =========================================================================
  // LOGIKA — tidak diubah sama sekali
  // =========================================================================
  Future<void> fetchJadwal() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        setState(() => daftarJadwal = json.decode(response.body));
        _fadeCtrl.forward(from: 0);
      }
    } catch (e) {
      debugPrint("Error Fetch: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> tambahJadwal(int jam, int menit) async {
    bool exists = daftarJadwal.any((j) => j['jam'] == jam && j['menit'] == menit);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Jadwal ${jam.toString().padLeft(2, '0')}:${menit.toString().padLeft(2, '0')} sudah ada!"),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"jam": jam, "menit": menit}),
      );
      
      if (!mounted) return;
      
      if (response.statusCode == 201) {
        fetchJadwal();
      } else if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Gagal: Jadwal sudah ada di server!"),
            backgroundColor: _kRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error Add: $e");
    }
  }

  Future<void> hapusJadwal(int id) async {
    try {
      final response = await http.delete(Uri.parse("$baseUrl?id=$id"));
      if (response.statusCode == 200) {
        fetchJadwal();
      }
    } catch (e) {
      debugPrint("Error Delete: $e");
    }
  }

  Future<void> hapusSemuaJadwal() async {
    if (selectedIds.isEmpty) return;
    try {
      final idsParam = selectedIds.join(',');
      final response = await http.delete(Uri.parse("$baseUrl?ids=$idsParam"));
      if (response.statusCode == 200) {
        setState(() {
          isSelectionMode = false;
          selectedIds.clear();
        });
        fetchJadwal();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Jadwal terpilih berhasil dihapus!"),
              backgroundColor: _kTeal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error Delete Batch: $e");
    }
  }

  Future<void> pilihWaktu() async {
    // Animasi FAB rotate saat tap
    await _fabCtrl.forward();
    _fabCtrl.reverse();

    HapticFeedback.mediumImpact();

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        // Theming TimePicker supaya sesuai design system
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _kTeal,
              onPrimary: Colors.white,
              onSurface: _kTextPri,
              surface: _kWhite,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _kTeal),
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: _kWhite,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: _kBorder),
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: _kBorder),
              ),
              dayPeriodColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? _kTeal.withOpacity(0.12)
                    : _kSurface,
              ),
              hourMinuteColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? _kTeal.withOpacity(0.12)
                    : _kSurface,
              ),
              hourMinuteTextColor: WidgetStateColor.resolveWith(
                (states) =>
                    states.contains(WidgetState.selected) ? _kTeal : _kTextSec,
              ),
              dialHandColor: _kTeal,
              dialBackgroundColor: _kSurface,
              entryModeIconColor: _kTextTer,
              helpTextStyle: const TextStyle(
                color: _kTextTer,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ),
          // FAKTA INJEKSI: Memanipulasi *environment* lokal khusus untuk widget ini
          // Memaksa sistem membaca pengaturan waktu sebagai 24 jam absolut.
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      tambahJadwal(picked.hour, picked.minute);
    }
  }

  // =========================================================================
  // KONFIRMASI HAPUS — bottom sheet custom
  // =========================================================================
  void _konfirmasiHapus(int id, String label) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _HapusBottomSheet(
        label: label,
        onKonfirmasi: () {
          Navigator.pop(context);
          hapusJadwal(id);
        },
      ),
    );
  }

  void _konfirmasiHapusSemua() {
    if (selectedIds.isEmpty) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _HapusBottomSheet(
        label: "${selectedIds.length} JADWAL TERPILIH",
        onKonfirmasi: () {
          Navigator.pop(context);
          hapusSemuaJadwal();
        },
      ),
    );
  }

  void toggleSelection(int id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
        if (selectedIds.isEmpty) isSelectionMode = false;
      } else {
        selectedIds.add(id);
      }
    });
  }

  // =========================================================================
  // BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Grid background
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          _buildBody(),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  // =========================================================================
  // APP BAR
  // =========================================================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kWhite,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, _kTeal, Colors.transparent],
            ),
          ),
        ),
      ),
      leading: isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close_rounded, color: _kTextPri),
              onPressed: () => setState(() {
                isSelectionMode = false;
                selectedIds.clear();
              }),
            )
          : null,
      title: isSelectionMode
          ? Text(
              '${selectedIds.length} Dipilih',
              style: const TextStyle(
                color: _kTextPri,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            )
          : Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: _kTeal, width: 1),
                      borderRadius: BorderRadius.circular(8),
                      color: _kTeal.withOpacity(0.10),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: _kTeal,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [_kTealDeep, _kTeal],
                      ).createShader(b),
                      child: const Text(
                        'JADWAL PAKAN',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Text(
                      'V.I.S.I.O.N FEEDING SCHEDULER',
                      style: TextStyle(
                        color: _kTextTer,
                        fontSize: 9,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      actions: [
        if (isSelectionMode && selectedIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: _konfirmasiHapusSemua,
              icon: const Icon(Icons.delete_outline_rounded, color: _kRed, size: 20),
              label: const Text(
                'HAPUS',
                style: TextStyle(
                  color: _kRed,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: _kRed.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        if (!isSelectionMode)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _AnimatedIconButton(
              icon: Icons.refresh_rounded,
              onTap: fetchJadwal,
            ),
          ),
      ],
    );
  }

  // =========================================================================
  // BODY
  // =========================================================================
  Widget _buildBody() {
    if (isLoading) return _buildLoadingState();
    if (daftarJadwal.isEmpty) return _buildEmptyState();
    return _buildJadwalList();
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSummaryCard(isShimmer: true),
          const SizedBox(height: 16),
          // Shimmer tiles
          ...List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ShimmerTile(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(scale: v, child: child),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _kTeal.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: _kTeal.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                size: 32,
                color: _kTeal,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'BELUM ADA JADWAL',
              style: TextStyle(
                color: _kTeal,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ketuk tombol + untuk menambahkan\njadwal pemberian pakan otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kTextSec, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 32),
            // Arrow hint ke FAB
            Column(
              children: [
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _kTextMuted,
                  size: 20,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tambah Jadwal',
                  style: TextStyle(color: _kTextMuted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJadwalList() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: daftarJadwal.length + 1, // +1 untuk summary card
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildSummaryCard(),
            );
          }
          final item = daftarJadwal[index - 1];
          final label =
              "${item['jam'].toString().padLeft(2, '0')}:${item['menit'].toString().padLeft(2, '0')}";

          return _JadwalTile(
            jam: item['jam'],
            menit: item['menit'],
            label: label,
            entryIndex: index - 1,
            isSelected: selectedIds.contains(item['id']),
            isSelectionMode: isSelectionMode,
            onTap: () {
              if (isSelectionMode) {
                toggleSelection(item['id']);
              }
            },
            onLongPress: () {
              if (!isSelectionMode) {
                setState(() {
                  isSelectionMode = true;
                  selectedIds.add(item['id']);
                });
                HapticFeedback.mediumImpact();
              }
            },
            onHapus: () => _konfirmasiHapus(item['id'], label),
          );
        },
      ),
    );
  }

  // =========================================================================
  // SUMMARY CARD — jumlah jadwal + status
  // =========================================================================
  Widget _buildSummaryCard({bool isShimmer = false}) {
    if (isShimmer) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color: _kTeal.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShimmerBox(width: 160, height: 12, radius: 4),
            SizedBox(height: 14),
            _ShimmerBox(width: double.infinity, height: 20, radius: 6),
          ],
        ),
      );
    }

    final count = daftarJadwal.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: _kTeal.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ikon dengan pulse
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _kTeal.withOpacity(0.08 + _pulseAnim.value * 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _kTeal.withOpacity(0.2 + _pulseAnim.value * 0.1),
                ),
              ),
              child: const Icon(Icons.alarm_rounded, color: _kTeal, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _kTeal,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'STATUS JADWAL',
                      style: TextStyle(
                        color: _kTeal,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: _kTextSec, fontSize: 13),
                    children: [
                      TextSpan(
                        text: '$count ',
                        style: const TextStyle(
                          color: _kTeal,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text: count == 1 ? 'jadwal aktif' : 'jadwal aktif',
                        style: const TextStyle(color: _kTextSec, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Badge "AUTO"
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kTeal.withOpacity(0.10 + _pulseAnim.value * 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kTeal.withOpacity(0.3)),
              ),
              child: const Text(
                'AUTO',
                style: TextStyle(
                  color: _kTeal,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // FAB
  // =========================================================================
  Widget _buildFab() {
    return GestureDetector(
      onTapDown: (_) => _fabCtrl.forward(),
      onTapUp: (_) {
        _fabCtrl.reverse();
        pilihWaktu();
      },
      onTapCancel: () => _fabCtrl.reverse(),
      child: ScaleTransition(
        scale: _fabScaleAnim,
        child: RotationTransition(
          turns: _fabRotateAnim,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kTeal, _kTealDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _kTeal.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// JADWAL TILE — individual item
// ===========================================================================
class _JadwalTile extends StatefulWidget {
  final int jam, menit, entryIndex;
  final String label;
  final VoidCallback onHapus;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _JadwalTile({
    super.key,
    required this.jam,
    required this.menit,
    required this.label,
    required this.entryIndex,
    required this.onHapus,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_JadwalTile> createState() => _JadwalTileState();
}

class _JadwalTileState extends State<_JadwalTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;
  late Animation<double> _scale;
  bool _isPressed = false;

  String get _periodeHari {
    final h = widget.jam;
    if (h >= 4 && h < 11) return 'PAGI';
    if (h >= 11 && h < 15) return 'SIANG';
    if (h >= 15 && h < 18) return 'SORE';
    return 'MALAM';
  }

  IconData get _periodeIcon {
    final h = widget.jam;
    if (h >= 4 && h < 11) return Icons.wb_sunny_rounded;
    if (h >= 11 && h < 15) return Icons.light_mode_rounded;
    if (h >= 15 && h < 18) return Icons.wb_twilight_rounded;
    return Icons.nightlight_round;
  }

  Color get _periodeColor {
    final h = widget.jam;
    if (h >= 4 && h < 11) return const Color(0xFFE8A020);
    if (h >= 11 && h < 15) return const Color(0xFFD06010);
    if (h >= 15 && h < 18) return const Color(0xFFE05040);
    return const Color(0xFF5060C0);
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slide = Tween<Offset>(
      begin: Offset(widget.entryIndex.isEven ? -0.05 : 0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _scale = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Delay stagger berdasarkan index
    Future.delayed(Duration(milliseconds: widget.entryIndex * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) {
                setState(() => _isPressed = false);
                widget.onTap();
              },
              onTapCancel: () => setState(() => _isPressed = false),
              onLongPress: widget.onLongPress,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
                transformAlignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.isSelected ? _kTeal.withOpacity(0.08) : _kWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isSelected ? _kTeal : (_isPressed ? _kTeal.withOpacity(0.3) : _kBorder),
                    width: widget.isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _kTeal.withOpacity(_isPressed ? 0.12 : 0.06),
                      blurRadius: _isPressed ? 16 : 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      // Ikon periode hari
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _periodeColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _periodeColor.withOpacity(0.25),
                          ),
                        ),
                        child: Icon(
                          _periodeIcon,
                          color: _periodeColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Waktu + label periode
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badge periode
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _periodeColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _periodeColor.withOpacity(0.25),
                                ),
                              ),
                              child: Text(
                                _periodeHari,
                                style: TextStyle(
                                  color: _periodeColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Waktu besar
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  widget.label,
                                  style: const TextStyle(
                                    color: _kTextPri,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'WIB',
                                  style: TextStyle(
                                    color: _kTextMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Tombol hapus atau Checkbox
                      if (widget.isSelectionMode)
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.isSelected ? _kTeal : Colors.transparent,
                            border: Border.all(
                              color: widget.isSelected ? _kTeal : _kBorder.withOpacity(0.8),
                              width: 2,
                            ),
                          ),
                          child: widget.isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                              : null,
                        )
                      else
                        _DeleteButton(onTap: widget.onHapus),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// DELETE BUTTON dengan animasi
// ===========================================================================
class _DeleteButton extends StatefulWidget {
  final VoidCallback onTap;
  const _DeleteButton({required this.onTap});

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<_DeleteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.82,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _kRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kRed.withOpacity(0.20)),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: _kRed,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// HAPUS BOTTOM SHEET — konfirmasi sebelum hapus
// ===========================================================================
class _HapusBottomSheet extends StatelessWidget {
  final String label;
  final VoidCallback onKonfirmasi;
  const _HapusBottomSheet({required this.label, required this.onKonfirmasi});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kTeal.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _kBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Ikon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _kRed.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: _kRed.withOpacity(0.20)),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: _kRed,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'HAPUS JADWAL?',
            style: TextStyle(
              color: _kTextPri,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                color: _kTextSec,
                fontSize: 13,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'Jadwal pakan pukul '),
                TextSpan(
                  text: '$label WIB',
                  style: const TextStyle(
                    color: _kTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: ' akan dihapus secara permanen.'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _OutlineButton(
                  label: 'BATAL',
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DangerButton(label: 'HAPUS', onTap: onKonfirmasi),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutlineButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineButton({required this.label, required this.onTap});

  @override
  State<_OutlineButton> createState() => _OutlineButtonState();
}

class _OutlineButtonState extends State<_OutlineButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ctrl.forward(),
    onTapUp: (_) {
      _ctrl.reverse();
      widget.onTap();
    },
    onTapCancel: () => _ctrl.reverse(),
    child: ScaleTransition(
      scale: _scale,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Center(
          child: Text(
            widget.label,
            style: const TextStyle(
              color: _kTextSec,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    ),
  );
}

class _DangerButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _DangerButton({required this.label, required this.onTap});

  @override
  State<_DangerButton> createState() => _DangerButtonState();
}

class _DangerButtonState extends State<_DangerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ctrl.forward(),
    onTapUp: (_) {
      _ctrl.reverse();
      widget.onTap();
    },
    onTapCancel: () => _ctrl.reverse(),
    child: ScaleTransition(
      scale: _scale,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kRed, Color(0xFFD62828)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _kRed.withOpacity(0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    ),
  );
}

// ===========================================================================
// HELPER WIDGETS
// ===========================================================================

/// Icon button dengan press scale
class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AnimatedIconButton({required this.icon, required this.onTap});

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.82,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ctrl.forward(),
    onTapUp: (_) {
      _ctrl.reverse();
      widget.onTap();
    },
    onTapCancel: () => _ctrl.reverse(),
    child: ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(widget.icon, color: _kTextTer, size: 18),
      ),
    ),
  );
}

/// Shimmer tile untuk loading state
class _ShimmerTile extends StatefulWidget {
  @override
  State<_ShimmerTile> createState() => _ShimmerTileState();
}

class _ShimmerTileState extends State<_ShimmerTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final bg = Color.lerp(
          const Color(0xFFE8F2F0),
          const Color(0xFFC8E0DB),
          _anim.value,
        )!;
        return Container(
          height: 74,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
        );
      },
    );
  }
}

/// Shimmer box statis
class _ShimmerBox extends StatefulWidget {
  final double width, height, radius;
  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        color: Color.lerp(
          const Color(0xFFE8F2F0),
          const Color(0xFFC8E0DB),
          _anim.value,
        ),
      ),
    ),
  );
}

/// Grid background
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kTeal.withOpacity(0.05)
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

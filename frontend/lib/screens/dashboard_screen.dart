import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/dashboard_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/grid_painter.dart';
import '../widgets/ph_realtime_card.dart';
import '../widgets/telemetry_feeder_card.dart';
import 'login_screen.dart';
import 'ph_history_screen.dart';
import 'feeding_history_screen.dart';
import 'jadwal_screen.dart';
import 'riwayat_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final _dashboardService = DashboardService();
  final _authService = AuthService();

  // ── Color Mapping for Central Theme ──
  static const Color _kPrimary = AppColors.primary;
  static const Color _kPrimaryDark = AppColors.primaryDark;
  static const Color _kBgPage = AppColors.bgPage;
  static const Color _kTextSecondary = AppColors.textSecondary;
  static const Color _kWarning = AppColors.warning;
  static const Color _kWarningDark = AppColors.warningDark;
  static const Color _kError = AppColors.error;

  Map<String, dynamic>? _kolamInfo;
  bool _isLoading = true;
  String _errorMessage = '';

  // ── State Data Stabil ──
  Stream<List<Map<String, dynamic>>>? _phStream;
  Map<String, dynamic>? _telemetryData;

  // ── Feed Button State ──
  bool _isSendingCommand = false;
  bool _isWaitingForSatiated = false;
  Timer? _globalPollingTimer;

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _initDashboard();
    _startPollingTimer();
  }

  void _startPollingTimer() {
    _globalPollingTimer?.cancel();
    final duration = _isWaitingForSatiated
        ? const Duration(seconds: 1)
        : const Duration(seconds: 15);
    _globalPollingTimer = Timer.periodic(duration, (_) {
      if (mounted && _kolamInfo != null) {
        _sinkronisasiStatusRealtime(_kolamInfo!['id_kolam'] as int);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _globalPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initDashboard() async {
    try {
      final info = await _dashboardService.getKolamInfo();
      if (mounted) {
        setState(() {
          _kolamInfo = info;
          if (info != null) {
            _phStream = _dashboardService
                .streamRiwayatPh(info['id_kolam'] as int)
                .asBroadcastStream();
          }
        });
        
        // Panggil sinkronisasi pertama kali secara langsung agar data terisi instan
        if (info != null) {
          await _sinkronisasiStatusRealtime(info['id_kolam'] as int);
        }
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _fadeController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data kolam: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  // Pull-to-refresh handler
  Future<void> _onRefresh() async {
    if (_kolamInfo == null) return;
    await _sinkronisasiStatusRealtime(_kolamInfo!['id_kolam'] as int);
  }

  // FUNGSI BARU PENYELAMAT SINKRONISASI TOMBOL & AI
  Future<void> _sinkronisasiStatusRealtime(int idKolam) async {
    try {
      final data = await _dashboardService.getStatus();
      bool isServoMenyala = data['status_servo_aktif'] ?? false;
      String statusAi = data['status_ai_terakhir']?.toString() ?? '';

      if (mounted) {
        setState(() {
          _telemetryData = data;

          // JIKA SERVO MATI DI BACKEND TAPI TOMBOL MASIH ORANYE DI APLIKASI
          if (!isServoMenyala && _isWaitingForSatiated) {
            _isWaitingForSatiated = false;
            _isSendingCommand = false;
            _startPollingTimer();

            // Cek apakah mati otomatis karena AI (Ada kata 'kenyang')
            if (statusAi.toLowerCase().contains('kenyang')) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'AI: Pakan dihentikan, ikan sudah kenyang!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: _kPrimary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          }

          // JIKA SERVO MENYALA DI BACKEND (KARENA JADWAL) TAPI TOMBOL UI MASIH MERAH
          if (isServoMenyala && !_isWaitingForSatiated) {
            _isWaitingForSatiated = true;
            _isSendingCommand = false;
            _startPollingTimer();
          }
        });
      }
    } catch (e) {
      debugPrint('Error sinkronisasiStatusRealtime: $e');
    }
  }

  void _handleLogout() async {
    _globalPollingTimer?.cancel();
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _eksekusiPakanManual(int idKolam) async {
    if (_isSendingCommand || _isWaitingForSatiated) return;
    setState(() => _isSendingCommand = true);

    try {
      await _dashboardService.triggerPakanManual();
      setState(() {
        _isSendingCommand = false;  // ← reset agar tombol langsung pindah ke state "HENTIKAN PAKAN"
        _isWaitingForSatiated = true;
        _startPollingTimer();
      });
    } catch (e) {
      if (mounted) setState(() => _isSendingCommand = false);
    }
  }

  Future<void> _hentikanPakanManual(int idKolam) async {
    if (_isSendingCommand) return;
    setState(() => _isSendingCommand = true);

    try {
      await _dashboardService.hentikanPakanManual();
      setState(() {
        _isSendingCommand = false;  // ← reset agar tombol langsung kembali ke "BERI PAKAN MANUAL"
        _isWaitingForSatiated = false;
        _startPollingTimer();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Pakan dihentikan paksa (Override).',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: _kWarningDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSendingCommand = false);
    }
  }

  bool _checkSistemOnline(String waktuRekamTerakhir) {
    final lastUpdate = DateTime.parse(waktuRekamTerakhir).toLocal();
    return DateTime.now().difference(lastUpdate).inMinutes <= 30;
  }

  void _bukaDetailPh(int idKolam) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhHistoryScreen(idKolam: idKolam),
      ),
    );
  }

  void _bukaDetailTelemetri(int idKolam) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedingHistoryScreen(idKolam: idKolam),
      ),
    );
  }

  void _bukaJadwalPakan() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const JadwalScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  void _bukaRiwayat() {
    if (_kolamInfo != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RiwayatScreen(idKolam: _kolamInfo!['id_kolam'] as int),
        ),
      );
    }
  }

  // =========================================================================
  // BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgPage,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
              SizedBox(height: 20),
              Text(
                'MENGINISIALISASI SISTEM...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: _kBgPage,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.signal_wifi_connected_no_internet_4,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 20),
                const Text(
                  'KONEKSI GAGAL',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(_errorMessage, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    if (_kolamInfo == null) {
      return const Scaffold(body: Center(child: Text("TIDAK ADA DATA")));
    }

    final idKolam = _kolamInfo!['id_kolam'] as int;
    final namaKolam = _kolamInfo!['nama_kolam'] as String;

    return Scaffold(
      backgroundColor: _kBgPage,
      appBar: _buildAppBar(namaKolam),
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: GridPainter())),
          FadeTransition(
            opacity: _fadeAnimation,
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: _kPrimary,
              backgroundColor: Colors.white,
              displacement: 50,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _phStream,
                    builder: (context, snapshot) {
                      bool isOnline = false;
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        isOnline = _checkSistemOnline(
                          snapshot.data!.first['waktu_rekam'],
                        );
                      }
                      return _buildStatusHeader(isOnline);
                    },
                  ),
                  const SizedBox(height: 20),
                  PhRealtimeCard(
                    phStream: _phStream,
                    realtimePh: _telemetryData != null
                        ? (_telemetryData!['tingkat_ph'] as num?)?.toDouble()
                        : null,
                    isIotAktif: _telemetryData != null
                        ? (_telemetryData!['is_iot_aktif'] as bool? ?? false)
                        : true,
                    onTap: () => _bukaDetailPh(idKolam),
                  ),
                  const SizedBox(height: 16),
                  TelemetryFeederCard(
                    telemetryData: _telemetryData,
                    onTap: () => _bukaDetailTelemetri(idKolam),
                  ),
                  const SizedBox(height: 16),
                  _buildFeedActionGroup(idKolam),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String namaKolam) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: _kPrimary, width: 1),
              borderRadius: BorderRadius.circular(8),
              color: _kPrimary.withOpacity(0.10),
            ),
            child: const Icon(Icons.water, color: _kPrimary, size: 16),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [_kPrimaryDark, _kPrimary],
                ).createShader(bounds),
                child: const Text(
                  'V.I.S.I.O.N',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                namaKolam.toUpperCase(),
                style: const TextStyle(
                  color: _kTextSecondary,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: _kTextSecondary),
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildStatusHeader(bool isOnline) {
    final color = isOnline ? _kPrimary : _kError;
    final statusLabel = isOnline
        ? 'SISTEM KONTROL AKTIF & TERHUBUNG'
        : 'KONEKSI SENSOR TERPUTUS';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color.withOpacity(0.3 + (_pulseAnimation.value * 0.7)),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(_pulseAnimation.value * 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            statusLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildFeedActionGroup(int idKolam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'KENDALI PAKAN',
                style: TextStyle(
                  color: _kPrimary,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _buildManualFeedButton(idKolam),
        const SizedBox(height: 10),
        _buildJadwalButton(),
        const SizedBox(height: 10),
        _buildRiwayatButton(),
      ],
    );
  }

  Widget _buildManualFeedButton(int idKolam) {
    final isSending = _isSendingCommand;
    final isRunning = _isWaitingForSatiated;

    String btnText;
    List<Color> btnGradient;
    Color btnBorder;
    Color btnShadow;
    IconData btnIcon;
    VoidCallback? onTapAction;

    if (isSending) {
      btnText = 'MENGIRIM KOMANDO...';
      btnGradient = [AppColors.primaryLight, AppColors.primaryLight];
      btnBorder = AppColors.primaryBorder;
      btnShadow = Colors.transparent;
      btnIcon = Icons.hourglass_empty;
      onTapAction = null;
    } else if (isRunning) {
      btnText = '🛑 HENTIKAN PAKAN (OVERRIDE)';
      btnGradient = [_kWarning, _kWarningDark];
      btnBorder = _kWarning.withOpacity(0.5);
      btnShadow = _kWarningDark.withOpacity(0.3);
      btnIcon = Icons.stop_circle_outlined;
      onTapAction = () => _hentikanPakanManual(idKolam);
    } else {
      btnText = 'BERI PAKAN MANUAL';
      btnGradient = [_kError, const Color(0xFFD62828)];
      btnBorder = _kError.withOpacity(0.5);
      btnShadow = _kError.withOpacity(0.28);
      btnIcon = Icons.power_settings_new_rounded;
      onTapAction = () => _eksekusiPakanManual(idKolam);
    }

    return GestureDetector(
      onTap: onTapAction,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: btnGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: btnBorder),
          boxShadow: isSending
              ? []
              : [
                  BoxShadow(
                    color: btnShadow,
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSending)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.textSecondary,
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(btnIcon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                btnText,
                style: TextStyle(
                  color: isSending ? AppColors.textDark : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJadwalButton() => _JadwalButton(onTap: _bukaJadwalPakan);

  Widget _buildRiwayatButton() {
    return GestureDetector(
      onTap: _bukaRiwayat,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kPrimary.withOpacity(0.3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14009E83),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0x14009E83),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x33009E83)),
                ),
                child: const Icon(
                  Icons.history,
                  color: _kPrimary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RIWAYAT HARIAN',
                      style: TextStyle(
                        color: _kPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Lihat data pH, pakan, & riwayat feeder',
                      style: TextStyle(
                        color: _kTextSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: _kPrimary,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }


}

class _JadwalButton extends StatefulWidget {
  final VoidCallback onTap;
  const _JadwalButton({required this.onTap});
  @override
  State<_JadwalButton> createState() => _JadwalButtonState();
}

class _JadwalButtonState extends State<_JadwalButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _arrowSlide;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _arrowSlide = Tween<double>(
      begin: 0,
      end: 4,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
        child: AnimatedBuilder(
          animation: _arrowSlide,
          builder: (_, child) => Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3 + _ctrl.value * 0.4),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14009E83),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0x14009E83),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x33009E83)),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ATUR JADWAL OTOMATIS',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kelola waktu pemberian pakan terjadwal',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(_arrowSlide.value, 0),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.primary,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



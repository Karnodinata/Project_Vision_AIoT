import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../services/dashboard_service.dart';
import '../services/auth_service.dart';
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

    // Global Polling Timer yang agresif untuk menarik status Servo & AI (Setiap 1 detik)
    _globalPollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
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
          _isLoading = false;
        });
        _fadeController.forward();
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

  // FUNGSI BARU PENYELAMAT SINKRONISASI TOMBOL & AI
  Future<void> _sinkronisasiStatusRealtime(int idKolam) async {
    try {
      final res = await http.get(Uri.parse('${AppConfig.baseUrl}/api/status'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        bool isServoMenyala = data['status_servo_aktif'] ?? false;
        String statusAi = data['status_ai_terakhir']?.toString() ?? '';

        if (mounted) {
          setState(() {
            _telemetryData = data;

            // JIKA SERVO MATI DI BACKEND TAPI TOMBOL MASIH ORANYE DI APLIKASI
            if (!isServoMenyala && _isWaitingForSatiated) {
              _isWaitingForSatiated = false;
              _isSendingCommand = false;

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
                    backgroundColor: const Color(0xFF009E83),
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
            }
          });
        }
      }
    } catch (_) {}
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
      // UI State akan otomatis diubah oleh _sinkronisasiStatusRealtime()
      // Tidak perlu set _isWaitingForSatiated di sini lagi
    } catch (e) {
      if (mounted) setState(() => _isSendingCommand = false);
    }
  }

  Future<void> _hentikanPakanManual(int idKolam) async {
    if (_isSendingCommand) return;
    setState(() => _isSendingCommand = true);

    try {
      await _dashboardService.hentikanPakanManual();
      // UI State akan otomatis diubah oleh _sinkronisasiStatusRealtime()
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
            backgroundColor: const Color(0xFFD97706),
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
        backgroundColor: Color(0xFFF0F4F3),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF009E83),
                strokeWidth: 2,
              ),
              SizedBox(height: 20),
              Text(
                'MENGINISIALISASI SISTEM...',
                style: TextStyle(
                  color: Color(0xFF4A7A72),
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
        backgroundColor: const Color(0xFFF0F4F3),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.signal_wifi_connected_no_internet_4,
                  size: 48,
                  color: Color(0xFFE63946),
                ),
                const SizedBox(height: 20),
                const Text(
                  'KONEKSI GAGAL',
                  style: TextStyle(
                    color: Color(0xFFE63946),
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
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: _buildAppBar(namaKolam),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
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
                  _buildPhRealtimeSection(idKolam),
                  const SizedBox(height: 16),
                  _buildTelemetrySection(idKolam),
                  const SizedBox(height: 16),
                  _buildFeedActionGroup(idKolam),
                ],
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
              border: Border.all(color: const Color(0xFF009E83), width: 1),
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF009E83).withOpacity(0.10),
            ),
            child: const Icon(Icons.water, color: Color(0xFF009E83), size: 16),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF006B58), Color(0xFF009E83)],
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
                  color: Color(0xFF4A7A72),
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
          icon: const Icon(Icons.logout_rounded, color: Color(0xFF4A7A72)),
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildStatusHeader(bool isOnline) {
    final color = isOnline ? const Color(0xFF009E83) : const Color(0xFFE63946);
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

  Widget _buildPhRealtimeSection(int idKolam) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _phStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return _buildLoadingCard('METRIK pH REAL-TIME');
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildCardWrapper(
            title: 'METRIK pH REAL-TIME',
            icon: Icons.science_outlined,
            child: const _EmptyDataWidget(
              message: 'Belum ada data hidrologi masuk.',
            ),
          );
        }

        final data = snapshot.data!;
        final latestPh = data.first['ph_level'] as num;

        Color phColor = const Color(0xFF009E83);
        String statusText = 'OPTIMAL';
        String statusDesc = 'Kadar pH dalam rentang ideal 6.5 – 8.5';
        if (latestPh < 6.5 || latestPh > 8.5) {
          phColor = const Color(0xFFE63946);
          statusText = 'PERINGATAN ANOMALI';
          statusDesc = 'Kadar pH di luar rentang ideal!';
        }

        return _buildClickableCardWrapper(
          title: 'METRIK pH REAL-TIME',
          icon: Icons.science_outlined,
          onTap: () => _bukaDetailPh(idKolam),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [phColor.withOpacity(0.75), phColor],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: Text(
                      latestPh.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: phColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: phColor.withOpacity(0.35),
                              ),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: phColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            statusDesc,
                            style: const TextStyle(
                              color: Color(0xFF2E4F48),
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 130,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: const Color(0xFFD5E5E2),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.max || value == meta.min)
                              return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                value.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Color(0xFF4A7A72),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: data
                            .asMap()
                            .entries
                            .map(
                              (e) => FlSpot(
                                (data.length - 1 - e.key).toDouble(),
                                (e.value['ph_level'] as num).toDouble(),
                              ),
                            )
                            .toList(),
                        isCurved: true,
                        color: phColor,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              phColor.withOpacity(0.18),
                              phColor.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTelemetrySection(int idKolam) {
    if (_telemetryData == null) {
      return _buildLoadingCard('TELEMETRI FEEDER & AI');
    }

    final session = _telemetryData!;
    final sisaPakan = session['persen_sisa_pakan'] ?? '--';
    final statusAi = session['status_ai_terakhir'] ?? 'STANDBY';
    final isServoAktif = session['status_servo_aktif'] ?? false;

    double? sisaPakanNum;
    if (sisaPakan != '--') sisaPakanNum = (sisaPakan as num).toDouble();
    final pakanColor = sisaPakanNum != null && sisaPakanNum < 20
        ? const Color(0xFFE63946)
        : const Color(0xFF009E83);

    return _buildClickableCardWrapper(
      title: 'TELEMETRI FEEDER & AI',
      icon: Icons.router_outlined,
      onTap: () => _bukaDetailTelemetri(idKolam),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, _) => Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isServoAktif
                        ? const Color(
                            0xFFE63946,
                          ).withOpacity(0.1 + (_pulseAnimation.value * 0.2))
                        : const Color(0xFFF5FAF9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isServoAktif
                          ? const Color(0xFFE63946)
                          : const Color(0xFFD5E5E2),
                    ),
                  ),
                  child: Icon(
                    isServoAktif ? Icons.camera : Icons.camera_alt_outlined,
                    color: isServoAktif
                        ? const Color(0xFFE63946)
                        : const Color(0xFF4A7A72),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Status ESP32-CAM',
                  style: TextStyle(color: Color(0xFF2E4F48), fontSize: 13),
                ),
              ),
              isServoAktif
                  ? AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, _) => Opacity(
                        opacity: 0.5 + (_pulseAnimation.value * 0.5),
                        child: const Text(
                          '🔴 MEREKAM...',
                          style: TextStyle(
                            color: Color(0xFFE63946),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    )
                  : const Text(
                      '⚪ STANDBY',
                      style: TextStyle(
                        color: Color(0xFF4A7A72),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ],
          ),
          _buildDivider(),
          _buildTelemetryRow(
            icon: Icons.auto_awesome,
            label: 'Hasil Analisis AI',
            value: statusAi.toString().toUpperCase(),
            valueColor: const Color(0xFF0D1F1B),
          ),
          _buildDivider(),
          _buildTelemetryRow(
            icon: Icons.inventory_2_outlined,
            label: 'Sisa Pakan Dispenser',
            value: '$sisaPakan%',
            valueColor: pakanColor,
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
                  color: const Color(0xFF009E83),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'KENDALI PAKAN',
                style: TextStyle(
                  color: Color(0xFF009E83),
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
      btnGradient = [const Color(0xFFE8F2F0), const Color(0xFFE8F2F0)];
      btnBorder = const Color(0xFFD5E5E2);
      btnShadow = Colors.transparent;
      btnIcon = Icons.hourglass_empty;
      onTapAction = null;
    } else if (isRunning) {
      btnText = '🛑 HENTIKAN PAKAN (OVERRIDE)';
      btnGradient = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      btnBorder = const Color(0xFFF59E0B).withOpacity(0.5);
      btnShadow = const Color(0xFFD97706).withOpacity(0.3);
      btnIcon = Icons.stop_circle_outlined;
      onTapAction = () => _hentikanPakanManual(idKolam);
    } else {
      btnText = 'BERI PAKAN MANUAL';
      btnGradient = [const Color(0xFFE63946), const Color(0xFFD62828)];
      btnBorder = const Color(0xFFE63946).withOpacity(0.5);
      btnShadow = const Color(0xFFE63946).withOpacity(0.28);
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
                    color: Color(0xFF4A7A72),
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(btnIcon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                btnText,
                style: TextStyle(
                  color: isSending ? const Color(0xFF2E4F48) : Colors.white,
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
          border: Border.all(color: const Color(0xFF009E83).withOpacity(0.3)),
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
                  color: Color(0xFF009E83),
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
                        color: Color(0xFF009E83),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Lihat data pH, pakan, & riwayat feeder',
                      style: TextStyle(
                        color: Color(0xFF4A7A72),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF009E83),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    height: 1,
    color: const Color(0xFFD5E5E2),
  );

  Widget _buildTelemetryRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF5FAF9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD5E5E2)),
          ),
          child: Icon(icon, color: const Color(0xFF4A7A72), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF2E4F48), fontSize: 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF0D1F1B),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard(String title) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5E5E2)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildCardHeader(title: title, icon: Icons.hourglass_empty_rounded),
          const SizedBox(height: 24),
          const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              color: Color(0xFF009E83),
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardWrapper({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5E5E2)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(title: title, icon: icon),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildClickableCardWrapper({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD5E5E2)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCardHeader(title: title, icon: icon),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5FAF9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD5E5E2)),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF4A7A72),
                      size: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF009E83),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF009E83),
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
                color: const Color(
                  0xFF009E83,
                ).withOpacity(0.3 + _ctrl.value * 0.4),
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
                      color: Color(0xFF009E83),
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
                            color: Color(0xFF009E83),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kelola waktu pemberian pakan terjadwal',
                          style: TextStyle(
                            color: Color(0xFF4A7A72),
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
                      color: Color(0xFF009E83),
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

class _EmptyDataWidget extends StatelessWidget {
  final String message;
  const _EmptyDataWidget({required this.message});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.inbox_outlined, color: Color(0xFF4A7A72), size: 18),
        const SizedBox(width: 10),
        Text(
          message,
          style: const TextStyle(color: Color(0xFF2E4F48), fontSize: 13),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF009E83).withOpacity(0.05)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += 40)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

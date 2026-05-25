import 'package:flutter/material.dart';

class TelemetryFeederCard extends StatefulWidget {
  final Map<String, dynamic>? telemetryData;
  final VoidCallback onTap;

  const TelemetryFeederCard({
    super.key,
    required this.telemetryData,
    required this.onTap,
  });

  @override
  State<TelemetryFeederCard> createState() => _TelemetryFeederCardState();
}

class _TelemetryFeederCardState extends State<TelemetryFeederCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      height: 1,
      color: const Color(0xFFD5E5E2),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.telemetryData == null) {
      return _buildLoadingCard('TELEMETRI FEEDER & AI');
    }

    final session = widget.telemetryData!;
    final sisaPakan = session['persen_sisa_pakan'] ?? '--';
    final statusAi = session['status_ai_terakhir'] ?? 'STANDBY';
    final isServoAktif = session['status_servo_aktif'] ?? false;

    double? sisaPakanNum;
    if (sisaPakan != '--') {
      sisaPakanNum = (sisaPakan as num).toDouble();
    }
    final pakanColor = sisaPakanNum != null && sisaPakanNum < 20
        ? const Color(0xFFE63946)
        : const Color(0xFF009E83);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
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
                  _buildCardHeader(
                    title: 'TELEMETRI FEEDER & AI',
                    icon: Icons.router_outlined,
                  ),
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
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) => Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isServoAktif
                            ? const Color(0xFFE63946).withOpacity(
                                0.1 + (_pulseAnimation.value * 0.2),
                              )
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
        ),
      ),
    );
  }
}

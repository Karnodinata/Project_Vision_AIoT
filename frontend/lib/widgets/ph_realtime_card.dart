import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'empty_data_widget.dart';

class PhRealtimeCard extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>>? phStream;
  final double? realtimePh;
  final bool isIotAktif;
  final VoidCallback onTap;

  const PhRealtimeCard({
    super.key,
    required this.phStream,
    this.realtimePh,
    this.isIotAktif = true,
    required this.onTap,
  });

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

  @override
  Widget build(BuildContext context) {
    if (!isIotAktif) {
      Color phColor = const Color(0xFF9E9E9E);
      String statusText = 'OFFLINE';
      String statusDesc = 'Sensor IoT sedang tidak aktif / mati.';

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
                    _buildCardHeader(
                      title: 'METRIK pH REAL-TIME',
                      icon: Icons.science_outlined,
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
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [phColor.withOpacity(0.75), phColor],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds),
                      child: const Text(
                        '--',
                        style: TextStyle(
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
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: phStream,
      builder: (context, snapshot) {
        final bool hasStreamData = snapshot.hasData && snapshot.data!.isNotEmpty;

        if (realtimePh == null && snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard('METRIK pH REAL-TIME');
        }
        if (realtimePh == null && (snapshot.hasError || !hasStreamData)) {
          return _buildCardWrapper(
            title: 'METRIK pH REAL-TIME',
            icon: Icons.science_outlined,
            child: const EmptyDataWidget(
              message: 'Belum ada data hidrologi masuk.',
            ),
          );
        }

        final num? streamPh = hasStreamData ? snapshot.data!.first['ph_level'] as num : null;
        final num? latestPh = realtimePh ?? streamPh;

        if (latestPh == null) {
          return _buildLoadingCard('METRIK pH REAL-TIME');
        }

        Color phColor = const Color(0xFF009E83);
        String statusText = 'OPTIMAL';
        String statusDesc = 'Kadar pH dalam rentang ideal 6.5 – 8.5';
        if (latestPh < 6.5 || latestPh > 8.5) {
          phColor = const Color(0xFFE63946);
          statusText = 'PERINGATAN ANOMALI';
          statusDesc = 'Kadar pH di luar rentang ideal!';
        }

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
                      _buildCardHeader(
                        title: 'METRIK pH REAL-TIME',
                        icon: Icons.science_outlined,
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
                    child: hasStreamData
                        ? LineChart(
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
                                      if (value == meta.max || value == meta.min) {
                                        return const SizedBox.shrink();
                                      }
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
                                  spots: snapshot.data!
                                      .asMap()
                                      .entries
                                      .map(
                                        (e) => FlSpot(
                                          (snapshot.data!.length - 1 - e.key).toDouble(),
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
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF009E83),
                                    strokeWidth: 1.5,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Memuat grafik histori...',
                                  style: TextStyle(
                                    color: Color(0xFF4A7A72),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

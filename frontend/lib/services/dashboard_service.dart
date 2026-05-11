import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config.dart';

class DashboardService {
  Future<Map<String, dynamic>?> getKolamInfo() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {'id_kolam': 1, 'nama_kolam': 'Kolam Empang Lele'};
  }

  Future<void> triggerPakanManual() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/kontrol');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'aksi': 'feed'}),
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal mengirim komando ke server');
    }
  }

  Future<void> hentikanPakanManual() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/kontrol');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'aksi': 'stop'}),
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal menghentikan komando pakan');
    }
  }

  Stream<List<Map<String, dynamic>>> streamRiwayatPh(int idKolam) async* {
    // BUKU CATATAN: Membuat memori lokal khusus untuk grafik ini
    final List<Map<String, dynamic>> historyLokal = [];

    while (true) {
      try {
        final url = Uri.parse('${AppConfig.baseUrl}/api/status');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          double currentPh = (data['tingkat_ph'] as num).toDouble();

          // 1. Catat data baru ke urutan paling awal (index 0)
          historyLokal.insert(0, {
            'ph_level': currentPh,
            'waktu_rekam': DateTime.now().toIso8601String(),
          });

          // 2. Batasi memori hanya menyimpan 20 titik terakhir agar grafik tidak menumpuk
          if (historyLokal.length > 20) {
            historyLokal.removeLast();
          }

          // 3. Kirim seluruh buku catatan (20 titik) ke UI Grafik
          yield List.from(historyLokal);
        }
      } catch (e) {
        // Abaikan error koneksi sesaat agar stream tidak mati
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<Map<String, dynamic>?> getSesiPakanTerakhir(int idKolam) async {
    try {
      final res = await http.get(Uri.parse('${AppConfig.baseUrl}/api/status'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        bool isAktif = data['status_servo_aktif'] ?? false;
        String statusAiAsli =
            data['status_ai_terakhir']?.toString() ?? 'STANDBY';
        String idFotoAktif = data['id_foto_terakhir']?.toString() ?? '';

        // Cek secara spesifik ke endpoint API baru untuk mendapatkan URL foto (Opsional)
        // Namun, kita asumsikan untuk riwayat real-time ini, kita gunakan pendekatan UI

        String urlFoto = '';
        // Simulasi jika status AI Kenyang, kita cek URL dari Supabase atau beri penanda
        if (statusAiAsli.toLowerCase().contains('kenyang')) {
          // Karena URL asli ada di database, idealnya kita panggil dari DB.
          // Untuk demo cepat, kita berikan flag ke UI agar UI mengambil gambar
          urlFoto = "fetch_from_db";
        }

        return {
          'waktu_mulai': DateTime.now().toIso8601String(),
          'status_eksekusi': isAktif,
          'telemetri_feeder': [
            {'sisa_pakan_persen': (data['persen_sisa_pakan'] as num).toInt()},
          ],
          'log_visual_ai': [
            {
              'status_ikan': statusAiAsli.toUpperCase(),
              'url_foto': urlFoto, // Flag URL gambar
            },
          ],
        };
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> getRiwayatPakanLengkap(int idKolam) async {
    final sesiTerakhir = await getSesiPakanTerakhir(idKolam);
    if (sesiTerakhir != null) {
      return [sesiTerakhir];
    }
    return [];
  }
}

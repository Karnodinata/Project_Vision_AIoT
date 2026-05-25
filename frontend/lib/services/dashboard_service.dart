import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

class DashboardService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getStatus() async {
    try {
      final res = await http.get(Uri.parse('${AppConfig.baseUrl}/api/status'));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      } else {
        throw Exception('Gagal memuat status: HTTP ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getStatus: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getKolamInfo() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      // Fallback untuk testing jika tidak login
      return {'id_kolam': 1, 'nama_kolam': 'Kolam Empang Lele'};
    }
    try {
      final response = await _supabase
          .from('kolam')
          .select()
          .eq('id_akun', user.id)
          .maybeSingle();
      if (response != null) {
        return response;
      }
    } catch (e) {
      debugPrint('Error getKolamInfo: $e');
    }
    return {'id_kolam': 1, 'nama_kolam': 'Kolam Empang Lele (Default)'};
  }

  Future<void> triggerPakanManual() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/kontrol');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'aksi': 'feed'}),
      );
      if (response.statusCode != 200) {
        throw Exception('Gagal mengirim komando ke server: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error triggerPakanManual: $e');
      rethrow;
    }
  }

  Future<void> hentikanPakanManual() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/kontrol');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'aksi': 'stop'}),
      );
      if (response.statusCode != 200) {
        throw Exception('Gagal menghentikan komando pakan: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error hentikanPakanManual: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> streamRiwayatPh(int idKolam) {
    try {
      return _supabase
          .from('riwayat_ph')
          .stream(primaryKey: ['id_log'])
          .eq('id_kolam', idKolam)
          .order('waktu_rekam', ascending: false)
          .limit(20);
    } catch (e) {
      debugPrint('Error streamRiwayatPh: $e');
      // Fallback jika realtime tidak aktif/gagal
      return Stream.value([]);
    }
  }

  Future<Map<String, dynamic>?> getSesiPakanTerakhir(int idKolam) async {
    try {
      final data = await getStatus();

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
    } catch (e) {
      debugPrint('Error getSesiPakanTerakhir: $e');
    }
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


import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class JadwalService {
  final String baseUrl = "${AppConfig.baseUrl}/api/jadwal";

  Future<List<Map<String, dynamic>>> fetchJadwal() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Gagal memuat jadwal: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetchJadwal: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> tambahJadwal(int jam, int menit) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"jam": jam, "menit": menit}),
      );
      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data; // contain status and data
      } else if (response.statusCode == 409) {
        throw Exception('Jadwal sudah ada');
      } else {
        throw Exception('Gagal menyimpan jadwal: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error tambahJadwal: $e');
      rethrow;
    }
  }

  Future<void> hapusJadwal(int id) async {
    try {
      final response = await http.delete(Uri.parse("$baseUrl?id=$id"));
      if (response.statusCode != 200) {
        throw Exception('Gagal menghapus jadwal: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error hapusJadwal: $e');
      rethrow;
    }
  }

  Future<void> hapusSemuaJadwal(Set<int> selectedIds) async {
    if (selectedIds.isEmpty) return;
    try {
      final idsParam = selectedIds.join(',');
      final response = await http.delete(Uri.parse("$baseUrl?ids=$idsParam"));
      if (response.statusCode != 200) {
        throw Exception('Gagal menghapus jadwal massal: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error hapusSemuaJadwal: $e');
      rethrow;
    }
  }
}

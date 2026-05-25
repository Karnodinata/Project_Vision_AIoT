import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Format username menjadi email jika belum memiliki suffix '@'
  static String formatEmail(String rawInput) {
    final clean = rawInput.trim();
    if (!clean.contains('@') && clean.isNotEmpty) {
      return '$clean@gmail.com';
    }
    return clean;
  }

  // Fungsi Login Faktual
  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email, // Di Supabase, default auth biasanya pakai email
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      // Menangkap error spesifik dari server Supabase
      throw Exception('Gagal otentikasi: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan sistem: $e');
    }
  }

  // Cek apakah user sudah login
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Fungsi Logout
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}

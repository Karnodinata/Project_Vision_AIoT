import 'package:flutter_test/flutter_test.dart';
import 'package:vision/services/auth_service.dart';

void main() {
  group('AuthService - formatEmail Unit Tests', () {
    test('Mengonversi username murni tanpa suffix menjadi Gmail', () {
      final result = AuthService.formatEmail('pongo');
      expect(result, 'pongo@gmail.com');
    });

    test('Mempertahankan input yang sudah berupa email lengkap', () {
      final result = AuthService.formatEmail('karnodinata@gmail.com');
      expect(result, 'karnodinata@gmail.com');
    });

    test('Mempertahankan input email dengan domain selain Gmail', () {
      final result = AuthService.formatEmail('admin@awdyfarm.co.id');
      expect(result, 'admin@awdyfarm.co.id');
    });

    test('Membersihkan spasi tambahan sebelum memproses username/email', () {
      final result = AuthService.formatEmail('  pongo_vision   ');
      expect(result, 'pongo_vision@gmail.com');
    });

    test('Mengembalikan string kosong jika input hanya berisi spasi atau kosong', () {
      final result1 = AuthService.formatEmail('');
      final result2 = AuthService.formatEmail('   ');
      expect(result1, '');
      expect(result2, '');
    });
  });
}

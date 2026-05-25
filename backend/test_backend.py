import unittest
from unittest.mock import patch, MagicMock, mock_open
import json
import os
import io

# Import app Flask dari file app.py di direktori yang sama
import app

class TestBackendAPI(unittest.TestCase):
    def setUp(self):
        # Mengatur test client Flask
        app.app.config['TESTING'] = True
        self.client = app.app.test_client()

        # Reset state RAM sebelum setiap pengujian
        import datetime
        app.status_servo_aktif = False
        app.id_sesi_sekarang = None
        app.status_ai_terakhir = "STANDBY"
        app.id_foto_terakhir = None
        app.waktu_sensor_terakhir = datetime.datetime.now()
        app.daftar_jadwal = [
            {"id": 1, "jam": 8, "menit": 0},
            {"id": 2, "jam": 12, "menit": 30}
        ]

        # Patch MQTT client agar tidak melakukan publish nyata
        self.patcher_mqtt = patch('app.mqtt_client')
        self.mock_mqtt = self.patcher_mqtt.start()

        # Patch Supabase client
        self.patcher_supabase = patch('app.supabase')
        self.mock_supabase = self.patcher_supabase.start()

        # Setup mock untuk Supabase Table API fluent interface
        self.mock_table = MagicMock()
        self.mock_supabase.table.return_value = self.mock_table
        self.mock_table.select.return_value = self.mock_table
        self.mock_table.insert.return_value = self.mock_table
        self.mock_table.delete.return_value = self.mock_table
        self.mock_table.eq.return_value = self.mock_table
        self.mock_table.in_.return_value = self.mock_table

        # Patch Roboflow Inference Client
        self.patcher_roboflow = patch('app.ROBOFLOW_CLIENT')
        self.mock_roboflow = self.patcher_roboflow.start()

    def tearDown(self):
        # Menghentikan patching setelah pengujian selesai
        self.patcher_mqtt.stop()
        self.patcher_supabase.stop()
        self.patcher_roboflow.stop()

    def test_get_status(self):
        """Memverifikasi endpoint /api/status mengembalikan format data sensor & state yang benar"""
        app.data_sensor_terakhir = {"jarak_cm": 10.0, "ph_level": 7.2}
        
        response = self.client.get('/api/status')
        self.assertEqual(response.status_code, 200)
        
        data = json.loads(response.data.decode('utf-8'))
        self.assertEqual(data["tingkat_ph"], 7.2)
        self.assertEqual(data["kualitas_air"], "Optimal")
        self.assertEqual(data["status_servo_aktif"], False)
        self.assertEqual(data["status_ai_terakhir"], "STANDBY")
        self.assertIn("persen_sisa_pakan", data)
        self.assertEqual(len(data["daftar_jadwal"]), 2)

    def test_get_status_ph_anomali(self):
        """Memverifikasi kualitas air diatur ke 'Peringatan Anomali' ketika pH di luar batas normal"""
        app.data_sensor_terakhir = {"jarak_cm": 10.0, "ph_level": 5.8} # pH di bawah 6.5
        response = self.client.get('/api/status')
        data = json.loads(response.data.decode('utf-8'))
        self.assertEqual(data["kualitas_air"], "Peringatan Anomali")

    def test_get_status_sensor_offline(self):
        """Memverifikasi api/status melaporkan offline jika waktu_sensor_terakhir kosong atau sudah lampau"""
        app.waktu_sensor_terakhir = None
        response = self.client.get('/api/status')
        data = json.loads(response.data.decode('utf-8'))
        self.assertEqual(data["is_iot_aktif"], False)
        self.assertIsNone(data["tingkat_ph"])
        self.assertEqual(data["kualitas_air"], "Offline")

    def test_kontrol_manual_feed(self):
        """Memverifikasi aksi POST /api/kontrol 'feed' memicu servo dan membuat sesi di database"""
        # Set database mock return value
        mock_response = MagicMock()
        mock_response.data = [{"id_sesi": "test-uuid"}]
        self.mock_table.execute.return_value = mock_response

        response = self.client.post('/api/kontrol', 
                                    data=json.dumps({"aksi": "feed"}),
                                    content_type='application/json')
        
        self.assertEqual(response.status_code, 200)
        self.assertEqual(json.loads(response.data.decode('utf-8')), {"status": "sukses"})
        
        # Cek apakah state berubah
        self.assertTrue(app.status_servo_aktif)
        self.assertIsNotNone(app.id_sesi_sekarang)
        self.assertEqual(app.status_ai_terakhir, "IKAN LAPAR (PROSES)")

        # Cek apakah mempublikasikan MQTT
        self.mock_mqtt.publish.assert_called_with(app.TOPIC_KONTROL, '{"perintah_servo": "buka"}')
        # Cek apakah menginsert sesi pakan ke Supabase
        self.mock_supabase.table.assert_called_with("sesi_pakan")
        self.mock_table.insert.assert_called()

    def test_kontrol_manual_stop(self):
        """Memverifikasi aksi POST /api/kontrol 'stop' mematikan servo dan mencatat log override"""
        # Aktifkan pakan terlebih dahulu
        app.status_servo_aktif = True
        app.id_sesi_sekarang = "active-session-uuid"

        mock_response = MagicMock()
        mock_response.data = [{"id_foto": "foto-uuid"}]
        self.mock_table.execute.return_value = mock_response

        response = self.client.post('/api/kontrol', 
                                    data=json.dumps({"aksi": "stop"}),
                                    content_type='application/json')
        
        self.assertEqual(response.status_code, 200)
        self.assertEqual(json.loads(response.data.decode('utf-8')), {"status": "sukses"})
        
        # Cek apakah state mati
        self.assertFalse(app.status_servo_aktif)
        self.assertIsNone(app.id_sesi_sekarang)
        self.assertEqual(app.status_ai_terakhir, "STANDBY")

        # Cek apakah mempublikasikan MQTT tutup
        self.mock_mqtt.publish.assert_called_with(app.TOPIC_KONTROL, '{"perintah_servo": "tutup"}')
        # Cek apakah menyimpan log manual ke database
        self.mock_supabase.table.assert_any_call("log_visual_ai")
        self.mock_table.insert.assert_called_with({
            "id_foto": unittest.mock.ANY,
            "id_sesi": "active-session-uuid",
            "url_foto": app.url_foto_dummy,
            "status_ikan": "DIHENTIKAN MANUAL"
        })

    @patch('app.os.path.exists', return_value=True)
    @patch('app.os.remove')
    @patch('builtins.open', new_callable=mock_open)
    def test_prediksi_kamera_ikan_lapar(self, mock_file, mock_remove, mock_exists):
        """Memverifikasi prediksi kamera Roboflow saat ikan terdeteksi belum kenyang/lapar"""
        app.status_servo_aktif = True
        app.id_sesi_sekarang = "active-session-uuid"

        # Mock hasil Roboflow: kelas selain "ikan kenyang"
        self.mock_roboflow.run_workflow.return_value = [
            {
                "predictions_node": {
                    "predictions": [{"class": "ikan lapar", "confidence": 0.85}]
                }
            }
        ]

        # Mock database insert
        mock_response = MagicMock()
        mock_response.data = [{"id_foto": "foto-uuid"}]
        self.mock_table.execute.return_value = mock_response

        # Kirim request POST raw data image
        image_data = b"fake-image-bytes-data"
        response = self.client.post('/api/prediksi-kamera', data=image_data, content_type='image/jpeg')
        
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data.decode('utf-8'))
        self.assertEqual(data["status_ikan"], "ikan lapar")
        self.assertEqual(data["servo_dimatikan_ai"], False)

        # Servo harus tetap aktif
        self.assertTrue(app.status_servo_aktif)
        
        # File temporer harus dihapus
        mock_remove.assert_called()

        # Harus log ke Supabase
        self.mock_supabase.table.assert_any_call("log_visual_ai")
        self.mock_table.insert.assert_called_with({
            "id_foto": unittest.mock.ANY,
            "id_sesi": "active-session-uuid",
            "url_foto": app.url_foto_dummy,
            "status_ikan": "ikan lapar"
        })

    @patch('app.os.path.exists', return_value=True)
    @patch('app.os.remove')
    @patch('builtins.open', new_callable=mock_open)
    def test_prediksi_kamera_ikan_kenyang(self, mock_file, mock_remove, mock_exists):
        """Memverifikasi deteksi ikan kenyang memicu auto-stop servo dan mengunggah gambar ke storage"""
        app.status_servo_aktif = True
        app.id_sesi_sekarang = "active-session-uuid"

        # Mock hasil Roboflow: kelas "ikan kenyang"
        self.mock_roboflow.run_workflow.return_value = [
            {
                "predictions_node": {
                    "predictions": [{"class": "ikan kenyang", "confidence": 0.90}]
                }
            }
        ]

        # Mock Storage Supabase
        mock_storage = MagicMock()
        self.mock_supabase.storage.from_.return_value = mock_storage
        mock_storage.get_public_url.return_value = "https://supabase.co/storage/v1/object/public/foto-ai/test.jpg"

        # Mock database insert
        mock_response = MagicMock()
        mock_response.data = [{"id_foto": "foto-uuid"}]
        self.mock_table.execute.return_value = mock_response

        # Kirim request POST
        image_data = b"fake-image-bytes-data"
        response = self.client.post('/api/prediksi-kamera', data=image_data, content_type='image/jpeg')
        
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data.decode('utf-8'))
        self.assertEqual(data["status_ikan"], "ikan kenyang")
        self.assertEqual(data["servo_dimatikan_ai"], True)

        # Servo harus mati otomatis
        self.assertFalse(app.status_servo_aktif)
        
        # Harus mengunggah ke storage bucket 'foto-ai'
        self.mock_supabase.storage.from_.assert_called_with("foto-ai")
        mock_storage.upload.assert_called()
        
        # Harus mencatat log dengan URL publik yang baru
        self.mock_table.insert.assert_called_with({
            "id_foto": unittest.mock.ANY,
            "id_sesi": "active-session-uuid",
            "url_foto": "https://supabase.co/storage/v1/object/public/foto-ai/test.jpg",
            "status_ikan": "ikan kenyang"
        })

    def test_kelola_jadwal_get(self):
        """Memverifikasi GET /api/jadwal mengembalikan daftar jadwal dari RAM"""
        response = self.client.get('/api/jadwal')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data.decode('utf-8'))
        self.assertEqual(data, app.daftar_jadwal)

    def test_kelola_jadwal_post(self):
        """Memverifikasi POST /api/jadwal berhasil menyisipkan jadwal baru ke Supabase dan RAM"""
        # Mock kembalian insert Supabase
        mock_response = MagicMock()
        mock_response.data = [{"id": 3, "jam": 18, "menit": 45}]
        self.mock_table.execute.return_value = mock_response

        data_post = {"jam": 18, "menit": 45}
        response = self.client.post('/api/jadwal', 
                                    data=json.dumps(data_post), 
                                    content_type='application/json')
        
        self.assertEqual(response.status_code, 201)
        data_json = json.loads(response.data.decode('utf-8'))
        self.assertEqual(data_json["status"], "sukses")
        self.assertEqual(data_json["data"]["id"], 3)

        # RAM local list should be updated and sorted
        self.assertEqual(len(app.daftar_jadwal), 3)
        self.assertEqual(app.daftar_jadwal[2]["jam"], 18)

    def test_kelola_jadwal_delete_single(self):
        """Memverifikasi DELETE /api/jadwal?id=x berhasil menghapus dari database dan RAM"""
        mock_response = MagicMock()
        self.mock_table.execute.return_value = mock_response

        response = self.client.delete('/api/jadwal?id=1')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(json.loads(response.data.decode('utf-8')), {"status": "sukses"})

        # Hapus id:1 dari RAM
        self.assertEqual(len(app.daftar_jadwal), 1)
        self.assertEqual(app.daftar_jadwal[0]["id"], 2)
        self.mock_table.delete.assert_called()
        self.mock_table.eq.assert_called_with("id", 1)

    def test_kelola_jadwal_delete_batch(self):
        """Memverifikasi DELETE /api/jadwal?ids=x,y berhasil menghapus secara massal dari DB dan RAM"""
        mock_response = MagicMock()
        self.mock_table.execute.return_value = mock_response

        response = self.client.delete('/api/jadwal?ids=1,2')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(json.loads(response.data.decode('utf-8')), {"status": "sukses"})

        # Keduanya dihapus dari RAM
        self.assertEqual(len(app.daftar_jadwal), 0)
        self.mock_table.delete.assert_called()
        self.mock_table.in_.assert_called_with("id", [1, 2])

if __name__ == '__main__':
    unittest.main()

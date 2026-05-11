import cv2
import requests
import time
import threading

# =====================================================================
# KONFIGURASI
# =====================================================================
# 1. Ganti dengan IP dari aplikasi IP Webcam di HP kamu
#    (Biasanya berakhiran /video)
URL_KAMERA_HP = "http://10.62.8.45:8080/video"

# 2. URL Backend Flask kamu
URL_BACKEND = "http://127.0.0.1:5001/api/prediksi-kamera"
URL_STATUS = "http://127.0.0.1:5001/api/status"

# 3. Interval pengiriman foto (dalam detik)
INTERVAL_KIRIM = 5

def kirim_foto_ke_backend(frame):
    """Fungsi untuk mengirim frame (foto) ke backend Flask"""
    try:
        # Encode frame OpenCV menjadi format .jpg
        _, img_encoded = cv2.imencode('.jpg', frame)
        img_bytes = img_encoded.tobytes()

        # Cek status servo dulu (agar tidak spam jika sedang standby)
        # Sesuai logika di app.py, prediksi diabaikan jika servo tidak aktif
        response_status = requests.get(URL_STATUS, timeout=3)
        if response_status.status_code == 200:
            data_status = response_status.json()
            if not data_status.get("status_servo_aktif", False):
                print("⏳ Servo sedang OFF (Standby). Menunggu jadwal pakan...")
                return

        print("🚀 Mengirim foto ke AI (Roboflow) lewat Backend...")
        
        # Kirim HTTP POST multipart/form-data (seperti perilaku ESP32-CAM)
        files = {'image': ('kamera_hp.jpg', img_bytes, 'image/jpeg')}
        response = requests.post(URL_BACKEND, files=files, timeout=10)
        
        if response.status_code == 200:
            hasil = response.json()
            print(f"✅ Balasan Backend: {hasil}")
        else:
            print(f"❌ Backend Error ({response.status_code}): {response.text}")

    except requests.exceptions.RequestException as e:
        print(f"⚠️ Gagal terhubung ke Backend: {e}")

# =====================================================================
# PROGRAM UTAMA
# =====================================================================
def main():
    print(f"Menghubungkan ke Kamera HP: {URL_KAMERA_HP} ...")
    cap = cv2.VideoCapture(URL_KAMERA_HP)

    if not cap.isOpened():
        print("❌ Gagal terhubung ke Kamera HP! Pastikan URL benar dan satu WiFi.")
        return

    waktu_terakhir_kirim = time.time()
    print("✅ Berhasil terhubung. Menampilkan video... (Tekan 'q' untuk keluar)")

    while True:
        ret, frame = cap.read()
        if not ret:
            print("❌ Terputus dari kamera HP.")
            break

        # Tampilkan video feed dari HP
        cv2.imshow("Simulator ESP32-CAM (Kamera HP)", frame)

        # Logika Pengiriman Otomatis setiap X detik
        waktu_sekarang = time.time()
        if waktu_sekarang - waktu_terakhir_kirim >= INTERVAL_KIRIM:
            waktu_terakhir_kirim = waktu_sekarang
            # Kirim foto menggunakan thread agar video tidak macet (lag) saat proses HTTP Request
            threading.Thread(target=kirim_foto_ke_backend, args=(frame.copy(),)).start()

        # Tekan 's' untuk mengirim foto secara manual (jika tidak mau nunggu interval)
        key = cv2.waitKey(1) & 0xFF
        if key == ord('s'):
            print("📸 Mengirim paksa secara manual...")
            threading.Thread(target=kirim_foto_ke_backend, args=(frame.copy(),)).start()
        
        # Tekan 'q' untuk keluar
        elif key == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()

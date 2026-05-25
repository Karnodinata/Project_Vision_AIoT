import os
import json
import uuid
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
import paho.mqtt.client as mqtt
from apscheduler.schedulers.background import BackgroundScheduler
from supabase import create_client, Client

# IMPORT LIBRARY BARU DARI ROBOFLOW
from inference_sdk import InferenceHTTPClient

app = Flask(__name__)
CORS(app)

# ==============================================================================
# KONFIGURASI GLOBAL & API
# ==============================================================================
MQTT_BROKER = "broker.emqx.io"
MQTT_PORT = 1883
TOPIC_SENSOR = "visio/bioflok/sensor"
TOPIC_KONTROL = "visio/bioflok/kontrol"

# --- KONFIGURASI ROBOFLOW WORKFLOW ---
# Menggunakan SDK sesuai dengan snippet dari Roboflow
ROBOFLOW_CLIENT = InferenceHTTPClient(
    api_url="https://serverless.roboflow.com",
    api_key="hX1iQ1FK8QVJOV1ksVE4"
)
WORKSPACE_NAME = "ai-lele"
WORKFLOW_ID = "detect-and-classify"
CLASS_IKAN_KENYANG = "ikan kenyang" 

# --- KONFIGURASI SUPABASE ---
SUPABASE_URL = "https://keginmdkkgtvaxchtjug.supabase.co" # GANTI DENGAN URL SUPABASE ANDA
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtlZ2lubWRra2d0dmF4Y2h0anVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODkwOTEsImV4cCI6MjA4NzE2NTA5MX0.KGiNU8S1oLpJ1fep8p9uqVTFg0OwPRvxduGqzHLz3BU" # GANTI DENGAN KEY ANDA
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# --- STATE MESIN & DATA ---
status_servo_aktif = False
menit_jadwal_terakhir = -1
daftar_jadwal = [] 
id_jadwal_counter = 1

data_sensor_terakhir = {"jarak_cm": 20.0, "ph_level": 7.0}
waktu_sensor_terakhir = None

id_sesi_sekarang = None
status_ai_terakhir = "STANDBY"
id_foto_terakhir = None 
url_foto_dummy = "https://dummyimage.com/600x400/0D151B/009E83.png&text=V.I.S.I.O.N"

# ==============================================================================
# KONTROL MQTT & SENSOR
# ==============================================================================
def hitung_persentase_pakan(jarak_cm):
    tinggi_wadah_maks = 20.0
    if jarak_cm >= tinggi_wadah_maks: return 0
    elif jarak_cm <= 2.0: return 100
    return int(((tinggi_wadah_maks - jarak_cm) / (tinggi_wadah_maks - 2.0)) * 100)

def on_connect(client, userdata, flags, rc):
    print(f"MQTT Terhubung! (Code: {rc})")
    client.subscribe(TOPIC_SENSOR)

def on_message(client, userdata, msg):
    global data_sensor_terakhir, waktu_sensor_terakhir
    try:
        if msg.topic == TOPIC_SENSOR:
            payload = json.loads(msg.payload.decode('utf-8'))
            data_sensor_terakhir["jarak_cm"] = payload.get("jarak_cm", 20.0)
            data_sensor_terakhir["ph_level"] = payload.get("ph_level", 7.0)
            waktu_sensor_terakhir = datetime.now()
    except Exception as e:
        pass

mqtt_client = mqtt.Client()
mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message
mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
mqtt_client.loop_start()

# ==============================================================================
# FUNGSI PICU PAKAN (MEMULAI SESI)
# ==============================================================================
def mulai_pakan():
    global status_servo_aktif, id_sesi_sekarang, status_ai_terakhir, id_foto_terakhir
    status_servo_aktif = True
    id_sesi_sekarang = str(uuid.uuid4())
    status_ai_terakhir = "IKAN LAPAR (PROSES)"
    id_foto_terakhir = None 

    # --- KODE BARU: INSERT KE TABEL sesi_pakan DI SUPABASE ---
    try:
        # Sesuaikan kunci (key) dictionary ini jika tabel sesi_pakan Anda 
        # memiliki kolom wajib lain selain id_sesi
        data_sesi_baru = {
            "id_sesi": id_sesi_sekarang
            # "waktu_mulai": datetime.now().isoformat() # Buka komentar ini jika Anda punya kolom waktu_mulai
        }
        supabase.table("sesi_pakan").insert(data_sesi_baru).execute()
        print(f"✅ [SUPABASE] Sesi Pakan Induk berhasil dibuat!")
    except Exception as e:
        print(f"❌ [SUPABASE] Gagal membuat Sesi Pakan Induk: {e}")
    # ---------------------------------------------------------

    mqtt_client.publish(TOPIC_KONTROL, '{"perintah_servo": "buka"}')
    print(f">> PAKAN DIMULAI | ID Sesi: {id_sesi_sekarang}")

def hentikan_pakan():
    global status_servo_aktif, id_sesi_sekarang, status_ai_terakhir
    status_servo_aktif = False
    id_sesi_sekarang = None
    status_ai_terakhir = "STANDBY"
    mqtt_client.publish(TOPIC_KONTROL, '{"perintah_servo": "tutup"}')
    print(">> PAKAN DIHENTIKAN")

# ==============================================================================
# SCHEDULER & ROUTING API
# ==============================================================================
def cek_dan_eksekusi_jadwal():
    global menit_jadwal_terakhir
    sekarang = datetime.now()
    ada_jadwal = any(j['jam'] == sekarang.hour and j['menit'] == sekarang.minute for j in daftar_jadwal)

    if ada_jadwal:
        if menit_jadwal_terakhir != sekarang.minute:
            menit_jadwal_terakhir = sekarang.minute
            mulai_pakan()
    else:
        menit_jadwal_terakhir = -1

def simpan_riwayat_ph_ke_supabase():
    global waktu_sensor_terakhir
    try:
        # Jangan simpan jika IoT offline / belum pernah mengirim data
        is_iot_aktif = False
        if waktu_sensor_terakhir is not None:
            selisih = (datetime.now() - waktu_sensor_terakhir).total_seconds()
            if selisih < 30:
                is_iot_aktif = True
                
        if not is_iot_aktif:
            print("⚠️ [SUPABASE] Batal menyimpan riwayat pH berkala karena sensor IoT offline.")
            return

        # Ambil id_kolam pertama dari database (default 1 jika kosong)
        id_kolam = 1
        res_kolam = supabase.table("kolam").select("id_kolam").limit(1).execute()
        if res_kolam.data:
            id_kolam = res_kolam.data[0]["id_kolam"]
            
        ph = round(data_sensor_terakhir["ph_level"], 2)
        data_insert = {
            "id_kolam": id_kolam,
            "ph_level": ph,
            "waktu_rekam": datetime.now().isoformat()
        }
        supabase.table("riwayat_ph").insert(data_insert).execute()
        print(f"✅ [SUPABASE] Berhasil menyimpan riwayat pH berkala: {ph} (Kolam ID: {id_kolam})")
    except Exception as e:
        print(f"❌ [SUPABASE] Gagal menyimpan riwayat pH berkala: {e}")

scheduler = BackgroundScheduler()
scheduler.add_job(func=cek_dan_eksekusi_jadwal, trigger="interval", seconds=10)
scheduler.add_job(func=simpan_riwayat_ph_ke_supabase, trigger="interval", minutes=30)
scheduler.start()

@app.route('/api/status', methods=['GET'])
def get_status():
    global waktu_sensor_terakhir
    
    is_iot_aktif = False
    if waktu_sensor_terakhir is not None:
        selisih = (datetime.now() - waktu_sensor_terakhir).total_seconds()
        if selisih < 30:
            is_iot_aktif = True

    ph = round(data_sensor_terakhir["ph_level"], 2)
    kualitas = "Peringatan Anomali" if ph < 6.5 or ph > 8.5 else "Optimal"
    
    return jsonify({
        "tingkat_ph": ph if is_iot_aktif else None,
        "kualitas_air": kualitas if is_iot_aktif else "Offline",
        "is_iot_aktif": is_iot_aktif,
        "persen_sisa_pakan": hitung_persentase_pakan(data_sensor_terakhir["jarak_cm"]) if is_iot_aktif else 0,
        "status_servo_aktif": status_servo_aktif,
        "status_ai_terakhir": status_ai_terakhir,
        "id_sesi_aktif": id_sesi_sekarang,
        "id_foto_terakhir": id_foto_terakhir, 
        "daftar_jadwal": daftar_jadwal
    })

@app.route('/api/kontrol', methods=['POST'])
def kontrol_manual():
    global id_sesi_sekarang # Pastikan kita bisa membaca ID sesi sebelum dihapus

    aksi = request.json.get('aksi')
    
    if aksi == 'feed' and not status_servo_aktif:
        mulai_pakan()
        return jsonify({"status": "sukses"})
        
    elif aksi == 'stop' and status_servo_aktif:
        # =====================================================================
        # TAMBAHAN BARU: Simpan log "Override Manual" ke Supabase
        # =====================================================================
        if id_sesi_sekarang:
            try:
                data_insert = {
                    "id_foto": str(uuid.uuid4()),
                    "id_sesi": id_sesi_sekarang,
                    "url_foto": url_foto_dummy, # Gunakan URL dummy karena tidak ada foto AI final
                    "status_ikan": "DIHENTIKAN MANUAL" # Status khusus untuk penanda
                }
                supabase.table("log_visual_ai").insert(data_insert).execute()
                print(f"✅ [DATABASE] Log Override Manual tersimpan!")
            except Exception as e:
                print(f"❌ [DATABASE] Error menyimpan log override: {e}")
        # =====================================================================
        
        hentikan_pakan() # Panggil fungsi ini SETELAH data disimpan
        return jsonify({"status": "sukses"})
        
    return jsonify({"status": "diabaikan"})

@app.route('/api/prediksi-kamera', methods=['POST'])
def prediksi_kamera():
    global status_ai_terakhir, id_foto_terakhir
    
    if not status_servo_aktif:
        return jsonify({"status": "diabaikan", "pesan": "Kamera standby"})

    if 'image' in request.files:
        image_bytes = request.files['image'].read()
    else:
        image_bytes = request.data
        
    if not image_bytes:
        return jsonify({"error": "Tidak ada gambar"}), 400

    # 1. Simpan sementara gambar ke hardisk
    temp_filename = f"temp_{uuid.uuid4().hex}.jpg"
    with open(temp_filename, "wb") as f:
        f.write(image_bytes)

    try:
        # 2. Jalankan Workflow Roboflow
        result = ROBOFLOW_CLIENT.run_workflow(
            workspace_name=WORKSPACE_NAME,
            workflow_id=WORKFLOW_ID,
            images={"image": temp_filename},
            use_cache=True
        )
        
        hasil_prediksi_ai = "Tidak Terdeteksi"
        if isinstance(result, list) and len(result) > 0:
            first_result = result[0]
            for key, value in first_result.items():
                if isinstance(value, dict) and "predictions" in value:
                    if len(value["predictions"]) > 0:
                        hasil_prediksi_ai = value["predictions"][0].get("class", "Tidak Terdeteksi")
                        break
                elif isinstance(value, dict) and "top" in value:
                    hasil_prediksi_ai = value.get("top", "Tidak Terdeteksi")
                    break

    except Exception as e:
        pesan_error = str(e)
        print(f"❌ [ERROR ROBOFLOW]: {pesan_error}")
        
        # Hapus file sementara agar tidak menumpuk
        if os.path.exists(temp_filename): 
            os.remove(temp_filename)
            
        # TANGKAL BUG ROBOFLOW: Jika error karena dynamic_crop (tidak ada objek)
        if "dynamic_crop" in pesan_error.lower():
            print(">> INFO: Roboflow gagal memotong gambar (Kemungkinan besar tidak ada ikan yang terlihat).")
            # Anggap saja sebagai "Tidak Terdeteksi" dan kembalikan status sukses ke ESP32
            return jsonify({
                "status": "sukses", 
                "status_ikan": "Tidak Terdeteksi", 
                "servo_dimatikan_ai": False
            })
            
        # Jika error lain (misal API Key salah, kuota habis), baru kembalikan 500
        return jsonify({"error": pesan_error}), 500

    status_ai_terakhir = hasil_prediksi_ai
    print(f"✅ [AI VISION] Mendeteksi: {hasil_prediksi_ai}")
    sesi_aktif_saat_ini = id_sesi_sekarang

    # =====================================================================
    # LOGIKA UPLOAD FOTO KE SUPABASE JIKA IKAN TERDETEKSI KENYANG
    # =====================================================================
    hasil_teks = str(hasil_prediksi_ai).lower()
    dimatikan_ai = False
    url_foto_final = url_foto_dummy 

    # LOGIKA BARU: Pastikan ada kata "kenyang", TETAPI TIDAK ADA kata "belum"
    if "kenyang" in hasil_teks and "belum" not in hasil_teks:
        print(">> MENGUNGGAH FOTO BUKTI AI KE SUPABASE STORAGE...")
        try:
            nama_file_storage = f"bukti_kenyang_{uuid.uuid4().hex}.jpg"
            
            with open(temp_filename, "rb") as f:
                file_upload = f.read()
            
            # Upload ke bucket 'foto-ai'
            res = supabase.storage.from_("foto-ai").upload(
                file=file_upload,
                path=nama_file_storage,
                file_options={"content-type": "image/jpeg"}
            )
            
            url_foto_final = supabase.storage.from_("foto-ai").get_public_url(nama_file_storage)
            print(f"✅ [STORAGE] Foto berhasil diunggah: {url_foto_final}")
            
        except Exception as e:
            print(f"❌ [STORAGE] Gagal mengunggah foto: {e}")
            
        # Matikan servo HANYA JIKA benar-benar kenyang
        hentikan_pakan()
        dimatikan_ai = True
    # =====================================================================

    # Hapus file sementara dari laptop
    if os.path.exists(temp_filename):
        os.remove(temp_filename)

    # 4. INSERT KE TABEL SUPABASE (Gunakan sesi_aktif_saat_ini yang sudah diamankan)
    if sesi_aktif_saat_ini:
        id_foto_baru = str(uuid.uuid4())
        id_foto_terakhir = id_foto_baru 
        
        try:
            data_insert = {
                "id_foto": id_foto_baru,
                "id_sesi": sesi_aktif_saat_ini, # Menggunakan variabel lokal yang aman
                "url_foto": url_foto_final,
                "status_ikan": str(hasil_prediksi_ai) 
            }
            supabase.table("log_visual_ai").insert(data_insert).execute()
            print(f"✅ [DATABASE] Log tersimpan dengan URL: {url_foto_final}")
        except Exception as e:
            print(f"❌ [DATABASE] Error menyimpan log: {e}")
        
    return jsonify({
        "status": "sukses", 
        "status_ikan": hasil_prediksi_ai, 
        "servo_dimatikan_ai": dimatikan_ai
    })

# ==============================================================================
# INISIALISASI & JADWAL API (TERINTEGRASI SUPABASE)
# ==============================================================================

# Fungsi ini akan dipanggil otomatis saat Flask pertama kali dijalankan
def muat_jadwal_dari_supabase():
    global daftar_jadwal
    try:
        # Menarik semua data jadwal dari tabel 'jadwal_pakan' di Supabase
        response = supabase.table("jadwal_pakan").select("id, jam, menit").execute()
        daftar_jadwal = response.data
        # Urutkan berdasarkan jam dan menit dari pagi ke malam
        daftar_jadwal = sorted(daftar_jadwal, key=lambda x: (x['jam'], x['menit']))
        print(f"✅ [SUPABASE] Berhasil memuat {len(daftar_jadwal)} jadwal pakan dari database.")
    except Exception as e:
        print(f"❌ [SUPABASE] Gagal memuat jadwal: {e}")

# Panggil fungsi ini SATU KALI sebelum masuk ke route API
muat_jadwal_dari_supabase()

@app.route('/api/jadwal', methods=['GET', 'POST', 'DELETE'])
def kelola_jadwal():
    global daftar_jadwal
    
    if request.method == 'GET':
        return jsonify(daftar_jadwal)
        
    elif request.method == 'POST':
        data = request.json
        jam = data.get('jam')
        menit = data.get('menit')
        
        if jam is None or menit is None: 
            return jsonify({"error": "Format tidak valid"}), 400
            
        if any(j['jam'] == jam and j['menit'] == menit for j in daftar_jadwal):
            return jsonify({"error": "Jadwal pada waktu tersebut sudah ada"}), 409
            
        try:
            # 1. Simpan (Insert) ke Supabase
            data_insert = {"jam": jam, "menit": menit}
            response = supabase.table("jadwal_pakan").insert(data_insert).execute()
            
            # 2. Ambil data yang baru masuk (lengkap dengan ID otomatisnya)
            jadwal_baru = response.data[0]
            
            # 3. Perbarui variabel lokal di RAM agar scheduler tidak perlu 
            #    bertanya ke Supabase setiap 10 detik (menghemat kuota)
            daftar_jadwal.append(jadwal_baru)
            daftar_jadwal = sorted(daftar_jadwal, key=lambda x: (x['jam'], x['menit']))
            
            print(f"✅ [DATABASE] Jadwal baru ditambahkan: {jam:02d}:{menit:02d}")
            return jsonify({"status": "sukses", "data": jadwal_baru}), 201
            
        except Exception as e:
            print(f"❌ [DATABASE] Error Insert Jadwal: {e}")
            return jsonify({"error": "Gagal menyimpan jadwal"}), 500
            
    elif request.method == 'DELETE':
        ids_hapus = request.args.get('ids')
        id_hapus = request.args.get('id', type=int)
        
        try:
            if ids_hapus:
                list_ids = [int(i) for i in ids_hapus.split(',') if i.strip()]
                if not list_ids:
                    return jsonify({"error": "ID tidak valid"}), 400
                
                supabase.table("jadwal_pakan").delete().in_("id", list_ids).execute()
                daftar_jadwal = [j for j in daftar_jadwal if j.get('id') not in list_ids]
                
                print(f"🗑️ [DATABASE] {len(list_ids)} jadwal berhasil dihapus secara massal.")
                return jsonify({"status": "sukses"})
            elif id_hapus is not None:
                # 1. Hapus dari Supabase berdasarkan ID
                supabase.table("jadwal_pakan").delete().eq("id", id_hapus).execute()
                
                # 2. Hapus dari variabel lokal di RAM
                daftar_jadwal = [j for j in daftar_jadwal if j.get('id') != id_hapus]
                
                print(f"🗑️ [DATABASE] Jadwal dengan ID {id_hapus} dihapus.")
                return jsonify({"status": "sukses"})
            else:
                return jsonify({"error": "ID tidak ditemukan"}), 400
            
        except Exception as e:
            print(f"❌ [DATABASE] Error Delete Jadwal: {e}")
            return jsonify({"error": "Gagal menghapus jadwal"}), 500

# ==============================================================================
# MAIN PELAKSANAAN
# ==============================================================================
if __name__ == '__main__':
    try:
        print("Memulai V.I.S.I.O.N Backend Server (Workflow Mode)...")
        app.run(host='0.0.0.0', port=5001, debug=False, use_reloader=False)
    except (KeyboardInterrupt, SystemExit):
        scheduler.shutdown()
        mqtt_client.loop_stop()
        mqtt_client.disconnect()
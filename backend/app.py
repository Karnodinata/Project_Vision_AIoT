import os
import json
import uuid
import threading
import tempfile
import glob
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
import paho.mqtt.client as mqtt
from apscheduler.schedulers.background import BackgroundScheduler
from supabase import create_client, Client
from dotenv import load_dotenv

# Muat variabel dari file .env
load_dotenv()

# IMPORT LIBRARY ROBOFLOW
from inference_sdk import InferenceHTTPClient

app = Flask(__name__)
CORS(app)

# ==============================================================================
# KONFIGURASI GLOBAL & API — Dibaca dari .env, TIDAK hardcoded
# ==============================================================================
MQTT_BROKER = os.getenv("MQTT_BROKER", "broker.emqx.io")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
TOPIC_SENSOR = "visio/bioflok/sensor"
TOPIC_KONTROL = "visio/bioflok/kontrol"

# --- KONFIGURASI ROBOFLOW ---
_roboflow_api_key = os.getenv("ROBOFLOW_API_KEY", "")
_roboflow_api_url = os.getenv("ROBOFLOW_API_URL", "https://serverless.roboflow.com")
WORKSPACE_NAME  = os.getenv("ROBOFLOW_WORKSPACE", "")
WORKFLOW_ID     = os.getenv("ROBOFLOW_WORKFLOW_ID", "")
CLASS_IKAN_KENYANG = "ikan kenyang"

ROBOFLOW_CLIENT = InferenceHTTPClient(
    api_url=_roboflow_api_url,
    api_key=_roboflow_api_key,
)

# --- KONFIGURASI SUPABASE ---
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# ==============================================================================
# STATE MESIN & LOCK (Fix #3 — Thread Safety)
# ==============================================================================
_state_lock = threading.Lock()

status_servo_aktif    = False
menit_jadwal_terakhir = -1
daftar_jadwal         = []
data_sensor_terakhir  = {"jarak_cm": 20.0, "ph_level": 7.0}
waktu_sensor_terakhir = None
id_sesi_sekarang      = None
status_ai_terakhir    = "STANDBY"
id_foto_terakhir      = None
id_kolam_cache        = None  # Fix #6 — cache id_kolam
url_foto_dummy        = "https://dummyimage.com/600x400/0D151B/009E83.png&text=V.I.S.I.O.N"


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================
def _is_iot_online() -> bool:
    """Fix #5 — satu fungsi terpusat untuk cek status IoT."""
    with _state_lock:
        ts = waktu_sensor_terakhir
    if ts is None:
        return False
    return (datetime.now() - ts).total_seconds() < 30


def hitung_persentase_pakan(jarak_cm: float) -> int:
    tinggi_wadah_maks = 20.0
    if jarak_cm >= tinggi_wadah_maks:
        return 0
    elif jarak_cm <= 2.0:
        return 100
    return int(((tinggi_wadah_maks - jarak_cm) / (tinggi_wadah_maks - 2.0)) * 100)


def _dapatkan_id_kolam() -> int:
    """Fix #6 — kembalikan id_kolam dari cache; query DB hanya jika belum ada."""
    global id_kolam_cache
    if id_kolam_cache is not None:
        return id_kolam_cache
    try:
        res = supabase.table("kolam").select("id_kolam").limit(1).execute()
        if res.data:
            id_kolam_cache = res.data[0]["id_kolam"]
            return id_kolam_cache
    except Exception as e:
        print(f"❌ [SUPABASE] Gagal mendapatkan id_kolam: {e}")
    id_kolam_cache = 1  # fallback
    return id_kolam_cache


def _bersihkan_file_temp_lama():
    """Fix #2 — hapus file temp yang tersisa dari session sebelumnya."""
    for f in glob.glob("temp_*.jpg"):
        try:
            os.remove(f)
            print(f"🧹 [CLEANUP] File temp lama dihapus: {f}")
        except OSError:
            pass


def _parse_hasil_workflow(result: list) -> str:
    """
    Parse hasil run_workflow() Roboflow untuk workflow Gemini-powered.

    Workflow ini menggunakan Google Gemini untuk keputusan akhir,
    bukan langsung dari model klasifikasi CNN.

    Urutan prioritas output:
    1. 'feeding_status' — keputusan akhir dari Gemini (final_feeding_status)
       Nilai: "Kenyang" | "Belum Kenyang" | "Tidak Valid"
    2. 'centroid_feeding_analysis' — raw output Gemini centroid
       Nilai: "Kenyang" | "Belum Kenyang"
    3. 'classification_predictions' — fallback dari model CNN (ai-lele/6)
       Nilai: list of dicts dengan key 'top'
    4. Fallback ke 'Tidak Terdeteksi'
    """
    if not isinstance(result, list) or len(result) == 0:
        return "Tidak Terdeteksi"

    first_result = result[0]

    # --- DEBUG: Tampilkan raw output untuk diagnosa ---
    print(f"🔍 [DEBUG] Keys dalam result         : {list(first_result.keys())}")
    print(f"🔍 [DEBUG] feeding_status            : {first_result.get('feeding_status')}")
    print(f"🔍 [DEBUG] pond_precheck             : {first_result.get('pond_precheck')}")
    print(f"🔍 [DEBUG] centroid_feeding_analysis : {first_result.get('centroid_feeding_analysis')}")
    print(f"🔍 [DEBUG] classification_predictions: {first_result.get('classification_predictions')}")

    # --- Prioritas 1: 'feeding_status' (keputusan akhir Gemini) ---
    # Output: "Kenyang" | "Belum Kenyang" | "Tidak Valid"
    feeding_status = first_result.get("feeding_status", "")
    if feeding_status and str(feeding_status).strip():
        hasil = str(feeding_status).strip()
        print(f"✅ [PARSE] Hasil dari 'feeding_status' (Gemini): {hasil}")
        return hasil

    # --- Prioritas 2: 'centroid_feeding_analysis' (raw Gemini centroid) ---
    centroid = first_result.get("centroid_feeding_analysis", "")
    if centroid and str(centroid).strip():
        hasil = str(centroid).strip()
        print(f"✅ [PARSE] Hasil dari 'centroid_feeding_analysis' (Gemini): {hasil}")
        return hasil

    # --- Prioritas 3: 'classification_predictions' (fallback CNN model) ---
    clf = first_result.get("classification_predictions")
    if clf:
        if isinstance(clf, list) and len(clf) > 0:
            kelas = clf[0].get("top", "").strip()
            if kelas:
                print(f"✅ [PARSE] Hasil dari 'classification_predictions' (list): {kelas}")
                return kelas
        elif isinstance(clf, dict):
            kelas = clf.get("top", "").strip()
            if kelas:
                print(f"✅ [PARSE] Hasil dari 'classification_predictions' (dict): {kelas}")
                return kelas

    print("⚠️ [PARSE] Tidak ada prediksi valid ditemukan, fallback ke 'Tidak Terdeteksi'")
    return "Tidak Terdeteksi"


# ==============================================================================
# KONTROL MQTT & SENSOR
# ==============================================================================
def on_connect(client, userdata, flags, rc):
    print(f"MQTT Terhubung! (Code: {rc})")
    client.subscribe(TOPIC_SENSOR)


def on_message(client, userdata, msg):
    # Fix #4 — tidak lagi silent pass, error di-log
    global data_sensor_terakhir, waktu_sensor_terakhir
    try:
        if msg.topic == TOPIC_SENSOR:
            payload = json.loads(msg.payload.decode("utf-8"))
            with _state_lock:
                data_sensor_terakhir["jarak_cm"] = payload.get("jarak_cm", 20.0)
                data_sensor_terakhir["ph_level"]  = payload.get("ph_level",  7.0)
                waktu_sensor_terakhir = datetime.now()
    except Exception as e:
        print(f"⚠️ [MQTT] Gagal memproses pesan sensor: {e}")


mqtt_client = mqtt.Client()
mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message
mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
mqtt_client.loop_start()


# ==============================================================================
# FUNGSI PICU PAKAN (MEMULAI / MENGHENTIKAN SESI)
# ==============================================================================
def mulai_pakan():
    global status_servo_aktif, id_sesi_sekarang, status_ai_terakhir, id_foto_terakhir
    id_kolam = _dapatkan_id_kolam()

    with _state_lock:
        status_servo_aktif = True
        id_sesi_sekarang   = str(uuid.uuid4())
        status_ai_terakhir = "IKAN LAPAR (PROSES)"
        id_foto_terakhir   = None
        sesi_id_copy       = id_sesi_sekarang

    # Fix #8b — sertakan id_kolam saat INSERT sesi_pakan
    try:
        supabase.table("sesi_pakan").insert({
            "id_sesi":  sesi_id_copy,
            "id_kolam": id_kolam,
        }).execute()
        print(f"✅ [SUPABASE] Sesi Pakan dibuat: {sesi_id_copy}")
    except Exception as e:
        print(f"❌ [SUPABASE] Gagal membuat Sesi Pakan: {e}")

    mqtt_client.publish(TOPIC_KONTROL, '{"perintah_servo": "buka"}')
    print(f">> PAKAN DIMULAI | ID Sesi: {sesi_id_copy}")


def hentikan_pakan():
    global status_servo_aktif, id_sesi_sekarang, status_ai_terakhir

    with _state_lock:
        id_sesi_yang_berhenti = id_sesi_sekarang
        status_servo_aktif    = False
        id_sesi_sekarang      = None
        status_ai_terakhir    = "STANDBY"

    mqtt_client.publish(TOPIC_KONTROL, '{"perintah_servo": "tutup"}')

    if id_sesi_yang_berhenti:
        try:
            supabase.table("sesi_pakan").update({
                "waktu_selesai": datetime.now().isoformat()
            }).eq("id_sesi", id_sesi_yang_berhenti).execute()
            print(f"✅ [SUPABASE] waktu_selesai dicatat: {id_sesi_yang_berhenti}")
        except Exception as e:
            print(f"❌ [SUPABASE] Gagal mencatat waktu_selesai: {e}")

    print(">> PAKAN DIHENTIKAN")


# ==============================================================================
# SCHEDULER JOBS
# ==============================================================================
def cek_dan_eksekusi_jadwal():
    global menit_jadwal_terakhir
    sekarang = datetime.now()
    with _state_lock:
        jadwal_copy = list(daftar_jadwal)

    ada_jadwal = any(
        j["jam"] == sekarang.hour and j["menit"] == sekarang.minute
        for j in jadwal_copy
    )

    if ada_jadwal:
        if menit_jadwal_terakhir != sekarang.minute:
            menit_jadwal_terakhir = sekarang.minute
            mulai_pakan()
    else:
        menit_jadwal_terakhir = -1


def simpan_riwayat_ph_ke_supabase():
    if not _is_iot_online():
        print("⚠️ [SUPABASE] Batal menyimpan riwayat pH — sensor IoT offline.")
        return

    id_kolam = _dapatkan_id_kolam()
    with _state_lock:
        ph = round(data_sensor_terakhir["ph_level"], 2)

    try:
        supabase.table("riwayat_ph").insert({
            "id_kolam":    id_kolam,
            "ph_level":    ph,
            "waktu_rekam": datetime.now().isoformat(),
        }).execute()
        print(f"✅ [SUPABASE] Riwayat pH berkala disimpan: {ph} (Kolam ID: {id_kolam})")
    except Exception as e:
        print(f"❌ [SUPABASE] Gagal menyimpan riwayat pH: {e}")


def muat_jadwal_dari_supabase():
    """Fix #7 — dipanggil saat startup DAN secara berkala tiap 5 menit."""
    global daftar_jadwal
    try:
        response = supabase.table("jadwal_pakan").select("id, jam, menit").execute()
        jadwal_baru = sorted(response.data, key=lambda x: (x["jam"], x["menit"]))
        with _state_lock:
            daftar_jadwal = jadwal_baru
        print(f"✅ [SUPABASE] {len(daftar_jadwal)} jadwal pakan dimuat/diperbarui.")
    except Exception as e:
        print(f"❌ [SUPABASE] Gagal memuat jadwal: {e}")


# ==============================================================================
# INISIALISASI SCHEDULER
# ==============================================================================
_bersihkan_file_temp_lama()  # Fix #2 — bersihkan sisa file lama saat startup
_dapatkan_id_kolam()          # Fix #6 — pre-cache id_kolam
muat_jadwal_dari_supabase()   # Fix #7 — muat jadwal awal

scheduler = BackgroundScheduler()
scheduler.add_job(func=cek_dan_eksekusi_jadwal,       trigger="interval", seconds=10)
scheduler.add_job(func=simpan_riwayat_ph_ke_supabase, trigger="interval", minutes=30)
scheduler.add_job(func=muat_jadwal_dari_supabase,      trigger="interval", minutes=5)  # Fix #7
scheduler.start()


# ==============================================================================
# API ENDPOINTS
# ==============================================================================
@app.route("/api/status", methods=["GET"])
def get_status():
    with _state_lock:
        sensor_copy = dict(data_sensor_terakhir)
        servo_aktif = status_servo_aktif
        ai_status   = status_ai_terakhir
        id_sesi     = id_sesi_sekarang
        id_foto     = id_foto_terakhir
        jadwal_copy = list(daftar_jadwal)

    online   = _is_iot_online()
    ph       = round(sensor_copy["ph_level"], 2)
    kualitas = "Peringatan Anomali" if ph < 6.5 or ph > 8.5 else "Optimal"

    return jsonify({
        "tingkat_ph":         ph if online else None,
        "kualitas_air":       kualitas if online else "Offline",
        "is_iot_aktif":       online,
        "persen_sisa_pakan":  hitung_persentase_pakan(sensor_copy["jarak_cm"]) if online else 0,
        "status_servo_aktif": servo_aktif,
        "status_ai_terakhir": ai_status,
        "id_sesi_aktif":      id_sesi,
        "id_foto_terakhir":   id_foto,
        "daftar_jadwal":      jadwal_copy,
    })


@app.route("/api/kontrol", methods=["POST"])
def kontrol_manual():
    aksi = request.json.get("aksi")

    with _state_lock:
        servo_aktif   = status_servo_aktif
        sesi_sekarang = id_sesi_sekarang

    if aksi == "feed" and not servo_aktif:
        mulai_pakan()
        return jsonify({"status": "sukses"})

    elif aksi == "stop" and servo_aktif:
        if sesi_sekarang:
            try:
                supabase.table("log_visual_ai").insert({
                    "id_foto":     str(uuid.uuid4()),
                    "id_sesi":     sesi_sekarang,
                    "url_foto":    url_foto_dummy,
                    "status_ikan": "DIHENTIKAN MANUAL",
                }).execute()
                print("✅ [DATABASE] Log Override Manual tersimpan!")
            except Exception as e:
                print(f"❌ [DATABASE] Error menyimpan log override: {e}")

        hentikan_pakan()
        return jsonify({"status": "sukses"})

    return jsonify({"status": "diabaikan"})


@app.route("/api/prediksi-kamera", methods=["POST"])
def prediksi_kamera():
    global status_ai_terakhir, id_foto_terakhir

    with _state_lock:
        servo_aktif = status_servo_aktif

    if not servo_aktif:
        return jsonify({"status": "diabaikan", "pesan": "Kamera standby"})

    if "image" in request.files:
        image_bytes = request.files["image"].read()
    else:
        image_bytes = request.data

    if not image_bytes:
        return jsonify({"error": "Tidak ada gambar"}), 400

    # Fix #2 — gunakan tempfile agar otomatis terhapus
    tmp = tempfile.NamedTemporaryFile(suffix=".jpg", delete=False)
    temp_filename = tmp.name
    hasil_prediksi_ai = "Tidak Terdeteksi"

    try:
        tmp.write(image_bytes)
        tmp.close()

        # Jalankan Workflow Roboflow
        # Fix: use_cache=False agar setiap gambar diproses ulang, tidak pakai cache
        result = ROBOFLOW_CLIENT.run_workflow(
            workspace_name=WORKSPACE_NAME,
            workflow_id=WORKFLOW_ID,
            images={"image": temp_filename},
            use_cache=False,
        )

        # Fix: parsing hasil workflow secara robust via fungsi terpisah
        hasil_prediksi_ai = _parse_hasil_workflow(result)

    except Exception as e:
        pesan_error = str(e)
        print(f"❌ [ERROR ROBOFLOW]: {pesan_error}")

        # Tangani kasus tidak ada ikan terdeteksi (dynamic_crop gagal)
        if "dynamic_crop" in pesan_error.lower():
            print(">> INFO: Roboflow gagal crop (tidak ada ikan terlihat).")
            return jsonify({
                "status":            "sukses",
                "status_ikan":       "Tidak Terdeteksi",
                "servo_dimatikan_ai": False,
            })

        return jsonify({"error": pesan_error}), 500

    finally:
        # Fix #2 — pastikan file temp selalu terhapus
        if os.path.exists(temp_filename):
            os.remove(temp_filename)

    with _state_lock:
        status_ai_terakhir  = hasil_prediksi_ai
        sesi_aktif_saat_ini = id_sesi_sekarang

    print(f"✅ [AI VISION] Mendeteksi: {hasil_prediksi_ai}")

    hasil_teks   = str(hasil_prediksi_ai).lower()
    dimatikan_ai = False
    url_foto_final = url_foto_dummy

    if "kenyang" in hasil_teks and "belum" not in hasil_teks:
        print(">> MENGUNGGAH FOTO BUKTI AI KE SUPABASE STORAGE...")
        try:
            nama_file_storage = f"bukti_kenyang_{uuid.uuid4().hex}.jpg"
            supabase.storage.from_("foto-ai").upload(
                file=image_bytes,
                path=nama_file_storage,
                file_options={"content-type": "image/jpeg"},
            )
            url_foto_final = supabase.storage.from_("foto-ai").get_public_url(nama_file_storage)
            print(f"✅ [STORAGE] Foto diunggah: {url_foto_final}")
        except Exception as e:
            print(f"❌ [STORAGE] Gagal mengunggah foto: {e}")

        hentikan_pakan()
        dimatikan_ai = True

    if sesi_aktif_saat_ini:
        id_foto_baru = str(uuid.uuid4())
        with _state_lock:
            id_foto_terakhir = id_foto_baru
        try:
            supabase.table("log_visual_ai").insert({
                "id_foto":     id_foto_baru,
                "id_sesi":     sesi_aktif_saat_ini,
                "url_foto":    url_foto_final,
                "status_ikan": str(hasil_prediksi_ai),
            }).execute()
            print(f"✅ [DATABASE] Log tersimpan: {url_foto_final}")
        except Exception as e:
            print(f"❌ [DATABASE] Error menyimpan log: {e}")

    return jsonify({
        "status":            "sukses",
        "status_ikan":       hasil_prediksi_ai,
        "servo_dimatikan_ai": dimatikan_ai,
    })


@app.route("/api/jadwal", methods=["GET", "POST", "DELETE"])
def kelola_jadwal():
    global daftar_jadwal

    if request.method == "GET":
        with _state_lock:
            return jsonify(list(daftar_jadwal))

    elif request.method == "POST":
        data  = request.json
        jam   = data.get("jam")
        menit = data.get("menit")

        if jam is None or menit is None:
            return jsonify({"error": "Format tidak valid"}), 400

        with _state_lock:
            exists = any(j["jam"] == jam and j["menit"] == menit for j in daftar_jadwal)
        if exists:
            return jsonify({"error": "Jadwal pada waktu tersebut sudah ada"}), 409

        try:
            response    = supabase.table("jadwal_pakan").insert({"jam": jam, "menit": menit}).execute()
            jadwal_baru = response.data[0]
            with _state_lock:
                daftar_jadwal.append(jadwal_baru)
                daftar_jadwal = sorted(daftar_jadwal, key=lambda x: (x["jam"], x["menit"]))
            print(f"✅ [DATABASE] Jadwal baru: {jam:02d}:{menit:02d}")
            return jsonify({"status": "sukses", "data": jadwal_baru}), 201
        except Exception as e:
            print(f"❌ [DATABASE] Error Insert Jadwal: {e}")
            return jsonify({"error": "Gagal menyimpan jadwal"}), 500

    elif request.method == "DELETE":
        ids_hapus = request.args.get("ids")
        id_hapus  = request.args.get("id", type=int)

        try:
            if ids_hapus:
                list_ids = [int(i) for i in ids_hapus.split(",") if i.strip()]
                if not list_ids:
                    return jsonify({"error": "ID tidak valid"}), 400
                supabase.table("jadwal_pakan").delete().in_("id", list_ids).execute()
                with _state_lock:
                    daftar_jadwal[:] = [j for j in daftar_jadwal if j.get("id") not in list_ids]
                print(f"🗑️ [DATABASE] {len(list_ids)} jadwal dihapus massal.")
                return jsonify({"status": "sukses"})

            elif id_hapus is not None:
                supabase.table("jadwal_pakan").delete().eq("id", id_hapus).execute()
                with _state_lock:
                    daftar_jadwal[:] = [j for j in daftar_jadwal if j.get("id") != id_hapus]
                print(f"🗑️ [DATABASE] Jadwal ID {id_hapus} dihapus.")
                return jsonify({"status": "sukses"})

            else:
                return jsonify({"error": "ID tidak ditemukan"}), 400

        except Exception as e:
            print(f"❌ [DATABASE] Error Delete Jadwal: {e}")
            return jsonify({"error": "Gagal menghapus jadwal"}), 500


# ==============================================================================
# MAIN
# ==============================================================================
if __name__ == "__main__":
    try:
        print("Memulai V.I.S.I.O.N Backend Server...")
        app.run(host="0.0.0.0", port=5001, debug=False, use_reloader=False)
    except (KeyboardInterrupt, SystemExit):
        scheduler.shutdown()
        mqtt_client.loop_stop()
        mqtt_client.disconnect()
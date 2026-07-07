# firebase_logger.py
# Pi-side Firebase logger for AI-Powered Cat Feeder System

import firebase_admin
from firebase_admin import credentials, firestore, storage
from datetime import datetime
import subprocess
import urllib.request

# ── Initialize Firebase ───────────────────────────────────────────────────────
cred = credentials.Certificate('/home/raspberry/cat_feeder/config/serviceAccountKey.json')
firebase_admin.initialize_app(cred, {
    'storageBucket': 'cat-feeder-hjh.firebasestorage.app'
})
db = firestore.client()


# ── Log feeding event ─────────────────────────────────────────────────────────
def log_feeding(cat_id, cat_name, authorized, confidence, portion_g, reason=''):
    now    = datetime.now()
    doc_id = 'feeding_' + now.strftime('%Y%m%d_%H%M%S')

    db.collection('feedings').document(doc_id).set({
        'cat_id':     cat_id,
        'cat_name':   cat_name,
        'timestamp':  now.isoformat(),
        'authorized': authorized,
        'confidence': round(confidence, 4),
        'portion_g':  portion_g,
        'reason':     reason,
    })
    print(f"Firebase: feeding logged → {doc_id} | {cat_name} | authorized={authorized}")

    # Update cat profile stats if authorized
    if authorized:
        ref = db.collection('cats').document(cat_id)
        doc = ref.get()
        if doc.exists:
            current = doc.to_dict().get('total_feedings', 0)
            ref.update({
                'total_feedings': current + 1,
                'last_seen':      now.isoformat(),
            })
            print(f"Firebase: {cat_name} total feedings = {current + 1}")


# ── Update system status ──────────────────────────────────────────────────────
# FIXED: now writes per-cat documents (system_status/{cat_id}) so the
# app's per-cat status screen and cloud.py's per-cat reads both work
# correctly. Previously wrote to one single 'system_status/status' document
# which cloud.py could never read (it reads by cat_id, not 'status').
def update_system_status(food_pct, water_pct, pi_online=True):
    now = datetime.now().isoformat()

    # Get all registered cat IDs and write the same levels for each
    # (the feeder hardware is shared, so all cats see the same food/water %)
    try:
        cats = db.collection('cats').stream()
        cat_ids = [c.id for c in cats]
    except Exception as e:
        print(f"Firebase: could not get cats for status update: {e}")
        cat_ids = []

    for cat_id in cat_ids:
        db.collection('system_status').document(cat_id).set({
            'food_level_pct':  food_pct,
            'water_level_pct': water_pct,
            'pi_online':       pi_online,
            'last_updated':    now,
        }, merge=True)

    print(f"Firebase: status updated for {len(cat_ids)} cat(s) — "
          f"food={food_pct}% water={water_pct}%")


# ── Check for commands from app ───────────────────────────────────────────────
def check_for_commands():
    commands = db.collection('commands')\
                 .where(filter=firestore.FieldFilter('status', '==', 'pending'))\
                 .stream()
    for cmd in commands:
        data = cmd.to_dict()
        print(f"Firebase: command received: {data.get('type')}")
        db.collection('commands').document(cmd.id).update({'status': 'done'})
        return data
    return None


# ── Get cat settings from Firestore ──────────────────────────────────────────
def get_cat_settings(cat_id):
    doc = db.collection('cats').document(cat_id).get()
    if doc.exists:
        return doc.to_dict()
    return None


# ── Get voice URL for a cat (uploaded by app) ─────────────────────────────────
def get_voice_url(cat_id):
    doc = db.collection('cats').document(cat_id).get()
    if doc.exists:
        return doc.to_dict().get('voice_url')
    return None


# ── Download and play voice for a cat ────────────────────────────────────────
def play_cat_voice(cat_id):
    url = get_voice_url(cat_id)
    if not url:
        print(f"Firebase: no voice found for {cat_id} — skipping")
        return

    local_path = f"/tmp/{cat_id}_voice.wav"
    print(f"Firebase: downloading voice for {cat_id}...")
    urllib.request.urlretrieve(url, local_path)
    subprocess.Popen(['aplay', '-D', 'plughw:1,0', local_path])
    print(f"Firebase: playing voice for {cat_id}")

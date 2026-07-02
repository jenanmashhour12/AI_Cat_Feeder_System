# dfplayer.py
# DFPlayer Mini controller
# Plays voice repeatedly with 4 second delay between plays
# Stops when stop_voice() is called

import serial
import time
import threading

SERIAL_PORT = '/dev/ttyS0'
BAUD_RATE   = 9600

# Cat ID to SD card track mapping
# SD card must have:
#   mp3/0001.mp3 → nana voice (cat_001)
#   mp3/0002.mp3 → luna voice (cat_002)
CAT_TRACK = {
    'cat_001': 1,
    'cat_002': 2,
}

# Global stop event to control the loop
_stop_event = threading.Event()


def _send_cmd(ser, cmd, param1=0, param2=0):
    """Send a command to the DFPlayer"""
    buf = bytes([
        0x7E,    # start byte
        0xFF,    # version
        0x06,    # length
        cmd,     # command
        0x00,    # feedback off
        param1,  # param high byte
        param2,  # param low byte
        0xEF     # end byte
    ])
    ser.write(buf)
    time.sleep(0.1)


def _play_track(track):
    """Send play command to DFPlayer for a specific track"""
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        time.sleep(0.3)
        _send_cmd(ser, 0x06, 0, 30)    # set volume to max (30)
        time.sleep(0.2)
        _send_cmd(ser, 0x12, 0, track) # play track from mp3 folder
        ser.close()
        print(f"DFPlayer: playing track {track}")
    except Exception as e:
        print(f"DFPlayer play error: {e}")


def _stop_playback():
    """Send stop command to DFPlayer"""
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        time.sleep(0.3)
        _send_cmd(ser, 0x16, 0, 0)  # stop command
        ser.close()
        print("DFPlayer: playback stopped")
    except Exception as e:
        print(f"DFPlayer stop error: {e}")


def _loop(track):
    """
    Loop logic:
    1. Play track
    2. Wait for track to finish (~3 seconds)
    3. Wait 4 seconds delay
    4. Repeat until stop_voice() is called
    """
    while not _stop_event.is_set():
        _play_track(track)
        # Wait 7 seconds total (3s track + 4s delay)
        # Check stop event every 0.1s so we can stop quickly
        for _ in range(50):
            if _stop_event.is_set():
                break
            time.sleep(0.1)


def play_voice(cat_id):
    """
    Start playing voice for a cat in a background thread.
    Loops repeatedly with 4 second delay between plays.
    Call stop_voice() to stop.
    """
    track = CAT_TRACK.get(cat_id)
    if not track:
        print(f"DFPlayer: no track mapped for {cat_id} — skipping")
        return

    _stop_event.clear()
    t = threading.Thread(target=_loop, args=(track,), daemon=True)
    t.start()
    print(f"DFPlayer: started looping voice for {cat_id}")


def stop_voice():
    """Stop the voice loop and DFPlayer playback"""
    _stop_event.set()
    time.sleep(0.3)
    _stop_playback()

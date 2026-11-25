"""Compresses your soundtracks and locks them for the game.

    py -3.12 tools/make_music.py

For every track in TRACKS below (your originals live in art_source/music/, which Godot and git ignore):
  1. ffmpeg -> mono, 22 kHz OGG Vorbis at quality 0 (~30 kbps), loudness-matched so the tracks play at the
     same level: a 26 MB WAV becomes ~0.5 MB.
  2. Encrypts it into assets/audio/music/<key>.dat (tools/encrypt_music.gd). The game decrypts it in
     memory, so there's no playable audio file in the game's files to copy out.
assets/audio/music/ is gitignored: the music is never in the public GitHub repo, only inside the game.
Change a track: put the new file in art_source/music/, edit TRACKS, run this again.
"""
import os
import shutil
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art_source", "music")
OUT = os.path.join(ROOT, "assets", "audio", "music")
GODOT = os.environ.get("GODOT", r"E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
FFMPEG = os.environ.get("FFMPEG") or shutil.which("ffmpeg") or \
    r"D:\streamlabs\resources\app.asar.unpacked\node_modules\obs-studio-node\ffmpeg.exe"
QUALITY = "0"      # Vorbis quality: 0 = ~30 kbps mono (tiny); 2 = ~45 kbps (a bit clearer)
RATE = "22050"
LOUDNESS = "-16"   # LUFS every track is matched to

# key (Config.MUSIC_TRACKS "file") -> your original file in art_source/music/
TRACKS = {
    "rocks": "Gambler Symphony.mp3",           # the rock-breaking screen
    "mine": "MeltdownTheme.wav",               # the mining wall
    "shop": "Shop Theme - Thameuszin.wav",     # while the Shop is open
}


def main():
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="rfr_music_")
    try:
        for key, name in TRACKS.items():
            src = os.path.join(SRC, name)
            ogg = os.path.join(tmp, key + ".ogg")
            subprocess.run([FFMPEG, "-y", "-hide_banner", "-loglevel", "error", "-i", src, "-vn",
                            "-af", "loudnorm=I=%s:TP=-1.5:LRA=11" % LOUDNESS,
                            "-ac", "1", "-ar", RATE, "-c:a", "libvorbis", "-q:a", QUALITY,
                            "-map_metadata", "-1", ogg], check=True)
            dat = os.path.join(OUT, key + ".dat")
            subprocess.run([GODOT, "--headless", "--path", ROOT, "--script", "res://tools/encrypt_music.gd",
                            "--", ogg, dat], check=True, capture_output=True)
            print("%-6s %-32s %6.1f MB -> %5.0f KB" % (key, name, os.path.getsize(src) / 1e6, os.path.getsize(dat) / 1024))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()

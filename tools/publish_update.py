"""Publishes an update: players' games download it the next time they start (see scripts/updater.gd).

    py -3.12 tools/publish_update.py 0.5 "What changed"
    py -3.12 tools/publish_update.py --attach-full                 (adds the full download to the current release)

Versions: Indev 0.1 is the first release. Releases are titled "Geode Galore Indev <version>"
(GameVersion.STAGE). (Ported from Seed Splicer's publish script.)

1. Sets GameVersion.VERSION (scripts/game_version.gd) to the new version.
2. Exports the game pack: build/RichFromRocks-update-<version>.pck + its SHA-256 (.pck.sha256). Then
   SELF-TESTS the pack with the real release engine: nothing is published unless the game starts and
   builds its whole screen.
3. Commits everything, tags it v<version> and pushes to GitHub.
4. Creates the GitHub Release v<version> on GameVersion.RELEASES_REPO (a PUBLIC repo) with the pack
   and its hash. Games older than <version> download it, check the hash and restart into it.
Every release also gets the complete game for new players: GeodeGalore-Windows.zip (a "Geode Galore"
folder with GeodeGalore.exe + GeodeGalore.pck). It always has the same name, so the README's link
https://github.com/<repo>/releases/latest/download/GeodeGalore-Windows.zip always gives the newest version.
(The game finds its pack by its own exe name, and old installs keep RichFromRocks.exe: both update fine.)

Needs: git, the GitHub CLI (gh, logged in), Godot 4.7.2 + its export templates (set GODOT to its exe
if it isn't the Steam one). Only the pack goes over the air: a new Godot version needs a --full release.
"""
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
VERSION_FILE = os.path.join(ROOT, "scripts", "game_version.gd")
BUILD = os.path.join(ROOT, "build")
GODOT = os.environ.get("GODOT", r"E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
TEMPLATE = os.path.join(os.path.dirname(GODOT), "editor_data", "export_templates", "4.7.2.stable", "windows_release_x86_64.exe")
# New downloads (from 0.2) ship the slim engine (tools/engine: no 3D, physics...: ~30 MB instead of 109 MB).
# Players who installed 0.1 run the official engine. Updates are only the pack, so they must work on BOTH.
SLIM_TEMPLATE = os.path.join(ROOT, "tools", "engine", "bin", "richfromrocks_template_release.x86_64.exe")
PRESET = "Windows"
NAME = "RichFromRocks"
GH = shutil.which("gh") or r"C:\Program Files\GitHub CLI\gh.exe"
FULL_ZIP = "GeodeGalore-Windows.zip"   # the download for new players (same name every release)
FULL_DIR = "Geode Galore"              # the folder inside it
FULL_EXE = "GeodeGalore"               # GeodeGalore.exe + GeodeGalore.pck
SELFTEST_CODE = 42  # main.gd quits with this under --selftest once its whole screen is built


def stage():
    m = re.search(r'const STAGE := "([^"]+)"', open(VERSION_FILE, encoding="utf-8").read())
    return m.group(1) if m else ""


def run(*cmd, **kw):
    print("> " + " ".join(cmd))
    subprocess.run(cmd, check=True, cwd=ROOT, **kw)


def tag_exists(tag):
    r = subprocess.run(["git", "ls-remote", "--tags", "origin", tag], capture_output=True, text=True, cwd=ROOT)
    local = subprocess.run(["git", "tag", "-l", tag], capture_output=True, text=True, cwd=ROOT)
    return bool(r.stdout.strip()) or bool(local.stdout.strip())


def smoke_test(pack):
    """Runs the pack on every engine players have: the official one (0.1 installs) and the slim one."""
    for name, template in (("official", TEMPLATE), ("slim", SLIM_TEMPLATE)):
        smoke_test_on(pack, name, template)


def smoke_test_on(pack, name, template):
    """Plays the update exactly like a player's PC will: a copy of the release engine named
    RichFromRocks.exe, this pack next to it, a throwaway user folder, and `--selftest`. Anything but
    exit code 42 (or any script error) stops the publish: a broken update would reach every player."""
    if not os.path.exists(template):
        raise SystemExit("Can't test the build: no %s release template at %s" % (name, template))
    tmp = tempfile.mkdtemp(prefix="richfromrocks_smoke_")
    try:
        game = os.path.join(tmp, "game")
        os.makedirs(game)
        exe = os.path.join(game, NAME + ".exe")
        shutil.copy(template, exe)
        shutil.copy(pack, os.path.join(game, NAME + ".pck"))
        env = dict(os.environ, APPDATA=os.path.join(tmp, "appdata"))
        r = subprocess.run([exe, "--headless", "--quit-after", "6000", "--", "--selftest", "--no-update"],
                           capture_output=True, text=True, env=env, timeout=180)
        out = (r.stdout or "") + (r.stderr or "")
        bad = [l for l in out.splitlines() if "SCRIPT ERROR" in l or "Parse Error" in l or "Failed to load" in l
               or "Failed to instantiate" in l or "Aborting" in l]
        if bad or r.returncode != SELFTEST_CODE:
            raise SystemExit("THE BUILD IS BROKEN on the %s engine, nothing was published (self-test exit code %d):\n  %s\n%s" % (
                name, r.returncode, "\n  ".join(bad[:10]), out[-1500:]))
        print("Smoke test passed on the %s engine: the exported game starts and builds its whole screen." % name)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def build_full():
    """Exports the whole game and zips it as FULL_ZIP, then self-tests the unzipped copy."""
    exe = os.path.join(BUILD, "windows", NAME + ".exe")
    os.makedirs(os.path.dirname(exe), exist_ok=True)
    run(GODOT, "--headless", "--path", ROOT, "--export-release", PRESET, exe)
    bundle = os.path.join(BUILD, FULL_ZIP)
    with zipfile.ZipFile(bundle, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for ext in (".exe", ".pck"):
            z.write(os.path.join(os.path.dirname(exe), NAME + ext), FULL_DIR + "/" + FULL_EXE + ext)
    tmp = tempfile.mkdtemp(prefix="geodegalore_full_")
    try:  # play the download exactly like a new player: unzip it and start it
        with zipfile.ZipFile(bundle) as z:
            z.extractall(tmp)
        game = os.path.join(tmp, FULL_DIR, FULL_EXE + ".exe")
        env = dict(os.environ, APPDATA=os.path.join(tmp, "appdata"))
        r = subprocess.run([game, "--headless", "--quit-after", "6000", "--", "--selftest", "--no-update"],
                           capture_output=True, text=True, env=env, timeout=180)
        if r.returncode != SELFTEST_CODE:
            raise SystemExit("THE FULL DOWNLOAD IS BROKEN (self-test exit code %d), nothing was uploaded:\n%s"
                             % (r.returncode, ((r.stdout or "") + (r.stderr or ""))[-1500:]))
        print("Smoke test passed on the full download: unzipped, it starts and builds its whole screen.")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return bundle


def build_and_test(version, full=True):
    os.makedirs(BUILD, exist_ok=True)
    pack = os.path.join(BUILD, "%s-update-%s.pck" % (NAME, version))
    run(GODOT, "--headless", "--path", ROOT, "--export-pack", PRESET, pack)
    digest = hashlib.sha256(open(pack, "rb").read()).hexdigest()
    sha_file = pack + ".sha256"
    open(sha_file, "w", newline="\n").write("%s  %s\n" % (digest, os.path.basename(pack)))
    smoke_test(pack)
    assets = [pack, sha_file]
    if full:
        assets.append(build_full())
    return assets


def publish(version, notes, repo, assets):
    run("git", "add", "-A")
    run("git", "commit", "-m", "Release %s %s (v%s)" % (stage(), version, version) + ("\n\n" + notes if notes else "")
        + "\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>")
    run("git", "tag", "v%s" % version)
    run("git", "push", "origin", "HEAD", "--tags")
    run(GH, "release", "create", "v%s" % version, *assets, "--repo", repo,
        "--title", "Geode Galore %s %s" % (stage(), version), "--notes", notes or "Update %s %s" % (stage(), version))
    print("\nPublished %s %s to %s. Games older than it update the next time they start." % (stage(), version, repo))


def attach_full():
    """Builds the full download for the version that's already published and adds it to that release."""
    text = open(VERSION_FILE, encoding="utf-8").read()
    version = re.search(r'const VERSION := "([^"]+)"', text).group(1)
    repo = re.search(r'const RELEASES_REPO := "([^"]+)"', text).group(1)
    bundle = build_full()
    run(GH, "release", "upload", "v%s" % version, bundle, "--repo", repo, "--clobber")
    print("Added %s to v%s." % (FULL_ZIP, version))


def main():
    if "--attach-full" in sys.argv:
        return attach_full()
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    full = "--no-full" not in sys.argv  # every release gets the full download (--no-full skips it)
    if not args or not re.fullmatch(r"\d+(\.\d+){0,3}", args[0]):
        raise SystemExit(__doc__)
    version, notes = args[0], (args[1] if len(args) > 1 else "")
    text = open(VERSION_FILE, encoding="utf-8").read()
    old = re.search(r'const VERSION := "([^"]+)"', text).group(1)
    repo = re.search(r'const RELEASES_REPO := "([^"]+)"', text).group(1)
    first = version == old and not tag_exists("v" + version)  # the very first release of this version
    if not first and [int(x) for x in version.split(".")] <= [int(x) for x in old.split(".")]:
        raise SystemExit("%s isn't newer than the current version %s" % (version, old))
    old_text = text
    text = text.replace('const VERSION := "%s"' % old, 'const VERSION := "%s"' % version)
    open(VERSION_FILE, "w", encoding="utf-8", newline="\n").write(text)
    try:
        assets = build_and_test(version, full)
    except BaseException:
        open(VERSION_FILE, "w", encoding="utf-8", newline="\n").write(old_text)  # nothing published
        raise
    publish(version, notes, repo, assets)


if __name__ == "__main__":
    main()

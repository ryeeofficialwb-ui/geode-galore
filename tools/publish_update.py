"""Publishes an update: players' games download it the next time they start (see scripts/updater.gd).

    py -3.12 tools/publish_update.py 0.2 "What changed"
    py -3.12 tools/publish_update.py 0.2 "What changed" --full     (also a full Windows download)

Versions: Indev 0.1 is the first release. Releases are titled "Geode Galore Indev <version>"
(GameVersion.STAGE). (Ported from Seed Splicer's publish script.)

1. Sets GameVersion.VERSION (scripts/game_version.gd) to the new version.
2. Exports the game pack: build/RichFromRocks-update-<version>.pck + its SHA-256 (.pck.sha256). Then
   SELF-TESTS the pack with the real release engine: nothing is published unless the game starts and
   builds its whole screen.
3. Commits everything, tags it v<version> and pushes to GitHub.
4. Creates the GitHub Release v<version> on GameVersion.RELEASES_REPO (a PUBLIC repo) with the pack
   and its hash. Games older than <version> download it, check the hash and restart into it.
--full also exports RichFromRocks.exe and attaches build/RichFromRocks-<stage>-<version>-windows.zip:
the complete game for new players (needed for the first release; after that only when Godot changes).

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


def build_and_test(version, full):
    os.makedirs(BUILD, exist_ok=True)
    pack = os.path.join(BUILD, "%s-update-%s.pck" % (NAME, version))
    run(GODOT, "--headless", "--path", ROOT, "--export-pack", PRESET, pack)
    digest = hashlib.sha256(open(pack, "rb").read()).hexdigest()
    sha_file = pack + ".sha256"
    open(sha_file, "w", newline="\n").write("%s  %s\n" % (digest, os.path.basename(pack)))
    smoke_test(pack)
    assets = [pack, sha_file]
    if full:
        exe = os.path.join(BUILD, "windows", NAME + ".exe")
        os.makedirs(os.path.dirname(exe), exist_ok=True)
        run(GODOT, "--headless", "--path", ROOT, "--export-release", PRESET, exe)
        bundle = os.path.join(BUILD, "%s-%s-%s-windows.zip" % (NAME, stage(), version))
        with zipfile.ZipFile(bundle, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            for name in (NAME + ".exe", NAME + ".pck"):
                z.write(os.path.join(os.path.dirname(exe), name), NAME + "/" + name)
        assets.append(bundle)
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


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    full = "--full" in sys.argv
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

#!/usr/bin/env python3
"""Adds a release to the AltStore Classic source (altstore/source.json).

Reads the version, build number, bundle ID and permissions from the .ipa itself, so the
source always matches what AltStore will check when it installs the app.

    scripts/update-altstore-source.py --ipa dist/Splitter.ipa \
        --download-url https://github.com/OWNER/REPO/releases/download/TAG/Splitter.ipa \
        --repo OWNER/REPO [--notes "What's new"]

Spec: https://faq.altstore.io/developers/make-a-source
AltStore only looks at versions[0] to decide whether an update exists, so new versions go first.
"""
import argparse
import datetime
import json
import os
import plistlib
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "altstore", "source.json")

TINT = "#3373F5"  # Splitter accent blue
DESCRIPTION = (
    "A native speedrun timer for iPhone and iPad, built on livesplit-core.\n\n"
    "• Imports Splitter .split files, LiveSplit .lss and Splits.io .json\n"
    "• Big Start/Split button with haptics, plus Undo, Skip, Pause and Reset\n"
    "• Ahead/behind and gold-segment colours, comparisons, Real/Game time\n"
    "• Edit splits on the device; runs autosave as .lss in the Files app"
)


def read_ipa(path):
    """Returns (Info.plist dict, entitlements list) from an .ipa."""
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        plist_name = next(n for n in names if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", n))
        info = plistlib.loads(z.read(plist_name))
        # An unsigned IPA (what xtool's --ipa makes) has no embedded entitlements.
        # AltStore signs it with its own; only entitlements the app declares count here.
        entitlements = []
        ent_name = plist_name.replace("Info.plist", "archived-expanded-entitlements.xcent")
        if ent_name in names:
            ent = plistlib.loads(z.read(ent_name))
            ignore = {"application-identifier", "com.apple.developer.team-identifier"}
            entitlements = sorted(k for k in ent if k not in ignore)
    return info, entitlements


def privacy_keys(info):
    return {k: v for k, v in sorted(info.items()) if k.endswith("UsageDescription")}


def load_source(path, repo):
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    raw = f"https://raw.githubusercontent.com/{repo}/main"
    return {
        "name": "Splitter for iOS",
        "subtitle": "A native speedrun timer for iPhone and iPad.",
        "description": "Builds of Splitter for iOS, a SwiftUI speedrun timer built on livesplit-core.",
        "iconURL": f"{raw}/Resources/AppIcon.png",
        "website": f"https://github.com/{repo}",
        "tintColor": TINT,
        "apps": [],
        "news": [],
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--ipa", required=True)
    p.add_argument("--download-url", required=True)
    p.add_argument("--repo", required=True, help="OWNER/REPO on GitHub")
    p.add_argument("--notes", default="")
    p.add_argument("--source", default=SOURCE, help="source JSON to update (default: altstore/source.json)")
    p.add_argument("--date", default=datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat())
    args = p.parse_args()

    info, entitlements = read_ipa(args.ipa)
    bundle_id = info["CFBundleIdentifier"]
    version = info["CFBundleShortVersionString"]
    build = str(info["CFBundleVersion"])
    raw = f"https://raw.githubusercontent.com/{args.repo}/main"

    source = load_source(args.source, args.repo)
    app = next((a for a in source["apps"] if a["bundleIdentifier"] == bundle_id), None)
    if app is None:
        app = {"bundleIdentifier": bundle_id, "versions": []}
        source["apps"].insert(0, app)
    app.update({
        "name": info.get("CFBundleDisplayName", info.get("CFBundleName", "Splitter")),
        "developerName": args.repo.split("/")[0],
        "subtitle": "Speedrun timer powered by livesplit-core",
        "localizedDescription": DESCRIPTION,
        "iconURL": f"{raw}/Resources/AppIcon.png",
        "tintColor": TINT,
        "category": "utilities",
        "appPermissions": {"entitlements": entitlements, "privacy": privacy_keys(info)},
    })

    entry = {
        "version": version,
        "buildVersion": build,
        "date": args.date,
        "localizedDescription": args.notes or f"Splitter {version} (build {build}).",
        "downloadURL": args.download_url,
        "size": os.path.getsize(args.ipa),
        "minOSVersion": str(info.get("MinimumOSVersion", "17.0")),
    }
    # Re-publishing the same version+build replaces that entry instead of duplicating it.
    app["versions"] = [v for v in app["versions"]
                       if (v["version"], v["buildVersion"]) != (version, build)]
    app["versions"].insert(0, entry)
    source.setdefault("featuredApps", [bundle_id])

    os.makedirs(os.path.dirname(os.path.abspath(args.source)), exist_ok=True)
    with open(args.source, "w") as f:
        json.dump(source, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"{args.source}: {bundle_id} {version} ({build}), {len(app['versions'])} version(s)")


if __name__ == "__main__":
    sys.exit(main())

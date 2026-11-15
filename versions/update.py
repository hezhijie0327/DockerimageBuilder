#!/usr/bin/env python3

## How to get and use?
# git clone "https://github.com/hezhijie0327/DockerimageBuilder.git" && python3 ./DockerimageBuilder/versions/update.py

import json
import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent

# name -> (GitHub repo, tag filter, prefix to strip)
# Filters mirror the original grep chains; the last matching tag wins.
VERSION_SOURCES = {
    "CLOUDFLARED_VERSION": ("cloudflare/cloudflared", r"^refs/tags/", "refs/tags/"),
    "JELLYFIN_VERSION": ("jellyfin/jellyfin", r"^refs/tags/v(?!.*-)", "refs/tags/v"),
    "JELLYFIN_WEB_VERSION": ("jellyfin/jellyfin-web", r"^refs/tags/v(?!.*-)", "refs/tags/v"),
    "QBITTORRENT_VERSION": ("qbittorrent/qBittorrent", r"^refs/tags/release-(?!.*(?:alpha|beta|rc))", "refs/tags/release-"),
    "SIYUAN_VERSION": ("siyuan-note/siyuan", r"^refs/tags/v(?!.*-dev)", "refs/tags/v"),
    "VAULTWARDEN_VERSION": ("dani-garcia/vaultwarden", r"^refs/tags/", "refs/tags/"),
    "VAULTWARDEN_WEB_VERSION": ("dani-garcia/bw_web_builds", r"^refs/tags/v", "refs/tags/v"),
    "VUETORRENT_VERSION": ("VueTorrent/VueTorrent", r"^refs/tags/v", "refs/tags/v"),
    "XRAY_VERSION": ("XTLS/Xray-core", r"^refs/tags/v(?!.*-)", "refs/tags/v"),
}


## Function
# Download one URL, return decoded text (empty string on failure, like curl -s)
def download(url):
    try:
        request = Request(url, headers={"User-Agent": "DockerimageBuilder-update"})
        with urlopen(request, timeout=15) as response:
            return response.read().decode("utf-8", errors="replace")
    except OSError:
        return ""


# Get Latest Version for one component (last matching tag, like tail -n 1)
def get_latest_version(name):
    repo, pattern, prefix = VERSION_SOURCES[name]
    fixed = os.environ.get(f"{name}_FIXED", "")
    if fixed:
        return fixed
    try:
        refs = json.loads(download(f"https://api.github.com/repos/{repo}/git/matching-refs/tags") or "[]")
    except ValueError:
        refs = []
    tags = [item["ref"] for item in refs if re.search(pattern, item["ref"])]
    return tags[-1].removeprefix(prefix) if tags else ""


# Output Package: render template.json with resolved versions
def output_package(versions):
    missing = [name for name, version in versions.items() if version in ("", "000")]
    if missing:
        print(f"Error: latest version missing for {', '.join(missing)}, exit script.")
        sys.exit(1)

    template = (ROOT / "template.json").read_text()
    for name, version in versions.items():
        template = template.replace("{" + name + "}", version)

    # "-000." keeps the original grep semantics: -000 followed by any char
    if re.search(r'""|-000.|\{[A-Z_]+\}', template):
        print("Error: metadata missing, exit script.")
        sys.exit(1)

    (ROOT / "package.json").write_text(template)
    print(template, end="")


## Process
def main():
    with ThreadPoolExecutor(max_workers=9) as pool:
        versions = dict(zip(VERSION_SOURCES, pool.map(get_latest_version, VERSION_SOURCES)))
    print("Info: resolved versions: " + ", ".join(f"{name}={version}" for name, version in versions.items()))
    output_package(versions)


if __name__ == "__main__":
    main()

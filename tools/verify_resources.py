#!/usr/bin/env python3
"""Link-rot verifier for Recovery for All resource registries.

Extracts every https URL from the lib/data registries (and optionally a
custom file list) and checks each is alive. Law (resource-system.md):
NO unverified URL ships. Run before any commit touching resources.

Usage:
    python tools/verify_resources.py            # check all registries
    python tools/verify_resources.py --quiet    # failures only

Pass criteria: HTTP 2xx/3xx. Some hosts reject bots; add exact URLs to
MANUAL_REVIEW below with a comment, and verify them in a browser.
"""

import io
import re
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

TARGET_FILES = [
    "lib/data/recovery_literature.dart",
    "lib/data/recovery_resources.dart",
    "lib/services/gguf_model_service.dart",
]

URL_RE = re.compile(r"https://[^\s'\"]+")

# Hosts that block automated requests — verify by hand, note the date.
MANUAL_REVIEW = {
    # Cloudflare TLS-fingerprints non-browser clients; site verified alive
    # in a real browser 2026-08-25.
    "https://al-anon.org",
}

TIMEOUT = 15
RANGE_HEADERS = {
    "User-Agent": "Mozilla/5.0 (RecoveryForAll link checker)",
    "Range": "bytes=0-1023",
    "Accept": "*/*",
}


def extract_urls():
    urls = []
    seen = set()
    root = __file__.rsplit("tools", 1)[0]
    for rel in TARGET_FILES:
        path = root + rel
        try:
            with io.open(path, encoding="utf-8") as f:
                text = f.read()
        except OSError:
            print(f"WARN: missing file {rel}")
            continue
        for url in URL_RE.findall(text):
            url = url.rstrip("\\,);")
            if url not in seen:
                seen.add(url)
                urls.append(url)
    return sorted(urls)


def check(url):
    req = urllib.request.Request(url, headers=RANGE_HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return url, resp.status
    except Exception as e:  # noqa: BLE001 - report everything
        code = getattr(e, "code", None)
        return url, code if code else f"ERR {type(e).__name__}"


def main():
    quiet = "--quiet" in sys.argv
    urls = extract_urls()
    manual = [u for u in urls if any(u.startswith(m) for m in MANUAL_REVIEW)]
    to_check = [u for u in urls if u not in manual]

    results = []
    with ThreadPoolExecutor(max_workers=4) as pool:
        for url, status in pool.map(check, to_check):
            ok = isinstance(status, int) and 200 <= status < 400
            results.append((url, status, ok))

    failures = [(u, s) for u, s, ok in results if not ok]
    if not quiet:
        print(f"Checked {len(results)} URLs "
              f"({len(manual)} on manual-review list)\n")
        for url, status, ok in results:
            print(f"  {'OK ' if ok else 'FAIL'} {status} {url}")

    print()
    if manual:
        print("Manual review (excluded from automated check):")
        for u in manual:
            print(f"  HAND {u}")

    if failures:
        print(f"\n*** {len(failures)} DEAD LINK(S) — commit blocked ***")
        for url, status in failures:
            print(f"  {status} {url}")
        sys.exit(1)

    print("\nAll links alive. Ship it.")
    sys.exit(0)


if __name__ == "__main__":
    main()

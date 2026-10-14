"""Licensed training images from Wikimedia Commons.

License gate: only files whose Commons metadata says CC0 or public domain,
with no listed restrictions (personality rights, trademarks, ...). Every file
is recorded with its page, author, licence and SHA-256 in ``manifest.json`` so
the dataset can be audited and rebuilt.

Usage::

    uv run python -m hookkadr_ai.datasets.sources --out data/sources/commons
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import time
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass
from pathlib import Path

from ..paths import SOURCES_DIR

API = "https://commons.wikimedia.org/w/api.php"
USER_AGENT = "HOOKKADR-dataset-builder/0.1 (open-source dataset tool; +https://commons.wikimedia.org/wiki/Commons:Reusing_content_outside_Wikimedia)"

LICENSE_TEMPLATES = ("Cc-zero", "PD-self")
ALLOWED_LICENSES = {"cc0", "pd"}
ALLOWED_MIME = {"image/jpeg", "image/png"}
MIN_WIDTH, MIN_HEIGHT = 1600, 900
THUMB_WIDTH = 1920

# Topic -> how many files to take. Weighted toward what HOOKKADR users film.
DEFAULT_TOPICS: dict[str, int] = {
    "interior": 50,
    "kitchen": 25,
    "food": 40,
    "product": 25,
    "portrait": 25,
    "people": 20,
    "street": 30,
    "market": 15,
    "architecture": 25,
    "landscape": 30,
    "night": 20,
    "car": 15,
    "animal": 20,
    "flower": 15,
}


@dataclass
class SourceImage:
    id: str
    title: str
    topic: str
    license: str
    license_short: str
    license_url: str
    artist: str
    source_page: str
    download_url: str
    width: int
    height: int
    sha256: str
    file: str


def _get(params: dict[str, str]) -> dict:
    url = f"{API}?{urllib.parse.urlencode({**params, 'format': 'json', 'formatversion': '2'})}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def _strip_html(text: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", "", text or "")).strip()


def search_titles(query: str, limit: int) -> list[str]:
    data = _get(
        {
            "action": "query",
            "list": "search",
            "srnamespace": "6",
            "srlimit": str(min(limit, 500)),
            "srsearch": query,
        }
    )
    return [hit["title"] for hit in data.get("query", {}).get("search", [])]


def image_infos(titles: list[str]) -> list[dict]:
    out: list[dict] = []
    for i in range(0, len(titles), 50):
        data = _get(
            {
                "action": "query",
                "titles": "|".join(titles[i : i + 50]),
                "prop": "imageinfo",
                "iiprop": "url|size|mime|extmetadata",
                "iiurlwidth": str(THUMB_WIDTH),
                "iiextmetadatafilter": "License|LicenseShortName|LicenseUrl|Artist|Restrictions|AttributionRequired",
            }
        )
        out.extend(p for p in data.get("query", {}).get("pages", []) if p.get("imageinfo"))
        time.sleep(0.3)
    return out


def license_ok(page: dict) -> tuple[bool, str]:
    """The licence gate. Returns (accepted, reason)."""
    info = page["imageinfo"][0]
    meta = {k: (v or {}).get("value", "") for k, v in info.get("extmetadata", {}).items()}
    lic = meta.get("License", "").lower()
    if lic not in ALLOWED_LICENSES:
        return False, f"licence {lic or 'unknown'}"
    if meta.get("Restrictions", "").strip():
        return False, f"restrictions {meta['Restrictions']}"
    if info.get("mime") not in ALLOWED_MIME:
        return False, f"mime {info.get('mime')}"
    if info.get("width", 0) < MIN_WIDTH or info.get("height", 0) < MIN_HEIGHT:
        return False, "too small"
    return True, "ok"


def _download(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.read()
        except urllib.error.HTTPError as e:
            if e.code != 429 or attempt == 3:
                raise
            time.sleep(5 * (attempt + 1))
    raise RuntimeError("unreachable")


def fetch(out_dir: Path, topics: dict[str, int]) -> list[SourceImage]:
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = out_dir / "manifest.json"
    known: dict[str, SourceImage] = {}
    if manifest_path.exists():
        for e in json.loads(manifest_path.read_text())["images"]:
            known[e["id"]] = SourceImage(**e)

    chosen: dict[str, tuple[str, dict]] = {}
    rejected: dict[str, int] = {}
    for topic, want in topics.items():
        taken = 0
        for template in LICENSE_TEMPLATES:
            if taken >= want:
                break
            titles = search_titles(f"incategory:Quality_images hastemplate:{template} {topic}", want * 3)
            for page in image_infos([t for t in titles if t not in {c[1]['title'] for c in chosen.values()}]):
                ok, why = license_ok(page)
                if not ok:
                    rejected[why.split()[0]] = rejected.get(why.split()[0], 0) + 1
                    continue
                key = f"commons:{page['pageid']}"
                if key in chosen:
                    continue
                chosen[key] = (topic, page)
                taken += 1
                if taken >= want:
                    break
        print(f"{topic}: {taken}/{want}")

    images: list[SourceImage] = []
    for key, (topic, page) in sorted(chosen.items()):
        info = page["imageinfo"][0]
        meta = {k: (v or {}).get("value", "") for k, v in info.get("extmetadata", {}).items()}
        url = info.get("thumburl") or info["url"]
        prev = known.get(key)
        if prev and (out_dir / prev.file).exists():
            images.append(prev)
            continue
        data = _download(url)
        digest = hashlib.sha256(data).hexdigest()
        ext = ".png" if info["mime"] == "image/png" else ".jpg"
        name = f"{page['pageid']}{ext}"
        (out_dir / name).write_bytes(data)
        images.append(
            SourceImage(
                id=key,
                title=page["title"],
                topic=topic,
                license=meta.get("License", "").lower(),
                license_short=meta.get("LicenseShortName", ""),
                license_url=meta.get("LicenseUrl", ""),
                artist=_strip_html(meta.get("Artist", ""))[:200],
                source_page=info.get("descriptionurl", ""),
                download_url=url,
                width=int(info.get("thumbwidth") or info["width"]),
                height=int(info.get("thumbheight") or info["height"]),
                sha256=digest,
                file=name,
            )
        )
        time.sleep(0.2)

    manifest = {
        "source": "Wikimedia Commons, category Quality_images",
        "licenseGate": {
            "allowed": sorted(ALLOWED_LICENSES),
            "templates": list(LICENSE_TEMPLATES),
            "restrictions": "none allowed",
            "minSize": [MIN_WIDTH, MIN_HEIGHT],
        },
        "rejected": rejected,
        "images": [asdict(i) for i in images],
    }
    manifest_path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False))
    print(f"{len(images)} images, rejected {rejected}")
    return images


def load_manifest(src_dir: Path) -> list[SourceImage]:
    data = json.loads((src_dir / "manifest.json").read_text())
    return [SourceImage(**e) for e in data["images"]]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, default=SOURCES_DIR / "commons")
    args = ap.parse_args()
    fetch(args.out, DEFAULT_TOPICS)


if __name__ == "__main__":
    main()

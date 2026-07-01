"""
Extract member portraits from a GPO "Pictorial Directory of Congress" PDF.

Each page of the pictorial directory is a single scanned image (not
individually embedded photos) with an OCR text layer giving each member's
name, home city/district, party, and term. This script:

  1. Renders each page and detects the photo rectangles via pixel density
     (photos are dense continuous-tone blocks; caption text is sparse).
  2. Parses the OCR text layer into per-member caption entries (name, city,
     district, party, term) and a state/territory + office label.
  3. Pairs each caption to the photo directly above it and crops the photo
     from the native embedded page image (avoids re-render upsampling).
  4. Writes one PNG per member to images/<state>/<name>.png plus a
     manifest.csv with the parsed metadata.

Usage:
    python extract_portraits.py --pdf GPO-PICTDIR-98.pdf --out OUT_DIR \
        --first-page 19 --last-page 168
"""

import argparse
import csv
import re
import urllib.request
from pathlib import Path

import fitz  # PyMuPDF
import numpy as np
from PIL import Image

STATE_NAMES = {
    "ALABAMA", "ALASKA", "ARIZONA", "ARKANSAS", "CALIFORNIA", "COLORADO",
    "CONNECTICUT", "DELAWARE", "FLORIDA", "GEORGIA", "HAWAII", "IDAHO",
    "ILLINOIS", "INDIANA", "IOWA", "KANSAS", "KENTUCKY", "LOUISIANA",
    "MAINE", "MARYLAND", "MASSACHUSETTS", "MICHIGAN", "MINNESOTA",
    "MISSISSIPPI", "MISSOURI", "MONTANA", "NEBRASKA", "NEVADA",
    "NEW HAMPSHIRE", "NEW JERSEY", "NEW MEXICO", "NEW YORK",
    "NORTH CAROLINA", "NORTH DAKOTA", "OHIO", "OKLAHOMA", "OREGON",
    "PENNSYLVANIA", "RHODE ISLAND", "SOUTH CAROLINA", "SOUTH DAKOTA",
    "TENNESSEE", "TEXAS", "UTAH", "VERMONT", "VIRGINIA", "WASHINGTON",
    "WEST VIRGINIA", "WISCONSIN", "WYOMING",
}

DASH = "—"

# Density thresholds for photo-region detection (grayscale render at ZOOM px/pt).
# Real portraits are consistently ~340-350px wide and ~400px tall at ZOOM=3;
# these minimums are set well below that (comfortably above border slivers /
# faint bleed-through-text blobs from the facing page, which are ~100-160px)
# rather than tight to the true size, so minor page-to-page variation in
# scan crop doesn't cause false rejections.
ZOOM = 3
DARK_THRESHOLD = 235
ROW_DENSITY_MIN = 0.25
COL_DENSITY_MIN = 0.3
MIN_PHOTO_HEIGHT_PX = 250
MIN_PHOTO_WIDTH_PX = 200


def download_pdf(url: str, dest: Path):
    if dest.exists():
        return
    print(f"Downloading {url} -> {dest}")
    urllib.request.urlretrieve(url, dest)


def find_runs(mask, thresh):
    runs = []
    in_run = False
    start = 0
    for i, v in enumerate(mask):
        if v > thresh and not in_run:
            start = i
            in_run = True
        elif v <= thresh and in_run:
            runs.append((start, i))
            in_run = False
    if in_run:
        runs.append((start, len(mask)))
    return runs


MARGIN_FRAC = 0.06  # trim outer edges before density analysis: scanned pages
# often have a black binding/edge strip (left or right, depending on recto vs
# verso) plus faint bleed-through text from the facing page, either of which
# can otherwise fuse with a real photo's density run and widen its crop.


def detect_photo_boxes(page):
    """Return list of (x0, y0, x1, y1) in ZOOM-scaled pixel coords."""
    pix = page.get_pixmap(matrix=fitz.Matrix(ZOOM, ZOOM), colorspace=fitz.csGRAY)
    arr = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width)

    mx = int(pix.width * MARGIN_FRAC)
    my = int(pix.height * MARGIN_FRAC / 2)
    arr = arr[my:pix.height - my, mx:pix.width - mx]
    dark = arr < DARK_THRESHOLD

    row_density = dark.mean(axis=1)
    row_runs = [
        (y0, y1) for y0, y1 in find_runs(row_density, ROW_DENSITY_MIN)
        if y1 - y0 >= MIN_PHOTO_HEIGHT_PX
    ]

    boxes = []
    for y0, y1 in row_runs:
        band = dark[y0:y1]
        col_density = band.mean(axis=0)
        col_runs = [
            (x0, x1) for x0, x1 in find_runs(col_density, COL_DENSITY_MIN)
            if x1 - x0 >= MIN_PHOTO_WIDTH_PX
        ]
        for x0, x1 in col_runs:
            boxes.append((x0 + mx, y0 + my, x1 + mx, y1 + my))
    return boxes, pix.width, pix.height


def get_lines(page):
    """Flatten the text dict into a list of line-segment dicts, split on
    bold/non-bold transitions within a visual line (some entries mix a bold
    name continuation and a non-bold city fragment on the same OCR'd line).
    Italic-vs-regular is NOT used as a split boundary: OCR occasionally
    mis-flags part of a single city/party field (e.g. 'of' rendered regular
    while the rest of the field is italic), and splitting on that would
    fragment one field into two. Ignores image blocks."""
    d = page.get_text("dict")
    lines = []
    for block in d["blocks"]:
        if "lines" not in block:
            continue
        for line in block["lines"]:
            spans = line["spans"]
            if not spans:
                continue
            run = []
            run_bold = None
            for s in spans:
                if not s["text"].strip():
                    if run:
                        run.append(s)
                    continue
                bold = bool(s["flags"] & 16)
                if run_bold is None or bold == run_bold:
                    run.append(s)
                    run_bold = bold
                else:
                    line_dict = _span_run_to_line(run)
                    if line_dict is not None:
                        lines.append(line_dict)
                    run = [s]
                    run_bold = bold
            line_dict = _span_run_to_line(run)
            if line_dict is not None:
                lines.append(line_dict)
    return lines


def _span_run_to_line(spans):
    text = "".join(s["text"] for s in spans).strip()
    if not text:
        return None
    x0 = min(s["bbox"][0] for s in spans)
    y0 = min(s["bbox"][1] for s in spans)
    x1 = max(s["bbox"][2] for s in spans)
    y1 = max(s["bbox"][3] for s in spans)
    flags = spans[0]["flags"]
    return {
        "text": text, "x0": x0, "y0": y0, "x1": x1, "y1": y1,
        "bold": bool(flags & 16), "italic": bool(flags & 2),
    }


def is_label(line):
    return line["bold"] and line["text"].isupper()


def is_name(line):
    return line["bold"] and not line["text"].isupper() and any(c.islower() for c in line["text"])


def merge_wrapped_names(lines):
    """Merge a bold name line with a bold continuation line directly below it
    (e.g. 'F. James Sensenbrenner,' + 'Jr.') into a single name line."""
    name_lines = sorted((l for l in lines if is_name(l)), key=lambda l: (l["y0"], l["x0"]))
    consumed = set()
    merged = []
    for i, nl in enumerate(name_lines):
        if id(nl) in consumed:
            continue
        cur = nl
        for other in name_lines[i + 1:]:
            if id(other) in consumed:
                continue
            gap = other["y0"] - cur["y1"]
            if -8 <= gap < 20 and abs(other["x0"] - cur["x0"]) < 30:
                cur = {
                    "text": (cur["text"] + " " + other["text"]).strip(),
                    "x0": cur["x0"], "y0": cur["y0"],
                    "x1": max(cur["x1"], other["x1"]), "y1": other["y1"],
                    "bold": True, "italic": False,
                }
                consumed.add(id(other))
            else:
                break
        merged.append(cur)
    original_name_ids = {id(l) for l in name_lines}
    non_name_lines = [l for l in lines if id(l) not in original_name_ids]
    return merged + non_name_lines


def find_next_nonbold(after_line, lines):
    """Find the next non-bold line at or below after_line's top edge (not its
    bottom edge, since a wrapped name's continuation can share a physical row
    with its city-line sibling)."""
    best = None
    for c in lines:
        if c is after_line or c["bold"]:
            continue
        if c["y0"] <= after_line["y0"] - 1:
            continue
        if c["y0"] - after_line["y1"] > 20:
            continue
        if abs(c["x0"] - after_line["x0"]) > 30:
            continue
        if best is None or c["y0"] < best["y0"]:
            best = c
    return best


def column_split(xs):
    """Find a threshold separating two x0 clusters (left/right column) by
    locating the largest gap between sorted values, rather than assuming
    columns are symmetric around the page's geometric center."""
    xs = sorted(xs)
    if len(xs) <= 1:
        return None
    gaps = [(xs[i + 1] - xs[i], i) for i in range(len(xs) - 1)]
    best_gap, best_i = max(gaps)
    if best_gap <= 5:
        return None
    return (xs[best_i] + xs[best_i + 1]) / 2


def build_entries(lines):
    lines = merge_wrapped_names(lines)
    name_lines = [l for l in lines if is_name(l)]
    label_lines = [l for l in lines if is_label(l)]
    entries = []
    for nl in name_lines:
        cand1 = find_next_nonbold(nl, lines)
        city_line, party_line = None, None
        if cand1 is not None:
            if DASH in cand1["text"]:
                party_line = cand1
            else:
                city_line = cand1
                cand2 = find_next_nonbold(cand1, lines)
                if cand2 is not None and DASH in cand2["text"]:
                    party_line = cand2
        y1 = max(nl["y1"], (city_line or nl)["y1"], (party_line or nl)["y1"])
        entries.append({
            "name_line": nl,
            "city_text": city_line["text"] if city_line else "",
            "party_text": party_line["text"] if party_line else "",
            "x0": nl["x0"], "y0": nl["y0"], "y1": y1,
        })

    threshold = column_split(e["x0"] for e in entries)

    def col_of(x0):
        if threshold is None:
            return "L"
        return "L" if x0 < threshold else "R"

    for e in entries:
        e["col"] = col_of(e["x0"])
        candidates = [l for l in label_lines if l["y1"] <= e["y0"] + 1]
        same_col = [l for l in candidates if col_of(l["x0"]) == e["col"]]
        pool = same_col if same_col else candidates
        e["label"] = max(pool, key=lambda l: l["y1"])["text"] if pool else ""
    return entries


def parse_name(raw_name):
    chamber = "Senate" if raw_name.startswith("Sen.") else "House"
    clean = re.sub(r"^Sen\.\s*", "", raw_name).strip()
    return chamber, clean


def parse_city(city_text):
    # Known OCR glyph confusion: "of " sometimes scans as "o/ ".
    city_text = re.sub(r"^o/\s", "of ", city_text)
    m = re.match(r"^of\s+(.+?)(?:\s*\((?P<dist>[^)]+)\))?$", city_text)
    if not m:
        return city_text, ""
    return m.group(1).strip().rstrip(","), (m.group("dist") or "").strip()


def parse_party(party_text):
    if DASH in party_text:
        party, term = party_text.split(DASH, 1)
        return party.strip(), term.strip()
    return party_text.strip(), ""


def region_from_label(label, city_full):
    if label.upper() in STATE_NAMES:
        return label.title(), label.title()
    if "," in city_full:
        territory = city_full.rsplit(",", 1)[1].strip()
        return territory, label.title() if label else "Delegate"
    return label.title() if label else "Unknown", label.title() if label else "Unknown"


def sanitize(s):
    s = re.sub(r"[.,]", "", s)
    s = re.sub(r"\s+", "_", s.strip())
    return re.sub(r"[^\w\-]", "", s)


def match_entry_to_box(entry, boxes, page_w):
    threshold = column_split(box[0] for box in boxes)
    if threshold is None:
        threshold = page_w / 2

    best, best_score = None, None
    for box in boxes:
        bx0, by0, bx1, by1 = box
        if by1 > entry["y0"] * ZOOM + 5:
            continue
        col_ok = (entry["col"] == "L") == (bx0 < threshold)
        gap = entry["y0"] * ZOOM - by1
        if not col_ok or gap < -10 or gap > 250:
            continue
        score = gap
        if best_score is None or score < best_score:
            best, best_score = box, score
    return best


def process_pdf(pdf_path, out_dir, first_page, last_page):
    doc = fitz.open(pdf_path)
    img_dir = out_dir / "images"
    img_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    name_counts = {}
    unmatched_entries = 0
    unmatched_boxes = 0

    for page_num in range(first_page, last_page + 1):
        pno = page_num - 1
        page = doc[pno]
        lines = get_lines(page)
        entries = build_entries(lines)
        boxes, pw, ph = detect_photo_boxes(page)

        xrefs = page.get_images(full=True)
        if not xrefs:
            print(f"page {page_num}: no embedded image, skipping")
            continue
        xref = xrefs[0][0]
        img_info = doc.extract_image(xref)
        native = Image.open(__import__("io").BytesIO(img_info["image"]))
        sx = native.width / pw
        sy = native.height / ph

        used_boxes = set()
        for e in entries:
            box = match_entry_to_box(e, boxes, pw)
            if box is None:
                unmatched_entries += 1
                continue
            used_boxes.add(box)

            chamber, clean_name = parse_name(e["name_line"]["text"])
            city, district = parse_city(e["city_text"])
            party, term = parse_party(e["party_text"])
            region, office = region_from_label(e["label"], e["city_text"])
            if e["name_line"]["text"].startswith("Sen."):
                office = "Senator"
            elif region.upper() in STATE_NAMES:
                office = "Representative"

            fname = sanitize(clean_name) or "unknown"
            key = (region, fname)
            name_counts[key] = name_counts.get(key, 0) + 1
            if name_counts[key] > 1:
                fname = f"{fname}_p{page_num}"

            region_dir = img_dir / sanitize(region)
            region_dir.mkdir(parents=True, exist_ok=True)
            out_path = region_dir / f"{fname}.png"

            bx0, by0, bx1, by1 = box
            crop_box = (
                max(0, int(bx0 * sx)), max(0, int(by0 * sy)),
                min(native.width, int(bx1 * sx)), min(native.height, int(by1 * sy)),
            )
            native.crop(crop_box).save(out_path)

            rows.append({
                "file": str(out_path.relative_to(out_dir)),
                "name": clean_name,
                "region": region,
                "office": office,
                "party": party,
                "city": city,
                "district": district,
                "term": term,
                "pdf_page": page_num,
            })

        unmatched_boxes += len(boxes) - len(used_boxes)
        print(f"page {page_num}: {len(entries)} entries, {len(boxes)} photo boxes")

    with open(out_dir / "manifest.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "file", "name", "region", "office", "party", "city", "district", "term", "pdf_page",
        ])
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nDone. {len(rows)} portraits extracted.")
    print(f"Unmatched caption entries (no photo found): {unmatched_entries}")
    print(f"Unmatched photo boxes (no caption found): {unmatched_boxes}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pdf", required=True, help="Path to local PDF (downloaded if --url given and missing)")
    ap.add_argument("--url", default=None, help="URL to download the PDF from if not present locally")
    ap.add_argument("--out", required=True, help="Output directory")
    ap.add_argument("--first-page", type=int, default=19)
    ap.add_argument("--last-page", type=int, default=168)
    args = ap.parse_args()

    pdf_path = Path(args.pdf)
    if args.url:
        download_pdf(args.url, pdf_path)

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    process_pdf(pdf_path, out_dir, args.first_page, args.last_page)


if __name__ == "__main__":
    main()

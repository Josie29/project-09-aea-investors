#!/usr/bin/env python3
"""Generate the synthetic OCR golden set.

Every document here is fabricated. No real person's identity data appears in this
repository, which the brief requires explicitly: sample IDs must be synthetic.

The set is committed as images plus labels, so the eval harness runs from a clean
checkout with no generation step. This script exists so the set is reproducible and
auditable rather than a pile of opaque binaries -- and so difficulty can be tuned
deliberately when we discover what Tesseract actually struggles with.

Deterministic: a fixed seed means regenerating produces byte-comparable inputs, so a
change in eval score reflects a change in the pipeline, not a reshuffled fixture set.

Usage:
    python3 generate_documents.py [--out DIR]
"""

from __future__ import annotations

import argparse
import json
import math
import random
from dataclasses import dataclass, asdict
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

SEED = 20260812
CARD_SIZE = (1012, 638)

# Difficulty tiers, mirroring the brief: clean scans, phone photos, and mild skew or
# glare, with a few genuinely hard cases.
TIER_CLEAN = "clean_scan"
TIER_PHONE = "phone_photo"
TIER_HARD = "hard"

FIRST_NAMES = [
    "Marisol", "Devon", "Priya", "Tomasz", "Adaeze", "Rowan", "Hana", "Ibrahim",
    "Lucia", "Nkechi", "Bjorn", "Yusuf", "Camila", "Oskar", "Amara",
]
LAST_NAMES = [
    "Reyes", "Okafor", "Lindqvist", "Nakamura", "Whitfield", "Bergeron", "Adeyemi",
    "Kowalski", "Vasquez", "Thorne", "Mbeki", "Ferraro", "Delacroix", "Ashworth",
]
STREETS = [
    "W Fulton St", "N Ashland Ave", "S Blue Island Ave", "E Kinzie St", "W Cermak Rd",
    "N Damen Ave", "S Wabash Ave", "W Grand Ave", "N Milwaukee Ave", "S Halsted St",
]
CITIES = [("Chicago", "IL", "60607"), ("Evanston", "IL", "60201"), ("Oak Park", "IL", "60302")]

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
]
BOLD_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
]


@dataclass
class Document:
    """One synthetic ID and the ground truth the harness scores against."""

    id: str
    tier: str
    filename: str
    name: str
    dob: str
    address: str
    id_number: str
    note: str


def load_font(candidates: list[str], size: int) -> ImageFont.FreeTypeFont:
    """First available font from `candidates`, falling back to PIL's default.

    Fonts differ across machines; the committed images are the source of truth, so a
    fallback here only affects regeneration, never evaluation.
    """
    for path in candidates:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default(size)


def render_card(doc: Document, rng: random.Random) -> Image.Image:
    """Draw a plausible driver's licence layout."""
    card = Image.new("RGB", CARD_SIZE, (238, 240, 236))
    draw = ImageDraw.Draw(card)

    title = load_font(BOLD_CANDIDATES, 34)
    label = load_font(FONT_CANDIDATES, 18)
    value = load_font(BOLD_CANDIDATES, 30)
    small = load_font(FONT_CANDIDATES, 22)

    # Header band
    draw.rectangle([0, 0, CARD_SIZE[0], 88], fill=(28, 54, 90))
    draw.text((32, 24), "NORTHLINE STATE", font=title, fill=(255, 255, 255))
    draw.text((CARD_SIZE[0] - 250, 34), "DRIVER LICENSE", font=small, fill=(214, 224, 238))

    # Portrait placeholder. Present because a real card has one and it gives the OCR
    # a non-text region to cope with.
    draw.rectangle([32, 120, 232, 380], fill=(206, 210, 214), outline=(120, 126, 132), width=2)
    draw.text((78, 240), "PHOTO", font=small, fill=(120, 126, 132))

    x = 268
    rows = [
        ("DL", doc.id_number, value),
        ("NAME", doc.name, value),
        ("DOB", doc.dob, value),
    ]
    y = 124
    for caption, text, font in rows:
        draw.text((x, y), caption, font=label, fill=(90, 96, 104))
        draw.text((x, y + 22), text, font=font, fill=(18, 22, 28))
        y += 84

    draw.text((x, y), "ADDRESS", font=label, fill=(90, 96, 104))
    street, rest = doc.address.split(", ", 1)
    draw.text((x, y + 22), street, font=value, fill=(18, 22, 28))
    draw.text((x, y + 58), rest, font=value, fill=(18, 22, 28))

    # Footer detail, so the card is not just the three scored fields in isolation.
    issued = f"ISS {rng.randint(1, 12):02d}/{rng.randint(2019, 2024)}"
    expires = f"EXP {rng.randint(1, 12):02d}/{rng.randint(2027, 2031)}"
    draw.text((32, 560), f"{issued}    {expires}    CLASS D", font=small, fill=(70, 76, 84))

    return card


def perspective_transform(image: Image.Image, rng: random.Random, strength: float) -> Image.Image:
    """Approximate a photo taken at an angle rather than flat-on."""
    width, height = image.size
    dx = width * strength
    dy = height * strength

    source = [(0, 0), (width, 0), (width, height), (0, height)]
    target = [
        (rng.uniform(0, dx), rng.uniform(0, dy)),
        (width - rng.uniform(0, dx), rng.uniform(0, dy)),
        (width - rng.uniform(0, dx), height - rng.uniform(0, dy)),
        (rng.uniform(0, dx), height - rng.uniform(0, dy)),
    ]

    # Solve for the 8 perspective coefficients mapping target -> source.
    matrix = []
    for (sx, sy), (tx, ty) in zip(source, target):
        matrix.append([tx, ty, 1, 0, 0, 0, -sx * tx, -sx * ty])
        matrix.append([0, 0, 0, tx, ty, 1, -sy * tx, -sy * ty])

    a = matrix
    b = []
    for (sx, sy) in source:
        b.extend([sx, sy])

    coeffs = solve_linear(a, b)
    return image.transform(image.size, Image.Transform.PERSPECTIVE, coeffs, Image.Resampling.BICUBIC,
                           fillcolor=(120, 124, 128))


def solve_linear(a: list[list[float]], b: list[float]) -> list[float]:
    """Gaussian elimination with partial pivoting.

    Hand-rolled so the generator depends on Pillow alone rather than pulling numpy in
    for one 8x8 solve.
    """
    n = len(b)
    m = [row[:] + [b[i]] for i, row in enumerate(a)]

    for col in range(n):
        pivot = max(range(col, n), key=lambda r: abs(m[r][col]))
        m[col], m[pivot] = m[pivot], m[col]
        pivot_value = m[col][col]
        if abs(pivot_value) < 1e-12:
            continue
        for row in range(col + 1, n):
            factor = m[row][col] / pivot_value
            for k in range(col, n + 1):
                m[row][k] -= factor * m[col][k]

    solution = [0.0] * n
    for row in range(n - 1, -1, -1):
        total = m[row][n] - sum(m[row][k] * solution[k] for k in range(row + 1, n))
        solution[row] = total / m[row][row] if abs(m[row][row]) > 1e-12 else 0.0
    return solution


def add_glare(image: Image.Image, rng: random.Random, intensity: int) -> Image.Image:
    """Blown-out highlight, the way laminate reflects a ceiling light."""
    overlay = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(overlay)
    width, height = image.size

    cx = rng.uniform(width * 0.35, width * 0.8)
    cy = rng.uniform(height * 0.2, height * 0.7)
    rx = rng.uniform(width * 0.18, width * 0.32)
    ry = rng.uniform(height * 0.18, height * 0.3)
    draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=intensity)

    overlay = overlay.filter(ImageFilter.GaussianBlur(60))
    return Image.composite(Image.new("RGB", image.size, (255, 255, 255)), image, overlay)


def apply_lighting(image: Image.Image, rng: random.Random, floor: float = 0.72) -> Image.Image:
    """Uneven illumination across the card, as in a hand-held photo.

    Multiplicative shading, NOT a composite against black. An earlier version
    composited toward black and pushed the dim side of every card to roughly a third
    of its brightness — that is a photo taken in near-darkness, not one taken indoors
    at an angle, and it made the fixture set unrepresentative of what users submit.

    `floor` is the darkest multiplier applied, so shading ranges over [floor, 1.0].
    """
    width, height = image.size
    gradient = Image.new("L", (width, height))
    draw = ImageDraw.Draw(gradient)
    angle = rng.uniform(0, math.pi)

    span = 255 - int(floor * 255)
    for x in range(0, width, 8):
        shade = int(floor * 255) + int(span * (0.5 + 0.5 * math.cos(angle + (x / width) * math.pi)))
        draw.rectangle([x, 0, x + 8, height], fill=max(0, min(255, shade)))

    gradient = gradient.filter(ImageFilter.GaussianBlur(40))

    # Scale each channel by the mask rather than blending toward a colour.
    return Image.merge("RGB", [
        channel.point(lambda v: v).convert("L")
        for channel in ImageChops.multiply(image, Image.merge("RGB", [gradient] * 3)).split()
    ])


def degrade(image: Image.Image, tier: str, rng: random.Random) -> tuple[Image.Image, str]:
    """Apply tier-appropriate damage. Returns the image and the format to save as."""
    if tier == TIER_CLEAN:
        return image, "PNG"

    if tier == TIER_PHONE:
        image = perspective_transform(image, rng, strength=0.015)
        image = image.rotate(rng.uniform(-2.0, 2.0), expand=True, fillcolor=(150, 152, 154),
                             resample=Image.Resampling.BICUBIC)
        image = apply_lighting(image, rng, floor=0.80)
        image = image.filter(ImageFilter.GaussianBlur(rng.uniform(0.2, 0.5)))
        return image, "JPEG"

    # Hard: everything the phone tier does, harder, plus glare. These are the cases
    # that decide whether the pipeline is genuinely robust or merely tuned to easy
    # inputs -- a golden set without them would flatter the score.
    image = perspective_transform(image, rng, strength=0.035)
    image = image.rotate(rng.uniform(-5, 5), expand=True, fillcolor=(150, 152, 154),
                         resample=Image.Resampling.BICUBIC)
    image = apply_lighting(image, rng, floor=0.68)
    image = add_glare(image, rng, intensity=rng.randint(110, 165))
    image = image.filter(ImageFilter.GaussianBlur(rng.uniform(0.5, 1.0)))

    scale = rng.uniform(0.72, 0.88)
    small = (int(image.width * scale), int(image.height * scale))
    image = image.resize(small, Image.Resampling.LANCZOS)
    return image, "JPEG"


def build_documents(rng: random.Random) -> list[Document]:
    """Thirty documents: 12 clean scans, 12 phone photos, 6 hard cases.

    The brief asks for a set spanning clean scans, phone photos, and mild skew or
    glare, "including at least a few near-miss/hard cases" — so hard cases are a
    minority of the set by design, not a third of it.
    """
    docs: list[Document] = []
    tiers = [(TIER_CLEAN, 12), (TIER_PHONE, 12), (TIER_HARD, 6)]
    index = 1

    for tier, count in tiers:
        for _ in range(count):
            first = rng.choice(FIRST_NAMES)
            last = rng.choice(LAST_NAMES)
            middle = rng.choice(["A.", "J.", "M.", "R.", ""])
            name = " ".join(part for part in (first, middle, last) if part)

            city, state, postcode = rng.choice(CITIES)
            number = rng.randint(100, 9999)
            street = rng.choice(STREETS)
            unit = rng.choice(["", "", f", Apt {rng.randint(1, 40)}{rng.choice('ABCD')}"])
            address = f"{number} {street}{unit}, {city}, {state} {postcode}"

            dob = f"{rng.randint(1955, 2005)}-{rng.randint(1, 12):02d}-{rng.randint(1, 28):02d}"
            id_number = f"{rng.choice('DEFGH')}{rng.randint(100, 999)}-{rng.randint(1000, 9999)}-{rng.randint(1000, 9999)}"

            doc_id = f"{tier}_{index:02d}"
            extension = "png" if tier == TIER_CLEAN else "jpg"
            note = {
                TIER_CLEAN: "Flat, evenly lit scan.",
                TIER_PHONE: "Hand-held photo: slight angle, uneven light, mild blur.",
                TIER_HARD: "Steep angle, glare on the laminate, low resolution.",
            }[tier]

            docs.append(Document(
                id=doc_id, tier=tier, filename=f"{doc_id}.{extension}",
                name=name, dob=dob, address=address, id_number=id_number, note=note,
            ))
            index += 1

    return docs


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(Path(__file__).parent), help="output directory")
    args = parser.parse_args()

    out = Path(args.out)
    images = out / "images"
    expected = out / "expected"
    images.mkdir(parents=True, exist_ok=True)
    expected.mkdir(parents=True, exist_ok=True)

    rng = random.Random(SEED)
    documents = build_documents(rng)

    for doc in documents:
        card = render_card(doc, rng)
        image, fmt = degrade(card, doc.tier, rng)
        target = images / doc.filename
        if fmt == "JPEG":
            quality = 72 if doc.tier == TIER_HARD else 88
            image.save(target, fmt, quality=quality)
        else:
            image.save(target, fmt)

    labels = {
        "generated_by": "generate_documents.py",
        "seed": SEED,
        "synthetic": True,
        "note": "Every document is fabricated. No real identity data appears in this repository.",
        "scored_fields": ["name", "dob", "address"],
        "documents": [asdict(doc) for doc in documents],
    }
    (expected / "labels.json").write_text(json.dumps(labels, indent=2) + "\n")

    print(f"Wrote {len(documents)} documents to {images}")
    print(f"Wrote labels to {expected / 'labels.json'}")


if __name__ == "__main__":
    main()

"""Read controller inventories and preserve model and source identities."""
from html.parser import HTMLParser
import re
from urllib.parse import urljoin

SERATO_URL = "https://the-drop.serato.com/announcements/serato-dj-for-ios-hardware-compatibility-and-pricing-explained"
BRANDS = {"Akai", "Allen & Heath", "AlphaTheta", "Denon", "Gemini", "Hercules", "Mixars",
          "Novation", "Numark", "Pioneer DJ", "RANE", "Reloop", "Roland", "Vestax"}


class HardwareListParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tag = None
        self.text = []
        self.brand = None
        self.models = []

    def handle_starttag(self, tag, attributes):
        if tag in {"h2", "h3", "li"} and self.tag is None:
            self.tag, self.text = tag, []

    def handle_data(self, data):
        if self.tag:
            self.text.append(data)

    def handle_endtag(self, tag):
        if tag != self.tag:
            return
        text = " ".join("".join(self.text).split())
        if tag == "h2":
            self.brand = None
        elif tag == "h3":
            self.brand = text if text in BRANDS else None
        elif tag == "li" and self.brand:
            self.models.append({"name": text.rstrip(" *†").strip(), "manufacturer": self.brand,
                                "role": "dvs-only" if text.endswith("†") else "accessory" if text.endswith("*") else "primary",
                                "source": SERATO_URL})
        self.tag, self.text = None, []


def read_serato(html):
    parser = HardwareListParser()
    parser.feed(html)
    if len(parser.models) < 120 or len({model["name"] for model in parser.models}) != len(parser.models):
        raise ValueError("The Serato inventory is incomplete or contains duplicate rows.")
    return parser.models



DJAY_URL = "https://www.algoriddim.com/hardware"
DJAY_MODEL_NAMES = {
    "Reloop Digital Jockey IE2": "Reloop Digital Jockey 2 Interface Edition",
    "Reloop MIXAGE IE": "Reloop Mixage Interface Edition",
}


class DjayHardwareParser(HTMLParser):
    """Keep product rows separate from per-platform limitation notes and NEW badges."""
    def __init__(self):
        super().__init__()
        self.rows = []
        self.notes = []
        self.current = None
        self.badge_depth = 0

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if tag == "li" and attrs.get("data-hardware-target"):
            self.current = {"text": [], "platforms": attrs["data-hardware-target"].split(), "url": None}
            self.badge_depth = 0
        elif self.current is not None:
            if tag == "div": self.badge_depth += 1
            if tag == "a" and self.current["url"] is None: self.current["url"] = attrs.get("href")

    def handle_data(self, data):
        if self.current is not None and self.badge_depth == 0: self.current["text"].append(data)

    def handle_endtag(self, tag):
        if self.current is None: return
        if tag == "div": self.badge_depth = max(0, self.badge_depth - 1)
        if tag == "li":
            row = self.current
            self.current = None
            row["name"] = " ".join("".join(row.pop("text")).split()).rstrip(" *")
            if "midinote" in row["platforms"]:
                row["platforms"].remove("midinote")
                self.notes.append(row)
            else: self.rows.append(row)


def read_djay(html):
    """Read the published all-platform inventory without treating competitor support as our implementation."""
    parser = DjayHardwareParser()
    parser.feed(html)
    platforms = {"mac", "win", "winArm", "ios", "android", "quest"}
    if not 200 <= len(parser.rows) <= 512 or len({row["name"] for row in parser.rows}) != len(parser.rows):
        raise ValueError("The djay inventory is incomplete or contains duplicate rows.")
    rows = []
    for row in parser.rows:
        if not row["name"] or not row["platforms"] or not set(row["platforms"]) <= platforms:
            raise ValueError("The djay inventory contains an invalid product row.")
        rows.append({"name": DJAY_MODEL_NAMES.get(row["name"], row["name"]), "sourceName": row["name"],
                     "platforms": row["platforms"], "url": urljoin(DJAY_URL, row["url"]) if row["url"] else DJAY_URL,
                     "limitations": []})
    for note in parser.notes:
        matches = [row for row in rows if note["name"].startswith(row["sourceName"] + ": ")]
        if len(matches) != 1 or not set(note["platforms"]) <= platforms:
            raise ValueError("A djay limitation does not identify one published product.")
        row = matches[0]
        row["limitations"].append({"platforms": note["platforms"], "text": note["name"][len(row["sourceName"]) + 2:]})
    return rows


def canonical(name):
    value = name.lower().replace("native instruments", "ni")
    value = re.sub(r"\bpioneer dj\b", "pioneer", value)
    value = re.sub(r"^denon dj\s+", "denon ", value)
    value = value.replace("+", " plus ").replace("novation dicers", "novation dicer")
    value = re.sub(r"^alphatheta\s+", "pioneer ", value)
    value = re.sub(r"mk\s*(iii|ii|i)\b", lambda match: "mk" + {"i": "1", "ii": "2", "iii": "3"}[match[1]], value)
    value = re.sub(r"\b(?:advanced|enhanced|alternate|unfinished|hid|midi|linux|os x|windows)\b", "", value)
    value = re.sub(r"\bv\d+\.\d+\b", "", value)
    value = re.sub(r"\bch[12]\b", "", value)
    value = re.sub(r"\([^)]*(?:screens|3dex)[^)]*\)", "", value)
    value = value.replace("hile mod", "")
    value = value.replace("traktor kontrol", "traktor").replace("ni traktor", "traktor")
    result = re.sub(r"[^a-z0-9]", "", value)
    if result == "raneseventyatraksignatureedition":
        return "raneseventyatrakedition"
    return "traktorx1mk1" if result == "traktorx1" else result


def split_models(name):
    shared = {
        "Reloop CONTOUR": ["Reloop Contour Controller Edition", "Reloop Contour Interface Edition"],
        "Reloop Mixage": ["Reloop Mixage Interface Edition", "Reloop Mixage Interface Edition MK2", "Reloop Mixage Controller Edition"],
        "Allen&Heath Xone K1/K2/K3": ["Allen & Heath Xone:K1", "Allen & Heath Xone:K2", "Allen & Heath Xone:K3"],
        "American Audio VMS4/4.1": ["American Audio VMS4", "American Audio VMS4.1"],
        "Hercules DJ Control MP3 e2 / MP3 LE / Glow": ["Hercules DJ Control MP3 e2", "Hercules DJ Control MP3 LE", "Hercules DJ Control Glow"],
        "Numark MixTrack (Pro) II": ["Numark Mixtrack II", "Numark Mixtrack Pro II"],
        "Numark Mixtrack (Pro) 3": ["Numark Mixtrack 3", "Numark Mixtrack Pro 3"],
        "Reloop Terminal Mix 2/4": ["Reloop Terminal Mix 2", "Reloop Terminal Mix 4"],
        "Reloop Beatmix 2/4 MK2": ["Reloop Beatmix 2", "Reloop Beatmix 4", "Reloop Beatmix 2 MK2", "Reloop Beatmix 4 MK2"],
        "Mixars DUO (incl. MKII)": ["Mixars DUO", "Mixars DUO MKII"],
    }
    return shared.get(name, [name])


def manufacturer(name):
    brands = ["Native Instruments", "American Audio", "Allen & Heath", "Allen&Heath", "DJ TechTools", "AlphaTheta", "RANE", "Mixars",
              "Keith McMillen Instruments", "DJ-Tech", "M-Audio", "M-Vave", "Pioneer", "Traktor",
              "Hercules", "Numark", "Denon", "Reloop", "Vestax", "Behringer", "Novation", "Stanton",
              "Akai", "Arturia", "Korg", "Roland", "Gemini", "FaderFox", "Electrix", "MixVibes",
              "Tascam", "Intech", "Icon", "Ion", "EKS", "Yaeltex", "MidiTech", "Kontrol DJ",
              "Casio", "Philips", "Phase SAS", "The Next Beat", "Akiyama", "Audiophony", "BeyondMusic",
              "JB Systems", "Citronic", "DAP", "SKP", "Vistron", "Omnitronic", "Yahorng", "iDance",
              "Zomo", "Hanpin", "Synq", "Vieta DJ", "Vonyx", "Voxoa", "Welljoint", "Midiplus",
              "PCDJ", "ESI"]
    return next((brand for brand in brands if name.lower().startswith(brand.lower())), "Other")

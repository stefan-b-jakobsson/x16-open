"""
klc — a small, dependency-free parser for Microsoft .klc keyboard layout files.

Usage:
    from klc import parse_klc, KlcLayout

    layout = parse_klc("99409 ABC-Extended.txt")
    print(layout.kbd.name)                 # "ABC - Extended (X16)"
    print(layout.kbd.locale_name)          # "en-US"
    for entry in layout.layout:
        print(hex(entry.scancode), entry.vk, entry.chars)

Design notes:
  * Sections are split on a leading keyword token at column 0.
  * Lines are tab- or whitespace-split; inline "// ..." comments are stripped
    *before* field splitting (so "foo // bar" is just "foo").
  * Character columns may be:
        - a literal single character      -> "q", "Q"
        - a 4-hex-digit Unicode code point -> "00e4"
        - "-1"  (no character)
        - "%%"  (no character, "null")
        - "xxxx@" (dead key whose base char is U+xxxx)
  * The @ suffix is stripped and the dead-key bit recorded separately.
  * A column may also be a multi-char escape like "%%" or a bare "-1".

The parser is intentionally tolerant: unknown sections are kept verbatim in
`KlcLayout.unknown_sections` so you can inspect or round-trip them.
"""

from __future__ import annotations

import io
import re
from dataclasses import dataclass, field
from typing import Optional


# ---------------------------------------------------------------------------
# Shift-state constants (matching the Windows .klc encoding)
# ---------------------------------------------------------------------------

SHIFT = 1
CTRL  = 2
ALT   = 4
ALTGR = 6   # ALT | CTRL


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class KlcKey:
    """One physical key row of the LAYOUT section."""
    scancode: int                 # IBM PS/2 Set-1 scancode
    vk: str                       # virtual key name, e.g. "Q", "OEM_4", "1"
    cap: int                      # capslock behaviour: 0, 1, 4, 5, -1 (SGCap)
    chars: dict[int, Optional[str]] = field(default_factory=dict)  # shiftstate -> char (None = absent)
    deads: dict[int, bool] = field(default_factory=dict)           # shiftstate -> is-dead

    def char(self, shiftstate: int) -> Optional[str]:
        return self.chars.get(shiftstate)

    def is_dead(self, shiftstate: int) -> bool:
        return self.deads.get(shiftstate, False)


@dataclass
class KlcDeadKey:
    """One DEADKEY block: base -> {combining -> composed}."""
    base: str                                   # the dead character itself
    combos: dict[str, str] = field(default_factory=dict)

    def compose(self, add: str) -> Optional[str]:
        return self.combos.get(add)


@dataclass
class KlcLigature:
    vk: str
    modifier: int
    chars: list[str] = field(default_factory=list)


@dataclass
class KlcHeader:
    """The KBD / COPYRIGHT / COMPANY / ... preamble."""
    short_id: str = ""
    name: str = ""
    copyright: str = ""
    company: str = ""
    locale_name: str = ""
    locale_id: str = ""
    version: str = ""
    shift_states: list[int] = field(default_factory=list)
    descriptions: dict[str, str] = field(default_factory=dict)
    language_names: dict[str, str] = field(default_factory=dict)


@dataclass
class KlcLayout:
    header: KlcHeader
    layout: list[KlcKey] = field(default_factory=list)
    deadkeys: list[KlcDeadKey] = field(default_factory=list)
    ligatures: list[KlcLigature] = field(default_factory=list)
    keynames: dict[int, str] = field(default_factory=dict)         # scancode -> name
    keynames_ext: dict[int, str] = field(default_factory=dict)     # scancode -> name
    keynames_dead: dict[str, str] = field(default_factory=dict)    # base char -> name
    unknown_sections: dict[str, list[list[str]]] = field(default_factory=dict)

    # -- convenience accessors ------------------------------------------------

    @property
    def kbd(self) -> KlcHeader:
        """Alias so `layout.kbd.name` reads naturally."""
        return self.header

    def key_by_scancode(self, scancode: int) -> Optional[KlcKey]:
        for k in self.layout:
            if k.scancode == scancode:
                return k
        return None

    def key_by_vk(self, vk: str) -> Optional[KlcKey]:
        for k in self.layout:
            if k.vk == vk:
                return k
        return None

    def deadkey_by_base(self, base: str) -> Optional[KlcDeadKey]:
        for dk in self.deadkeys:
            if dk.base == base:
                return dk
        return None

    # -- validation / diagnostics --------------------------------------------

    def validate(self) -> list[str]:
        """Return a list of human-readable warnings; empty list == clean."""
        warnings: list[str] = []

        # 1. every scancode appears only once
        seen: dict[int, int] = {}
        for entry in self.layout:
            if entry.scancode in seen:
                warnings.append(
                    f"duplicate scancode 0x{entry.scancode:02x} "
                    f"(vk={entry.vk})"
                )
            seen[entry.scancode] = 1

        # 2. every non-flag, non-SGCap cap value is one of the known kinds
        for entry in self.layout:
            if entry.cap not in (-1, 0, 1, 4, 5):
                warnings.append(
                    f"unexpected cap value {entry.cap} on 0x{entry.scancode:02x}"
                )

        # 3. every dead key referenced by the layout exists as a DEADKEY block
        declared = {dk.base for dk in self.deadkeys}
        for entry in self.layout:
            for shiftstate, is_dead in entry.deads.items():
                if not is_dead:
                    continue
                base = entry.chars.get(shiftstate)
                if base is None:
                    warnings.append(
                        f"key 0x{entry.scancode:02x} shiftstate {shiftstate}: "
                        f"marked dead but has no character"
                    )
                elif base not in declared:
                    warnings.append(
                        f"key 0x{entry.scancode:02x} shiftstate {shiftstate}: "
                        f"dead key base {base!r} (U+{ord(base):04X}) has no DEADKEY block"
                    )

        # 4. each dead-key combination produces a single character
        for dk in self.deadkeys:
            for add, result in dk.combos.items():
                if len(result) != 1:
                    warnings.append(
                        f"dead key {dk.base!r} + {add!r} -> {result!r} "
                        f"is not a single character"
                    )

        # 5. every shiftstate in LAYOUT appears in SHIFTSTATE
        declared_states = set(self.header.shift_states)
        used_states: set[int] = set()
        for entry in self.layout:
            used_states.update(entry.chars.keys())
        for st in sorted(used_states - declared_states):
            warnings.append(f"layout uses shiftstate {st} not declared in SHIFTSTATE")

        return warnings


# ---------------------------------------------------------------------------
# Low-level helpers
# ---------------------------------------------------------------------------

_KEYWORDS = {
    "KBD", "COPYRIGHT", "COMPANY", "LOCALENAME", "LOCALEID", "VERSION",
    "SHIFTSTATE", "LAYOUT", "DEADKEY", "LIGATURE", "KEYNAME", "KEYNAME_EXT",
    "KEYNAME_DEAD", "DESCRIPTIONS", "LANGUAGENAMES", "ENDKBD",
}

ibm_keys = {
    0x29:0x1, 0x2:0x2, 0x3:0x3, 0x4:0x4, 0x5:0x5, 0x6:0x6, 0x7:0x7, 
    0x8:0x8, 0x9:0x9, 0xa:0xa, 0xb:0xb, 0xc:0xc, 0xd:0xd, 0xe:0xf, 
    0xf:0x10, 0x10:0x11, 0x11:0x12, 0x12:0x13, 0x13:0x14, 0x14:0x15, 
    0x15:0x16, 0x16:0x17, 0x17:0x18, 0x18:0x19, 0x19:0x1a, 0x1a:0x1b, 
    0x1b:0x1c, 0x2b:0x1d, 0x3a:0x1e, 0x1e:0x1f, 0x1f:0x20, 0x20:0x21, 
    0x21:0x22, 0x22:0x23, 0x23:0x24, 0x24:0x25, 0x25:0x26, 0x26:0x27, 
    0x27:0x28, 0x28:0x29, 0x1c:0x2b, 0x2a:0x2c, 0x2c:0x2e, 0x2d:0x2f, 
    0x2e:0x30, 0x2f:0x31, 0x30:0x32, 0x31:0x33, 0x32:0x34, 0x33:0x35, 
    0x34:0x36, 0x35:0x37, 0x36:0x39, 0x1d:0x3a, 0x38:0x3c, 0x39:0x3d, 
    0xe038:0x3e, 0xe01d:0x40, 0xe052:0x4b, 0xe04b:0x4f, 0xe047:0x50, 
    0xe04f:0x51, 0xe048:0x53, 0xe050:0x54, 0xe049:0x55, 0xe051:0x56, 
    0xe04d:0x59, 0x45:0x5a, 0x47:0x5b, 0x4b:0x5c, 0x4f:0x5d, 0xe035:0x5f, 
    0x48:0x60, 0x4c:0x61, 0x50:0x62, 0x52:0x63, 0x37:0x64, 0x49:0x65, 
    0x4d:0x66, 0x51:0x67, 0x53:0x68, 0x4a:0x69, 0x4e:0x6a, 0xe01c:0x6c, 
    0x1:0x6e, 0x3b:0x70, 0x3c:0x71, 0x3d:0x72, 0x3e:0x73, 0x3f:0x74, 
    0x40:0x75, 0x41:0x76, 0x42:0x77, 0x43:0x78, 0x44:0x79, 0x57:0x7a, 
    0x58:0x7b, 0xe02a:0x7c, 0x46:0x7d, 0xe11d:0x7e, 0x56:0x2d,
    0x73:0x38
}

def _ps2_to_ibmkey(code: int):
    if code in ibm_keys.keys():
        return ibm_keys[code]
    else:
        return 0

def _strip_comment(line: str) -> str:
    """Remove a `// ...` comment and trailing whitespace."""
    i = line.find("//")
    if i != -1:
        line = line[:i]
    return line.rstrip()


def _split_fields(line: str) -> list[str]:
    """Split on tabs, then on runs of whitespace, dropping empties."""
    return [f for f in re.split(r"[ \t]+", line.strip()) if f]


def _char_from_field(field: str) -> tuple[Optional[str], bool]:
    """
    Decode one LAYOUT character cell.

    Returns (char_or_None, is_dead).
    Raises ValueError on malformed hex (caller decides whether to warn).
    """
    dead = field.endswith("@")
    if dead:
        field = field[:-1]

    if field in ("-1", "%%", ""):
        return None, dead

    if len(field) == 1:
        return field, dead

    if len(field) == 4:
        try:
            return chr(int(field, 16)), dead
        except ValueError:
            pass

    if len(field) == 5 and field.startswith("+"):
        # e.g. "+1234" appears in some layouts for supplementary planes
        try:
            return chr(int(field[1:], 16)), dead
        except ValueError:
            pass

    # some layouts use a bare unicode escape "\u1234"
    if field.startswith("\\u") and len(field) == 6:
        try:
            return chr(int(field[2:], 16)), dead
        except ValueError:
            pass

    raise ValueError(f"cannot parse character field {field!r}")


def _unescape_quoted(field: str) -> str:
    """Strip surrounding double quotes, if any."""
    if len(field) >= 2 and field[0] == '"' and field[-1] == '"':
        return field[1:-1]
    return field


# ---------------------------------------------------------------------------
# Section splitting
# ---------------------------------------------------------------------------

def _read_sections(text: str) -> list[tuple[str, list[list[str]]]]:
    """
    Split the file into (keyword, rows) sections.

    rows is a list of field lists; the first row is always the keyword header
    itself (e.g. ["SHIFTSTATE"]) so callers can inspect it.
    """
    sections: list[tuple[str, list[list[str]]]] = []
    current_kw: Optional[str] = None
    current_rows: list[list[str]] = []

    for raw in text.splitlines():
        line = _strip_comment(raw)
        if not line:
            continue
        fields = _split_fields(line)
        if not fields:
            continue
        if fields[0] in _KEYWORDS:
            if current_kw is not None:
                sections.append((current_kw, current_rows))
            current_kw = fields[0]
            current_rows = [fields]
        elif current_kw is not None:
            current_rows.append(fields)
        # else: text before the first keyword — silently ignore

    if current_kw is not None:
        sections.append((current_kw, current_rows))

    return sections


# ---------------------------------------------------------------------------
# Section parsers
# ---------------------------------------------------------------------------

def _parse_header(sections: list[tuple[str, list[list[str]]]]) -> KlcHeader:
    h = KlcHeader()
    for kw, rows in sections:
        head = rows[0]
        if kw == "KBD":
            # KBD <short_id> "<name>"
            if len(head) >= 2:
                h.short_id = head[1]
            if len(head) >= 3:
                h.name = _unescape_quoted(head[2])
        elif kw == "COPYRIGHT" and len(head) >= 2:
            h.copyright = _unescape_quoted(head[1])
        elif kw == "COMPANY" and len(head) >= 2:
            h.company = _unescape_quoted(head[1])
        elif kw == "LOCALENAME" and len(head) >= 2:
            h.locale_name = _unescape_quoted(head[1])
        elif kw == "LOCALEID" and len(head) >= 2:
            h.locale_id = _unescape_quoted(head[1])
        elif kw == "VERSION" and len(head) >= 2:
            h.version = _unescape_quoted(head[1])
        elif kw == "SHIFTSTATE":
            for row in rows[1:]:
                if not row:
                    continue
                try:
                    h.shift_states.append(int(row[0]))
                except ValueError:
                    pass
        elif kw == "DESCRIPTIONS":
            for row in rows[1:]:
                if len(row) >= 2:
                    h.descriptions[row[0]] = _unescape_quoted(row[1])
        elif kw == "LANGUAGENAMES":
            for row in rows[1:]:
                if len(row) >= 2:
                    h.language_names[row[0]] = _unescape_quoted(row[1])
    return h


def _parse_layout(
    rows: list[list[str]], shift_states: list[int]
) -> list[KlcKey]:
    """
    Rows: [ ["LAYOUT", ...], ["02","1","0","1","0021",...], ... ]

    Each row is: scancode, vk, cap, then one char cell per shiftstate.
    The number of char cells must match len(shift_states).
    """
    keys: list[KlcKey] = []
    for row in rows[1:]:
        if len(row) < 3:
            continue
        try:
            scancode = _ps2_to_ibmkey(int(row[0], 16))
        except ValueError:
            continue
        vk = row[1]
        cap_token = row[2]
        cap = -1 if cap_token == "SGCap" else int(cap_token, 0)

        # character cells start at column 3
        cells = row[3:]
        # some .klc files carry extra columns; only take as many as we have states
        chars: dict[int, Optional[str]] = {}
        deads: dict[int, bool] = {}
        for i, shiftstate in enumerate(shift_states):
            if i >= len(cells):
                break
            try:
                ch, dead = _char_from_field(cells[i])
            except ValueError:
                # unknown cell — treat as absent, but keep the row
                ch, dead = None, False
            if ch is not None:
                chars[shiftstate] = ch
            deads[shiftstate] = dead

        keys.append(KlcKey(scancode=scancode, vk=vk, cap=cap,
                          chars=chars, deads=deads))
    return keys


def _parse_deadkeys(
    sections: list[tuple[str, list[list[str]]]]
) -> list[KlcDeadKey]:
    out: list[KlcDeadKey] = []
    for kw, rows in sections:
        if kw != "DEADKEY":
            continue
        if len(rows[0]) < 2:
            continue
        base_code = rows[0][1]
        try:
            base = chr(int(base_code, 16))
        except ValueError:
            base = base_code
        dk = KlcDeadKey(base=base)
        for row in rows[1:]:
            if len(row) < 2:
                continue
            try:
                add = chr(int(row[0], 16))
                result = chr(int(row[1], 16))
            except ValueError:
                continue
            dk.combos[add] = result
        out.append(dk)
    return out


def _parse_ligatures(
    sections: list[tuple[str, list[list[str]]]]
) -> list[KlcLigature]:
    out: list[KlcLigature] = []
    for kw, rows in sections:
        if kw != "LIGATURE":
            continue
        for row in rows[1:]:
            if len(row) < 3:
                continue
            vk = row[0]
            try:
                mod = int(row[1], 0)
            except ValueError:
                continue
            chars: list[str] = []
            for cell in row[2:]:
                try:
                    ch, _ = _char_from_field(cell)
                except ValueError:
                    continue
                if ch is not None:
                    chars.append(ch)
            out.append(KlcLigature(vk=vk, modifier=mod, chars=chars))
    return out


def _parse_keynames(
    sections: list[tuple[str, list[list[str]]]]
) -> tuple[dict[int, str], dict[int, str], dict[str, str]]:
    kn: dict[int, str] = {}
    kn_ext: dict[int, str] = {}
    kn_dead: dict[str, str] = {}

    for kw, rows in sections:
        if kw == "KEYNAME":
            for row in rows[1:]:
                if len(row) >= 2:
                    try:
                        kn[int(row[0], 16)] = _unescape_quoted(row[1])
                    except ValueError:
                        pass
        elif kw == "KEYNAME_EXT":
            for row in rows[1:]:
                if len(row) >= 2:
                    try:
                        kn_ext[int(row[0], 16)] = _unescape_quoted(row[1])
                    except ValueError:
                        pass
        elif kw == "KEYNAME_DEAD":
            for row in rows[1:]:
                if len(row) >= 2:
                    try:
                        base = chr(int(row[0], 16))
                    except ValueError:
                        base = row[0]
                    kn_dead[base] = _unescape_quoted(row[1])
    return kn, kn_ext, kn_dead


# ---------------------------------------------------------------------------
# Public entry points
# ---------------------------------------------------------------------------

def parse_klc_text(text: str) -> KlcLayout:
    sections = _read_sections(text)
    header = _parse_header(sections)

    layout: list[KlcKey] = []
    for kw, rows in sections:
        if kw == "LAYOUT":
            layout = _parse_layout(rows, header.shift_states)
            break

    deadkeys = _parse_deadkeys(sections)
    ligatures = _parse_ligatures(sections)
    kn, kn_ext, kn_dead = _parse_keynames(sections)

    known = {
        "KBD", "COPYRIGHT", "COMPANY", "LOCALENAME", "LOCALEID", "VERSION",
        "SHIFTSTATE", "LAYOUT", "DEADKEY", "LIGATURE", "KEYNAME", "KEYNAME_EXT",
        "KEYNAME_DEAD", "DESCRIPTIONS", "LANGUAGENAMES", "ENDKBD",
    }
    unknown: dict[str, list[list[str]]] = {}
    for kw, rows in sections:
        if kw not in known:
            unknown[kw] = rows

    return KlcLayout(
        header=header,
        layout=layout,
        deadkeys=deadkeys,
        ligatures=ligatures,
        keynames=kn,
        keynames_ext=kn_ext,
        keynames_dead=kn_dead,
        unknown_sections=unknown,
    )


def parse_klc(path: str, encoding: str = "utf-8") -> KlcLayout:
    """Parse a .klc file from disk."""
    with io.open(path, "r", encoding=encoding) as f:
        return parse_klc_text(f.read())

def to_latin9(c: str):
    try:
        return c.encode("iso-8859-15")[0]
    except:
        return 0


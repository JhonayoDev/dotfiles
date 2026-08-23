#!/usr/bin/env python3
"""
gen-keyhelp.py — genera lista de atajos para rofi keyhelp
Opción B: lee keys.py (descs) y produce salida agrupada con iconos,
usando los mismos colores que menu-apps via colors.rasi
"""
import re
from pathlib import Path

KEYS_PATH = Path(__file__).parent.parent / "keys.py"

# Mapeo de modificadores a texto legible
MOD_MAP = {
    "mod": "Super",
    "mod1": "Alt",
    "shift": "Shift",
    "control": "Ctrl",
    "mod4": "Super",
    "mod1": "Alt",
}

# XF86 / símbolos → etiqueta física legible (MacBook Pro 2014 + teclado externo)
# Sin esto rofi mostraría "XF86AudioRaiseVolume" o "question" que no coincide con lo impreso
XF86_FRIENDLY = {
    "XF86AudioRaiseVolume": "F12",
    "XF86AudioLowerVolume": "F11",
    "XF86AudioMute": "F10",
    "XF86AudioPlay": "F8",
    "XF86AudioPrev": "F7",
    "XF86AudioNext": "F9",
    "XF86LaunchB": "Tecla Trackpad",
    "XF86MonBrightnessUp": "F2",
    "XF86MonBrightnessDown": "F1",
    "question": "?",
    "slash": "/",
    "period": ".",
    "comma": ",",
}

def section_icon(name: str) -> str:
    n = name.lower()
    if "trackpad" in n:
        return "󰦥  TRACKPAD"
    if "rofi" in n:
        return "󰆍  ROFI"
    if "navegación" in n:
        return "󰖲  VENTANAS — Foco"
    if "mover ventanas" in n:
        return "󰖲  VENTANAS — Mover"
    if "redimensionar" in n:
        return "󰖲  VENTANAS — Redimensionar"
    if n.strip() == "ventanas":
        return "󰖲  VENTANAS"
    if "sistema" in n:
        return "󰍹  SISTEMA"
    if "monitores" in n:
        return "󰍹  MONITORES"
    if "media" in n:
        return "󰕾  AUDIO / MEDIA"
    if "brillo" in n:
        return "󰃠  BRILLO"
    if "screenshot" in n:
        return "󰄀  SCREENSHOTS"
    if "ayuda" in n:
        return "󰋖  AYUDA"
    if "grupos" in n:
        return "󰿱  GRUPOS"
    return f"  {name.upper()}"

def fmt_mods(mods_str: str) -> str:
    # mods_str like "[mod, \"shift\"]" or "[]"
    mods_str = mods_str.strip()
    if mods_str == "[]":
        return ""
    # extrae tokens
    tokens = re.findall(r'"([^"]+)"|\b(mod|mod1|shift|control)\b', mods_str)
    mods = []
    for a, b in tokens:
        token = a or b
        mods.append(MOD_MAP.get(token, token))
    return " + ".join(mods)

def parse_keys():
    text = KEYS_PATH.read_text()
    lines = text.splitlines()
    sections = []  # list of (section, list of (combo, desc))
    current_section = "General"
    current_items = []
    # temp for multiline Key
    buffer = ""
    in_key = False
    paren_depth = 0

    def flush_buffer(buf):
        nonlocal current_items
        # extrae modifiers, key, desc
        # Key([mod], "h", ..., desc="...")
        m_mods = re.search(r'Key\s*\(\s*(\[[^\]]*\])', buf)
        m_key = re.search(r'Key\s*\(\s*\[[^\]]*\]\s*,\s*"([^"]+)"', buf)
        # fallback para XF86 keys sin comillas dobles? ya captura
        if not m_key:
            m_key = re.search(r'Key\s*\(\s*\[[^\]]*\]\s*,\s*\'([^\']+)\'', buf)
        m_desc = re.search(r'desc\s*=\s*"([^"]+)"', buf)
        if not m_desc:
            m_desc = re.search(r"desc\s*=\s*'([^']+)'", buf)
        if not m_desc:
            m_desc = re.search(r'desc\s*=\s*f"([^"]+)"', buf)
        # desc con f-string para grupos: desc=f"Ir al grupo {i.name}" -> captura literal
        if m_mods and m_key and m_desc:
            mods = fmt_mods(m_mods.group(1))
            key = m_key.group(1)
            desc = m_desc.group(1)
            # mapea XF86 a etiqueta física
            friendly = XF86_FRIENDLY.get(key, key)
            combo = f"{mods} + {friendly}" if mods else friendly
            current_items.append((combo, desc))
        elif m_mods and m_key:
            mods = fmt_mods(m_mods.group(1))
            key = m_key.group(1)
            friendly = XF86_FRIENDLY.get(key, key)
            combo = f"{mods} + {friendly}" if mods else friendly
            current_items.append((combo, ""))

    for line in lines:
        stripped = line.strip()
        # detect section headers: # ── Rofi ──
        sec_match = re.search(r'#\s*──\s*(.+?)\s*──', line)
        if sec_match:
            # guarda sección anterior
            if current_items:
                sections.append((current_section, current_items))
                current_items = []
            name = sec_match.group(1).strip()
            # normaliza: "Trackpad ──" ya captura solo Trackpad
            # limpia guiones restantes
            name = re.split(r'─', name)[0].strip()
            current_section = name
            continue

        # detect start of Key(
        if "Key(" in line and not in_key:
            in_key = True
            buffer = line
            paren_depth = line.count("(") - line.count(")")
            if paren_depth <= 0 and "desc=" in line:
                flush_buffer(buffer)
                in_key = False
                buffer = ""
            continue
        if in_key:
            buffer += "\n" + line
            paren_depth += line.count("(") - line.count(")")
            if paren_depth <= 0 and "desc=" in buffer:
                flush_buffer(buffer)
                in_key = False
                buffer = ""
            elif paren_depth <= 0 and ")" in line and "desc=" not in buffer:
                # Key sin desc, ignora
                in_key = False
                buffer = ""

    if current_items:
        sections.append((current_section, current_items))

    return sections

def main():
    sections = parse_keys()
    # Imprime con iconos y secciones
    # Añade Grupos al final (los genera keys.py dinámicamente)
    has_grupos = any(s[0] == "Grupos" for s in sections)
    # Si no hay grupos parseados (porque es loop), los añadimos manual
    if not has_grupos:
        sections.append(("Grupos", [
            ("Super + 1..8", "Ir al grupo N (1-4 principal, 5-8 secundario)"),
            ("Super + Shift + 1..8", "Mover ventana al grupo N"),
        ]))

    out_lines = []
    for sec, items in sections:
        if not items:
            continue
        icon = section_icon(sec)
        out_lines.append(icon)
        for combo, desc in items:
            # alinea: "Super + h  → Foco izquierda"
            if desc:
                out_lines.append(f"  {combo}  →  {desc}")
            else:
                out_lines.append(f"  {combo}")
        out_lines.append("")  # separador

    # Limpia último separador vacío y multilíneas vacías
    text = "\n".join(out_lines).strip()
    print(text)

if __name__ == "__main__":
    main()

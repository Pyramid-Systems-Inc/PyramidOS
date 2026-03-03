# Arabic-First Roadmap (PyramidOS)

**Goal:** Arabic is the primary language from power-on (bootloader) to desktop, with real Arabic text rendering (RTL, shaping) and Arabic-first tools. English remains available as an optional debug/developer fallback.

> **Legend:**
> ✅ = Completed | 🚧 = In Progress | 📅 = Planned | 🔮 = Long Term Vision

---

## A0. Policy + Specs (Spec Freeze)

| Item | Status | Notes |
| :--- | :---: | :--- |
| **Internal Encoding** | 📅 | UTF-8 everywhere (kernel, userland, VFS). No “ASCII-only” APIs. |
| **Digits Policy** | 📅 | Default: Arabic-Indic digits (`٠١٢٣٤٥٦٧٨٩`) vs Western digits (`0123456789`). Must be user-togglable. |
| **Filename Policy** | 📅 | Define comparison rules for VFS/PyFS: byte-compare v1, later optional normalization/collation. |
| **RTL Policy** | 📅 | Define what “RTL by default” means in console + GUI and how mixed text behaves. |
| **Language Policy** | 📅 | Arabic-first strings everywhere; define where English fallback is allowed (panic, diagnostics, dev mode). |

---

## A1. Bootloader Arabic UX (PyramidBL)

**Constraint:** Stage 2 is size-limited; avoid heavyweight Unicode engines here. Prefer pre-rendered assets and a minimal renderer.

| Feature | Status | Notes |
| :--- | :---: | :--- |
| **Arabic Splash Branding (Mode 13h)** | ✅ | Arabic title/subtitle + splash layout in graphics mode. |
| **Arabic Boot Menu** | ✅ | Arabic-first menu text (F8). |
| **Arabic “Press Enter to Skip” + Countdown** | ✅ | 30s countdown + ENTER to skip (digits rendered correctly). |
| **Arabic Fatal Screen** | ✅ | Arabic fatal screens in graphics mode (with hex codes where needed). |
| **Tier 3 VBE Splash (Arabic-ready)** | 🔮 | High-res splash/installer UI with Arabic layout; robust fallback required. |

---

## A2. Kernel Unicode Foundation (UTF-8 Primitives)

| Feature | Status | Notes |
| :--- | :---: | :--- |
| **UTF-8 Decode/Iterate API** | 📅 | Decode codepoints, validate sequences, iterate safely (no byte-based cursor bugs). |
| **UTF-8 Display Width** | 📅 | Compute terminal cell width for codepoints used by the console (Arabic letters, digits, punctuation). |
| **String Utilities (UTF-8 aware)** | 📅 | Substring, truncation, safe copy, compare; no silent corruption on multibyte. |
| **UTF-8 in Logging/Panic Paths** | 📅 | Ensure panic/log output can print UTF-8 without breaking. |

---

## A3. Arabic Text Engine (Shaping + Bidi)

| Feature | Status | Notes |
| :--- | :---: | :--- |
| **Arabic Shaping v1** | 📅 | Joining forms (isolated/initial/medial/final) + Lam-Alef ligatures; minimal diacritics handling staged. |
| **Bidi v1 (Runs)** | 📅 | Mixed-direction line support using a “runs” approach (Arabic vs Latin/numbers). |
| **Cursor Semantics (RTL)** | 📅 | Cursor left/right behavior matches visual order; backspace/delete operate on codepoints/graphemes. |
| **Line Wrapping** | 📅 | Wrap based on visual order and glyph widths; no mid-sequence UTF-8 splits. |
| **Full UAX#9 Bidi** | 🔮 | Standards-level bidi correctness for complex mixed text. |

---

## A4. Framebuffer Terminal (Arabic-First Console)

**Goal:** Replace VGA text mode as the primary UI with a framebuffer console that can render Arabic correctly.

| Feature | Status | Notes |
| :--- | :---: | :--- |
| **Framebuffer Console v1 (Mode 13h)** | 📅 | Simple pixel console with bitmap font rendering and a stable `console_write()` API. |
| **Arabic Bitmap Font Pack (v1)** | 📅 | Ship an in-tree bitmap font that includes Arabic glyphs needed for the OS UI. |
| **VBE LFB Console** | 📅 | Higher resolution, better readability, future GUI foundation. |
| **Theme + Layout (RTL defaults)** | 📅 | Right-aligned prompts, RTL text direction, Arabic numerals option. |
| **VGA Text Mode as Compat** | 📅 | Keep text mode only for deep fallback; not the primary UX. |

---

## A5. Input: Arabic Keyboard + IME Basics

| Feature | Status | Notes |
| :--- | :---: | :--- |
| **Arabic Layout** | 📅 | Scancode -> Unicode Arabic mapping (PS/2 Set 1). |
| **Layout Toggle** | 📅 | Toggle between Arabic/English (example: Alt+Shift). |
| **Digit Mode Toggle** | 📅 | Toggle Arabic-Indic vs Western digits input and display. |
| **Diacritics/Compose (Optional v1)** | 📅 | Support basic harakat entry; staged if it complicates line editing early. |

---

## A6. KShell + Base System Tools (Arabic-First)

| Feature | Status | Notes |
| :--- | :---: | :--- |
| **Arabic System Messages** | 📅 | Boot messages, diagnostics summaries, errors in Arabic by default. |
| **Arabic Command Names** | 📅 | Primary commands in Arabic; keep English aliases for developers (documented, optional). |
| **Arabic Help System** | 📅 | `help`/manual output in Arabic; consistent terminology. |
| **RTL Line Editor** | 📅 | History/search/editing works in RTL with shaped/bidi rendering. |

---

## A7. VFS/Filesystem: UTF-8 Filenames End-to-End

| Feature | Status | Notes |
| :--- | :---: | :--- |
| **UTF-8 Paths** | 📅 | Path parsing, normalization policy, and bounds validation are UTF-8 safe. |
| **Directory Entries** | 📅 | Store and display UTF-8 filenames correctly in DevFS/PyFS. |
| **Sort/Collation (Optional)** | 🔮 | Arabic-aware collation and search behavior (later). |

---

## A8. GUI: RTL Desktop (Arabic-First)

| Feature | Status | Notes |
| :--- | :---: | :--- |
| **Text Rendering in GUI** | 📅 | Same shaping+bidi engine reused by GUI widgets. |
| **RTL Layout Mirroring** | 📅 | Windows, menus, taskbar, dialogs mirror layout and navigation for Arabic. |
| **Arabic-First Desktop Shell** | 📅 | Arabic start/menu, settings, file manager, default apps. |
| **Font System (Beyond Bitmap)** | 🔮 | Font format + rasterizer (TTF/OTF) or a Pyramid-native font pipeline. |

---

## A9. Toolchain + Ecosystem (Baa + Takween, Arabic-First DX)

| Feature | Status | Notes |
| :--- | :---: | :--- |
| **Takween OS Pipeline** | 📅 | One-command build/image/run; Arabic-first project schema and output. |
| **Baa Freestanding Target** | 📅 | `i386-elf-baremetal` target; kernel-safe subset + no hosted runtime assumptions. |
| **Arabic-First Developer UX** | 📅 | Arabic diagnostics, Arabic docs, Arabic-first project templates. |

---

## Definition of Done (Arabic Out-of-the-Box)

| Check | Status | Notes |
| :--- | :---: | :--- |
| **Bootloader is Arabic-first** | 📅 | Power-on shows Arabic splash/menu and Arabic failure screen. |
| **Console is Arabic-correct** | 📅 | RTL + shaping works; line editing behaves correctly. |
| **Keyboard is Arabic-first** | 📅 | Arabic layout works, toggle works, digits policy works. |
| **KShell is usable in Arabic** | 📅 | Arabic commands + help + errors. |
| **Filesystem handles Arabic filenames** | 📅 | Create/list/open UTF-8 Arabic names without corruption. |
| **GUI is RTL-native** | 🔮 | Desktop widgets and text are Arabic-first everywhere. |

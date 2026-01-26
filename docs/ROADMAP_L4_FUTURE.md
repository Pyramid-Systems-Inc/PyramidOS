# Layer 4: Future Concepts & Research (The "Moonshot" Backlog)

This document captures long-term visions, experimental features, and ecosystem goals. These are **not** currently scheduled for engineering but represent the ultimate sovereign vision of PyramidOS.

> **Philosophy:** "Windows 95 Soul, Pyramid Heart."
> We recreate the classic user experience, but every byte of the underlying technology is a custom, non-proprietary invention.

---

## 1. 🔮 "Blue Sky" Bootloader Innovations

* **AI-Powered Boot:**
  * On-device Machine Learning to analyze boot logs and predict hardware failures (S.M.A.R.T correlation).
  * Intelligent kernel module pre-loading based on user habits.
* **Cloud Integration (Pyramid Cloud):**
  * Remote boot policy enforcement.
  * Stateless booting: Pulling the latest Kernel image and User Profile (`.pdb` configs) from a secure HTTP endpoint on startup.
* **Instant Boot:**
  * Hibernation-based "Snapshot Boot" techniques.
  * Zero-copy memory restoration.

* **Bootloader UX Roadmap (3 Tiers):**
  * **Tier 1 (Text Mode Polish):** premium-feeling branded text UI, progress bar, clear diagnostics, boot menu (lowest risk).
  * **Tier 2 (Mode 13h Splash):** 320x200 graphics splash/progress with hard fallback to text mode.
  * **Tier 3 (VBE Splash):** high-resolution LFB splash + future installer UI; must include robust fallback for compatibility.

## 2. 🏛️ The Sovereign Application Ecosystem

* **Pyramid Component Model (PCM):**
  * A custom Inter-Process Communication (IPC) standard replacing OLE/COM.
  * Allows documents to embed live objects (e.g., a graph updating inside a text document) via shared memory pipes.
* **Pyramid Scripting Language (PySL):**
  * A native, system-level interpreted language for automation (replacing Batch/VBS).
  * Deep integration with the Kernel Shell and PyDB.
* **Advanced PXF Features:**
  * **Dynamic Linking:** Shared libraries (`.pyl`) loaded on demand.
  * **Security:** Mandatory code signing for all PXF binaries.
  * **ASLR:** Address Space Layout Randomization for PXF executables.

## 3. ⚙️ Advanced Configuration & Persistence

* **PyDB Clustering:**
  * Extending the **Pyramid Configuration Database** to support atomic transactions.
  * "Roaming Profiles": Syncing specific branches of the PyDB binary tree across the network.
* **System State Journaling:**
  * Rolling back system configuration changes (Undo/Redo for the OS settings) via PyDB snapshots.

## 4. 🛡️ Enterprise Security & Isolation

* **Pyramid Hypervisor (PyVisor):**
  * A Type-1 bare-metal hypervisor capability built into the kernel.
  * Running legacy OSs (Linux, DOS) in isolated "Glass Box" containers.
* **Cryptographic Identity:**
  * Hardware-backed identity management (TPM 2.0 integration).
  * Biometric authentication integration (Hello-style login) into the custom GINA.

## 5. 🌐 Network & Distributed Computing

* **Pyramid Transport Protocol (PTP):**
  * A custom, lightweight transport layer optimized for LAN transfers between PyramidOS machines (inspired by NetBEUI but routed over IP).
* **Distributed Filesystem:**
  * Seamlessly mounting remote PyramidFS volumes.
  * Block-level streaming for media.

## 6. 🏢 Ecosystem Goals

* **OEM Customization:**
  * "Branding Kits" allowing hardware vendors to skin the Bootloader and Desktop Shell without recompiling the kernel.
* **The "Pyramid Store":**
  * A decentralized package manager for PXF binaries.

## 7. 💾 Resilient Home Storage (PyPoolFS) — Union/Merge Pool (Much Later)

* **Concept:** A Pyramid-native storage pool layer that presents multiple physical disks as one logical namespace, with *graceful degradation*.
* **Core behavior:**
  * Add Disk 2 / Disk 3 later to expand capacity; system merges available volumes into one view.
  * If a disk is removed/unavailable, the filesystem still mounts and operates using remaining disks.
  * Files that lived only on the missing disk become unavailable, but the system remains functional.
* **Safety constraint (critical):**
  * Avoid striping a single file across multiple disks unless redundancy/erasure coding exists; otherwise disk loss corrupts files.
* **Optional durability modes (future):**
  * Per-directory replication policy (e.g., mirror “system” data, single-copy “media” data).
  * Background healing when a disk returns.
* **Naming:** “PyPoolFS” / “PyMergeFS” (final naming TBD).

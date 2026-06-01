# HP Envy x360 EC Thermal Control

<div align="center">
  <img src="./gui/utils/hp_ec_icon.svg" width="128" height="128" alt="HP EC Thermal Control Icon">
</div>

A complete hardware thermal management solution for the HP Envy x360 on Linux.

This project provides a custom Linux kernel module that safely interfaces with the HP Embedded Controller (EC) via ACPI registers, paired with a modern Wayland-native Rust/Slint graphical interface to monitor temperatures, view fan speeds, and seamlessly switch thermal profiles.

> **Hardware Compatibility**
> This module was developed and tested on the **HP ENVY x360 Laptop 15-ew0005nl** with the following hardware:
> * **Processor:** Intel Core i7-1260p
> * **Board ID:** 8A29
> * **Hardware SKU:** 6R3W6EA
>
> *Theoretical compatibility extends to the `HP ENVY x360 2-in-1 15-ew0xxx` Intel family. Compatibility with AMD-based variants is unconfirmed, as their ACPI thermal tables often differ.*

---

## Table of Contents

- [Features](#features)
- [Dependencies](#dependencies)
  - [Ubuntu / Debian](#ubuntu--debian)
  - [Fedora](#fedora)
  - [Arch Linux](#arch-linux)
- [Installation](#installation)
  - [Step 1: Clone the Repository](#step-1-clone-the-repository)
  - [Step 2: Build the Graphical Interface](#step-2-build-the-graphical-interface)
  - [Step 3: Run the System Installer](#step-3-run-the-system-installer)
- [Usage](#usage)
- [Uninstall](#uninstall)
- [Troubleshooting](#troubleshooting)

---

## Features

- **Native Kernel Driver:** A lightweight C kernel module that registers `/dev/hp_ec_thermal`.
- **Self-Healing Registers:** Automatically detects and corrects EC register desyncs that occur after waking from sleep or rebooting.
- **DKMS Support:** Automatically rebuilds the kernel module in the background whenever your Linux distribution updates its kernel.
- **Wayland-Native GUI:** A low-overhead Rust GUI built with Slint, fully integrated into system application menus.
- **Rootless Operation:** Udev rules automatically grant standard users read/write access to the thermal device, so the GUI runs without `sudo`.
- **Auto-Load on Boot:** Integrates with `systemd` modules-load to ensure the driver is active before you even log in.

---

## Dependencies

To build the driver and the GUI from source, you need standard build tools, your kernel headers, and the Rust toolchain.

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install build-essential dkms linux-headers-$(uname -r) pkg-config libfontconfig1-dev cargo rustc
```

### Fedora

```bash
sudo dnf install dkms kernel-devel kernel-headers gcc make pkgconf fontconfig-devel cargo rust
```

### Arch Linux

```bash
sudo pacman -S base-devel dkms linux-headers pkgconf fontconfig rust cargo
```

---

## Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/Salvogiarracca/hp-envy-ec-control.git
cd hp-envy-ec-control
```

### Step 2: Build the Graphical Interface

Before running the system installer, compile the Rust GUI. The installer script will automatically locate the finished binary and move it to your system path.

```bash
cd gui
cargo build --release
cd ..
```

### Step 3: Run the System Installer

Run the provided installation script. This will copy the source code, configure DKMS, apply the udev permissions, load the module into systemd boot, and install the global desktop icon.

```bash
sudo ./install.sh
```

---

## Usage

Once installed, simply open your desktop environment's application launcher (GNOME, KDE, wofi, fuzzel, etc.) and search for **"HP EC Controls"**.

The application will run natively, displaying your current CPU temperature, raw fan speed, and allowing you to select between:

- ⚖️ Balanced
- 🚀 Performance
- 🤫 Quiet
- ❄️ Cool
- 🔋 Power Save

---

## Uninstall

To completely remove the kernel module, DKMS configurations, udev rules, and the GUI from your system, run the uninstaller:

```bash
cd hp-envy-ec-control
sudo ./uninstall.sh
```

---

## Troubleshooting

### Invalid module format / Module won't load

Ensure your system isn't blocking unsigned out-of-tree modules via Secure Boot. If Secure Boot is enabled in your BIOS, you will need to sign the DKMS module or disable Secure Boot.

### GUI icon missing in GNOME Dock / Wayland

The GUI broadcasts a strict Wayland XDG App ID (`hp_ec_gui`). If the icon doesn't appear immediately after installation, log out of your desktop session and log back in to refresh the Wayland compositor's application cache.

### UI says "Balanced" but the laptop is running hot

The HP Embedded Controller sometimes resets auxiliary registers on boot. The driver is designed to self-heal. Simply selecting a profile in the UI will instantly resync all ACPI registers.

---

> **Disclaimer:** This software interacts directly with low-level hardware registers. It is provided as-is, without warranty. Use at your own risk.

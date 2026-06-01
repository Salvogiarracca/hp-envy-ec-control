#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root using sudo."
  exit 1
fi

# ==========================================
# --- KERNEL MODULE INSTALLATION ---
# ==========================================
MODULE_NAME="hp_ec"
MODULE_VERSION="1.0"
SRC_DIR="/usr/src/${MODULE_NAME}-${MODULE_VERSION}"

echo ">>> Copying source files to ${SRC_DIR}..."
mkdir -p "$SRC_DIR"
cp -r ./kernel/* "$SRC_DIR"

echo ">>> Adding module to DKMS..."
dkms add -m ${MODULE_NAME} -v ${MODULE_VERSION}

echo ">>> Building module via DKMS..."
dkms build -m ${MODULE_NAME} -v ${MODULE_VERSION}

echo ">>> Installing module via DKMS..."
dkms install -m ${MODULE_NAME} -v ${MODULE_VERSION}

echo ">>> Installing udev rules..."
cp ./kernel/99-hp-ec.rules /etc/udev/rules.d/
udevadm control --reload-rules
udevadm trigger

echo ">>> Configuring module to load on boot..."
echo "${MODULE_NAME}" > "/etc/modules-load.d/${MODULE_NAME}.conf"

echo ">>> Loading the module..."
modprobe ${MODULE_NAME}

echo ">>> SUCCESS! The hp_ec module is installed and loaded."
echo ">>> /dev/hp_ec_thermal is ready for use."

# ==========================================
# --- GUI INSTALLATION ---
# ==========================================
echo ">>> Installing GUI components..."

GUI_BIN="hp_ec_gui"
BIN_DEST="/usr/local/bin/${GUI_BIN}"

if [ -f "gui/target/release/${GUI_BIN}" ]; then
    echo ">>> Found locally built GUI binary. Installing to $BIN_DEST..."
    cp "gui/target/release/${GUI_BIN}" "$BIN_DEST"
    chmod +x "$BIN_DEST"
elif [ -f "gui/${GUI_BIN}" ]; then
    echo ">>> Found pre-compiled GUI binary. Installing to $BIN_DEST..."
    cp "gui/${GUI_BIN}" "$BIN_DEST"
    chmod +x "$BIN_DEST"
else
    echo ">>> WARNING: No GUI binary found in gui/ or gui/target/release/!"
    echo ">>> The kernel module is installed, but the UI was skipped."
fi

if [ -f "./gui/utils/hp_ec_icon.svg" ] && [ -f "./gui/utils/hp_ec_gui.desktop" ]; then
    echo ">>> Installing desktop integration..."

    mkdir -p /usr/share/icons/hicolor/scalable/apps/
    cp ./gui/utils/hp_ec_icon.svg /usr/share/icons/hicolor/scalable/apps/

    mkdir -p /usr/share/applications/
    cp ./gui/utils/hp_ec_gui.desktop /usr/share/applications/

    update-desktop-database /usr/share/applications/
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi

echo ">>> GUI Installation complete!"

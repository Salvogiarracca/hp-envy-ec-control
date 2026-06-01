#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root using sudo."
  exit 1
fi

# ==========================================
# --- KERNEL MODULE UNINSTALL ---
# ==========================================
MODULE_NAME="hp_ec"
MODULE_VERSION="1.0"
SRC_DIR="/usr/src/${MODULE_NAME}-${MODULE_VERSION}"

echo ">>> Unloading the module..."
modprobe -r ${MODULE_NAME} || echo "Module not currently loaded."

echo ">>> Removing module from DKMS..."
dkms remove -m ${MODULE_NAME} -v ${MODULE_VERSION} --all || echo "Module not found in DKMS."

echo ">>> Removing source files from /usr/src/..."
rm -rf "$SRC_DIR"

echo ">>> Removing boot load configuration..."
rm -f "/etc/modules-load.d/${MODULE_NAME}.conf"

echo ">>> Removing udev rules..."
rm -f /etc/udev/rules.d/99-hp-ec.rules
udevadm control --reload-rules

echo ">>> SUCCESS! The hp_ec module has been completely removed."

# ==========================================
# --- GUI UNINSTALL ---
# ==========================================
echo ">>> Removing GUI components..."

GUI_BIN="hp_ec_gui"
BIN_DEST="/usr/local/bin/${GUI_BIN}"

if [ -f "$BIN_DEST" ]; then
    rm -f "$BIN_DEST"
    echo ">>> Removed executable from $BIN_DEST"
fi

if [ -f "/usr/share/applications/hp_ec_gui.desktop" ]; then
    rm -f "/usr/share/applications/hp_ec_gui.desktop"
    echo ">>> Removed .desktop entry"
fi

if [ -f "/usr/share/icons/hicolor/scalable/apps/hp_ec_icon.svg" ]; then
    rm -f "/usr/share/icons/hicolor/scalable/apps/hp_ec_icon.svg"
    echo ">>> Removed global icon"

    update-desktop-database /usr/share/applications/
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi

echo ">>> GUI Uninstallation complete!"

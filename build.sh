#!/bin/bash
set -e

# -----------------------------------------------------------------------------
# PurpyHen 3.0.0 — main HEN build
#
# 1. Builds the kernel payload (kpayload/)
# 2. Downloads + extracts plugins.zip from the plugins repo release
# 3. xxd's every PRX into installer/source/*.inc.c so they get embedded
# 4. xxd's hen.ini into installer/source/hen.ini.inc.c
# 5. Builds the installer, produces hen.bin
# -----------------------------------------------------------------------------

# Only update/install if running as root AND on Ubuntu
# This is for the CI
# On your system you shouldn't be running as root and should already have these installed
if [ "$(id -u)" -eq 0 ] && grep -qi ubuntu /etc/os-release; then
  apt-get update
  apt-get install -y --no-install-recommends ca-certificates curl unzip xxd
fi

# --- Build kernel payload ----------------------------------------------------
pushd kpayload > /dev/null
make
popd > /dev/null

mkdir -p tmp
pushd tmp > /dev/null

# --- Fetch plugins -----------------------------------------------------------
# Known bundled plugins (5 total).
#   plugin_bootloader  — first stage
#   plugin_loader      — loads per-app plugins from plugins.ini
#   plugin_mono        — ShellUI C# hooks + PurpyHen settings menu + PKG browser
#   plugin_server      — FTP + klog host
#   plugin_shellcore   — SceShellCore appinfo helper
PRX_FILES="plugin_bootloader.prx plugin_loader.prx plugin_mono.prx plugin_server.prx plugin_shellcore.prx"

# Only skip the download if plugins.zip is already present AND every required
# PRX has been extracted. The previous version skipped if ANY single file
# existed, which is how partial extracts ended up shipping stale zips.
SKIP_DOWNLOAD=true
if [ -f plugins.zip ]; then
  # zip present, verify contents are intact
  for prx in "${PRX_FILES[@]}"; do
    if [ ! -f "$prx" ]; then
      SKIP_DOWNLOAD=false
      break
    fi
  done
else
  SKIP_DOWNLOAD=false
fi

if [ "$SKIP_DOWNLOAD" = false ]; then
  f="plugins.zip"
  rm -f $f
  rm -f plugin_bootloader.prx plugin_loader.prx plugin_mono.prx \
        plugin_server.prx plugin_shellcore.prx
  curl -fLJO https://github.com/MexrlDev/PS4-Hen-Plugins/releases/latest/download/$f
  unzip -o $f
fi

# Sanity check: warn if plugin_server is missing so it's obvious in CI logs
if [ ! -f plugin_server.prx ]; then
  echo "::warning::plugin_server.prx not found in plugins.zip; FTP/klog will be unavailable."
fi

# --- Embed PRXs into installer sources ---------------------------------------
# need to use translation units to force rebuilds
# including as headers doesn't do it
for file in *.prx; do
  echo "${file}"
  xxd -i "$file" | sed 's/^unsigned /static const unsigned /' > "../installer/source/${file}.inc.c"
done

popd > /dev/null

# --- Embed hen.ini -----------------------------------------------------------
xxd -i "hen.ini" | sed 's/^unsigned /static const unsigned /' > "installer/source/hen.ini.inc.c"

# --- Build installer + assemble hen.bin --------------------------------------
pushd installer > /dev/null
make
popd > /dev/null

rm -f hen.bin
cp installer/installer.bin hen.bin

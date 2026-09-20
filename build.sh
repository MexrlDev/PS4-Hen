#!/bin/bash
set -e

# Only update/install if running as root AND on Ubuntu
# This is for the CI
# On your system you shouldn't be running as root and should already have these installed
if [ "$(id -u)" -eq 0 ] && grep -qi ubuntu /etc/os-release; then
  apt-get update
  apt-get install -y --no-install-recommends ca-certificates curl unzip xxd
fi

pushd kpayload > /dev/null
make
popd > /dev/null

mkdir -p tmp
pushd tmp > /dev/null

# known bundled plugins
PRX_FILES="plugin_bootloader.prx plugin_loader.prx plugin_mono.prx plugin_server.prx plugin_shellcore.prx"

# Only skip the download if EVERY expected PRX is already present.
# The previous version skipped if ANY file existed, which is how partial
# extracts ended up in the build tree.
SKIP_DOWNLOAD=true
if [ ! -f plugins.zip ]; then
  for prx in "${PRX_FILES[@]}"; do
    if [ ! -f "$prx" ]; then
      SKIP_DOWNLOAD=false
      break
    fi
  done
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

# need to use translation units to force rebuilds
# including as headers doesn't do it
for file in *.prx; do
  echo "${file}"
  xxd -i "$file" | sed 's/^unsigned /static const unsigned /' > "../installer/source/${file}.inc.c"
done

popd > /dev/null

xxd -i "hen.ini" | sed 's/^unsigned /static const unsigned /' > "installer/source/hen.ini.inc.c"

pushd installer > /dev/null
make
popd > /dev/null

rm -f hen.bin
cp installer/installer.bin hen.bin

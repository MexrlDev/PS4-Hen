#!/bin/bash
set -e

# -----------------------------------------------------------------------------
# PurpyHen plugins build script
#
# Builds every plugin_*/ directory, then copies each built PRX up to the repo
# root so the CI's `7z a plugins.zip *.prx` step picks all of them up.
#
# Fails loudly if an expected PRX is missing, so we never publish a partial
# plugins.zip again (this is what was happening with plugin_server.prx).
# -----------------------------------------------------------------------------

# Build int3 codecave (used by plugin_mono's prologue hooks)
echo "::group::Generating int3 codecave"
bash int3.sh 4096 > common/cave.inc.c
echo "::endgroup::"

# Clean repo root of stale PRXs from previous runs
rm -f ./*.prx

# Build every plugin_*/ directory
for dr in plugin_*/ ; do
    if [ -d "$dr" ]; then
        echo "::group::Build $dr"
        make -C "$dr" clean all
        echo "::endgroup::"
    fi
done

# -----------------------------------------------------------------------------
# Copy each plugin's PRX to repo root.
#
# Plugin layout is assumed to be:
#   plugin_<name>/plugin_<name>.prx
#
# If a plugin writes its PRX somewhere else, adjust its Makefile — don't
# special-case it here, otherwise we lose the "one convention" invariant that
# the sanity check below relies on.
# -----------------------------------------------------------------------------
echo "::group::Collecting PRXs"
for dr in plugin_*/ ; do
    [ -d "$dr" ] || continue
    dir="${dr%/}"                       # strip trailing slash
    prx="${dir}/${dir}.prx"             # e.g. plugin_server/plugin_server.prx

    if [ -f "$prx" ]; then
        cp -v "$prx" ./
    else
        echo "::warning::$prx not found after build; skipping."
    fi
done
echo "::endgroup::"

# -----------------------------------------------------------------------------
# Sanity check: these are the PRXs the HEN runtime actually loads.
# If any is missing, the corresponding feature won't work on the console,
# so we abort rather than publish a broken release.
# -----------------------------------------------------------------------------
REQUIRED_PRX="plugin_bootloader.prx plugin_loader.prx plugin_mono.prx plugin_server.prx plugin_shellcore.prx"

missing=""
for prx in $REQUIRED_PRX; do
    if [ ! -f "$prx" ]; then
        missing="$missing $prx"
    fi
done

if [ -n "$missing" ]; then
    echo "::error::Missing required PRX files:$missing"
    echo "::error::Each plugin_<name>/ must produce plugin_<name>/plugin_<name>.prx"
    echo "::error::Check the failing plugin's Makefile — it likely writes to a different name or path."
    echo
    echo "--- Repo root .prx files ---"
    ls -la ./*.prx 2>/dev/null || echo "(none)"
    echo
    echo "--- Per-plugin .prx files ---"
    for dr in plugin_*/ ; do
        [ -d "$dr" ] || continue
        echo "$dr:"
        find "$dr" -maxdepth 2 -name '*.prx' -printf '  %p\n' 2>/dev/null || true
    done
    exit 1
fi

echo
echo "All required PRXs present:"
ls -la ./*.prx

echo
echo "Build complete."

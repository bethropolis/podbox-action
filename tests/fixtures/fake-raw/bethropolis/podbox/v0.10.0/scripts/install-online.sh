#!/bin/sh
# Fake podbox installer: installs the stub binary into $PODBOX_BINDIR.
set -eu
mkdir -p "$PODBOX_BINDIR"
cp "$FAKE_PODBOX_SRC" "$PODBOX_BINDIR/podbox"
chmod +x "$PODBOX_BINDIR/podbox"
if [ -n "${FAKE_INSTALLER_LOG:-}" ]; then
  echo "version=$PODBOX_VERSION force=${PODBOX_FORCE:-} bindir=$PODBOX_BINDIR" >"$FAKE_INSTALLER_LOG"
fi

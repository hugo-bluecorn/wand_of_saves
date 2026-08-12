#!/usr/bin/env bash
# Copyright 2026 hugo-bluecorn
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Capture one already-built spike entry point as a PNG of the window alone.
#
#   usage: tool/capture.sh <out.png> [width] [height]
#
# ⚠️ Why not Spectacle, which is the KDE-native tool on this machine: it
# captures the whole desktop. On a live dual-monitor session that means the
# user's browser, media player and everything else land in the image, and the
# app window is buried behind them. `import -window <id>` captures the one
# window, composited, whatever is stacked on top of it.
#
# ⚠️ The app must therefore run as an XWayland client (GDK_BACKEND=x11). That is
# verified to work here: Xwayland is rootless on :0 with a window manager, GTK3
# is built with the x11 backend, and libgdk-3 exports the gdk_x11_* symbols.
#
# ⚠️ Always `pkill -x`, never `pkill -f` — the -f form matches this script's own
# command line and kills the shell running it, which surfaces as exit code 144
# and a command that silently stopped halfway.

set -euo pipefail

OUT=${1:?usage: tool/capture.sh <out.png> [width] [height]}
WIDTH=${2:-1280}
HEIGHT=${3:-720}
BIN=build/linux/x64/debug/bundle/ui_spikes
WINDOW_TITLE='"UI Spike"'

[ -x "$BIN" ] || { echo "not built: $BIN — run flutter build linux --debug -t <entry>"; exit 1; }

pkill -x ui_spikes 2>/dev/null || true
sleep 1

SPIKE_WIDTH="$WIDTH" SPIKE_HEIGHT="$HEIGHT" GDK_BACKEND=x11 \
  setsid "$BIN" >/dev/null 2>&1 </dev/null &
disown

# Bounded wait. An unbounded poll on another process's state becomes immortal
# when that process dies — two were once found still spinning two days later.
for _ in $(seq 1 25); do
  pgrep -x ui_spikes >/dev/null && break
  sleep 1
done
pgrep -x ui_spikes >/dev/null || { echo "spike failed to start"; exit 1; }

sleep 4  # let the first frame land and any animation settle

WID=$(xwininfo -root -tree | grep "$WINDOW_TITLE" \
  | grep -oE '^[[:space:]]+0x[0-9a-f]+' | tr -d ' ' | head -1)
if [ -z "$WID" ]; then
  echo "no X11 window titled $WINDOW_TITLE — is GDK_BACKEND=x11 taking effect?"
  pkill -x ui_spikes || true
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
import -window "$WID" "$OUT"
pkill -x ui_spikes || true
identify "$OUT"

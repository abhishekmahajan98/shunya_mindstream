#!/bin/sh
set -e
# apt-installed libs (libuuid1, libasound2t64, libssl) live here; Nix LD_PATH omits /usr/lib.
export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PYTHONPATH="${PYTHONPATH:-.}"
exec /opt/venv/bin/uvicorn main:app --host 0.0.0.0 --port "${PORT:?PORT not set}"

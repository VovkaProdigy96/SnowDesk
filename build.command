#!/bin/bash
# Двойной клик — собрать и запустить SnowDesk
cd "$(dirname "$0")"
pkill -x SnowDesk 2>/dev/null
sleep 0.5
{ echo "=== $(date) ==="; bash build.sh; echo "EXIT CODE: $?"; } > build.log 2>&1
cat build.log

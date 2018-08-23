#!/usr/bin/env bash

# bash flags
set -e

# validate args
if [ "$#" -ne 1 ]; then
  >&2 echo "usage: $0 config"
  exit 1
fi

# load config
source "$1"

LOG="${CURRENT}/log"
STATE="${CURRENT}/state"

# set dirty state
echo "dirty" > "$STATE"

# backup
echo $(date -u) "backup $SOURCE to $CURRENT" 2>&1 | tee -a "$LOG"
echo $(date -u) rsync -av --delete $RSYNC_ARGS "$SOURCE" "${CURRENT}/data" 2>&1 | tee -a "$LOG"
$RSYNC -av --delete $RSYNC_ARGS "$SOURCE" "${CURRENT}/data" 2>&1 | tee -a "$LOG"
echo $(date -u) "backup done" 2>&1 | tee -a "$LOG"

# touch to reflect date
touch "$CURRENT"

# clear state
echo "done" > "$STATE"


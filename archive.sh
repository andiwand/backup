#!/usr/bin/env bash

# bash flags
set -e

function roll() {
  local NUM=`basename $1`
  local NEXT=$((NUM + 1))
  NEXT="${ARCHIVE_DIR}/$(printf $FORMAT $NEXT)"
  if [ -d "$NEXT" ]; then
    roll "$NEXT"
  fi
  
  local LOG="${1}/log"
  local STATE="${1}/state"
  
  echo $(date -u) "roll backup: $1 to $NEXT" 2>&1 | tee -a "$LOG"
  echo $(date -u) "mv $1 $NEXT" 2>&1 | tee -a "$LOG"
  
  # set dirty state
  echo "dirty roll" > "$STATE"
  
  mv "$1" "$NEXT"
  LOG="${NEXT}/log"
  STATE="${NEXT}/state"
  
  echo $(date -u) "roll done" 2>&1 | tee -a "$LOG"
  
  # clear state
  echo "done" > "$STATE"
}

# validate args
if [ "$#" -ne 1 ]; then
  >&2 echo "usage: $0 config"
  exit 1
fi

# load config
source "$1"

FORMAT="%0${ZERO_PREFIX}d"
CURRENT="${ARCHIVE_DIR}/$(printf $FORMAT 0)"
LOG="${CURRENT}/log"
STATE="${CURRENT}/state"

if [ -d "$CURRENT" ]; then
  echo $(date -u) "roll"
  roll "$CURRENT"
fi

# archive
if [ ! -d "$BACKUP_DIR" ]; then
  >&2 echo $(date -u) "error: backup direcotry not found: $BACKUP_DIR"
  exit 3
fi

if [ `cat "${BACKUP_DIR}/state"` != "done" ]; then
  >&2 echo $(date -u) "error: tryed to archive dirty backup: $BACKUP_DIR"
  exit 4
fi

mkdir -p "${CURRENT}"

# set dirty state
echo "dirty archive" > "$STATE"

cp "${BACKUP_DIR}/log" "$CURRENT"

echo $(date -u) "archive $BACKUP_DIR to $CURRENT" 2>&1 | tee -a "$LOG"
echo $(date -u) "cp -al ${BACKUP_DIR}/data $CURRENT" 2>&1 | tee -a "$LOG"

cp -al "${BACKUP_DIR}/data" "$CURRENT" 2>&1 | tee -a "$LOG"

echo $(date -u) "archive done" 2>&1 | tee -a "$LOG"

# clear state
echo "done" > "$STATE"

# delete old backup
if [ ! -z "$ARCHIVE_COUNT" ]; then
  OLD="${ARCHIVE_DIR}/$(printf $FORMAT $ARCHIVE_COUNT)"
  if [ -d "$OLD" ]; then
    echo $(date -u) "remove old backup: $OLD"
    rm -rf "$OLD"
  fi
fi


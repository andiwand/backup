#!/usr/bin/env bash

# state stays dirty until everything is successfully done
# the backup log should only contain information about the backup itself

# roll backups
function roll() {
  local NUM=`basename $1`
  local NEXT=$((NUM + 1))
  NEXT="${BACKUP_DIR}/$(printf $FORMAT $NEXT)"
  if [ -d "$NEXT" ]; then
    roll "$NEXT"
  fi
  
  local LOG="${1}/log"
  
  echo $(date -u) "roll backup: $1 to $NEXT" 2>&1 | tee -a "$LOG"
  
  if [ "$NUM" -eq 0 ]; then
    mkdir -p "$NEXT"
    find "$1" -maxdepth 1 -type f -exec mv {} "$NEXT" \;
    echo $(date -u) "cp -al ${1}/data $NEXT" 2>&1 | tee -a "$LOG"
    cp -al "${1}/data" "$NEXT"
  else
    echo $(date -u) "mv $1 $NEXT" 2>&1 | tee -a "$LOG"
    mv "$1" "$NEXT"
  fi
}

# validate args
if [ "$#" -ne 1 ]; then
  >&2 echo "usage: $0 config"
  exit 1
fi

# bash flags
set -e
#set -x # debugging

# get script path
SRC="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SRC" )" && pwd )"
  SRC="$(readlink "$SRC")"
  [[ $SRC != /* ]] && SOURCE="$DIR/$SRC"
done
DIR="$( cd -P "$( dirname "$SRC" )" && pwd )"

# load config
source "$DIR/defaults"
source "$1"

FORMAT="%0${ZERO_PREFIX}d"
CURRENT="${BACKUP_DIR}/$(printf $FORMAT 0)"

if [ -d "$CURRENT" ]; then
  if [ ! -z "$DONT_ROLL" ]; then
    echo $(date -u) "roll"
    roll "$CURRENT"
  else
    echo $(date -u) "skipped roll"
  fi
else
  echo $(date -u) "first backup"
  mkdir -p "${CURRENT}/data"
fi

LOG="${CURRENT}/log"
STATE="${CURRENT}/state"

# set dirty state
echo "dirty" > "$STATE"

# backup / archive
if [ "$MODE" == "backup" ]; then
  echo $(date -u) "backup $SOURCE to $CURRENT" 2>&1 | tee -a "$LOG"
  echo $(date -u) rsync -av --delete $RSYNC_ARGS "$SOURCE" "${CURRENT}/data" 2>&1 | tee -a "$LOG"
  rsync -av --delete $RSYNC_ARGS "$SOURCE" "${CURRENT}/data" 2>&1 | tee -a "$LOG"
  echo $(date -u) "backup done" 2>&1 | tee -a "$LOG"
  
  # touch to reflect date
  touch "${CURRENT}"
elif [ "$MODE" == "archive" ]; then
  if [ ! -d "$SOURCE" ]; then
    >&2 echo $(date -u) "error: source direcotry not found: $SOURCE"
    exit 3
  fi
  
  if [ `cat "${SOURCE}/state"` != "done" ]; then
    >&2 echo $(date -u) "error: trying to archive dirty backup: $SOURCE"
    exit 4
  fi
  
  cp "${SOURCE}/log" "$CURRENT" 2>&1 | tee -a "$LOG"
  
  echo $(date -u) "archive $SOURCE to $CURRENT" 2>&1 | tee -a "$LOG"
  cp -al "${SOURCE}/data" "${CURRENT}/data" 2>&1 | tee -a "$LOG"
else
  >&2 echo $(date -u) "error: unknown mode: $MODE"
  exit 2
fi

# clear state
echo "done" > "$STATE"

# delete old backup
if [ ! -z "$COUNT" ]; then
  OLD="${BACKUP_DIR}/$(printf $FORMAT $COUNT)"
  if [ -d "$OLD" ]; then
    echo $(date -u) "remove old backup: $OLD"
    rm -rf "$OLD"
  fi
fi

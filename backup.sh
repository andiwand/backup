#!/bin/bash

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
  
  redirect
  
  echo $(date -u) "roll backup: $1 to $NEXT"
  if [ "$NUM" -eq 0 ]; then
    mkdir -p "${NEXT}/data"
    find "$1" -maxdepth 1 -type f -exec mv {} "$NEXT" \;
    cp -al "${1}/data" "${NEXT}/data"
  else
    mv "$1" "$NEXT"
  fi
  
  undirect
}

# log redirection
function redirect() {
  exec 7>&1
  exec 8>&2
  exec > >(tee -a "$LOG") 2> >(tee -a "$LOG" >&2)
}
function undirect() {
  exec 1>&7 7>&-
  exec 2>&8 8>&-
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
  roll "$CURRENT"
else
  mkdir -p "${CURRENT}/data"
fi

LOG="${CURRENT}/log"
STATE="${CURRENT}/state"

redirect

# set dirty state
echo "dirty" > "$STATE"

# backup / archive
if [ "$MODE" == "backup" ]; then
  echo $(date -u) "backup $SOURCE to $CURRENT"
  echo $(date -u) rsync -av --delete "$SOURCE" "${CURRENT}/data"
  rsync -av --delete $RSYNC_ARGS "$SOURCE" "${CURRENT}/data"
  echo $(date -u) "backup done"
  
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
  
  cp "${SOURCE}/log" "${CURRENT}"
  
  echo $(date -u) "archive $SOURCE to $CURRENT"
  cp -al "${SOURCE}/data" "${CURRENT}/data"
else
  >&2 echo $(date -u) "error: unknown mode: $MODE"
  exit 2
fi

undirect

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


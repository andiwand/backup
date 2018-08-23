#!/usr/bin/env bash

# bash flags
set -e

# validate args
if [ "$#" -ne 1 ]; then
  >&2 echo "usage: $0 config"
  exit 1
fi

# get script path
SRC="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SRC" )" && pwd )"
  SRC="$(readlink "$SRC")"
  [[ $SRC != /* ]] && SOURCE="$DIR/$SRC"
done
DIR="$( cd -P "$( dirname "$SRC" )" && pwd )"

"${DIR}/backup.sh" $1
"${DIR}/archive.sh" $1


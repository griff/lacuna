#!/bin/sh
# resolve links - $0 may be a softlink
PRG="$0"

while [ -h "$PRG" ]; do
  ls=`ls -ld "$PRG"`
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '/.*' > /dev/null; then
    PRG="$link"
  else
    PRG=`dirname "$PRG"`/"$link"
  fi
done

# Get standard environment variables
LACUNA_SRC=`dirname "$PRG"`
export LACUNA_SRC

NANO_TOOLS=/usr/src/tools/tools/nanobsd

if [ -f "${NANO_TOOLS}/nanobsd.sh" ] ; then
  sh ${NANO_TOOLS}/nanobsd.sh -c $LACUNA_SRC/nano.conf $@
else
  echo "nanobsd.sh script not found" 1>&2
  exit 1
fi
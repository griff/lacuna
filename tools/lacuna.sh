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
LACUNA_TOOLS=`dirname "$PRG"`
LACUNA_SRC=$LACUNA_TOOLS/../lacuna
LACUNA_PACKAGE_DIR=/usr/obj/lacuna/Pkg
export LACUNA_TOOLS
export LACUNA_SRC
export LACUNA_PACKAGE_DIR

NANO_TOOLS=/usr/src/tools/tools/nanobsd
FREAK_TOOLS=/usr/src/tools/tools/nanobsd

if [ -f "${NANO_TOOLS}/nanobsd.sh" ] ; then
  sh ${NANO_TOOLS}/nanobsd.sh -c $LACUNA_TOOLS/nano.conf $@
else
  echo "nanobsd.sh script not found" 1>&2
  exit 1
fi

if [ -f "${LACUNA_TOOLS}/freakbsd.sh" ] ; then
  sh ${LACUNA_TOOLS}/freakbsd.sh -c $LACUNA_TOOLS/freak.conf $@
else
  echo "freakbsd.sh script not found" 1>&2
  exit 1
fi
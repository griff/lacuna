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
export LACUNA_TOOLS
export LACUNA_SRC

NANO_TOOLS=/usr/src/tools/tools/nanobsd

if [ -f "${NANO_TOOLS}/nanobsd.sh" ] ; then
  sh ${NANO_TOOLS}/nanobsd.sh -c $LACUNA_TOOLS/nano.conf $@
  #cd $NANO_WORLDDIR do
    #sh mkisofs -J -R -no-emul-boot -b boot/cdboot -iso-level 3 -o nanobsd.iso .
  #end
else
  echo "nanobsd.sh script not found" 1>&2
  exit 1
fi
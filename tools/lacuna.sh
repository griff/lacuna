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

mtree -cip Files -k uname,gname,mode | sed "s/date\:.*//" > $LACUNA_TOOLS/Files.mtree
cd $LACUNA_SRC
rake template:mtree
cd -

# shell output
warn() { echo "$@" >&2; }
die() { warn "$@"; exit 1; }

git_is_clean_working_tree() {
        if ! git diff --no-ext-diff --ignore-submodules --quiet --exit-code; then
                return 1
        elif ! git diff-index --cached --quiet --ignore-submodules HEAD --; then
                return 2
        else
                return 0
        fi
}

require_clean_working_tree() {
        git_is_clean_working_tree
        local result=$?
        if [ $result -eq 1 ]; then
                die "fatal: Working tree contains unstaged changes. Aborting."
        fi
        if [ $result -eq 2 ]; then
                die "fatal: Index contains uncommited changes. Aborting."
        fi
}
require_clean_working_tree

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
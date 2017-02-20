#!/bin/sh

###
 # Copyright (c) 2017 d-r-p <d-r-p@users.noreply.github.com>
 #
 # Permission to use, copy, modify, and distribute this software for any
 # purpose with or without fee is hereby granted, provided that the above
 # copyright notice and this permission notice appear in all copies.
 #
 # THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 # WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 # MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 # ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 # WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 # ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 # OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
###

### define programs

SED="/bin/sed"
CP="/bin/cp"
MV="/bin/mv"
CHMOD="/bin/chmod"
MKDIR="/bin/mkdir"

THIS="`echo "$0" | $SED 's/.*\/\([^\/]*\)/\1/'`"

### defines files

IDMAPPING="idmapping.py"
IDMAPPINGSETUP="idmappingsetup.xml"
RUNIDMAPPING="runidmapping.sh"
RULEFILE="rule_to_set_cronjob_for_author_idmapping_export.rule"
RULECOMPONENTFILE="component_to_set_cronjob_for_author_idmapping_export.rulecomponent"

### define path components

INSTALLPATH_PRE="/var/www/html/sites" # no final slash!
INSTALLPATH_POST="files" # no final slash!

### define constants

DOPTNOTINVOKED=1
IOPTNOTINVOKED=1
NOPTNOTINVOKED=1
POPTNOTINVOKED=1
UOPTNOTINVOKED=1
DIR="/var/www/html/sites/institute/files" # this value here is just the default and will not be used
INSTITUTE="institute" # this value here is just the default and will not be used
NAME="DORA Institute" # this value here is just the default and will not be used
PORT="8080" # this value here is just the default and will not be used
UUID="00000000-0000-0000-0000-000000000000" # this value here is just the default and will not be used

### define help strings

USAGE="$THIS [-d directory] [-h] -i institute [-n name] [-p port] -u uuid"
usage() {
  echo "$USAGE" >&2
  exit 1
}

HELP="\t-d directory\t Override the default installation
\t\t\t directory (optional)
\t-h\t\t Display this message
\t-i institute\t Specify the institute's subsite-name (mandatory)
\t-n name\t\t Specify the institute's display-name (optional)
\t-p port\t\t Overide the default port (optional)
\t-u uuid\t\t Specify the uuid (mandatory)"

### parse command line options

# getopts-parsing inspired by https://blog.mafr.de/2007/08/05/cmdline-options-in-shell-scripts/ ;
# see also, e.g., http://www.gnu.org/software/bash/manual/bashref.html#Bourne-Shell-Builtins

while getopts "d:hi:n:p:u:" O
do
  case "$O" in
    d) # specify the directory to use instead of '/var/www/html/sites/<institute>/files/'
      DOPTNOTINVOKED=0
      DIR="$OPTARG"
      ;;
    h) # help
      echo "$USAGE"
      echo "$HELP"
      exit 0
      ;;
    i) # specify the institute (aka. subsite)
      IOPTNOTINVOKED=0
      INSTITUTE="$OPTARG"
      ;;
    n) # specify the institute's display-name
      NOPTNOTINVOKED=0
      NAME="$OPTARG"
      ;;
    p) # specify the port to use instead of '8080'
      POPTNOTINVOKED=0
      PORT="$OPTARG"
      ;;
    u) # specify the uuid (format 8-4-4-4-12 digits, dash-separated)
      UOPTNOTINVOKED=0
      UUID="$OPTARG"
      ;;
    \?) # unknown option, so show the usage and exit
      echo "Error: Unknown option -$O" >&2
      usage
      ;;
  esac
done

shift $(($OPTIND - 1))

if [ $# -ne 0 ]
then
  echo "Error: Did not expect any argument" >&2
  usage
fi

if [ $IOPTNOTINVOKED -ne 0 ] || [ -z "$INSTITUTE" ]
then
  echo "Error: You need to specify an institute" >&2
  exit 1
fi
  
if [ $UOPTNOTINVOKED -ne 0 ] || [ -z "$UUID" ]
then
  echo "Error: You need to specify a uuid" >&2
  exit 1
fi

if [ -z "`echo "$INSTITUTE" | $SED '/[^a-zA-Z0-9_-.~]/ d; /^\./ d;'`" ]
then
  echo "Error: I do not believe that your institute's subsite has those weird characters: \"$INSTITUTE\"! Please rename it, patch $THIS or install manually" >&2
  exit 1
fi

if [ -z "`echo "$UUID" | $SED '/^[0-9A-Za-z]\{8\}-[0-9A-Za-z]\{4\}-[0-9A-Za-z]\{4\}-[0-9A-Za-z]\{4\}-[0-9A-Za-z]\{12\}$/! d;'`" ]
then
  echo "Error: \"$UUID\" does not seem to me like a valid uuid" >&2
  exit 1
fi

if [ -z "`echo "$PORT" | $SED '/^[0-9]\+$/! d;'`" ] || [ $PORT -lt 1 ] || [ $PORT -gt 65535 ]
then
  echo "Error: Invalid port \"$PORT\"" >&2
  exit 1
fi

### check for necessary files

for f in "$IDMAPPING" "$IDMAPPINGSETUP" "$RUNIDMAPPING" "$RULEFILE" "$RULECOMPONENTFILE"
do
  if [ ! -f "$f" ] || [ ! -r "$f" ]
  then
    echo "Error: Missing or unreadable file \"$f\"" >&2
    exit 1
  fi
done

### define constants according to setup

INSTALLPATH="$INSTALLPATH_PRE""/""$INSTITUTE""/""$INSTALLPATH_POST""/"

if [ $DOPTNOTINVOKED -eq 0 ]
then
  INSTALLPATH="`echo "$DIR" | $SED 's/^$/./; /^\/$/! s/\/$//;'`"
fi

for var in "IDMAPPING" "IDMAPPINGSETUP" "RUNIDMAPPING" "RULEFILE" "RULECOMPONENTFILE"
do
  fstr="$""$var"
  ifvstr="INST""$var"
  ifstr="$""$ifvstr"
  f=`eval echo "$fstr"`
  eval "$ifvstr""=""`echo "$f" | $SED 's/^\(.*\)\(\.[^.]\+\)$/\1-$INSTITUTE\2/'`"
#  if=`eval echo "$ifstr"`
done
INSTIDMAPPING="$IDMAPPING" # overriding, since we do not need an institute-specific copy

### check the install path

if [ ! -d "$INSTALLPATH" ] || [ ! -w "$INSTALLPATH" ]
then
  echo "Error: Missing or unwritable installation path \"$INSTALLPATH\"" >&2
  exit 1
fi

if [ -d "$INSTALLPATH""/""$UUID" ] && [ ! -w "$INSTALLPATH""/""$UUID" ]
then
  echo "Error: Unwritable installation path \"$INSTALLPATH/$UUID\"" >&2
  exit 1
fi

### create the uuid directory, if necessary

if [ ! -d "$INSTALLPATH""/""$UUID" ]
then
  $MKDIR "$INSTALLPATH""/""$UUID"
  if [ $? -ne 0 ]
  then
    echo "Error: Could not create directory \"$INSTALLPATH/$UUID\"" >&2
    exit 1
  fi
fi

### install the files to destination

for var in "IDMAPPING" "IDMAPPINGSETUP" "RUNIDMAPPING" "RULEFILE" "RULECOMPONENTFILE"
do
  fstr="$""$var"
  ifvstr="INST""$var"
  ifstr="$""$ifvstr"
  f=`eval echo "$fstr"`
  if=`eval echo "$ifstr"`
  DONOTSKIP=1
  if [ "$var" = "IDMAPPING" ] && [ -f "$INSTALLPATH""/""$UUID""/""$if" ]
  then
    DONOTSKIP=0
  fi
  if [ $DONOTSKIP -ne 0 ]
  then
    $CP -p "$f" "$INSTALLPATH""/""$UUID""/""$if"
  fi
  if [ $? -ne 0 ]
  then
    echo "Error: Could not copy \"$f\" to \"$INSTALLPATH/$UUID/$if\"" >&2
    exit 1
  fi
done

### consolidate file permissions

CHMODERRORS=0

$CHMOD u+x "$INSTALLPATH""/""$UUID""/""$INSTIDMAPPING" || CHMODERRORS=1
if [ $CHMODERRORS -ne 0 ]
then
  echo "Warning: Could not make \"$INSTALLPATH/$UUID/$INSTIDMAPPING\" user-executable" >&2
fi
$CHMOD u+x "$INSTALLPATH""/""$UUID""/""$INSTRUNIDMAPPING" || CHMODERRORS=1
if [ $CHMODERRORS -ne 0 ]
then
  echo "Warning: Could not make \"$INSTALLPATH/$UUID/$INSTRUNIDMAPPING\" user-executable" >&2
fi

### modify the files according to the chosen institute-name, uuid and optional options

SEDERRORS=0

$SED -i '/^  <INSTITUTE>institute\|^  <NAMESPACE>institute\|^  <SUBSITE>institute\|^  <PATH>\/var\/www\/html\/sites\/institute\|^  <FILENAME>institute\|^  <ROOTKEY>institute/ s/institute/'"$INSTITUTE"'/' "$INSTALLPATH""/""$UUID""/""$INSTIDMAPPINGSETUP" || SEDERRORS=1
$SED -i '/^  <UUID>00000000-0000-0000-0000-000000000000\|00000000-0000-0000-0000-000000000000<\/PATH>$/ s/00000000-0000-0000-0000-000000000000/'"$UUID"'/' "$INSTALLPATH""/""$UUID""/""$INSTIDMAPPINGSETUP" || SEDERRORS=1
$SED -i '/^  <\([A-Z]\+\)>.*<\/\1>$/ { /INSTITUTE\|UUID/ n; s/^  <\(.*\)>$/  <!--\1-->/}' "$INSTALLPATH""/""$UUID""/""$INSTIDMAPPINGSETUP" || SEDERRORS=1

$SED -i '/^IDMAPPINGSETUPFILE=".\/'"$IDMAPPINGSETUP"'"/ s/'"$IDMAPPINGSETUP"'/'"$INSTIDMAPPINGSETUP"'/' "$INSTALLPATH""/""$UUID""/""$INSTRUNIDMAPPING" || SEDERRORS=1

$SED -i '/\$namespace = \\u0022institute-authors\\u0022;/ s/institute/'"$INSTITUTE"'/' "$INSTALLPATH""/""$UUID""/""$INSTRULEFILE" || SEDERRORS=1

$SED -i 's/00000000-0000-0000-0000-000000000000\\\/'"$RUNIDMAPPING"'/'"$UUID"'\\\/'"$INSTRUNIDMAPPING"'/' "$INSTALLPATH""/""$UUID""/""$INSTRULECOMPONENTFILE" || SEDERRORS=1

if [ $DOPTNOTINVOKED -eq 0 ]
then
  INSTALLPATH_ESCAPED="`echo $INSTALLPATH | $SED 's/\//\\\\\//g;'`"
  $SED -i 's/^  <!--PATH>\/var\/www\/html\/sites\/'"$INSTITUTE"'\/files\/'"$UUID"'<\/PATH-->$/  <PATH>'"$INSTALLPATH_ESCAPED"'\/'"$UUID"'<\/PATH>/' "$INSTALLPATH""/""$UUID""/""$INSTIDMAPPINGSETUP" || SEDERRORS=1
  $SED -i 's/\$_SERVER\[\\u0027DOCUMENT_ROOT\\u0027\] . \$base_path . \\u0022sites\\\/\\u0022 . $subsite . \\u0022\\\/files/\\u0022'"$INSTALLPATH_ESCAPED"'/' "$INSTALLPATH""/""$UUID""/""$INSTRULECOMPONENTFILE" || SEDERRORS=1
fi

if [ $NOPTNOTINVOKED -eq 0 ]
then
  NAME_ESCAPED="`echo $NAME | $SED 's/\//\\\\\//g;'`"
  $SED -i 's/variable_get(\\u0027site_name\\u0027, \\u0027DORA Institute\\u0027);/variable_get(\\u0027site_name\\u0027, \\u0027'"$NAME_ESCAPED"'\\u0027);/' "$INSTALLPATH""/""$UUID""/""$INSTRULECOMPONENTFILE" || SEDERRORS=1
fi

if [ $POPTNOTINVOKED -eq 0 ]
then
  $SED -i 's/^  <!--SOLRBASEURL>http:\/\/localhost:8080\/solr\/collection1\/select<\/SOLRBASEURL-->$/  <SOLRBASEURL>http:\/\/localhost:'"$PORT"'\/solr\/collection1\/select<\/SOLRBASEURL>/' "$INSTALLPATH""/""$UUID""/""$INSTIDMAPPINGSETUP" || SEDERRORS=1
fi

if [ $SEDERRORS -ne 0 ]
then
  echo "Warning: Not all necessary modifications could be made. Please check and modify manually all the files in \"$INSTALLPATH/$UUID\""
fi

if [ $CHMODERRORS -ne 0 ] || [ $SEDERRORS -ne 0 ]
then
  exit 1
fi

exit 0
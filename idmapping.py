#!/usr/bin/python

###
 # Copyright (c) 2016, 2017 d-r-p <d-r-p@users.noreply.github.com>
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

### load stuff we need

import os
import codecs
import requests
import xmltodict
import sys
from optparse import OptionParser
from time import gmtime, strftime

### some constants

STDIN   = sys.stdin  #'/dev/stdin'
STDOUT  = sys.stdout #'/dev/stdout'
testing = True
testing = False # uncomment this if you are done testing

timestamp = strftime('%Y%m%dT%H%M%SZ', gmtime())

### redirect all output to stderr

oldstdout = sys.stdout
sys.stdout = sys.stderr

### say that we are testing, if we are

if testing:
  print "Notice: Testing mode is active!"

### parse (and validate) the command line

if testing:
  print "Notice: Called \"" + " ".join(sys.argv) + "\""

usage = "Usage: %prog [-v] [-b] [-s SETUP.xml]"
parser = OptionParser(usage)
parser.add_option("-v", "--verbose",
  action = "store_true", dest = "verbose", default = False,
  help = "Show what I'm doing [default=false]")
parser.add_option("-b", "--backup",
  action = "store_true", dest = "backup", default = False,
  help = "Backup the output immediately [default=false]")
parser.add_option("-s", "--setup", nargs = 1,
  action = "store", dest = "setupfile",
  metavar = "SETUP.xml", help = "Specify the setup file")
  
(opts, args) = parser.parse_args()

verbose = testing or opts.verbose # always be verbose while testing

if verbose:
  print "Notice: Parsing the command line"

backup = opts.backup

if len(args) > 0:
  parser.error("Expected no input file!")

if not opts.setupfile:
  setupfile = None
else:
  setupfile = opts.setupfile

if setupfile and not setupfile.endswith(".xml"):
  print "The setup file should end in \".xml\"! Aborting..."
  exit(1)

if setupfile and not os.access(setupfile, os.R_OK):
  parser.error("It seems I cannot access the setup file \"" + setupfile + "\"!")

### parsing the setup file, if any

if setupfile:
  if verbose:
    print "Notice: Parsing the setup file"
  setup_fd = codecs.open(setupfile, "r", "utf8")

  try:
    if int(xmltodict.__version__.replace(".","")) > 45:
      setup_dict = xmltodict.parse(setup_fd.read(), encoding="utf-8")
    else:
      setup_dict = xmltodict.parse(setup_fd.read()) # this means, we should avoid unicode characters in the setup file!!!
  finally:
    if verbose:
      print "Notice: Successfully read " + setupfile + " and created the corresponding dictionary."
  setup_fd.close()

  if "IDMAPPINGSETUP" in setup_dict and "#text" in setup_dict["IDMAPPINGSETUP"] and setup_dict["IDMAPPINGSETUP"]["#text"].strip() == "":
    del setup_dict["IDMAPPINGSETUP"]["#text"] # this is to account for old xmltodict-versions
  if not "IDMAPPINGSETUP" in setup_dict or any([k not in ["INSTITUTE", "NAMESPACE", "UUID", "SUBSITE", "PATH", "FILENAME", "SRCIDKEY", "SOLRFIELDSRCID", "DESIDKEY", "SOLRFIELDDESID", "SOLRBASEURL", "ROOTKEY", "CONTAINERKEY"] for k in setup_dict["IDMAPPINGSETUP"]]):
    print "Error: Wrong format! Please provide a valid setup file!"
    exit (1)

def get_setup_val (key):
  if not setupfile:
    return None
  global setup_dict
  vals = setup_dict["IDMAPPINGSETUP"]
  if key in vals and isinstance(vals[key], basestring):
    return vals[key]
  return None

setup_institute = get_setup_val("INSTITUTE")
setup_snamespace = get_setup_val("NAMESPACE")
setup_uuid = get_setup_val("UUID")
setup_subsite = get_setup_val("SUBSITE")
setup_path = get_setup_val("PATH")
setup_outfile = get_setup_val("FILENAME")
setup_skey = get_setup_val("SRCIDKEY")
setup_ssid = get_setup_val("SOLRFIELDSRCID")
setup_dkey = get_setup_val("DESIDKEY")
setup_sdid = get_setup_val("SOLRFIELDDESID")
setup_base_url = get_setup_val("SOLRBASEURL")
setup_rootkey = get_setup_val("ROOTKEY")
setup_containerkey = get_setup_val("CONTAINERKEY")

### define institute (default is institute)
### (N.B.: if only institute is set, the default behaviour requires namespaces, subsites and subdirectories of the same name!
###  E.g., institute="INSTITUTE" => namespace="INSTITUTE-authors", subsite="INSTITUTE", path="/var/www/html/sites/INSTITUTE/files/...")

institute = (setup_institute if setup_institute else "institute")

### define namespace restriction (default is institute+"-authors")

snamespace = (setup_snamespace if setup_snamespace else institute + "-authors")

### define uuid to "hide" the output [security by obscurity!] (default is 00000000-0000-0000-0000-000000000000; use 'uuidgen -r' to generate a random one)

uuid = (setup_uuid if setup_uuid else "00000000-0000-0000-0000-000000000000")

### define subsite (default is institute; blank means no subsite, which puts "default" in the path)

subsite = (setup_subsite if setup_subsite else institute)

### define path (default is "/var/www/html/sites/"+subsite+"/files/"+uuid)

path_pre = ("./" if testing else "/var/www/html/sites/" + (subsite + "/" if subsite and subsite != "" else "default/") + "files/") # always store in current directory when testing
path = (setup_path if setup_path else (path_pre + uuid))

if not os.access(path, os.W_OK):
  if not setup_path and not os.access(path, os.F_OK) and os.access(path_pre, os.F_OK):
    if not os.access(path_pre, os.W_OK):
      parser.error("Cannot create directory in \"" + path_pre + "\" for you!")
    try:
      os.mkdir(path)
    except:
      parser.error("Could not create \"" + path + "\"!")
if not os.access(path, os.W_OK):
  parser.error("It seems I will not be able to write to \"" + path + "\"!")

### define output file name (default is snamespace+".xml")

outfile = (setup_outfile if setup_outfile else snamespace + ".xml")

### define the xml-keys for the ids (defaults are DORAid and SAPid, respectively)

skey = (setup_skey if setup_skey else "DORAid")
dkey = (setup_dkey if setup_dkey else "SAPid")

### define solr fields (defaults are PID and MADS_u1_ms, respectively)

ssid = (setup_ssid if setup_ssid else "PID") # DORA-id
sdid = (setup_sdid if setup_sdid else "MADS_u1_ms") # SAP-id

### define url for access to DORA via solr (default is http://localhost:8080/solr/collection1/select)

base_url = (setup_base_url if setup_base_url else "http://localhost:8080/solr/collection1/select")

### define container xml-keys

rootkey = (setup_rootkey if setup_rootkey else snamespace)
containerkey = (setup_containerkey if setup_containerkey else "IDmapping")

### construct the query

q               = "*:*"
fq              = ssid + ":" + snamespace + "\:*"
fl_list         = []
fl_list.append(ssid)
fl_list.append(sdid)
fl              = ", ".join(fl_list)
sort            = ssid + " asc"
rows            = (20 if testing else 50000)
wt              = "xml"
indent          = "true"
payload = {'q': q, 'fq': fq, 'sort': sort, 'fl': fl, 'rows': rows, 'wt': wt, 'indent': indent}

### query DORA

if verbose:
  print "Notice: Querying database"

r = requests.get(base_url, params=payload)
if r.status_code != 200:
  print "Error: Something went wrong (got HTTP" + str(r.status_code) + ")...";
  exit(1)
r_dict = xmltodict.parse(r.text)

if int(r_dict["response"]["result"]["@numFound"]) > rows:
  print "Warning: Not all " + r_dict["response"]["result"]["@numFound"] + " items were taken... Try increasing the value of 'rows'."

solr_aos = r_dict["response"]["result"]["doc"]
# catch the case where ao is not an array of objects like {"str": str, "arr": arr}
if isinstance(solr_aos, dict):
  solr_aos = [solr_aos]

### generate author objects

if verbose:
  print "Notice: Generating id mappings"

export_aos = []
for ao in solr_aos:
  mysid  = ''
  if not "str" in ao:
    print "Warning: It seems there is an item without " + skey + "! Skipping...";
    continue
  # catch the case where s is not an array of objects like {"@name": name} but just one such object
  if isinstance(ao["str"], dict):
    ao["str"] = [ao["str"]]
  for s in ao["str"]:
    if s["@name"] == ssid:
      mysid = s["#text"]
  if mysid != '':
    # exclude the collection object
    if mysid.replace(snamespace + ":", "") == "collection":
      continue
  mydid = [""]
  if not "arr" in ao:
    if verbose: # we print this message not by default, since it is very common
      print "Warning: It seems that object " + mysid + " has no " + dkey + "!";
  else:
    # catch the case where a is not an array of objects like {"@name": name, "str": str} but just one such object
    if isinstance(ao["arr"], dict):
      ao["arr"] = [ao["arr"]]
    for a in ao["arr"]:
      if a["@name"] == sdid:
        mydid = a["str"]
    # catch the case we only have one SAP-id (as we should), so that the next instruction works
    if isinstance(mydid, basestring):
      mydid = [mydid]
    if len(mydid) > 1:
      print "Warning: Object " + mysid + " has more than one " + dkey + "!";
  export_aos.append({skey: mysid, dkey: mydid})

### sorting result

export_aos = sorted(export_aos, key=lambda t: int(t[skey].replace(snamespace+":", "")))

### write items to utf8 xml file, prettyfied

f = codecs.open(path + "/" + outfile, "w", "utf8")
pub_db = {rootkey: {'@ts': timestamp, containerkey: export_aos}}
try:
  if int(xmltodict.__version__.replace(".", "")) >= 60:
    f.write(xmltodict.unparse(pub_db, encoding='utf-8', pretty=True, indent='  '))
  else:
    f.write(xmltodict.unparse(pub_db, encoding='utf-8')) # this means that the resulting xml will be ugly as hell!
finally:
  if verbose:
    print "Notice: Successfully exported " + str(len(export_aos)) + " items to " + path + "/" + outfile
  f.close()

### prettify the output xml, if necessary and possible (N.B.: requires libxml2-utils to be installed in your system)

if int(xmltodict.__version__.replace(".", "")) < 60 and os.system("/usr/bin/test -f /usr/bin/xmllint") == 0:
  if verbose:
    print "Notice: Prettifying the output-xml..."
  cmd  = '/usr/bin/test -f ' + path + '/' + outfile
  cmd += ' && /bin/cp -p ' + path + '/' + outfile + ' ' + path + '/' + outfile + '.ugly'
  cmd += ' && /usr/bin/xmllint --format ' + path + '/' + outfile + '.ugly > ' + path + '/' + outfile
  cmd += ' && /bin/rm ' + path + '/' + outfile + '.ugly'
  if os.system(cmd) == 0:
    if verbose:
      print "Notice: Successfully prettified the output"
  else:
    print "Warning: Something went wrong while prettifying the output"

### backup file, if required

if backup:
  cmd = '/usr/bin/test -f ' + path + '/' + outfile + ' && /bin/mv ' + path + '/' + outfile + ' ' + path + '/' + outfile + '.' + timestamp
  os.system(cmd)
  cmd = '/usr/bin/test ! -f ' + path + '/' + outfile + ' && /bin/cp -p ' + path + '/' + outfile + '.' + timestamp + ' ' + path + '/' + outfile
  os.system(cmd)

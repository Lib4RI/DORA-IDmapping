# DORA--IDmapping


## Introduction

A toolchain to export the mapping between two id's (e.g. PIDs and SAP--numbers) related to certain islandora entities (e.g. authors)


## Requirements

This toolchain assumes that you have the following installed on your server (it might work with different versions, but was not tested):

* [python](https://www.python.org) (2.6.6)
* [Apache](https://www.apache.org) (2.2.15)
* [php](https://secure.php.net) (5.3.3)
* [Drupal](https://www.drupal.org) (7.51)
* [Islandora](https://github.com/islandora/islandora) ([7.x-dev](https://github.com/Islandora/islandora/commit/14c8c68b4dcce4aca3f578e0daad4c2aa1951bed))


## Installation

In the following, we shall assume that you want to install the toolchain on your drupal-substite "institute". Words in angle brackets indicate the respective values you have decided on (do not forget to insert the values that apply to your installation). Although you can install this differently, we explain only one easy version that suited our needs.

N.B.: _This toolchain needs to be patched manually if you wish to use it for entities other than authors..._

1. Decide on a uuid (you may generate a random one using `/usr/bin/uuidgen -r`) and a file path (these installation instructions assume `/var/www/html/sites/<institute>/files/`) and have your IT department restrict access to `$base_url/sites/<institute>/files/<uuid>` (allow only your personal workstations and those servers that need the exported information). Here, `$base_url` refers to the url from which your subsite is accessed from the outside (say, `https://<islandora.somewhere.com>/<institute>`).

2. Go to `/var/www/html/sites/<institute>/files/` and clone this repository into the `<uuid>` folder (you will need to let github know your ssh-key<font size="-1"><sup><a name="dagger_caller"></a>[&dagger;](#dagger_callee)</sup></font>!):
   ```
   cd /var/www/html/sites/<institute>/files/
   if [ -z "$SSH_AUTH_SOCK" ]; then eval $(ssh-agent -s); fi
   ssh-add ~/.ssh/<your_id_rsa_github_key>
   /usr/bin/sudo SSH_AUTH_SOCK=$SSH_AUTH_SOCK /usr/bin/git clone git@github.com:/path/to/this/repo/idmapping.git ./<uuid>/
   ```
   Note that you could clone the repository to any destination; the install script will copy the necessary files to the necessary destination. Watch out for filesystem permissions!

3. Enter the `<uuid>`-directory, change file ownerships and install
   ```
   cd <uuid>
   /usr/bin/sudo /bin/chown -R apache.apache {*,.g*}
   /usr/bin/sudo -u apache ./installidmapping.sh -i <institute> -u <uuid> -n <InstituteName> -p <port>
   ```
   Here, `<InstituteName>` refers to the display name of `<institute>` and `<port>` to the port through which solr can be accessed on your server. Both parameters are optional and default to "DORA Institute" and "8080", respectively.

   The above command will create all the necessary files in `<uuid>`; the generated files all have the suffix `-<institute>`, with the exception of `idmapping.py` (note that those files are copies of the unsuffixed files, but including the necessary modifications to reflect the choices of `<institute>`, `<uuid>`, etc...; be careful that this might not work for you --- the install script is intended to work on *our* installation).

4. Go to `https://<islandora.somewhere.com>/<institute>/admin/config/workflow/rules/components` and import the component `component_to_set_cronjob_for_author_idmapping_export-<institute>.rulecomponent`.

5. Go to `https://<islandora.somewhere.com>/<institute>/admin/config/workflow/rules` and import the rule `rule_to_set_cronjob_for_author_idmapping_export-<institute>.rule`.

6. Test the installation as follows:

   1. Inside `/var/www/html/sites/<institute>/files/<uuid>` execute
      ```
      ls -laFh
      ```
      and verify that all files are owned by user `apache` and that `idmapping.py` and `runidmapping-<institute>.sh` are user-executable.

   2. Inside `/var/www/html/sites/<institute>/files/<uuid>` execute
      ```
      /usr/bin/sudo -u apache /usr/bin/crontab -l
      /usr/bin/sudo -u apache ./runidmapping-<institute>.sh -v -b -a
      /usr/bin/sudo -u apache /usr/bin/crontab -l
      ```
      You should see an addition line in the crontab that executes `runidmapping-<institute>.sh` twice.

   3. Inside `/var/www/html/sites/<institute>/files/<uuid>` execute
      ```
      /usr/bin/sudo -u apache /usr/bin/crontab -l
      /usr/bin/sudo -u apache ./runidmapping-<institute>.sh -v -b -c
      /usr/bin/sudo -u apache /usr/bin/crontab -l
      ```
      The addition line in the crontab should have disappeared.

   4. Inside `/var/www/html/sites/<institute>/files/<uuid>` execute
      ```
      /usr/bin/sudo -u apache ./runidmapping-<institute>.sh -v -b
      ls
      ```
      You should see the two files `<institute>-authors.xml` and `<institute>-authors.xml.<timestamp>`, as well as the log-file `idmapping.log.<timestamp>`, where `<timestamp>` is the UTC timestamp of execution (in the format "`YYYYmmddTHHMMSSZ`"; note that the timestamps of the two files will differ by a few seconds).

   5. Add an author-object and check if a line in the crontab that executes `runidmapping-<institute>.sh` twice has been created (use `/usr/bin/sudo -u apache /usr/bin/crontab -l`) --- you can delete apache's crontab with `/usr/bin/sudo -u apache /usr/bin/crontab -r` and re-do the test for other scenarios like modifying or deleting an author-object.

   6. Trigger the creation of the abovementioned line in crontab (add, modify or delete an author-object, or run `/var/www/html/sites/<institute>/files/<uuid>/runidmapping-<institute>.sh -v -b -a`) and wait for 11:45pm to see if the file `/var/www/html/sites/<institute>/files/<uuid>/<institute>-authors.xml` gets re-created.


<font size="-1"><sup><a name="dagger_callee"></a>[&dagger;](#dagger_caller)</sup>You can generate a new ssh-key by executing, e.g., `ssh-keygen -t rsa -b 4096 "<your-github-username>@users.noreply.github.com -f ~/.ssh/id_rsa_github`. Afterwards, make sure to upload the public key file (`~/.ssh/id_rsa_github.pub`) to [https://github.com/settings/keys](https://github.com/settings/keys) (log in first).</font>


## Output

The file `<institute>-authors.xml`, generated when following the above installation instructions, has the following format:
```xml
<?xml version="1.0" encoding="utf-8"?>
<institute-authors ts="YYYYmmddTHHMMSSZ">
  <IDmapping>
    <DORAid>institute-authors:NNNN</DORAid>
    <SAPid>NNNN</SAPid>
  </IDmapping>
  .
  .
  .
</institute-authors>
```
Here, `NNNN` stands for any number of digits and the literal "`institute`" is replaced by your choice of `<institute>` (including in the tag-name, which might generate a non-conforming `xml`-file if `<institute>` contains weird characters).

## Files

### `.gitignore`

The file is such that the repository only contains the generic files (where `<institute>`="`institute`", `<uuid>`="`00000000-0000-0000-0000-000000000000`", etc...), as well as itself. Specifically, it contains
```
/*

!/.gitignore
!/README.md
!/LICENSE.md
!/idmapping.py
!/idmappingsetup.xml
!/runidmapping.sh
!/rule_to_set_cronjob_for_author_idmapping_export.rule
!/component_to_set_cronjob_for_author_idmapping_export.rulecomponent
!/installidmapping.sh
```

### `README.md`

This file...

### `LICENSE.md`

The license under which the toolchain is distributed:
```
Copyright (c) 2017 d-r-p <d-r-p@users.noreply.github.com>

Permission to use, copy, modify, and distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
```

### `idmapping.py`

The python-script responsible for the export.

Usage: `idmapping.py [-v] [-b] [-s setup.xml]`
* `-v`: Be verbose about what the script is doing
* `-b`: Immediately create a backup copy of the exported file (the default filename is `<institute>-authors.xml`; an additional copy with suffix `.<timestamp>` will be created)
* `-s setup.xml`: Provide an xml-file with various customisations (see `idmappingsetup.xml` below)

### `idmappingsetup.xml`

This is the dummy setup file that, after modification by the installer script `installidmapping.sh`, will be given to `idmapping.py`. It contains a short explanatory header, as well as the default values for each setting (meaning that there is no need to hand over this file as is to `idmapping.py`):
```xml
<?xml version="1.0" encoding="utf8"?>
<IDMAPPINGSETUP>
  <!--
    REMARKS REGARDING THE TAGS:
    - Each of the following tags is optional and defaults to (lowercase tags refer to the current setting):
      - <INSTITUTE>:       institute
      - <NAMESPACE>:       <institute>-authors
      - <UUID>:            00000000-0000-0000-0000-000000000000
      - <SUBSITE>:         <institute>
      - <PATH>:            /var/www/html/sites/<subsite>/files/<uuid> (if <subsite> is blank, "default" will be substituted in the path)
      - <FILENAME>:        <namespace>.xml
      - <SRCIDKEY>:        DORAid
      - <SOLRFIELDSRCID>:  PID
      - <DESIDKEY>:        SAPid
      - <SOLRFIELDDESID>:  MADS_u1_ms
      - <SOLRBASEURL>:     http://localhost:8080/solr/collection1/select
      - <ROOTKEY>:         <namespace>
      - <CONTAINERKEY>:    IDmapping

    EXAMPLES:
    - <INSTITUTE>marsuniversity</INSTITUTE>
      <UUID>45cf5181-b077-4e94-b021-e2ccf39508a0</UUID>
    - <INSTITUTE>institute</INSTITUTE>
      <SUBSITE></SUBSITE>
      <NAMESPACE>people</NAMESPACE>
      <FILENAME>out.xml</FILENAME>
  -->
  <INSTITUTE>institute</INSTITUTE>
  <NAMESPACE>institute-authors</NAMESPACE>
  <UUID>00000000-0000-0000-0000-000000000000</UUID>
  <SUBSITE>institute</SUBSITE>
  <PATH>/var/www/html/sites/institute/files/00000000-0000-0000-0000-000000000000</PATH>
  <FILENAME>institute-authors.xml</FILENAME>
  <SRCIDKEY>DORAid</SRCIDKEY>
  <SOLRFIELDSRCID>PID</SOLRFIELDDORAID>
  <DESIDKEY>SAPid</DESIDKEY>
  <SOLRFIELDDESID>MADS_u1_ms</SOLRFIELDSAPID>
  <SOLRBASEURL>http://localhost:8080/solr/collection1/select</SOLRBASEURL>
  <ROOTKEY>institute-authors</ROOTKEY>
  <CONTAINERKEY>IDmapping</CONTAINERKEY>
</IDMAPPINGSETUP>
```

### `runidmapping.sh`

This is the wrapper script that invokes `idmapping.py` and modifies the crontab.

Usage: `runidmapping.sh [-v] [-b] [-a|-c|-g]`
* `-v`: Be verbose (transitively!)
* `-b`: Make a backup of the generated file (transitively!)
* `-a`: Schedule the cronjob next 11:45pm
* `-c`: Clean-up crontab (remove all references to executing `runidmapping.sh` with the chosen options)
* `-g`: Get the cron-command

Be careful that transitivity only works if the script is invoked in exactly the same way (also, mind the order of switches). E.g., `runidmapping.sh -b -c` requires the cronjob to have been added via `runidmapping.sh -b -a` (instead of, say, `runidmapping.sh -v -a`).

### `rule_to_set_cronjob_for_author_idmapping_export.rule`

This is the rule reacting to creation, modification or deletion of an entity object in the appropriate namespace (default: `<institute-authors>`). It invokes `component_to_set_cronjob_for_author_idmapping_export.rulecomponent` which sets the cronjob (see below).

### `component_to_set_cronjob_for_author_idmapping_export.rulecomponent`

This is the component invoked by `rule_to_set_cronjob_for_author_idmapping_export.rule`. It is responsible for adding an appropriate cronjob (which is done by calling `runidmapping.sh -v -b -a`).

### `installidmapping.sh`

This is the install script. It takes an insitute-name and a uuid (as well as some optional parameters) and copies the necessary files to the necessary location, making the necessary modifications.

Usage: `installidmapping.sh -i institute -u uuid [-d directory] [-n name] [-p port]`
* `-i institute`: Make all references to `<institute>` be `institute`
* `-u uuid`: Make all references to `<uuid>` be uuid (format: 8-4-4-4-12 digits, dash-separated)
* `-d directory`: Install into `directory` instead of `/var/www/html/sites/<institute>/files`
* `-n name`: Make all references to "`DORA Institute`" be `name`
* `-p port`: Change the default solr-port from `8080` to `port`


## @TODO

* Modify `idmapping.py` to restrict to collections and content models; make this configurable through `idmappingsetup.xml`
* Modify `installidmapping.sh` to deal with collections and content models (the script will have to also modify `rule_to_set_cronjob_for_author_idmapping_export.rule`)
* Add options to `installidmapping.sh` to remove backup-creation and verbosity
* Modify `component_to_set_cronjob_for_author_idmapping_export.rulecomponent` to use `drupal_mail()`


<br/><br/><br/>
> _This document is Copyright &copy; 2017 by d-r-p `<d-r-p@users.noreply.github.com>` and licensed under [CC&nbsp;BY&nbsp;4.0](https://creativecommons.org/licenses/by/4.0/)._

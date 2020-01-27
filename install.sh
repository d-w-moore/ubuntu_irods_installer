#!/bin/bash

: ${PHASE_VERBOSE:=1}
: ${APT_INSTALL:=0}
: ${IRODS_VSN:=4.2.7}
IRODS_HOME=/var/lib/irods
DEV_HOME="$HOME"
: ${DEV_REPOS:="$DEV_HOME/github"}
: ${DIR_FOR_BACKUPS:=$DEV_HOME}
RODS_DIR_PRESERVE=1
: ${IRODS_BASH_HISTORY="$IRODS_HOME/.bash_history"}
quit_on_phase_err='1'

usage () {
   echo >&2 $(basename "$0") '[option...]'
   cat >&2 <<-'EOF'
        options:
        -c  check if $DEV_REPOS a valid directory (run phase 0)
        -C  like -c but error exits if not an APT install
        -v  verbosely print stuff
        -e  silently exit before doing anything
        -h  help
        -o  override config variables from keyboard
        -a  execute all phases
        -f  force through all phases, despite errors

        --irods=Imajor.Iminor.Ipatch [ or just --irods=... or --i=... ]
            specify irods version

        --[with-options|with|w]="opt1 opt2 [...]"
            where optN... is:
               phase option-names
                 0      sudo-without-pw     - what it sounds like (this script depends on it)
                 0      backup              - tar up the essential irods directories
                 0      config-essentials   - install miscellaneous prerequisites for irods 
                 0      create-db           - create postgres
                 0      add-package-repo    - enable repos for irods install prerequisite pkgs
                 0      add-coredev-repo    - enable repos for building prerequisite packages
                 0      add-build-externals - install irods-externals for building from source
                 4      basic               - install runtime and dev packages only
                 4      basic-skip          - install server and database packages only

        -r  use APT for a remote install based on IRODS_VSN (-i)
            (this options causes DEV_REPOS to be ignored)

        --All=n or
        --A=n  execute all phases of install up to n
                 0 check package build dirs
                 5 (1 uninstall ... 2 clear_db ... 3 save_old ...
                    4 install_pkgs ... 5 config_irods)
                 6 : install Python RE plugin
                 7 : configure Python RE plugin
	EOF
   echo >&2 "Currently IRODS_VSN='$IRODS_VSN'; APT_INSTALL='$APT_INSTALL' (override with -o)"
   exit 123
}

ovrride() {
  local temp
  read -p $1\(\ $(eval "echo \"\$$1\"")\ \)-\> temp
  if [ -n "$temp" ]; then
    eval "$1='$temp'"
  fi
}

MIN=1
MAX=""
V=""
CHK=""
EXIT="";
USAGE_AND_EXIT=0

while [[ "$1" = -* ]]; do
  ARG="$1"
  shift
  case $ARG in
    --b=*) DIR_FOR_BACKUPS="${ARG#*=}"
             #echo >&2 "DIR_FOR_BACKUPS '$DIR_FOR_BACKUPS'"  ; exit 23
             ;;
    "-r") APT_INSTALL=1;;
    "-f") quit_on_phase_err='';;
    "-c") MIN=0 ; CHK=0 ;;
    "-C") MIN=0 ; CHK=1 ;;
    "-o") opt_o=1    ;;
    "-a") MAX=9 ;;
    --i=* | --irods=* |\
    --irods-version=*) IRODS_VSN=${ARG#*=};;
    --[Aa]=[0-9]* | --[Aa]ll=[0-9]* ) MAX=${ARG#*=} ;;
    --w=* | --with=* | --with-options=* ) withopts=${ARG#*=} ;;
    -v) VERBOSE=1;;
    -e) EXIT=1;;
    -*) USAGE_AND_EXIT=1 ;;
  esac
done

[ $USAGE_AND_EXIT = 1 ] && usage

if [ $# -eq 0 ] ; then
  if [ -n "$MAX" ] ; then
    eval "set {$MIN..${MAX:=$MIN}}"
  fi
fi

if [ "$1" != "0" -a $MIN = 0 ] ; then
    set "$MIN" "$@"
fi

OVERRIDES=(IRODS_VSN IRODS_HOME APT_INSTALL DEV_HOME DEV_REPOS DIR_FOR_BACKUPS)

if [ -n "$opt_o" ]; then
    #ovrride IRODS_VSN #ovrride IRODS_HOME #ovrride APT_INSTALL #ovrride DEV_HOME #ovrride DEV_REPOS
    for opt in "${OVERRIDES[@]}"; do
      ovrride "$opt"
    done
fi

if [ -n "$VERBOSE" ] ; then
  echo >&2 "==============="
  for opt in "${OVERRIDES[@]}"; do
    echo >&2 "$opt='$(eval "echo \$$opt")'"
  done
  for x in "$@"; do
    echo >&2 $(( ++na )) : "$x"
  done
fi

if [ -n "$EXIT" ] ; then exit 0; fi


run_phase() {

 local PHASE=$1
 local with_opts=" $2 "

 if [ $PHASE_VERBOSE -gt 0 ] ; then
     prt_phase() {
         echo '**************************************'
         echo '       ' $1
         echo '**************************************'
     }
 else
     prt_phase() { :
     }
 fi

 case "$PHASE" in

 0)

    if [[ $with_opts = *\ sudo-without-pw\ * ]]; then
      if [ -f "/etc/sudoers" ]; then
         sudo su -c "echo '$USER ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers"
      else
         echo >&2 "WARNING - Could not modify sudoers files"
         echo -n >&2 "           (hit 'Enter' to continue)"
         read key
      fi
    fi
#   #------ (needed for both package install and build from source)

    if [[ $with_opts = *\ config-essentials\ * ]]; then

	    prt_phase   config-essentials

        if ! dpkg -l tzdata >/dev/null 2>&1 ; then
          sudo su - root -c \
           "env DEBIAN_FRONTEND=noninteractive bash -c 'apt-get install -y tzdata'"
        fi

        sudo apt-get install -y software-properties-common apt-transport-https vim git postgresql wget
        sudo apt-get update && sudo apt-get install -y vim python-pip libfuse2 unixodbc rsyslog less
        sudo pip install xmlrunner
        sudo service postgresql start
    fi

    #------ CORE DEV stuff / build from source

    [[ $with_opts = *\ add-build-externals\ * ]] && { with_opts+=" add-coredev-repo "; } # --> dependency

    if [[ $with_opts = *\ add-coredev-repo\ * ]]; then # install things for iRODS master branch

	    prt_phase   add-coredev-repo

        sudo apt-get install -y software-properties-common
        #sudo add-apt-repository -r renci-irods # --?-- should be able to have packages & core-dev --?--
        wget -qO - https://core-dev.irods.org/irods-core-dev-signing-key.asc | sudo apt-key add -
        echo "deb [arch=amd64] https://core-dev.irods.org/apt/ $(lsb_release -sc) main" | \
          sudo tee /etc/apt/sources.list.d/renci-irods-core-dev.list
        sudo apt-get update

        sudo apt install -y libssl-dev rsyslog # packages uniquely required in iRODS master branch

        # -- basic  iRODS dependencies (?)
        sudo apt-get  install -y apt-transport-https wget lsb-release sudo \
                       python python-psutil python-requests python-jsonschema \
                       libssl-dev super lsof postgresql odbc-postgresql libjson-perl

    fi

    if [[ $with_opts = *\ add-build-externals\ * ]]; then

	    prt_phase   add-build-externals

        sudo apt-get install -y irods-externals\*

        # -- build  iRODS dependencies
        sudo  apt-get install -y git ninja-build libpam0g-dev unixodbc-dev libkrb5-dev libfuse-dev \
                       libcurl4-gnutls-dev libbz2-dev libxml2-dev zlib1g-dev python-dev \
                       make gcc help2man

    fi

    if [[ $with_opts = *\ add-package-repo\ * ]]; then

	    prt_phase   add-package-repo

      wget -qO - https://packages.irods.org/irods-signing-key.asc | sudo apt-key add - && \
      echo "deb [arch=amd64] https://packages.irods.org/apt/ $(lsb_release -sc) main" |\
          sudo tee /etc/apt/sources.list.d/renci-irods.list
      sudo apt update
    fi

    if [[ $with_opts = *\ create-db\ * ]]; then

	    prt_phase   create-db

    echo >&2 "-- Creating ICAT database -- "
    sudo su - postgres -c "
        { dropdb --if-exists ICAT
          dropuser --if-exists irods ; } >/dev/null 2>&1"
    sudo su - postgres -c "psql <<\\
________
        CREATE DATABASE \"ICAT\";
        CREATE USER irods WITH PASSWORD 'testpassword';
        GRANT ALL PRIVILEGES ON DATABASE \"ICAT\" to irods;
________"
    echo >&2 "-- status of create-db =  $? -- "
    fi

    #SAVE_DIR=$(pwd)

    ph0_status=0

    if [ "$CHK" != "" ]; then
      cd "$DEV_REPOS" >/dev/null 2>&1 || {
        echo >&2 "--> Cannot cd to DEV_REPOS directory, '$DEV_REPOS'";
        if [ $CHK -ge 1 -o $APT_INSTALL -eq 0 ] ; then
        {  echo $'\t.... Exiting now because  either: '
           echo $'\t       (1) local installation requires the DEV_REPOS dir to exist'
           echo $'\t   or: (2) option -C was invoked'  ; } >&2
           ph0_status=1
        elif [ $APT_INSTALL -eq 1 ] ; then
          { echo >&2 $'\t.... OK however, as this is not an install from source'; }
        fi
      }
    fi

    if [[ $with_opts = *\ backup\ * ]]; then

	    prt_phase    backup

      if cd "$DIR_FOR_BACKUPS" >/dev/null 2>&1; then  #(if '' then maybe /tmp ?)
        echo >&2 -n "--- backing up iRODS system dirs --- "
        (sudo su - irods -c "cd / && tar cf - ./etc/irods ./var/lib/irods ./usr/lib/irods")|gzip -c >irods_sysdirs.`date +%s`.tgz
        echo >&2 ""
      else
        echo >&2 " ( Did not find backups dir, not making TAR backups ) "
      fi
    fi

    #cd "$SAVE_DIR"
    test "$ph0_status" = 0
    ;;

    #------
 1)
 [ -f "$IRODS_HOME/irodsctl" ] && sudo su - irods -c "$IRODS_HOME/irodsctl stop"
 sudo apt -y remove irods-{dev,runtime} &&\
 sudo dpkg -P irods-database-plugin-postgres && \
 dpkg -l irods\*
 ;;

 2)
 sudo su - postgres -c 'dropdb --if-exists ICAT &&\
                        createdb ICAT && echo >&2 "DB cleared"'
 ;;

 3)

 if [ -f "$IRODS_BASH_HISTORY" ] ; then
     sudo su irods -c "cp -rp '$IRODS_BASH_HISTORY' /tmp/iRODS_History"
 fi
 Action="Remove"; oldrods=""
 if [ "$RODS_DIR_PRESERVE" -gt 0 ]; then
    oldrods=`date +%s`
    Action="Rename"
    sudo su - -c "mv /etc/irods{,.0$oldrods}
                  mv /var/lib/irods{,.0$oldrods}
                  rm -fr  /tmp/irods
                  rm -fr /usr/lib/irods "
 else
    sudo rm -fr /etc/irods /var/lib/irods /tmp/irods /usr/lib/irods
 fi
 echo >&2 "${Action} old iRODS directories"
 if [ -n "$oldrods" ]; then
   echo >&2 $'\t'"(tagged with: '.0$oldrods')"
 fi
 ;;

 4)
 sudo pkill 'irods.*Server'
 if [ "$APT_INSTALL" -gt 0 ]; then
   sudo apt install -y irods-{dev,runtime}${IRODS_VSN:+"=$IRODS_VSN"}
   if [[ $with_opts != *\ basic\ * ]]; then
     sudo apt install -y irods-{icommands,server,database-plugin-postgres}${IRODS_VSN:+"=$IRODS_VSN"}
   fi
 else
   cd $DEV_REPOS/build__irods &&\
   if [[ $with_opts = *" basic "* ]]; then
     sudo dpkg -i irods-dev_${IRODS_VSN}~*.deb  irods-runtime_${IRODS_VSN}~*.deb
   elif [[ $with_opts = *" basic-skip "* ]]; then
     sudo dpkg -i ../build__irods_client_icommands/irods-icommands_${IRODS_VSN}~*.deb  &&\
     sudo dpkg -i irods-server_${IRODS_VSN}~*.deb  irods-database-plugin-postgres_${IRODS_VSN}~*.deb
   else
     sudo dpkg -i irods-dev_${IRODS_VSN}~*.deb  irods-runtime_${IRODS_VSN}~*.deb  && \
     sudo dpkg -i ../build__irods_client_icommands/irods-icommands_${IRODS_VSN}~*.deb  &&\
     sudo dpkg -i irods-server_${IRODS_VSN}~*.deb  irods-database-plugin-postgres_${IRODS_VSN}~*.deb
   fi
 fi
 ;;

 5)
 sudo python /var/lib/irods/scripts/setup_irods.py < /var/lib/irods/packaging/localhost_setup_postgres.input
 if [ -f /tmp/iRODS_History ]; then
     sudo su irods -c "mv /tmp/iRODS_History '$IRODS_BASH_HISTORY'"
 fi
 ;;

 6)
 if [ "$APT_INSTALL" -gt 0 ]; then
   sudo apt install irods-rule-engine-plugin-python${IRODS_VSN:+"=$IRODS_VSN"}
 else
   cd $DEV_REPOS/build__irods_rule_engine_plugin_python/ &&\
   sudo dpkg -i irods-rule-engine-plugin-python-${IRODS_VSN}-*.deb
 fi
 ;;

 7) sudo su - irods -c "\
    cd $IRODS_HOME/scripts && python setup_python_rule_engine_as_only_rule_engine.py && \
    echo >&2 'Python is now the only rule engine plugin active'"
 ;;

 8) : ${NOP:=1} ;;
 9) : ${NOP:=1} ;;
 *) echo >&2 "unrecognized phase: '$PHASE'." ; QUIT=1 ;;
 esac
 return $?
}

#-------------------------- main

QUIT=0
while [ $# -gt 0 ] ; do
  ARG=$1 ; shift
  NOP="" ; run_phase $ARG " $withopts "; sts=$?
  [ $QUIT != 0 ] && break
  [ -n "$NOP" ] && continue
  echo -n "== $ARG == "
  if [ $sts -eq 0 ]; then
    echo Y >&2
  else
    [ $quit_on_phase_err ] && { echo >&2 "N - quitting"; exit 1; }
    echo N >&2
  fi
done

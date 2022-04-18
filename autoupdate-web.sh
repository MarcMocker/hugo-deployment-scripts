#!/usr/bin/env bash

ROOT=/root
REPO=/root/homepage
WEBROOT=/var/www/html
LOG=/tmp/autoupdate-web.log
WELL_KNOWN_DIR="$REPO/content/well-known"

function info {
    echo -e "\e[32m[info] $*\e[39m";
}

function log {
    echo -e "\e[32m[log] $*\e[39m" >> $LOG
}

function update_script() {
    renice "$NICE" $BASHPID # lowers the priority by NICE value; scope: until the end of the function

    info updating update script >> $LOG
    if [ -f $REPO/autoupdate-web.sh ]; then
        mv $REPO/autoupdate-web.sh $ROOT/autoupdate-web
        chmod +x $ROOT/autoupdate-web
    fi
}

function get_new_version() {
    # does the REPO exist at all?
    PULL_MSG=empty
    if [ -d $REPO ]; then
        # REPO exists
        cd $REPO || log "impossible state reached"
        log removing changes
        rm -r $REPO/public >> $LOG 2>> $LOG
        git stash >> $LOG
        log pulling REPO
        git pull
    else
        log cloning REPO
        cd $ROOT || log "impossible state reached"
        git clone git@github.com:MarcMocker/homepage.git >> $LOG
    fi
}

function rebuild_website() {
    log building website
    cd $REPO || log "impossible state reached"
    hugo -D >> $LOG 2>> $LOG
    mv "$WELL_KNOWN_DIR" "$REPO/public/.well-known"


    info syncing WEBROOT >> $LOG
    rsync -avur --delete "$REPO/public/" "$WEBROOT"
}

date >> $LOG

if [[ $(get_new_version | grep "Already up to date.") ]]; then # build new version of website if there are updates
    log "No changes detected"
else
    (update_script) # update this script with low priority
    rebuild_website
fi

log "done"
exit 0

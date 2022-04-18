#!/usr/bin/env bash

ROOT=/root
REPO=$1
WEBROOT=/var/www/html
LOG=/tmp/hugo-autodeployment/autoupdate-web.log
WELL_KNOWN_DIR="$REPO/content/well-known"

# continous delivery
LOCAL_AUTOUPDATE_SCRIPT=/usr/local/bin/autoupdate-web
UPSTREAM_AUTOUPDATE_SCRIPT=https://raw.githubusercontent.com/MarcMocker/hugo-deployment-scripts/main/autoupdate-web.sh


function info {
    echo -e "\e[32m[info] $*\e[39m";
}

function log {
    echo -e "\e[32m[log] $*\e[39m" >> $LOG
}

function update_script() {
    renice "$NICE" $BASHPID # lowers the priority by NICE value; scope: until the end of the function

    log updating update script
    curl "$UPSTREAM_AUTOUPDATE_SCRIPT" | tee $LOCAL_AUTOUPDATE_SCRIPT || log failed to update autoupdate script
    chmod +x $LOCAL_AUTOUPDATE_SCRIPT
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
        git clone git@github.com:MarcMocker/homepage.git $REPO >> $LOG
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

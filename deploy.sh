#!/usr/bin/env bash


# global vars ############################################

NULL=/dev/null
LOG=deploy.sh.log

# install dependencies
REQUIRED_PACKAGES="git apache2 hugo curl"

# ssh
PUBLIC_SSH_CERT=$HOME/.ssh/id_rsa.pub
SSH_USER=git
SSH_HOST=github.com

# hugo project
HUGO_LOCAL_REPOSITORY_LOCATION=/tmp/hugo-autodeployment
HUGO_LOCAL_REPOSITORY=""
HUGO_UPSTREAM_REPOSITORY=empty

# continous delivery
LOCAL_AUTOUPDATE_SCRIPT=/usr/local/bin/autoupdate-web
UPSTREAM_AUTOUPDATE_SCRIPT=https://raw.githubusercontent.com/MarcMocker/hugo-deployment-scripts/main/autoupdate-web.sh


#########################################################

# generic functions #####################################

function error(){
    echo -e "\e[35m[error] $*\e[39m";
    exit 1
}

function info {
    echo -e "\e[32m[info] $*\e[39m";
}

function warn {
    echo -e "\e[33m[warn] $*\e[39m";
}

function log {
    echo -e "\e[32m[log] $*\e[39m" >> $LOG
}

#########################################################

# specific functions ####################################

function install_dependencies(){
    info updating system...
    apt-get update > $NULL || error update failed

    info upgrading system...
    apt-get full-upgrade -y > $NULL 2> $NULL || error "full upgrade failed"

    info installing dependencies...
    apt-get install -y $REQUIRED_PACKAGES > $NULL 2> $NULL  || error "installation of required packages failed"

}

function create_ssh_keys_if_not_available(){
    # check if ssh-keys exist
    if [ ! -f $HOME/.ssh/id_rsa.pub ]; then
        warn No existing SSH keys detected. Creating new key pair...
        ssh-keygen -b 2048 -t rsa -f "$HOME"/.ssh/id_rsa -q -N ""

    else
        warn Existing SSH key detected.
    fi

    # avoid giving "yes" confirmation adding github as new known host
    ssh -o StrictHostKeyChecking=no -l "$SSH_USER" "$SSH_HOST" 2> /dev/null
}

function ask_to_add_deployment_key_to_upstream_repo() {
    info "You use a private repository!"
    info "To permit this system access to your github repository,"
    info "please go the the repositorys settings > deploy keys > add deploy key"
    info "There you need to give it a name you are free to select and "
    info "paste the following content as key:\n"
    cat "$PUBLIC_SSH_CERT"
    echo ""
    info "(write access is not needed)"
    info "Press enter to continue"
    read -p "> "
}

function handle_clone_failed() {
    warn "Failed to clone upstream repository: Permission denied"
    ask_to_add_deployment_key_to_upstream_repo

    info cloning again...
    git clone "$HUGO_UPSTREAM_REPOSITORY" "$HUGO_LOCAL_REPOSITORY_LOCATION/$HUGO_LOCAL_REPOSITORY" > $NULL 2> $NULL || error "Clone failed again, aborting."
}

function make_hugo_project_accessible() {
    read -p "Please enter the ssh address of the upstream repository: " repo
    HUGO_UPSTREAM_REPOSITORY=$repo

    read -p "Please enter the name of the local repository: " repo
    HUGO_LOCAL_REPOSITORY=$repo

    info "Trying to clone $HUGO_UPSTREAM_REPOSITORY..."
    rm -r $HUGO_LOCAL_REPOSITORY_LOCATION/$HUGO_LOCAL_REPOSITORY > $NULL 2> $NULL
    git clone "$HUGO_UPSTREAM_REPOSITORY" "$HUGO_LOCAL_REPOSITORY_LOCATION/$HUGO_LOCAL_REPOSITORY" > $NULL 2> $NULL || handle_clone_failed

    rm -r "$HUGO_LOCAL_REPOSITORY_LOCATION/$HUGO_LOCAL_REPOSITORY"
    info Upstream repository is accessible!
}

function setup_cd_script() {
    # download script
    info "Loading continous delivery script..."
    curl "$UPSTREAM_AUTOUPDATE_SCRIPT" | tee $LOCAL_AUTOUPDATE_SCRIPT > $NULL || error "failed to fetch CD script"
    chmod +x $LOCAL_AUTOUPDATE_SCRIPT || error "failed to make CD script executable"

    # setup crontab
    cat /etc/crontab | grep "$HUGO_LOCAL_REPOSITORY" > $NULL 2> $NULL
    if [ $? != 0 ]; then
        info "Generating crontab entry..."
        echo "*/2 *   * * *   root    $LOCAL_AUTOUPDATE_SCRIPT $HUGO_LOCAL_REPOSITORY_LOCATION/$HUGO_LOCAL_REPOSITORY $HUGO_UPSTREAM_REPOSITORY" >> /etc/crontab
    else
        warn "An existing crontab for $HUGO_LOCAL_REPOSITORY was found."
    fi

    info "Initially deploying the website..."
    $LOCAL_AUTOUPDATE_SCRIPT "$HUGO_LOCAL_REPOSITORY_LOCATION/$HUGO_LOCAL_REPOSITORY" "$HUGO_UPSTREAM_REPOSITORY" > $LOG 2> $LOG
    info done.
}

function confirm_site_is_online() {
    # if the localhost shows still the default page
    info "Validating the new site is served from the webserver..."
    if [ $(curl localhost | grep "Apache2" | grep "Default Page" > $NULL 2> $NULL) ]; then
        error "The webserver still serves the default page!\n[error] Validation failed, aborting."
    else
        info "Success."
    fi
}

#########################################################

# workflow ##############################################
clear # just for estetics

install_dependencies
create_ssh_keys_if_not_available
make_hugo_project_accessible
setup_cd_script
confirm_site_is_online

#########################################################
exit 0

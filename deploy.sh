#!/usr/bin/env bash


# global vars ############################################

NULL=/dev/null
LOG=deploy.sh.log

# install dependencies
REQUIRED_PACKAGES="git apache2 hugo"

# ssh
PUBLIC_SSH_CERT=$HOME/.ssh/id_rsa.pub
SSH_USER=git
SSH_HOST=github.com

# hugo project
DEPLOY_REPOSITORY=empty
HUGO_LOCAL_REPOSITORY=/tmp/hugo-project
HUGO_UPSTREAM_REPOSITORY=empty


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
    apt-get full-upgrade -y | tee $NULL || error full upgrade failed

    info installing dependencies...
    apt-get install -y "$REQUIRED_PACKAGES" | tee $NULL  || error installation of required packages failed

}

function create_ssh_keys_if_not_available(){
    # check if ssh-keys exist
    if [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
        info No existing SSH keys detected. Creating new key pair...
        ssh-keygen -b 2048 -t rsa -f "$HOME"/.ssh/id_rsa -q -N ""

    else
        info Existing SSH key detected.
    fi

    # avoid giving "yes" confirmation adding github as new known host
    ssh -o StrictHostKeyChecking=no -l "git" "github.com" 2> /dev/null
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
    git clone "$HUGO_UPSTREAM_REPOSITORY" "$HUGO_LOCAL_REPOSITORY" > $NULL 2> $NULL || error "Clone failed again, aborting."
}

function make_hugo_project_accessible() {
    read -p "Please enter the upstream repositorys ssh address: " repo
    HUGO_UPSTREAM_REPOSITORY=$repo

    info "Trying to clone $HUGO_UPSTREAM_REPOSITORY..."
    git clone "$HUGO_UPSTREAM_REPOSITORY" "$HUGO_LOCAL_REPOSITORY" > $NULL 2> $NULL || handle_clone_failed

    rm -r $HUGO_LOCAL_REPOSITORY
    info Upstream repository is accessible!
}

function setup_cd_script() {
    sleep 10
}

#########################################################

# workflow ##############################################
clear # just for estetics

#install_dependencies
#create_ssh_keys_if_not_available
#make_hugo_project_accessible

setup_cd_script


#########################################################
exit 0

# asking if ssh-key is needed for deployment
read -p "Is the Repository you are going to use private? [Y/n]: " yn
case $yn in
    [Nn]* ) ;; # do nothing
    * ) ask_to_add_deployment_key_to_upstream_repo;;
esac




exit 0
    info ""
    info "DEFAULT: update on boot             [1]"
    info "OPTION:  update daily at 1am        [2]"
    info "OPTION:  update never automatically [3]"
    info ""

    read -r -p "> "
    UPDATE_POLICY=$REPLY
    case $UPDATE_POLICY in
        [1]* ) echo @reboot root /root/autoupdate.sh >> /etc/crontab && info-log "selected option [1]";;
        [2]* ) echo "0 1 * * * /root/autoupdate.sh > /dev/null" >> /etc/crontab && info-log "selected option [2]";;
        [3]* ) info-log "selected option [3] \n[info] This requires patching the system manually";;
        * ) echo @reboot root /root/autoupdate.sh >> /etc/crontab && info-log "selected default [1]";;
    esac


    root@portfolio-page:~# history
        1  apt update && apt full-upgrade -y
        2  ssh-keygen
        3  cat .ssh/id_rsa.pub
        4  apt install git apache2 tree -y
        5  git clone git@github.com:MarcMocker/homepage.git
        6  tree
        7  cd homepage/
        8  git pull
        9  cp autoupdate-web.sh ../autoupdate-web.sh
       10  cd ..
       11  ll
       12  chmod +x autoupdate-web.sh
       13  echo "*/2 *   * * *   root    /root/autoupdate-web" >> /etc/crontab
       14  ls /tmp/
       15  cat /tmp/autoupdate-web.log
       16  watch cat /tmp/autoupdate-web.log
       17  apt install hugo
       18  watch cat /tmp/autoupdate-web.log
       19  cat /etc/crontab
       20  ll
       21  watch cat /tmp/autoupdate-web.log
       22  ./autoupdate-web.sh
       23  watch cat /tmp/autoupdate-web.log
       24  cat /tmp/autoupdate-web.log
       25  curl localhost
       26  wget -qO- localhost
       27  wget -qO- localhost | grep marc
       28  reboot now
       29  cat /tmp/autoupdate-web.log
       30  history
    root@portfolio-page:~#

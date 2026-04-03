#!/bin/bash
set -e
source config.env

create_dir() {
    DIR_PATH=$1
    if [ ! -d "$DIR_PATH" ]; then
        echo "Creating directory: $DIR_PATH"
        sudo mkdir -p $DIR_PATH
        sudo chown $(whoami):$(whoami) $DIR_PATH
        sudo chmod 755 $DIR_PATH
    else
        echo "Directory exists: $DIR_PATH"
    fi
}

# GitLab
create_dir $PV_GITLAB_POSTGRES
create_dir $PV_GITLAB_GITALY
create_dir $PV_GITLAB_LOGS

# AWX
create_dir $PV_AWX_POSTGRES
create_dir $PV_AWX_PROJECTS

# Argo CD
create_dir $PV_ARGOCD_REPOS

echo "=== All Persistent Volume directories created ==="
#!/usr/bin/env bash

set -e

# Find out where I am
script_path=$(readlink -f "$0")
script_dir=$(dirname "$script_path")
# Move up to the testing directory
echo "Changig directory to $script_dir/../"
cd "$script_dir/../" || exit 1

git config --global --add safe.directory /home/admin.ackbar/LME
git config --global --add safe.directory /opt/lme

#Get the branch I am working on
echo "Checking current branch"
export current_branch=$(git rev-parse --abbrev-ref HEAD)


# Get the version that we are going to upgrade to
. ./merging_version.sh

# Checkout the version in /opt/lme that we are on in ~/LME
sudo  echo "Current branch: $current_branch"
sudo  echo "Forcing version: $FORCE_LATEST_VERSION"
sudo  sh -c "cd '/opt/lme/' && git checkout 'Chapter\ 3\ Files/deploy.sh' && git checkout -t origin/$current_branch && git pull"
echo "Running the upgrade"
sudo  sh -c "export TERM=dumb; export FORCE_LATEST_VERSION=$FORCE_LATEST_VERSION; cd '/opt/lme/Chapter 3 Files' && ./deploy.sh upgrade" 

echo "UPGRADE_SUCCESSFUL"
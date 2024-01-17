#!/bin/sh

# Clear any echo text coloring
nocolor='\033[0m'

# Informational message coloring
burntYellow='\033[0;33m'
function infoecho() {
    echo -e $burntYellow"$@"$nocolor
}

# Error message coloring
red='\033[0;31m'
function errorecho() {
    echo -e $red"$@"$nocolor
}

# Iterate through the directory and clean up
function iterateDirectories() {
  infoecho "Checking projects..."
  for d in */ ; do
    cd $d
    if [ -d "$1.git" ]
    then
      infoecho "Processing $d."
      fetchRemotes
      removeDeleted
      removeMerged
      pruneLocal
      checkStashes
    else
      infoecho "Skipping $d not a git repository."
      fi
    cd -
  done
}

# Fetch remotes and prune removed branched
function fetchRemotes() {
  echo "Removing deleted remote branches..."
  git fetch --prune $(git remote)
}

# Clear up deleted branches
function removeDeleted() {
  echo "Removing local branches with a deleted remote..."
  git for-each-ref --format '%(refname:short) %(upstream:track)' | awk '$2 == "[gone]" {print $1}' | xargs -r git branch -D
}

# Clear up merged branches
function removeMerged() {
  echo "Removing merged local branches..."
  branches=$(git branch --merged master | sed 's/^ *//g' | grep -v master)
  if [ ! -z "$branches" ]
  then
    git branch -d $branches
  fi
}

# Prune orphaned objects
function pruneLocal() {
  echo "Removing orphaned objects..."
  git prune --progress
}

# Check for stashes
function checkStashes() {
  echo "Checking for old stashes..."
  stashes=$(git stash list | grep -q 'stash')
  if [ ! -z "$stashes" ]
  then
    errorecho "Stashes found."
  fi
}

iterateDirectories

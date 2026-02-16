#!/bin/bash

set -euo pipefail

function debug() {
    echo "::debug file=${BASH_SOURCE[0]},line=${BASH_LINENO[0]}::$1"
}

function warning() {
    echo "::warning file=${BASH_SOURCE[0]},line=${BASH_LINENO[0]}::$1"
}

function error() {
    echo "::error file=${BASH_SOURCE[0]},line=${BASH_LINENO[0]}::$1"
}

function add_mask() {
    echo "::add-mask::$1"
}

if [ -z "$GITHUB_ACTOR" ]; then
    error "GITHUB_ACTOR environment variable is not set"
    exit 1
fi

if [ -z "$GITHUB_REPOSITORY" ]; then
    error "GITHUB_REPOSITORY environment variable is not set"
    exit 1
fi

if [ -z "$GH_PERSONAL_ACCESS_TOKEN" ]; then
    error "GH_PERSONAL_ACCESS_TOKEN environment variable is not set"
    exit 1
fi

add_mask "${GH_PERSONAL_ACCESS_TOKEN}"

if [ -z "${WIKI_COMMIT_MESSAGE:-}" ]; then
    debug "WIKI_COMMIT_MESSAGE not set, using default"
    WIKI_COMMIT_MESSAGE='Automatically publish wiki'
fi

GIT_REPOSITORY_URL="https://${GH_PERSONAL_ACCESS_TOKEN}@${GITHUB_SERVER_URL#https://}/$GITHUB_REPOSITORY.wiki.git"

debug "Checking out wiki repository"
tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
(
    cd "$tmp_dir" || exit 1
    git init
    git config user.name "$GITHUB_ACTOR"
    git config user.email "$GITHUB_ACTOR@users.noreply.github.com"
    git pull "$GIT_REPOSITORY_URL"
) || exit 1

debug "Adding changed files"
(
    cd "$tmp_dir" || exit 1
    git add .
) || exit 1

debug "Deleting contents of $tmp_dir"
rm -r $tmp_dir
# for file in $(find $tmp_dir -maxdepth 100 -type f -name '*.md' -execdir basename '{}' ';'); do
#    debug "Deleting $file"
#    rm -rf "$tmp_dir/$file"
#done

debug "Adding changed files"
(
    cd "$tmp_dir" || exit 1
    git add .
) || exit 1

debug "Copying contents of $1 to $tmp_dir"
cp -R $1 $tmp_dir
# for file in $(find $1 -maxdepth 100 -type f -name '*.md' -execdir basename '{}' ';'); do
#    debug "Copying $file"
#     cp -r "$1/$file" "$tmp_dir"
#done

debug "Committing and pushing changes"
(
    cd "$tmp_dir" || exit 1
    git add .
    git commit -m "$WIKI_COMMIT_MESSAGE"
    git push --set-upstream "$GIT_REPOSITORY_URL" master
) || exit 1

rm -rf "$tmp_dir"
exit 0

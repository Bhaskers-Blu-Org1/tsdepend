#!/bin/bash

set -e

echo
echo "  'Update Branch Action' is using the following input:"
echo "    - stable_branch = '$INPUT_STABLE_BRANCH'"
echo "    - development_branch = '$INPUT_DEVELOPMENT_BRANCH'"
echo "    - allow_ff = $INPUT_ALLOW_FF"
echo "    - allow_git_lfs = $INPUT_GIT_LFS"
echo "    - ff_only = $INPUT_FF_ONLY"
echo "    - allow_forks = $INPUT_ALLOW_FORKS"
echo "    - user_name = $INPUT_USER_NAME"
echo "    - user_email = $INPUT_USER_EMAIL"
echo "    - push_token = $INPUT_PUSH_TOKEN = ${!INPUT_PUSH_TOKEN}"
echo

if [[ -z "${!INPUT_PUSH_TOKEN}" ]]; then
  echo "Set the ${INPUT_PUSH_TOKEN} env variable."
  exit 1
fi

FF_MODE="--no-ff"
if $INPUT_ALLOW_FF; then
  FF_MODE="--ff"
  if $INPUT_FF_ONLY; then
    FF_MODE="--ff-only"
  fi
fi

if ! $INPUT_ALLOW_FORKS; then
  if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Set the GITHUB_TOKEN env variable."
    exit 1
  fi
  URI=https://api.github.com
  API_HEADER="Accept: application/vnd.github.v3+json"
  AUTH_HEADER="Authorization: token $GITHUB_TOKEN"
  pr_resp=$(curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" "${URI}/repos/$GITHUB_REPOSITORY")
  if [[ "$(echo "$pr_resp" | jq -r .fork)" != "false" ]]; then
    echo "Update Branch action is disabled for forks (use the 'allow_forks' option to enable it)."
    exit 0
  fi
fi

git remote set-url origin https://x-access-token:${!INPUT_PUSH_TOKEN}@github.com/$GITHUB_REPOSITORY.git
git config --global user.name "$INPUT_USER_NAME"
git config --global user.email "$INPUT_USER_EMAIL"

set -o xtrace

git fetch origin $INPUT_STABLE_BRANCH
git checkout $INPUT_STABLE_BRANCH 
git pull

git checkout $INPUT_DEVELOPMENT_BRANCH
git pull


if git merge-base --is-ancestor $INPUT_STABLE_BRANCH $INPUT_DEVELOPMENT_BRANCH; then
  echo "No merge is necessary"
  exit 0
fi;

set +o xtrace
echo
echo "  'Update Branch Action' is trying to merge the '$INPUT_STABLE_BRANCH' branch ($(git log -1 --pretty=%H $INPUT_STABLE_BRANCH))"
echo "  into the '$INPUT_DEVELOPMENT_BRANCH' branch ($(git log -1 --pretty=%H $INPUT_DEVELOPMENT_BRANCH))"
echo
set -o xtrace

# Do the merge
git merge -s recursive $INPUT_STABLE_BRANCH $INPUT_DEVELOPMENT_BRANCH --allow-unrelated-histories --no-edit

# Pull lfs if enabled
if $INPUT_GIT_LFS; then
  git lfs pull
fi

# Push the branch
git push origin $INPUT_DEVELOPMENT_BRANCH 

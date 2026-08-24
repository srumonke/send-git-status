#!/usr/bin/env bash
# Seeds github.com/srumonke/send-git-status with this demo and opens a PR.
#
# Needs push access to the repo. If you use gh: `gh auth login` first.
set -euo pipefail

cd "$(dirname "$0")"

REPO_URL="https://github.com/srumonke/send-git-status.git"

if [ ! -d .git ]; then
  git init -b main
  git remote add origin "$REPO_URL"
fi

# main: everything except the PR-triggering change
git add .
git commit -m "Add sendGitStatus demo pipeline and app" || true
git push -u origin main

# PR branch: touch the app so there's a real diff for the pipeline to build
git checkout -b demo/check-names
printf '\n// Touched to trigger the demo pipeline.\n' >> app/index.js
git commit -am "Touch app to trigger demo pipeline"
git push -u origin demo/check-names

echo
echo "Now open a PR from demo/check-names -> main:"
echo "  gh pr create --fill --base main --head demo/check-names"
echo
echo "Then inspect the checks:"
echo "  gh pr checks 1"

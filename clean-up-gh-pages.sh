#!/bin/bash

ENV="github-pages"
REPO="stanleykywu/quicksilver-macos"

# 1. Get all deployment IDs for the environment, sorted by newest first
# We use jq to get all IDs except the first one (index 0)
IDS=$(gh api -X GET "repos/$REPO/deployments?environment=${ENV// /%20}" | jq -r '.[1:] | .[].id')

if [ -z "$IDS" ]; then
  echo "No inactive deployments to delete for environment: $ENV"
  exit 0
fi

for ID in $IDS
do 
  echo "Deleting inactive deployment $ID"
  # Note: Removed the leading slash and fixed the path
  gh api -X DELETE "repos/$REPO/deployments/$ID"
done

echo "Done. The most recent deployment was preserved."
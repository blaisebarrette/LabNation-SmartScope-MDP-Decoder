#!/bin/bash

# Script to automatically commit and push changes in the submodule
# and then update the main repository.

# Check if a commit message was provided
if [ -z "$1" ]; then
  echo "Error: Please provide a commit message as an argument."
  exit 1
fi

COMMIT_MESSAGE="$1"
SUBMODULE_DIR="labnation_decoders_repo"

echo "--- Updating submodule '$SUBMODULE_DIR' ---"
cd "$SUBMODULE_DIR" || exit 1

echo "Adding changes in submodule..."
git add .

echo "Committing submodule with message: '$COMMIT_MESSAGE'"
git commit -m "$COMMIT_MESSAGE"
if [ $? -ne 0 ]; then
    echo "Submodule commit failed or nothing to commit."
    # Optionally exit if commit fails, or continue to push anyway
    # exit 1
fi

echo "Pushing submodule..."
git push
if [ $? -ne 0 ]; then
    echo "Submodule push failed."
    # exit 1 # Decide if failure here should stop the script
fi

echo "--- Updating main repository ---"
cd .. || exit 1

echo "Adding changes to main repository..."
git add .

echo "Committing main repository with message: 'Update submodule: $COMMIT_MESSAGE'"
git commit -m "Update submodule: $COMMIT_MESSAGE"
if [ $? -ne 0 ]; then
    echo "Main repository commit failed or nothing to commit."
    # exit 1
fi

echo "Pushing main repository..."
git push
if [ $? -ne 0 ]; then
    echo "Main repository push failed."
    # exit 1
fi

echo "--- Submodule and main repository update complete ---"

exit 0 
#!/usr/bin/env sh

set -eu

SSH_PATH="$HOME/.ssh"

# Guarantees cleanup of the SSH key on script exit
trap 'echo "Cleaning up SSH keys..."; rm -rf "$SSH_PATH"' EXIT

# Fix CVE-2022-24765 false positive
git config --global --add safe.directory /github/workspace


mkdir -p "$SSH_PATH"
chmod 700 "$SSH_PATH"

if [ -n "$INPUT_SSH_PRIVATE_KEY" ] && { [ -n "$INPUT_GIT_USERNAME" ] || [ -n "$INPUT_GIT_TOKEN" ]; }; then
    echo "ERROR: Option ssh_private_key is mutually exclusive with git_username and git_token"
    exit 1
fi

if [ -n "$INPUT_SSH_PRIVATE_KEY" ]; then
    echo "Setting up SSH private key..."
    echo "$INPUT_SSH_PRIVATE_KEY" > "$SSH_PATH/id_rsa"
    chmod 600 "$SSH_PATH/id_rsa"

    if [ -n "$INPUT_SSH_KNOWN_HOSTS" ]; then
        echo "Setting up SSH known hosts..."
        echo "$INPUT_SSH_KNOWN_HOSTS" > "$SSH_PATH/known_hosts"
        chmod 600 "$SSH_PATH/known_hosts"
        
        # Explicitly wire Git to use our exact files, bypassing any pathing ambiguity
        git config --global core.sshCommand "ssh -i $SSH_PATH/id_rsa -o IdentitiesOnly=yes -o UserKnownHostsFile=$SSH_PATH/known_hosts -o StrictHostKeyChecking=yes"
    else
        if [ "$INPUT_SSH_STRICT_HOST_KEY_CHECKING" = "false" ]; then
            git config --global core.sshCommand "ssh -i $SSH_PATH/id_rsa -o IdentitiesOnly=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
        else
            echo "ERROR: Strict host key checking is enabled but no known_hosts file was provided"
            exit 1
        fi
    fi
fi

git remote add mirror "$INPUT_TARGET_REPO"

PUSH_ARGS=""

if [ "$INPUT_DRY_RUN" = "true" ]; then
    echo "DRY RUN ENABLED: No data will actually be pushed."
    PUSH_ARGS="--dry-run"
fi

if git lfs ls-files 2>/dev/null | grep -q .; then
    if [ "$INPUT_DRY_RUN" != "true" ]; then
        echo "Pushing LFS objects to mirror..."
        git lfs push mirror --all
    else
        echo "Dry run enabled: Skipping LFS push."
    fi
else
    echo "No LFS files detected, skipping LFS phase."
fi

# This uses refs/remotes/origin/* because actions/checkout maps remote branches here, 
# not to local refs/heads/. This avoids pushing GitHub's hidden refs/pull/* spaces.
REFSPEC="refs/remotes/origin/*:refs/heads/* refs/tags/*:refs/tags/*"

if [ "$INPUT_DISABLE_FORCE_PUSH" = "true" ]; then
    echo "FORCE PUSH DISABLED: Pushing branches and tags securely..."
    git push mirror $PUSH_ARGS --prune $REFSPEC
else
    echo "FORCE PUSH ENABLED: Performing an exact mirror..."
    git push mirror $PUSH_ARGS --force --prune $REFSPEC
fi

echo "Mirror completed successfully."

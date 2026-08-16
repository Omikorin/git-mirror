#!/usr/bin/env sh

set -eu

# Guarantees cleanup of the SSH key on script exit
trap 'echo "Cleaning up SSH keys..."; rm -rf ~/.ssh' EXIT

mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [ -n "$INPUT_SSH_PRIVATE_KEY" ]; then
    echo "Setting up SSH private key..."
    echo "$INPUT_SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa
fi

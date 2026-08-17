#!/usr/bin/env sh

set -eu

# ============ Constants

SSH_PATH="$HOME/.ssh"
REMOTE_NAME="mirror"

# ============ Helpers

log_info() {
  echo "INFO: $1"
}

log_error() {
  echo "ERROR: $1" >&2
}

die() {
  log_error "$1"
  exit 1
}

cleanup() {
  log_info "Cleaning up SSH keys..."
  rm -rf "$SSH_PATH"
}

# ============ Core logic

validate_inputs() {
  if [ -n "${INPUT_SSH_PRIVATE_KEY:-}" ] && { [ -n "${INPUT_GIT_USERNAME:-}" ] || [ -n "${INPUT_GIT_TOKEN:-}" ]; }; then
    die "Option ssh_private_key is mutually exclusive with git_username and git_token."
  fi
}

setup_workspace() {
  # Fix CVE-2022-24765 false positive for GitHub Actions runner
  git config --global --add safe.directory /github/workspace
  git remote add "$REMOTE_NAME" "$INPUT_TARGET_REPO"
}

setup_ssh() {
  # Skip if no SSH key is provided
  if [ -z "${INPUT_SSH_PRIVATE_KEY:-}" ]; then
    return 0
  fi

  log_info "Setting up SSH private key..."
  mkdir -p "$SSH_PATH"
  chmod 700 "$SSH_PATH"

  echo "$INPUT_SSH_PRIVATE_KEY" >"$SSH_PATH/id_ed25519"
  chmod 600 "$SSH_PATH/id_ed25519"

  if [ -n "${INPUT_SSH_KNOWN_HOSTS:-}" ]; then
    log_info "Setting up SSH known hosts..."
    echo "$INPUT_SSH_KNOWN_HOSTS" >"$SSH_PATH/known_hosts"
    chmod 600 "$SSH_PATH/known_hosts"

    git config --global core.sshCommand "ssh -i $SSH_PATH/id_ed25519 -o IdentitiesOnly=yes -o UserKnownHostsFile=$SSH_PATH/known_hosts -o StrictHostKeyChecking=yes"

  elif [ "${INPUT_SSH_STRICT_HOST_KEY_CHECKING:-}" = "false" ]; then
    log_info "Strict host key checking disabled (Warning: less secure)."
    git config --global core.sshCommand "ssh -i $SSH_PATH/id_ed25519 -o IdentitiesOnly=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

  else
    die "Strict host key checking is enabled but no known_hosts file was provided."
  fi
}

push_lfs() {
  if ! git lfs ls-files 2>/dev/null | grep -q .; then
    log_info "No LFS files detected, skipping LFS phase."
    return 0
  fi

  if [ "$INPUT_DRY_RUN" = "true" ]; then
    log_info "Dry run enabled: Skipping LFS push."
  else
    log_info "Pushing LFS objects to mirror..."
    git lfs push "$REMOTE_NAME" --all
  fi
}

push_refs() {
  PUSH_ARGS=""

  if [ "$INPUT_DRY_RUN" = "true" ]; then
    log_info "DRY RUN ENABLED: No data will actually be pushed."
    PUSH_ARGS="--dry-run"
  fi

  # Uses refs/remotes/origin/* because actions/checkout maps remote branches here,
  # avoiding GitHub's hidden refs/pull/* spaces.
  REFSPEC="refs/remotes/origin/*:refs/heads/* refs/tags/*:refs/tags/*"

  if [ "$INPUT_DISABLE_FORCE_PUSH" = "true" ]; then
    log_info "FORCE PUSH DISABLED: Pushing branches and tags securely (with pruning)..."
    git push "$REMOTE_NAME" $PUSH_ARGS --prune $REFSPEC
  else
    log_info "FORCE PUSH ENABLED: Performing an exact mirror..."
    git push "$REMOTE_NAME" $PUSH_ARGS --force --prune $REFSPEC
  fi
}

# ============ Main

main() {
  trap cleanup EXIT

  validate_inputs
  setup_workspace
  setup_ssh
  push_lfs
  push_refs

  log_info "Mirror completed successfully."
}

main

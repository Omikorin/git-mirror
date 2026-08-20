# Git Mirror

This action mirrors the state of the repository to the specified target repository.
It supports HTTPS, SSH, and LFS. Addtionally, the LFS protocol is detected automatically if the repository has already been downloaded.

> [!TIP]
> This action should work in Forgejo without any changes.
> In comparison, Forgejo's native mirror does not support LFS.

## Usage

```yaml
- uses: Omikorin/git-mirror@v1
  with:
    # Target repository URL in SSH or HTTPS format
    # Required
    target_repo: ''

    # SSH private key used for connection with target repository
    # Works only with SSH
    # Mutually exclusive with git_username and git_token.
    # Default: null
    ssh_private_key: ''

    # Username for the target repository
    # Works only with HTTPS
    # Mutually exclusive with ssh_private_key.
    # Default: null
    git_username: ''

    # Personal Access Token for the target repository
    # Works only with HTTPS
    # Mutually exclusive with ssh_private_key.
    # Default: null
    git_token: ''

    # The SSH known_hosts file contents
    # Default: null
    ssh_known_hosts: ''

    # Set strict host key verification
    # Always enabled when ssh_known_hosts is provided.
    # Default: true
    ssh_strict_host_key_checking: ''

    # Disable force push to protect the target repository
    # Default: false
    disable_force_push: ''

    # Test the push without actually sending data
    # Default: false
    dry_run: ''
```

### Common scenario

The most common GitHub mirroring workflow I could find is `--mirror` (force push) on any push (or on push to the `main` branch).

It is recommended to run mirroring workflow in unique concurrency group (without any ref) to mitigate race condition risk.

Create a workflow file (i.e. `.github/workflows/mirror.yml`) in your source repository (the one you wish to mirror) with the following contents:

```yaml
name: Mirror

on:
  push:
    branches:
      - main

permissions:
  contents: read # mirroring does not need write access on the source

concurrency:
  group: mirror
  cancel-in-progress: true

jobs:
  mirror:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
          persist-credentials: false
          # Uncomment lfs: true if your repository contains LFS objects. 
          # Otherwise, the action will only push the LFS pointer files.
          # lfs: true

      - uses: Omikorin/git-mirror@v1
        with:
          target_repo: ${{ vars.TARGET_REPO }}
          ssh_private_key: ${{ secrets.MIRROR_SSH_KEY }}
          ssh_known_hosts: ${{ vars.SSH_KNOWN_HOSTS }}
          # Uncomment if you wish to mirror safely
          # disable_force_push: 'true'
```

Then, set up the following Actions variables:

- `TARGET_REPO` - target repository URL in HTTPS or SSH format
- `SSH_KNOWN_HOSTS` - contents of the `known_hosts` file that includes your target repository

> [!TIP]
> A cut example of the mentioned file:
>
> ```txt
> gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AA...
> codeberg.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5...
> codeberg.org ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC8hZi7K1/2E2uBX8...
> codeberg.org ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAy...
> ```

Also, set up secrets:

- `MIRROR_SSH_KEY` - SSH private key for source repository

> [!NOTE]
> On the other hand, the **public** key should be added as a *deploy key* in the target repository's settings.

## Development

### Requirements

- mise 2026.8.8+
- prek 0.4.14+

### Setup tooling

You can install all needed tooling using mise:

```shell
mise install
```

### Setup pre-commit hooks

You can install hooks to automatically run the validation checks:

```shell
prek install
```

### Basic workflow

```bash
# Run pre-commit checks for changed files
prek

# Run all pre-commit checks
prek --all-files
```

## License

This project is licensed under the terms of the [ISC License](https://github.com/Omikorin/git-mirror/blob/main/LICENSE).

---

<p align="center">Made with 🩵 by <a href="https://omikor.in" target="_blank">Michał Korczak</a></p>

---

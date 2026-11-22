#!/usr/bin/env sh

set -eu

ROOT_DIR=$(CDPATH='' cd "$(dirname "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d)
FAKE_BIN="$TEST_ROOT/bin"
PUSH_LOG="$TEST_ROOT/push-args"
REAL_GIT=$(command -v git)

mkdir -p "$FAKE_BIN"
trap 'rm -rf "$TEST_ROOT"' EXIT

cat >"$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env sh

case "$1" in
  check-ref-format)
    exec "$REAL_GIT" "$@"
    ;;
  show-ref)
    [ "${TEST_REF_EXISTS:-true}" = "true" ]
    ;;
  lfs)
    exit 0
    ;;
  push)
    shift
    printf '%s\n' "$@" >>"$GIT_PUSH_LOG"
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "$FAKE_BIN/git"

fail() {
  fail_msg="$1"
  printf 'FAIL: %s\n' "$fail_msg" >&2
  exit 1
}

assert_has() {
  assert_arg="$1"
  grep -F -x -e "$assert_arg" "$PUSH_LOG" >/dev/null || fail "push args missing: $assert_arg"
}

assert_lacks() {
  assert_arg="$1"
  if grep -F -x -e "$assert_arg" "$PUSH_LOG" >/dev/null; then
    fail "unexpected push arg: $assert_arg"
  fi
}

run_action() {
  disable_force_push="$1"
  branch="$2"
  dry_run="$3"
  github_ref_name="$4"
  github_ref_type="$5"
  ref_exists="$6"

  : >"$PUSH_LOG"
  env \
    "PATH=$FAKE_BIN:$PATH" \
    "REAL_GIT=$REAL_GIT" \
    "GIT_PUSH_LOG=$PUSH_LOG" \
    "TEST_REF_EXISTS=$ref_exists" \
    INPUT_TARGET_REPO=local-test-target \
    INPUT_GIT_USERNAME=test-user \
    INPUT_GIT_TOKEN=test-token \
    "INPUT_DISABLE_FORCE_PUSH=$disable_force_push" \
    "INPUT_BRANCH=$branch" \
    "INPUT_DRY_RUN=$dry_run" \
    "GITHUB_REF_NAME=$github_ref_name" \
    "GITHUB_REF_TYPE=$github_ref_type" \
    sh "$ROOT_DIR/entrypoint.sh" >/dev/null
}

run_action true "" false next branch true
assert_has refs/remotes/origin/next:refs/heads/next
assert_has +refs/tags/*:refs/tags/*
assert_lacks refs/remotes/origin/*:refs/heads/*
assert_lacks --force
assert_lacks --prune
printf 'PASS: safe mode pushes only the workflow branch without pruning\n'

run_action true release/next true main branch true
assert_has refs/remotes/origin/release/next:refs/heads/release/next
assert_has --dry-run
assert_lacks --force
printf 'PASS: branch override and dry run are passed through\n'

run_action false "" false main branch true
assert_has refs/remotes/origin/*:refs/heads/*
assert_has refs/tags/*:refs/tags/*
assert_has --force
assert_has --prune
printf 'PASS: force mode retains exact-mirror push arguments\n'

if run_action true "bad..branch" false main branch true >/dev/null 2>&1; then
  fail "invalid branch name was accepted"
fi
if [ -s "$PUSH_LOG" ]; then
  fail "invalid branch name reached git push"
fi
printf 'PASS: invalid branch names are rejected before push\n'

if run_action true missing false main branch false >/dev/null 2>&1; then
  fail "missing source branch was accepted"
fi
if [ -s "$PUSH_LOG" ]; then
  fail "missing source branch reached git push"
fi
printf 'PASS: missing source branches are rejected before push\n'

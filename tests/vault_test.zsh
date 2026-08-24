#!/usr/bin/env zsh
# Test suite for Vault helpers in .zsh/lib/vault.zsh and .zsh/helpers.zsh
# Verifies:
# 1. KVAULT_TOKEN is never passed in kubectl or remote process argv (no token in argv).
# 2. Token is securely framed via stdin and exported to remote vault process.
# 3. Piped stdin (e.g. cookies.json) is preserved and passed to vault stdin.
# 4. KVAULT_TOKEN remains a shell-local variable (never exported in env), even if previously exported.
# 5. kvlogin successfully reads input, authenticates via kvault token lookup, and stores token locally.
# 6. kvlogout clears KVAULT_TOKEN.
# 7. HTTP Vault requests keep tokens out of curl argv and clean temporary credentials.

set -euo pipefail

# Setup isolated test directory
TEST_DIR="$(mktemp -d -t vault-test-XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT

BIN_DIR="$TEST_DIR/bin"
LOG_DIR="$TEST_DIR/logs"
mkdir -p "$BIN_DIR" "$LOG_DIR"

# Create mock vault executable
cat << 'EOF' > "$BIN_DIR/vault"
#!/bin/sh
echo "VAULT_TOKEN=${VAULT_TOKEN:-}" >> "$VAULT_TEST_LOGS/vault_env.log"
echo "$@" >> "$VAULT_TEST_LOGS/vault_argv.log"
cat > "$VAULT_TEST_LOGS/vault_stdin.log"
if [ "$1" = "token" ] && [ "$2" = "lookup" ]; then
  if [ "${VAULT_TOKEN:-}" = "invalid-token" ]; then
    echo "Error looking up token: permission denied" >&2
    exit 2
  fi
  echo "Key             Value"
  echo "---             -----"
  echo "display_name    test-user"
  exit 0
fi
exit 0
EOF
chmod +x "$BIN_DIR/vault"

# Create mock kubectl executable
cat << 'EOF' > "$BIN_DIR/kubectl"
#!/bin/sh
echo "$@" >> "$VAULT_TEST_LOGS/kubectl_argv.log"

# Handle pod discovery
for arg in "$@"; do
  if [ "$arg" = "pod" ] || [ "$arg" = "pods" ]; then
    if [ "${MOCK_KUBECTL_ERROR:-}" = "true" ]; then
      echo "Error from server: connection refused" >&2
      exit 1
    fi
    if [ "${MOCK_KUBECTL_ACTIVE_EMPTY:-}" = "true" ]; then
      case "$*" in
        *vault-active=true*)
          exit 0
          ;;
        *)
          echo "vault-fallback-0"
          exit 0
          ;;
      esac
    fi
    if [ "${MOCK_KUBECTL_NOT_FOUND:-}" = "true" ]; then
      exit 0
    fi
    echo "vault-0"
    exit 0
  fi
done

# Handle exec
if [ "$1" = "exec" ]; then
  shift
  # Skip flags until --
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do
    shift
  done
  if [ "$1" = "--" ]; then
    shift
  fi
  # Execute the target command directly with inherited stdin/stdout
  exec "$@"
fi

exit 0
EOF
chmod +x "$BIN_DIR/kubectl"

# Export environment for test runner
export PATH="$BIN_DIR:$PATH"
export VAULT_TEST_LOGS="$LOG_DIR"

# Simulate pre-existing exported KVAULT_TOKEN before sourcing
export KVAULT_TOKEN="pre-existing-exported-token"

# Source the vault library
VAULT_LIB="$(cd "$(dirname "$0")/../.zsh/lib" && pwd)/vault.zsh"
if [[ ! -f "$VAULT_LIB" ]]; then
  echo "ERROR: Vault library not found at $VAULT_LIB" >&2
  exit 1
fi
source "$VAULT_LIB"

# Check that sourcing vault.zsh immediately unexported KVAULT_TOKEN
if env | grep -q "^KVAULT_TOKEN="; then
  echo "FAIL: KVAULT_TOKEN remained exported after sourcing vault.zsh!" >&2
  exit 1
fi
echo "PASS: Sourcing vault.zsh unexports pre-existing KVAULT_TOKEN"

echo "=== Test 1: Sentinel token absent from kubectl argv ==="
SENTINEL_TOKEN="sentinel-secret-token-xyz-12345"
KVAULT_TOKEN="$SENTINEL_TOKEN"
: > "$LOG_DIR/kubectl_argv.log"
: > "$LOG_DIR/vault_env.log"
: > "$LOG_DIR/vault_argv.log"

kvault token lookup >/dev/null

if grep -q "$SENTINEL_TOKEN" "$LOG_DIR/kubectl_argv.log"; then
  echo "FAIL: Sentinel token found in kubectl argv!" >&2
  cat "$LOG_DIR/kubectl_argv.log" >&2
  exit 1
fi

if ! grep -q "VAULT_TOKEN=$SENTINEL_TOKEN" "$LOG_DIR/vault_env.log"; then
  echo "FAIL: VAULT_TOKEN not received by mock vault environment!" >&2
  cat "$LOG_DIR/vault_env.log" >&2
  exit 1
fi

if ! grep -q "token lookup" "$LOG_DIR/vault_argv.log"; then
  echo "FAIL: Expected 'token lookup' in vault argv!" >&2
  cat "$LOG_DIR/vault_argv.log" >&2
  exit 1
fi
echo "PASS: Token framed via stdin without appearing in kubectl argv"

echo "=== Test 2: Piped cookie stdin preservation ==="
COOKIE_PAYLOAD='{"twitter":[{"name":"auth_token","value":"secret_val_42"}]}'
: > "$LOG_DIR/kubectl_argv.log"
: > "$LOG_DIR/vault_env.log"
: > "$LOG_DIR/vault_argv.log"
: > "$LOG_DIR/vault_stdin.log"

print -rn -- "$COOKIE_PAYLOAD" | kvault kv patch secret/configs/hermes-agent sourcetap-cookies.json=- >/dev/null

if grep -q "$SENTINEL_TOKEN" "$LOG_DIR/kubectl_argv.log"; then
  echo "FAIL: Sentinel token found in kubectl argv during piped call!" >&2
  exit 1
fi

RECORDED_STDIN="$(cat "$LOG_DIR/vault_stdin.log")"
if [[ "$RECORDED_STDIN" != "$COOKIE_PAYLOAD" ]]; then
  echo "FAIL: Piped stdin mismatch!" >&2
  echo "Expected: $COOKIE_PAYLOAD" >&2
  echo "Got:      $RECORDED_STDIN" >&2
  exit 1
fi
echo "PASS: Piped cookie stdin preserved exactly across stdin framing"

echo "=== Test 3: Real kvlogin execution with input and unexported token ==="
unset KVAULT_TOKEN
LOGIN_TOKEN="user-session-token-777"
: > "$LOG_DIR/kubectl_argv.log"
: > "$LOG_DIR/vault_env.log"
: > "$LOG_DIR/vault_argv.log"

# Exercise real kvlogin using here-string input
kvlogin >/dev/null <<< "$LOGIN_TOKEN"

if [[ "${KVAULT_TOKEN:-}" != "$LOGIN_TOKEN" ]]; then
  echo "FAIL: KVAULT_TOKEN not set after kvlogin (got '${KVAULT_TOKEN:-}')" >&2
  exit 1
fi

# Verify KVAULT_TOKEN is NOT exported to child processes
if env | grep -q "^KVAULT_TOKEN="; then
  echo "FAIL: KVAULT_TOKEN is exported in environment!" >&2
  exit 1
fi

# Verify kvault token lookup was executed during kvlogin without leaking token in argv
if grep -q "$LOGIN_TOKEN" "$LOG_DIR/kubectl_argv.log"; then
  echo "FAIL: Login token found in kubectl argv!" >&2
  exit 1
fi

echo "PASS: kvlogin authenticated via kvault token lookup and kept token unexported"

echo "=== Test 4: Failed kvlogin clears token ==="
unset KVAULT_TOKEN
if kvlogin >/dev/null 2>&1 <<< "invalid-token"; then
  echo "FAIL: kvlogin should have failed for invalid-token!" >&2
  exit 1
fi

if [[ -n "${KVAULT_TOKEN:-}" ]]; then
  echo "FAIL: KVAULT_TOKEN should be unset after failed login" >&2
  exit 1
fi
echo "PASS: Failed kvlogin cleared KVAULT_TOKEN"

echo "=== Test 5: kvlogout clears token ==="
KVAULT_TOKEN="temporary-token"
kvlogout >/dev/null
if [[ -n "${KVAULT_TOKEN:-}" ]]; then
  echo "FAIL: KVAULT_TOKEN not cleared after kvlogout" >&2
  exit 1
fi
echo "PASS: kvlogout cleared KVAULT_TOKEN"

echo "=== Test 6: Discovery fallback to generic Vault label when active label is empty ==="
export MOCK_KUBECTL_ACTIVE_EMPTY="true"
: > "$LOG_DIR/kubectl_argv.log"
kvault status </dev/null >/dev/null
if ! grep -q "vault-fallback-0" "$LOG_DIR/kubectl_argv.log"; then
  echo "FAIL: Discovery did not fall back to generic selector when active label was empty!" >&2
  exit 1
fi
unset MOCK_KUBECTL_ACTIVE_EMPTY
echo "PASS: Discovery falls back to generic selector when active label is empty"

echo "=== Test 7: Kubectl discovery error causes immediate failure without masking ==="
export MOCK_KUBECTL_ERROR="true"
: > "$LOG_DIR/kubectl_argv.log"
DISCOVERY_ERR_OUT=""
if DISCOVERY_ERR_OUT="$(kvault status 2>&1)"; then
  echo "FAIL: kvault should have failed when kubectl discovery failed!" >&2
  exit 1
fi
if ! grep -q "connection refused" <<< "$DISCOVERY_ERR_OUT"; then
  echo "FAIL: kubectl discovery error message was suppressed!" >&2
  echo "Got output: $DISCOVERY_ERR_OUT" >&2
  exit 1
fi
unset MOCK_KUBECTL_ERROR
echo "PASS: Kubectl discovery error causes immediate failure and remains visible"

echo "=== Test 8: Vault pod not found when both selectors return empty ==="
export MOCK_KUBECTL_NOT_FOUND="true"
NOT_FOUND_OUT=""
if NOT_FOUND_OUT="$(kvault status 2>&1)"; then
  echo "FAIL: kvault should have failed when no pod was found!" >&2
  exit 1
fi
if ! grep -q "Vault pod not found" <<< "$NOT_FOUND_OUT"; then
  echo "FAIL: Expected 'Vault pod not found' message!" >&2
  echo "Got output: $NOT_FOUND_OUT" >&2
  exit 1
fi
unset MOCK_KUBECTL_NOT_FOUND
echo "PASS: Clean error message when no Vault pod is found in namespace"

echo "=== Test 9: Sourcing library fails-closed if typeset +x fails ==="
SOURCE_FAIL_OUT="$(
  zsh -c '
    disable -r typeset
    eval "
      typeset() {
        if [[ \"\$*\" == *\"+x KVAULT_TOKEN\"* ]]; then
          return 1
        fi
        builtin typeset \"\$@\"
      }
      source \"$1\"
    "
  ' _ "$VAULT_LIB" 2>&1 || true
)"
if ! grep -q "Failed to unexport KVAULT_TOKEN" <<< "$SOURCE_FAIL_OUT"; then
  echo "FAIL: Expected 'Failed to unexport KVAULT_TOKEN' on failed source typeset!" >&2
  echo "Got output: $SOURCE_FAIL_OUT" >&2
  exit 1
fi
echo "PASS: Sourcing fails-closed with clear error when typeset fails"

echo "=== Test 10: kvlogin fails-closed before token assignment if typeset +x fails ==="
LOGIN_FAIL_OUT="$(
  zsh -c '
    disable -r typeset
    eval "
      call_count=0
      typeset() {
        if [[ \"\$*\" == *\"+x KVAULT_TOKEN\"* ]]; then
          (( call_count++ ))
          if (( call_count > 1 )); then
            return 1
          fi
        fi
        builtin typeset \"\$@\"
      }
      source \"$1\"
      unset KVAULT_TOKEN
      kvlogin <<< \"untrusted-secret-token\"
      echo \"AFTER_TOKEN=\${KVAULT_TOKEN:-<unset>}\"
    "
  ' _ "$VAULT_LIB" 2>&1 || true
)"
if ! grep -q "Failed to unexport KVAULT_TOKEN" <<< "$LOGIN_FAIL_OUT"; then
  echo "FAIL: Expected 'Failed to unexport KVAULT_TOKEN' on failed kvlogin typeset!" >&2
  echo "Got output: $LOGIN_FAIL_OUT" >&2
  exit 1
fi
if ! grep -q "AFTER_TOKEN=<unset>" <<< "$LOGIN_FAIL_OUT"; then
  echo "FAIL: KVAULT_TOKEN was assigned despite typeset failure in kvlogin!" >&2
  echo "Got output: $LOGIN_FAIL_OUT" >&2
  exit 1
fi
echo "PASS: kvlogin fails-closed and prevents token assignment when typeset fails"

echo "=== Test 11: Single-path contract for start-k8s-work in kubernetes.zsh ==="
K8S_ZSH="$(cd "$(dirname "$0")/../.zsh" && pwd)/kubernetes.zsh"
MOCK_HOME_EMPTY="$TEST_DIR/mock_home_empty"
MOCK_HOME_VALID="$TEST_DIR/mock_home_valid"
mkdir -p "$MOCK_HOME_EMPTY/dotfiles/.zsh/lib" "$MOCK_HOME_VALID/.zsh/lib"

cat << 'EOF' > "$MOCK_HOME_EMPTY/dotfiles/.zsh/lib/vault.zsh"
fallback_loaded() { echo "fallback_loaded"; }
EOF

START_K8S_FAIL_OUT="$(
  zsh -c '
    export HOME="$1"
    has() { return 0; }
    zpcompdef() { :; }
    source "$2"
    if start-k8s-work 2>&1; then
      echo "UNEXPECTED_SUCCESS"
    else
      echo "FAILED_AS_EXPECTED"
    fi
  ' _ "$MOCK_HOME_EMPTY" "$K8S_ZSH"
)"

if ! grep -q "FAILED_AS_EXPECTED" <<< "$START_K8S_FAIL_OUT" || grep -q "UNEXPECTED_SUCCESS" <<< "$START_K8S_FAIL_OUT"; then
  echo "FAIL: start-k8s-work should have failed when \$HOME/.zsh/lib/vault.zsh was missing!" >&2
  echo "Got output: $START_K8S_FAIL_OUT" >&2
  exit 1
fi

cp "$VAULT_LIB" "$MOCK_HOME_VALID/.zsh/lib/vault.zsh"
START_K8S_PASS_OUT="$(
  zsh -c '
    export HOME="$1"
    export PATH="$2:$PATH"
    has() { return 0; }
    zpcompdef() { :; }
    zinit() { :; }
    source "$3"
    start-k8s-work >/dev/null 2>&1
    if typeset -f kvlogin >/dev/null 2>&1 && typeset -f kvault >/dev/null 2>&1; then
      echo "SUCCESS_LOADED"
    else
      echo "FAILED_TO_LOAD"
    fi
  ' _ "$MOCK_HOME_VALID" "$BIN_DIR" "$K8S_ZSH"
)"

if ! grep -q "SUCCESS_LOADED" <<< "$START_K8S_PASS_OUT"; then
  echo "FAIL: start-k8s-work failed to load vault helper when \$HOME/.zsh/lib/vault.zsh was present!" >&2
  echo "Got output: $START_K8S_PASS_OUT" >&2
  exit 1
fi
echo "PASS: start-k8s-work enforces single-path contract and fails without fallback"

echo "=== Test 12: HTTP helper keeps Vault token out of curl argv and cleans credentials ==="
cat << 'EOF' > "$BIN_DIR/curl"
#!/bin/sh
printf '%s\n' "$@" > "$VAULT_TEST_LOGS/curl_argv.log"
header_file=""
for arg in "$@"; do
  case "$arg" in
    @*) header_file="${arg#@}" ;;
  esac
done
[ -n "$header_file" ] || exit 2
printf '%s\n' "$header_file" > "$VAULT_TEST_LOGS/curl_header_path.log"
cat "$header_file" > "$VAULT_TEST_LOGS/curl_header.log"
stat -c '%a' "$header_file" > "$VAULT_TEST_LOGS/curl_header_mode.log"
printf '%s\n' '{"data":{"data":{"ok":true}}}'
exit "${MOCK_CURL_STATUS:-0}"
EOF
chmod +x "$BIN_DIR/curl"

HELPERS_LIB="$(cd "$(dirname "$0")/../.zsh" && pwd)/helpers.zsh"
source "$HELPERS_LIB"
HTTP_SENTINEL_TOKEN="http-sentinel-token-9988"
HTTP_TMPDIR="$TEST_DIR/vault-http-tmp"
mkdir -p "$HTTP_TMPDIR"
TMPDIR="$HTTP_TMPDIR" vault_http_get "https://vault.example.test/v1/secret" "$HTTP_SENTINEL_TOKEN" >/dev/null

if grep -q "$HTTP_SENTINEL_TOKEN" "$LOG_DIR/curl_argv.log"; then
  echo "FAIL: HTTP Vault token appeared in curl argv!" >&2
  exit 1
fi
if ! grep -q "X-Vault-Token: $HTTP_SENTINEL_TOKEN" "$LOG_DIR/curl_header.log"; then
  echo "FAIL: HTTP Vault token was not passed through the temporary header file!" >&2
  exit 1
fi
if [[ "$(cat "$LOG_DIR/curl_header_mode.log")" != "600" ]]; then
  echo "FAIL: Temporary Vault header did not use mode 0600!" >&2
  exit 1
fi
HTTP_HEADER_PATH="$(cat "$LOG_DIR/curl_header_path.log")"
if [[ -e "$HTTP_HEADER_PATH" || -n "$(find "$HTTP_TMPDIR" -mindepth 1 -print -quit)" ]]; then
  echo "FAIL: Temporary Vault credential files were not removed!" >&2
  exit 1
fi
echo "PASS: HTTP Vault token uses a mode-0600 header file, stays out of argv, and is cleaned up"

echo "=== Test 13: HTTP helper propagates temporary header cleanup failure ==="
RM_FAIL_BIN="$TEST_DIR/rm-fail-bin"
mkdir -p "$RM_FAIL_BIN"
cat << 'EOF' > "$RM_FAIL_BIN/rm"
#!/bin/sh
/bin/rm "$@"
exit 73
EOF
chmod +x "$RM_FAIL_BIN/rm"

HTTP_CLEANUP_STATUS=0
PATH="$RM_FAIL_BIN:$PATH" TMPDIR="$HTTP_TMPDIR" \
  vault_http_get "https://vault.example.test/v1/secret" "$HTTP_SENTINEL_TOKEN" \
  >/dev/null 2>"$LOG_DIR/curl_cleanup_error.log" || HTTP_CLEANUP_STATUS=$?
if (( HTTP_CLEANUP_STATUS == 0 )); then
  echo "FAIL: HTTP helper hid temporary header cleanup failure!" >&2
  exit 1
fi
if ! grep -q "failed to remove temporary credential files" "$LOG_DIR/curl_cleanup_error.log"; then
  echo "FAIL: HTTP helper did not report temporary header cleanup failure!" >&2
  exit 1
fi
echo "PASS: HTTP helper propagates temporary header cleanup failure"

echo "=== Test 14: HTTP helper propagates temporary directory cleanup failure ==="
RMDIR_FAIL_BIN="$TEST_DIR/rmdir-fail-bin"
mkdir -p "$RMDIR_FAIL_BIN"
cat << 'EOF' > "$RMDIR_FAIL_BIN/rmdir"
#!/bin/sh
/usr/bin/rmdir "$@"
exit 74
EOF
chmod +x "$RMDIR_FAIL_BIN/rmdir"

HTTP_CLEANUP_STATUS=0
PATH="$RMDIR_FAIL_BIN:$PATH" TMPDIR="$HTTP_TMPDIR" \
  vault_http_get "https://vault.example.test/v1/secret" "$HTTP_SENTINEL_TOKEN" \
  >/dev/null 2>"$LOG_DIR/curl_cleanup_error.log" || HTTP_CLEANUP_STATUS=$?
if (( HTTP_CLEANUP_STATUS == 0 )); then
  echo "FAIL: HTTP helper hid temporary directory cleanup failure!" >&2
  exit 1
fi
echo "PASS: HTTP helper propagates temporary directory cleanup failure"

echo "=== Test 15: HTTP helper preserves curl failure when cleanup also fails ==="
HTTP_CLEANUP_STATUS=0
MOCK_CURL_STATUS=42 PATH="$RM_FAIL_BIN:$PATH" TMPDIR="$HTTP_TMPDIR" \
  vault_http_get "https://vault.example.test/v1/secret" "$HTTP_SENTINEL_TOKEN" \
  >/dev/null 2>"$LOG_DIR/curl_cleanup_error.log" || HTTP_CLEANUP_STATUS=$?
if (( HTTP_CLEANUP_STATUS != 42 )); then
  echo "FAIL: HTTP helper returned $HTTP_CLEANUP_STATUS instead of curl status 42!" >&2
  exit 1
fi
echo "PASS: HTTP helper preserves curl failure when cleanup also fails"
echo "=== ALL VAULT HELPER TESTS PASSED ==="

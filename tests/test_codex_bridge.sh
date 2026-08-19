#!/usr/bin/env bash
# Fixture tests for codex_bridge.sh: find_codex() binary detection (CODEX_BIN /
# PATH / extension-bundle precedence, version sort, platform fallback) and the
# session-id capture + resume threading, driven through a fake codex binary.
# No network, no billing. Run: tests/test_codex_bridge.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIDGE="$HERE/../scripts/codex_bridge.sh"
[[ -x "$BRIDGE" ]] || { echo "FATAL: bridge not executable: $BRIDGE"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAKE_HOME="$WORK/home"
mkdir -p "$FAKE_HOME"

# Same os-arch mapping as find_codex, so fixtures land in the preferred bin dir.
case "$(uname -s)" in
  Linux)  OS=linux ;;
  Darwin) OS=darwin ;;
  *)      OS=unknown ;;
esac
case "$(uname -m)" in
  x86_64|amd64)  [[ "$OS" == darwin ]] && ARCH=x64 || ARCH=x86_64 ;;
  arm64|aarch64) ARCH=arm64 ;;
  *)             ARCH="$(uname -m)" ;;
esac
PLAT="$OS-$ARCH"

pass=0 fail=0
check() {  # check DESC CMD... — CMD's exit status decides pass/fail
  local desc="$1"; shift
  if "$@"; then echo "ok   $desc"; pass=$((pass+1))
  else echo "FAIL $desc"; fail=$((fail+1)); fi
}

# Env-isolated bridge call: fake HOME, controlled PATH, WSL host scan off.
# RB_PATH / RB_EXTROOT / RB_CODEX_BIN configure the fixture per call.
run_bridge() {
  env HOME="$FAKE_HOME" \
      PATH="${RB_PATH:-/usr/bin:/bin}" \
      CODEX_BRIDGE_NO_WSL_SCAN=1 \
      VSCODE_EXTENSIONS="${RB_EXTROOT:-}" \
      CODEX_BIN="${RB_CODEX_BIN:-}" \
      "$BRIDGE" "$@"
}

mkexe() { mkdir -p "$(dirname "$1")"; printf '#!/bin/sh\ntrue\n' > "$1"; chmod 755 "$1"; }

# --- find_codex: explicit CODEX_BIN override ---------------------------------
mkexe "$WORK/override/codex"
out="$(RB_CODEX_BIN="$WORK/override/codex" run_bridge which)"
check "CODEX_BIN override is used verbatim" test "$out" = "$WORK/override/codex"

: > "$WORK/override/not-exec"
RB_CODEX_BIN="$WORK/override/not-exec" run_bridge which >/dev/null 2>&1
check "non-executable CODEX_BIN dies with exit 2" test "$?" -eq 2

# --- find_codex: codex on PATH -----------------------------------------------
mkexe "$WORK/pathbin/codex"
out="$(RB_PATH="$WORK/pathbin:/usr/bin:/bin" run_bridge which)"
check "standalone codex on PATH is found" test "$out" = "$WORK/pathbin/codex"

out="$(RB_CODEX_BIN="$WORK/override/codex" RB_PATH="$WORK/pathbin:/usr/bin:/bin" run_bridge which)"
check "CODEX_BIN wins over PATH" test "$out" = "$WORK/override/codex"

# --- find_codex: extension bundle under VSCODE_EXTENSIONS --------------------
EXT="$WORK/ext"
mkexe "$EXT/openai.chatgpt-0.9.0/bin/$PLAT/codex"
out="$(RB_EXTROOT="$EXT" run_bridge which)"
check "extension bundle found via VSCODE_EXTENSIONS" \
  test "$out" = "$EXT/openai.chatgpt-0.9.0/bin/$PLAT/codex"

mkexe "$EXT/openai.chatgpt-0.10.0/bin/$PLAT/codex"
out="$(RB_EXTROOT="$EXT" run_bridge which)"
check "newest extension version wins (0.10.0 > 0.9.0, sort -V)" \
  test "$out" = "$EXT/openai.chatgpt-0.10.0/bin/$PLAT/codex"

out="$(RB_EXTROOT="$EXT" RB_PATH="$WORK/pathbin:/usr/bin:/bin" run_bridge which)"
check "PATH wins over extension bundle" test "$out" = "$WORK/pathbin/codex"

EXT2="$WORK/ext2"
mkexe "$EXT2/openai.chatgpt-1.0.0/bin/weird-arch/codex"
out="$(RB_EXTROOT="$EXT2" run_bridge which)"
check "non-native bin dir found via bin/* fallback" \
  test "$out" = "$EXT2/openai.chatgpt-1.0.0/bin/weird-arch/codex"

# --- find_codex: nothing anywhere --------------------------------------------
err="$(run_bridge which 2>&1 >/dev/null)"; rc=$?
check "no binary anywhere dies with exit 2" test "$rc" -eq 2
check "not-found error names CODEX_BIN remedy" grep -q "CODEX_BIN" <<<"$err"

# --- session threading via a fake codex binary -------------------------------
# Emulates `codex exec` / `exec resume`: records argv, consumes stdin, prints a
# session id line, and writes the reply to the -o file (like the real binary).
SID=123e4567-e89b-12d3-a456-426614174000
cat > "$WORK/pathbin/fakecodex" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_CODEX_ARGS:-/dev/null}"
out=""; prev=""
for a in "$@"; do [[ "$prev" == "-o" ]] && out="$a"; prev="$a"; done
cat >/dev/null
if [[ -z "${FAKE_CODEX_NO_SID:-}" ]]; then
  echo "session id: 123e4567-e89b-12d3-a456-426614174000"
fi
[[ -n "$out" && -z "${FAKE_CODEX_EMPTY:-}" ]] && printf 'FAKE-REPLY' > "$out"
exit "${FAKE_CODEX_EXIT:-0}"
FAKE
chmod 755 "$WORK/pathbin/fakecodex"
FAKE="$WORK/pathbin/fakecodex"
ARGS="$WORK/args.log"

out="$(FAKE_CODEX_ARGS="$ARGS" RB_CODEX_BIN="$FAKE" run_bridge start --state "$WORK/t1" "q1")"
check "start echoes the reply to stdout" test "$out" = "FAKE-REPLY"
check "session id captured from transcript into .sid" test "$(cat "$WORK/t1.sid")" = "$SID"
check "start passes read-only sandbox" grep -q -- "--sandbox read-only" "$ARGS"

out="$(RB_CODEX_BIN="$FAKE" run_bridge session --state "$WORK/t1")"
check "session subcommand prints the stored id" test "$out" = "$SID"

out="$(FAKE_CODEX_ARGS="$ARGS" RB_CODEX_BIN="$FAKE" run_bridge reply --state "$WORK/t1" "q2")"
check "reply echoes the reply to stdout" test "$out" = "FAKE-REPLY"
check "reply resumes the captured session id" grep -q "exec resume $SID" "$ARGS"
check "reply re-enforces sandbox via config override" grep -q 'sandbox_mode="read-only"' "$ARGS"

# --- degraded / failure paths ------------------------------------------------
err="$(FAKE_CODEX_NO_SID=1 RB_CODEX_BIN="$FAKE" run_bridge start --state "$WORK/t2" "q" 2>&1 >/dev/null)"; rc=$?
check "missing session id: start still succeeds" test "$rc" -eq 0
check "missing session id: warning emitted" grep -q "could not capture session id" <<<"$err"
check "missing session id: no .sid written" test ! -f "$WORK/t2.sid"

RB_CODEX_BIN="$FAKE" run_bridge reply --state "$WORK/t2" "q" >/dev/null 2>&1
check "reply without prior session dies with exit 2" test "$?" -eq 2

FAKE_CODEX_EXIT=3 RB_CODEX_BIN="$FAKE" run_bridge start --state "$WORK/t3" "q" >/dev/null 2>&1
check "codex failure surfaces as exit 2" test "$?" -eq 2

FAKE_CODEX_EMPTY=1 RB_CODEX_BIN="$FAKE" run_bridge start --state "$WORK/t4" "q" >/dev/null 2>&1
check "empty final message dies with exit 2" test "$?" -eq 2

echo "-----------------------------------------"
echo "PASS=$pass FAIL=$fail"
[[ "$fail" -eq 0 ]]

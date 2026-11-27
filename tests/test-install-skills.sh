#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SH="$REPO_ROOT/scripts/install-skills.sh"
SNIPPET_MD="$REPO_ROOT/templates/AGENTS-handoff-snippet.md"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/fish996-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS_COUNT=0

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "PASS [$PASS_COUNT]: $1"
}

file_hash() {
  git hash-object -- "$1"
}

file_perm_str() {
  # Cross-platform POSIX permission string (e.g., -rw-------) via ls -l on resolved target
  ls -l "$1" | awk '{print $1}' | cut -c 1-10
}

# 1. Contract parity: install-skills.sh managed block == templates/AGENTS-handoff-snippet.md managed block
t1_dir="$TMP_ROOT/t1"
mkdir -p "$t1_dir"
bash "$INSTALL_SH" --with-rules "$t1_dir/generated.md" >/dev/null
awk '
  /^<!-- fish-996:task-handoff-rules:begin -->$/ { in_block=1 }
  in_block { print }
  /^<!-- fish-996:task-handoff-rules:end -->$/ { in_block=0 }
' "$SNIPPET_MD" > "$t1_dir/snippet_block.md"
[ -s "$t1_dir/snippet_block.md" ] || fail "T1: failed to extract managed block from snippet"
cmp -s "$t1_dir/generated.md" "$t1_dir/snippet_block.md" || {
  diff -u "$t1_dir/snippet_block.md" "$t1_dir/generated.md" >&2 || true
  fail "T1: install-skills.sh managed block diverges from AGENTS-handoff-snippet.md"
}
pass "Managed rules block matches AGENTS-handoff-snippet.md byte-for-byte"

# 2. Legacy regression: --target + --with-rules first run & idempotent second run
t2_dir="$TMP_ROOT/t2"
mkdir -p "$t2_dir"
bash "$INSTALL_SH" --target "$t2_dir/skills" --with-rules "$t2_dir/AGENTS.md" >/dev/null
[ -L "$t2_dir/skills/task-handoff" ] || fail "T2: task-handoff symlink missing"
[ -L "$t2_dir/skills/task-review-loop" ] || fail "T2: task-review-loop symlink missing"
h_before="$(file_hash "$t2_dir/AGENTS.md")"
out2="$(bash "$INSTALL_SH" --target "$t2_dir/skills" --force --with-rules "$t2_dir/AGENTS.md")"
case "$out2" in
  *"skipped"*) ;;
  *) fail "T2: expected 'skipped' on second --with-rules run, got: $out2" ;;
esac
h_after="$(file_hash "$t2_dir/AGENTS.md")"
[ "$h_before" = "$h_after" ] || fail "T2: AGENTS.md changed on idempotent skip"
pass "Legacy --target + --with-rules first run and idempotent skip"

# 3. Positive: standalone --with-rules --update-rules (without --target) preserves surrounding content byte-for-byte
t3_dir="$TMP_ROOT/t3"
mkdir -p "$t3_dir"
cat <<'EOF' > "$t3_dir/prefix.md"
# Project Rules

Custom intro line.

EOF
cat <<'EOF' > "$t3_dir/suffix.md"

### 本项目专属覆盖
- 自定义红线：严禁触碰 legacy/
EOF
{
  cat "$t3_dir/prefix.md"
  printf '<!-- fish-996:task-handoff-rules:begin -->\nOLD MANAGED CONTENT\n<!-- fish-996:task-handoff-rules:end -->\n'
  cat "$t3_dir/suffix.md"
} > "$t3_dir/AGENTS.md"
{
  cat "$t3_dir/prefix.md"
  cat "$t1_dir/snippet_block.md"
  cat "$t3_dir/suffix.md"
} > "$t3_dir/expected.md"
bash "$INSTALL_SH" --with-rules "$t3_dir/AGENTS.md" --update-rules >/dev/null
cmp -s "$t3_dir/AGENTS.md" "$t3_dir/expected.md" || {
  diff -u "$t3_dir/expected.md" "$t3_dir/AGENTS.md" >&2 || true
  fail "T3: updated AGENTS.md does not match exact byte-for-byte expectation"
}
pass "Standalone --with-rules --update-rules replaces block and preserves custom content byte-for-byte"

# 4. Positive: combined --target --force --with-rules --update-rules
t4_dir="$TMP_ROOT/t4"
mkdir -p "$t4_dir"
cp "$t3_dir/AGENTS.md" "$t4_dir/AGENTS.md"
awk '{ gsub(/HANDOFF_LEDGER\.md/, "STALE_LEDGER"); print }' "$t4_dir/AGENTS.md" > "$t4_dir/AGENTS.tmp"
mv "$t4_dir/AGENTS.tmp" "$t4_dir/AGENTS.md"
bash "$INSTALL_SH" --target "$t4_dir/skills" --force --with-rules "$t4_dir/AGENTS.md" --update-rules >/dev/null
[ -L "$t4_dir/skills/task-handoff" ] || fail "T4: skill symlink missing"
grep -Fq "HANDOFF_LEDGER.md" "$t4_dir/AGENTS.md" || fail "T4: rules block not refreshed"
! grep -Fq "STALE_LEDGER" "$t4_dir/AGENTS.md" || fail "T4: stale text remained"
pass "Combined --target --force --with-rules --update-rules"

# 5. Boundary: CRLF file --update-rules and no-marker append preserve CRLF with zero mixing
t5_dir="$TMP_ROOT/t5"
mkdir -p "$t5_dir"
CR="$(printf '\r')"
awk -v cr="$CR" '{ printf "%s%s\n", $0, cr }' <<'EOF' > "$t5_dir/crlf_update.md"
# Win Header
<!-- fish-996:task-handoff-rules:begin -->
OLD WIN BLOCK
<!-- fish-996:task-handoff-rules:end -->
# Win Footer
EOF
bash "$INSTALL_SH" --with-rules "$t5_dir/crlf_update.md" --update-rules >/dev/null
grep -Fq "HANDOFF_LEDGER.md" "$t5_dir/crlf_update.md" || fail "T5a: CRLF update missing new block"
grep -Fq "# Win Header" "$t5_dir/crlf_update.md" || fail "T5a: CRLF header lost"
grep -Fq "# Win Footer" "$t5_dir/crlf_update.md" || fail "T5a: CRLF footer lost"
# Assert EVERY line ends with CR (zero LF-only lines)
awk -v cr="$CR" '
  {
    n = length($0)
    if (n == 0 || substr($0, n, 1) != cr) { bad = NR; exit 1 }
  }
' "$t5_dir/crlf_update.md" || fail "T5a: mixed CRLF/LF detected after --update-rules"

awk -v cr="$CR" '{ printf "%s%s\n", $0, cr }' <<'EOF' > "$t5_dir/crlf_append.md"
# Win Fresh
EOF
{
  printf '# Win Fresh%s\n%s\n' "$CR" "$CR"
  awk -v cr="$CR" '{ printf "%s%s\n", $0, cr }' "$t1_dir/snippet_block.md"
} > "$t5_dir/crlf_append_expected.md"
bash "$INSTALL_SH" --with-rules "$t5_dir/crlf_append.md" >/dev/null
cmp -s "$t5_dir/crlf_append.md" "$t5_dir/crlf_append_expected.md" || {
  diff -u "$t5_dir/crlf_append_expected.md" "$t5_dir/crlf_append.md" >&2 || true
  fail "T5b: CRLF append output does not match byte-for-byte expected CRLF content"
}
pass "CRLF files preserve CRLF line endings with zero CRLF/LF mixing"

# 6. Boundary: inline code and 4-space indented code block marker examples are NOT misidentified
t6_dir="$TMP_ROOT/t6"
mkdir -p "$t6_dir"
cat <<'EOF' > "$t6_dir/body.md"
# Docs Mentioning Markers

Inline reference: `<!-- fish-996:task-handoff-rules:begin -->` and `<!-- fish-996:task-handoff-rules:end -->`.

Indented example block:

    <!-- fish-996:task-handoff-rules:begin -->
    Example indented content
    <!-- fish-996:task-handoff-rules:end -->
EOF
cp "$t6_dir/body.md" "$t6_dir/AGENTS.md"
{
  cat "$t6_dir/body.md"
  printf '\n'
  cat "$t1_dir/snippet_block.md"
} > "$t6_dir/expected.md"
bash "$INSTALL_SH" --with-rules "$t6_dir/AGENTS.md" >/dev/null
cmp -s "$t6_dir/AGENTS.md" "$t6_dir/expected.md" || {
  diff -u "$t6_dir/expected.md" "$t6_dir/AGENTS.md" >&2 || true
  fail "T6a: --with-rules output mismatch when inline/indented marker examples exist"
}
# Mutate ONLY the real top-level managed block to stale text, then verify --update-rules refreshes ONLY the top-level block
{
  cat "$t6_dir/body.md"
  printf '\n<!-- fish-996:task-handoff-rules:begin -->\nSTALE TOP LEVEL\n<!-- fish-996:task-handoff-rules:end -->\n'
} > "$t6_dir/AGENTS.md"
bash "$INSTALL_SH" --with-rules "$t6_dir/AGENTS.md" --update-rules >/dev/null
cmp -s "$t6_dir/AGENTS.md" "$t6_dir/expected.md" || {
  diff -u "$t6_dir/expected.md" "$t6_dir/AGENTS.md" >&2 || true
  fail "T6b: --update-rules did not refresh top-level block cleanly or altered inline/indented examples"
}
pass "Inline code and indented code block marker examples are not misidentified"

# 7. Boundary: no marker + missing trailing newline appends cleanly without gluing
t7_dir="$TMP_ROOT/t7"
mkdir -p "$t7_dir"
printf '# No Trailing Newline' > "$t7_dir/AGENTS.md"
bash "$INSTALL_SH" --with-rules "$t7_dir/AGENTS.md" --update-rules >/dev/null
first_line="$(head -n 1 "$t7_dir/AGENTS.md")"
second_line="$(sed -n '2p' "$t7_dir/AGENTS.md")"
third_line="$(sed -n '3p' "$t7_dir/AGENTS.md")"
[ "$first_line" = "# No Trailing Newline" ] || fail "T7: line 1 glued: $first_line"
[ -z "$second_line" ] || fail "T7: expected blank separator on line 2, got: $second_line"
[ "$third_line" = "<!-- fish-996:task-handoff-rules:begin -->" ] || fail "T7: marker missing on line 3: $third_line"
pass "No-marker file without trailing newline appends cleanly without gluing"

# 8. Boundary: symlink target + 0600 permissions preserved on --update-rules (verified against stale block)
t8_dir="$TMP_ROOT/t8"
mkdir -p "$t8_dir"
{
  cat "$t3_dir/prefix.md"
  printf '<!-- fish-996:task-handoff-rules:begin -->\nOLD_SYMLINK_BLOCK\n<!-- fish-996:task-handoff-rules:end -->\n'
  cat "$t3_dir/suffix.md"
} > "$t8_dir/real_agents.md"
chmod 0600 "$t8_dir/real_agents.md"
ln -s "$t8_dir/real_agents.md" "$t8_dir/link_agents.md"
perm_before="$(file_perm_str "$t8_dir/real_agents.md")"
[ "$perm_before" = "-rw-------" ] || fail "T8: setup perm mismatch: $perm_before"
bash "$INSTALL_SH" --with-rules "$t8_dir/link_agents.md" --update-rules >/dev/null
[ -L "$t8_dir/link_agents.md" ] || fail "T8: symlink was replaced by regular file"
perm_after="$(file_perm_str "$t8_dir/real_agents.md")"
[ "$perm_after" = "$perm_before" ] || fail "T8: permissions changed from $perm_before to $perm_after"
! grep -Fq "OLD_SYMLINK_BLOCK" "$t8_dir/real_agents.md" || fail "T8: stale block still present after symlink update"
cmp -s "$t8_dir/real_agents.md" "$t3_dir/expected.md" || {
  diff -u "$t3_dir/expected.md" "$t8_dir/real_agents.md" >&2 || true
  fail "T8: underlying symlink target did not match expected updated content"
}
pass "Symlink and 0600 permissions preserved on --update-rules with verified content update"

# 9. Boundary: --dry-run does not modify disk
t9_dir="$TMP_ROOT/t9"
mkdir -p "$t9_dir"
cat <<'EOF' > "$t9_dir/AGENTS.md"
<!-- fish-996:task-handoff-rules:begin -->
OLD
<!-- fish-996:task-handoff-rules:end -->
EOF
h9_before="$(file_hash "$t9_dir/AGENTS.md")"
out9="$(bash "$INSTALL_SH" --with-rules "$t9_dir/AGENTS.md" --update-rules --dry-run)"
case "$out9" in
  *"[dry-run]"*) ;;
  *) fail "T9: expected [dry-run] output, got: $out9" ;;
esac
h9_after="$(file_hash "$t9_dir/AGENTS.md")"
[ "$h9_before" = "$h9_after" ] || fail "T9: --dry-run modified file on disk"
pass "--dry-run leaves disk untouched"

# 10. Negative: invalid CLI argument combinations (strict non-zero exit code + stderr assertions)
t10_dir="$TMP_ROOT/t10"
mkdir -p "$t10_dir"
if bash "$INSTALL_SH" --update-rules >/dev/null 2>"$t10_dir/err10a.log"; then
  fail "T10a: --update-rules without --with-rules unexpectedly succeeded (exit 0)"
fi
grep -Fq "requires --with-rules" "$t10_dir/err10a.log" || fail "T10a: unexpected stderr: $(cat "$t10_dir/err10a.log")"

if bash "$INSTALL_SH" >/dev/null 2>"$t10_dir/err10b.log"; then
  fail "T10b: invoking with neither --target nor --with-rules unexpectedly succeeded (exit 0)"
fi
grep -Fq -- "--target or --with-rules is required" "$t10_dir/err10b.log" || fail "T10b: unexpected stderr: $(cat "$t10_dir/err10b.log")"
pass "Invalid CLI argument combinations fail with non-zero exit and clear stderr"

# 11. Negative: malformed markers Fail-Closed on BOTH --update-rules and default --with-rules
t11_dir="$TMP_ROOT/t11"
mkdir -p "$t11_dir"

cat <<'EOF' > "$t11_dir/missing_end.md"
<!-- fish-996:task-handoff-rules:begin -->
ORPHAN
EOF

cat <<'EOF' > "$t11_dir/missing_begin.md"
ORPHAN
<!-- fish-996:task-handoff-rules:end -->
EOF

cat <<'EOF' > "$t11_dir/reversed.md"
<!-- fish-996:task-handoff-rules:end -->
<!-- fish-996:task-handoff-rules:begin -->
EOF

cat <<'EOF' > "$t11_dir/dup_begin.md"
<!-- fish-996:task-handoff-rules:begin -->
<!-- fish-996:task-handoff-rules:begin -->
<!-- fish-996:task-handoff-rules:end -->
EOF

for bad_file in "$t11_dir/missing_end.md" "$t11_dir/missing_begin.md" "$t11_dir/reversed.md" "$t11_dir/dup_begin.md"; do
  hb="$(file_hash "$bad_file")"
  if bash "$INSTALL_SH" --with-rules "$bad_file" --update-rules >/dev/null 2>"$t11_dir/err.log"; then
    fail "T11: --update-rules should have failed on $bad_file"
  fi
  grep -Fq "malformed fish-996 rules markers" "$t11_dir/err.log" || fail "T11: missing marker error message for $bad_file"
  [ "$(file_hash "$bad_file")" = "$hb" ] || fail "T11: $bad_file modified on --update-rules failure"

  if bash "$INSTALL_SH" --with-rules "$bad_file" >/dev/null 2>"$t11_dir/err.log"; then
    fail "T11: default --with-rules should have failed closed on $bad_file"
  fi
  grep -Fq "malformed fish-996 rules markers" "$t11_dir/err.log" || fail "T11: missing marker error message on default --with-rules for $bad_file"
  [ "$(file_hash "$bad_file")" = "$hb" ] || fail "T11: $bad_file modified on default --with-rules failure"
done
pass "Malformed markers fail closed with zero disk modification on both --with-rules and --update-rules"

echo "ALL $PASS_COUNT TESTS PASSED"

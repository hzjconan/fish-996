#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"

MODE="symlink"
FORCE=0
DRY_RUN=0
TARGET=""
RULES_FILE=""
SELECTED_SKILLS=()

usage() {
  cat <<'EOF'
Usage:
  install-skills.sh --list
  install-skills.sh --target <preset|path> [--skill <name>]... [--mode symlink|copy] [--with-rules <file>] [--force] [--dry-run]

Target presets:
  agy-global      ~/.gemini/config/skills
  agy-project     ./.agents/skills
  claude-global   ~/.claude/skills
  claude-project  ./.claude/skills
  codex-global    ~/.codex/skills
  cursor-project  ./.cursor/skills
  <custom path>   Any custom destination directory

Options:
  --list               List all installable skills in this repository
  --target <dst>       Destination preset or directory path (required unless --list)
  --skill <name>       Install only the specified skill (repeatable; default: all)
  --mode symlink|copy  Install via symlink (default, auto-updates on git pull) or copy
  --with-rules <file>  Idempotently append default trigger rules to an AGENTS.md / CLAUDE.md / GEMINI.md file
  --force              Replace existing skill at destination
  --dry-run            Show planned actions without modifying the filesystem
  -h, --help           Show this help message

Examples:
  ./scripts/install-skills.sh --list
  ./scripts/install-skills.sh --target agy-global
  ./scripts/install-skills.sh --target claude-global --skill task-handoff --skill task-review-loop
  ./scripts/install-skills.sh --target /path/to/repo/.agents/skills --mode copy --force
  ./scripts/install-skills.sh --target /path/to/repo/.agents/skills --with-rules /path/to/repo/AGENTS.md
EOF
}

list_available_skills() {
  local d name
  for d in "$SKILLS_SRC"/*/; do
    [ -f "${d}SKILL.md" ] || continue
    name="$(basename "$d")"
    printf '%s\n' "$name"
  done
}

resolve_target() {
  case "$1" in
    agy-global)     printf '%s\n' "$HOME/.gemini/config/skills" ;;
    agy-project)    printf '%s\n' "$PWD/.agents/skills" ;;
    claude-global)  printf '%s\n' "$HOME/.claude/skills" ;;
    claude-project) printf '%s\n' "$PWD/.claude/skills" ;;
    codex-global)   printf '%s\n' "$HOME/.codex/skills" ;;
    cursor-project) printf '%s\n' "$PWD/.cursor/skills" ;;
    *)              printf '%s\n' "$1" ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --list)
      list_available_skills
      exit 0
      ;;
    --target)
      [ $# -ge 2 ] || { echo "Error: --target requires a value" >&2; exit 1; }
      TARGET="$2"
      shift 2
      ;;
    --skill)
      [ $# -ge 2 ] || { echo "Error: --skill requires a value" >&2; exit 1; }
      SELECTED_SKILLS+=("$2")
      shift 2
      ;;
    --mode)
      [ $# -ge 2 ] || { echo "Error: --mode requires symlink or copy" >&2; exit 1; }
      MODE="$2"
      shift 2
      ;;
    --with-rules)
      [ $# -ge 2 ] || { echo "Error: --with-rules requires a file path" >&2; exit 1; }
      RULES_FILE="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "Error: --target is required (or use --list)." >&2
  usage >&2
  exit 1
fi

if [ "$MODE" != "symlink" ] && [ "$MODE" != "copy" ]; then
  echo "Error: --mode must be 'symlink' or 'copy' (got '$MODE')." >&2
  exit 1
fi

if [ ${#SELECTED_SKILLS[@]} -eq 0 ]; then
  while IFS= read -r s; do
    [ -n "$s" ] && SELECTED_SKILLS+=("$s")
  done < <(list_available_skills)
fi

if [ ${#SELECTED_SKILLS[@]} -eq 0 ]; then
  echo "Error: no skills found under $SKILLS_SRC" >&2
  exit 1
fi

DEST_DIR="$(resolve_target "$TARGET")"

if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$DEST_DIR"
else
  echo "[dry-run] mkdir -p $DEST_DIR"
fi

for skill in "${SELECTED_SKILLS[@]}"; do
  if [[ "$skill" == *"/"* || "$skill" == ".." || "$skill" == "." ]]; then
    echo "Error: invalid skill name '$skill'" >&2
    exit 1
  fi

  src="$SKILLS_SRC/$skill"
  if [ ! -f "$src/SKILL.md" ]; then
    echo "Error: skill '$skill' not found at $src/SKILL.md" >&2
    exit 1
  fi

  dst="$DEST_DIR/$skill"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ "$FORCE" -ne 1 ]; then
      echo "Error: destination already exists: $dst (re-run with --force to replace)" >&2
      exit 1
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[dry-run] rm -rf $dst"
    else
      rm -rf "$dst"
    fi
  fi

  if [ "$MODE" = "symlink" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[dry-run] ln -s $src $dst"
    else
      ln -s "$src" "$dst"
      echo "Installed (symlink): $skill -> $dst"
    fi
  else
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[dry-run] cp -R $src $dst"
    else
      cp -R "$src" "$dst"
      echo "Installed (copy): $skill -> $dst"
    fi
  fi
done

if [ -n "$RULES_FILE" ]; then
  MARKER_BEGIN="<!-- fish-996:task-handoff-rules:begin -->"
  MARKER_END="<!-- fish-996:task-handoff-rules:end -->"
  if [ -f "$RULES_FILE" ] && grep -Fq "$MARKER_BEGIN" "$RULES_FILE"; then
    echo "Rules already present in $RULES_FILE (skipped)."
  elif [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] append default trigger rules to $RULES_FILE"
  else
    mkdir -p "$(dirname "$RULES_FILE")"
    {
      [ -s "$RULES_FILE" ] && printf '\n'
      cat <<EOF
$MARKER_BEGIN
## 开发工作流约定（Task Handoff & Review Loop）

- **新任务先出执行单**：收到“推进下一步”、规划任务、起草或按审稿意见修改执行单时，必须使用 \`task-handoff\` skill，在 \`docs/handoffs/\` 下起草并维护执行单；等用户审阅拍板并完成定稿后，再开始写代码。
- **验收前走独立复审闭环**：每个任务实施完成（或按外部评审返工完成）、向用户汇报验收前，必须使用 \`task-review-loop\` skill 执行「实现 → 独立只读复审 → 核实修复/举证异议 → 再复审」闭环（最多 5 轮）。
- **收口策略**：在用户明确确认验收前，不得勾选任务清单，不得 \`git commit\`，不得 \`git push\`。
$MARKER_END
EOF
    } >> "$RULES_FILE"
    echo "Appended default trigger rules to: $RULES_FILE"
  fi
fi

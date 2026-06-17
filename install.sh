#!/usr/bin/env bash
#
# Install the NPU agent helper bundle into a Claude Code environment:
#   - copies every skill in skills/ into ~/.claude/skills/
#   - sets up the npu-coding MCP server config (.mcp.json) for a project
#   - pre-approves that MCP server in ~/.claude/settings.json
#   - makes a persistent copy of the PTO-ISA docs the MCP serves
#
# Usage:
#   ./install.sh [PROJECT_DIR]      # PROJECT_DIR defaults to $PWD; .mcp.json lands there
#
# Env overrides:
#   CLAUDE_DIR     (default: $HOME/.claude)        where skills/settings/docs live
#   MCP_PY         (default: /root/repos/npu-coding-mcp/.venv/bin/python)
#                  python interpreter that runs the npu-coding MCP server
#   PTO_DOCS_SRC   (default: /sources/pto-isa/docs) source of the docs to snapshot
#
# NOTE: the npu-coding MCP *server* itself (the `npu_coding_mcp` package + its venv)
# is a separate repo and is NOT vendored here; MCP_PY must point at a working install.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
PROJECT_DIR="${1:-$PWD}"
MCP_PY="${MCP_PY:-/root/repos/npu-coding-mcp/.venv/bin/python}"
PTO_DOCS_SRC="${PTO_DOCS_SRC:-/sources/pto-isa/docs}"
DOCS_DST="$CLAUDE_DIR/mcp-data/pto-isa-docs"

echo "[install] CLAUDE_DIR=$CLAUDE_DIR  PROJECT_DIR=$PROJECT_DIR"

# 1) Skills -> ~/.claude/skills/<name>/
mkdir -p "$CLAUDE_DIR/skills"
for d in "$REPO_DIR"/skills/*/; do
  name="$(basename "$d")"
  rm -rf "$CLAUDE_DIR/skills/$name"
  cp -r "$d" "$CLAUDE_DIR/skills/$name"
  echo "[install] skill: $name"
done

# 2) Persistent snapshot of the docs the npu-coding MCP serves
if [ ! -d "$DOCS_DST" ] || [ -z "$(ls -A "$DOCS_DST" 2>/dev/null)" ]; then
  mkdir -p "$DOCS_DST"
  if [ -d "$PTO_DOCS_SRC" ]; then
    cp -r "$PTO_DOCS_SRC/." "$DOCS_DST/"
    echo "[install] docs: snapshot from $PTO_DOCS_SRC -> $DOCS_DST"
  else
    echo "[install] WARN: $PTO_DOCS_SRC not found — set PTO_DOCS_SRC or populate $DOCS_DST manually"
  fi
else
  echo "[install] docs: $DOCS_DST already present (re-sync: cp -r $PTO_DOCS_SRC/. $DOCS_DST/)"
fi

# 3) .mcp.json for the project (project-scope MCP definition)
mkdir -p "$PROJECT_DIR"
sed -e "s#@PY@#$MCP_PY#g" -e "s#@DOCS@#$DOCS_DST#g" \
  "$REPO_DIR/mcp/npu-coding.mcp.json.tmpl" > "$PROJECT_DIR/.mcp.json"
echo "[install] wrote $PROJECT_DIR/.mcp.json (server: $MCP_PY)"

# 4) Pre-approve the project MCP server so it loads without a prompt
python3 - "$CLAUDE_DIR/settings.json" <<'PY'
import json, os, sys
p = sys.argv[1]
d = json.load(open(p)) if os.path.exists(p) else {}
servers = set(d.get("enabledMcpjsonServers", []))
servers.add("npu-coding")
d["enabledMcpjsonServers"] = sorted(servers)
os.makedirs(os.path.dirname(p), exist_ok=True)
json.dump(d, open(p, "w"), indent=2)
print("[install] enabledMcpjsonServers:", d["enabledMcpjsonServers"])
PY

echo "[install] done."
echo "[install] Skills load at the START of a new Claude session."
echo "[install] Verify the MCP with:  (cd \"$PROJECT_DIR\" && claude mcp list)  -> npu-coding ... Connected"
[ -x "$MCP_PY" ] || echo "[install] NOTE: $MCP_PY not executable here — install the npu-coding-mcp server/venv (set MCP_PY)."

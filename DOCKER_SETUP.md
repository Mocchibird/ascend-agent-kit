# New-docker setup: skills, MCP, memory, Claude config

Everything we configured lives on **two host directories** that get bind-mounted into
the container. If a new docker mounts them, skills / memory / the CLAUDE.md directive /
settings / the `npu-coding` MCP all work automatically at session start. Verified layout
(2026-06-17):

| What | Path in container | Host source (persistent) |
|---|---|---|
| Skills, memory, settings.json, MCP docs snapshot | `/root/.claude` | `/home/hchang/.claude` |
| Repos, `npu-coding-mcp` + venv, `.mcp.json`, `CLAUDE.md` | `/root/repos` | `/home/hchang/repos` |
| Scratch (quant output) | `/scratch/hchang` | `/home/hchang`-side LVM |

`/root/.claude.json` and `/sources/*` are on the **ephemeral overlay** — do NOT rely on them.

## 1. Bind-mount the persistent dirs (the one essential step)

In your `docker run` (alongside your existing NPU device/driver flags), include:

```bash
docker run ... \
  -v /home/hchang/.claude:/root/.claude \
  -v /home/hchang/repos:/root/repos \
  -v /scratch/hchang:/scratch/hchang \
  # ...your existing Ascend flags: --device /dev/davinciX, /dev/davinci_manager,
  #    /dev/devmm_svm, /dev/hisi_hdc, -v /usr/local/Ascend/driver:...:ro, npu-smi ...
  <image>
```

That single pair of `.claude` + `repos` mounts brings in: all installed skills, the
`memory/` store, `settings.json` (with `enabledMcpjsonServers`), the MCP docs snapshot,
plus the repos, the MCP server code + `.venv`, `/root/repos/.mcp.json`, and
`/root/repos/CLAUDE.md`.

## 2. Start Claude from the repos root

```bash
cd /root/repos && claude
```

At session start it auto-loads: skills (from `~/.claude/skills/`), the kernel-skill
directive (`/root/repos/CLAUDE.md`), and the project MCP server (`/root/repos/.mcp.json`,
pre-approved via `enabledMcpjsonServers` in `~/.claude/settings.json`). No manual steps,
no `/command` needed — Claude will reach for the matching skill on its own.

## 3. Verify

```bash
claude mcp list           # expect: npu-coding ... ✔ Connected
ls /root/.claude/skills/  # expect the 9 skill dirs
```

In a Claude session, the skills appear in the available-skills list automatically.

## 4. Gotchas (only if something's missing in the new docker)

- **MCP server won't start / venv broken**: the venv references base Python
  `/usr/local/python3.11.15` (image-provided). If the new image ships a different Python,
  recreate the venv (config path is unchanged, so no `.mcp.json` edit needed):
  ```bash
  cd /root/repos/npu-coding-mcp
  python3 -m venv --clear .venv && .venv/bin/pip install -e .
  ```
- **`/sources/pto-isa` absent**: the MCP no longer depends on it (it serves the persistent
  snapshot at `/root/.claude/mcp-data/pto-isa-docs`). But your *kernel build* tooling uses
  `PTO_LIB_PATH=/sources/pto-isa`, so the image must still provision it. Re-sync the MCP
  docs snapshot if PTO-ISA docs change:
  `cp -r /sources/pto-isa/docs/. /root/.claude/mcp-data/pto-isa-docs/`
- **git push/pull fails (no credentials)**: the VS Code credential socket changes per
  session. Point at the live one before git ops:
  `export VSCODE_GIT_IPC_HANDLE=$(ls -t /tmp/vscode-git-*.sock | head -1)`
- **Duplicate `npu-coding` warning**: only happens in *this* original docker (a stale
  user-scope copy in the ephemeral `.claude.json`). A fresh docker won't have it.

## 5. Adding more later

- **New skill**: drop the whole skill dir into `/root/.claude/skills/<name>/` (SKILL.md +
  its `reference/` tree). Loads next session, in every docker.
- **New MCP server (persistent)**: define it in `/root/repos/.mcp.json` and add its name to
  `enabledMcpjsonServers` in `/root/.claude/settings.json`. Avoid `/root/.claude.json`
  (ephemeral — lost on a new docker).
- **New "always use X" directive**: edit `/root/repos/CLAUDE.md` (project) or create
  `/root/.claude/CLAUDE.md` (applies to every project/docker).

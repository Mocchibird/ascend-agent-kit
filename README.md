# ascend-agent-kit

A portable bundle of agent **skills** + the **npu-coding MCP** config for Ascend NPU /
PTO-ISA kernel work. Clone it into a fresh environment and run `./install.sh` to make a
Claude Code instance "just know" how to develop, test, profile, and verify NPU kernels —
no manual `/skill` calls.

## What's inside

```
skills/                      Claude Code skills (auto-loaded; descriptions injected each session)
  testing-pto-kernels          compile (bisheng) / launch (ctypes·pybind·ACL) / run / verify PTO kernels + CA-model sim
  pto-isa-operator-implementation  implement an operator in PTO-ISA (ISA choice, dataflow, codegen)
  npu-arch                     chip / NpuArch / SocVersion / feature-support / conditional-compile
  ops-simulator                functional + perf + pipeline analysis without NPU hardware
  ops-profiling                on-device perf collection, msprof bottlenecks, speedup-vs-baseline
  ops-precision-standard       accuracy thresholds (atol/rtol per dtype), ST precision tests
  npu_kernel_general           compile->run->verify definition-of-done for NPU kernels
  pr_feedback, caveman         general-purpose skills
mcp/
  npu-coding.mcp.json.tmpl     project-scope MCP definition (@PY@/@DOCS@ filled by install.sh)
install.sh                     installs skills + MCP config into a Claude env
DOCKER_SETUP.md                how to make all of this persist across containers
```

Skill sources: `testing-pto-kernels` from
[huawei-csl/pto-kernels#176](https://github.com/huawei-csl/pto-kernels/pull/176);
`pto-isa-operator-implementation` from gitcode `cann/pto-isa`; `npu-arch` / `ops-*` from
gitcode `cann/cannbot-skills`; `caveman` from JuliusBrussee/caveman.

## Install

```bash
./install.sh [PROJECT_DIR]      # PROJECT_DIR defaults to $PWD
```

This (idempotently):
1. copies every `skills/<name>/` into `~/.claude/skills/`,
2. snapshots the PTO-ISA docs to `~/.claude/mcp-data/pto-isa-docs` (from `/sources/pto-isa/docs`),
3. writes `PROJECT_DIR/.mcp.json` defining the `npu-coding` MCP server, and
4. adds `npu-coding` to `enabledMcpjsonServers` in `~/.claude/settings.json` so it loads
   with no approval prompt.

Env overrides: `CLAUDE_DIR` (default `$HOME/.claude`), `MCP_PY` (python that runs the
server, default `/root/repos/npu-coding-mcp/.venv/bin/python`), `PTO_DOCS_SRC`
(default `/sources/pto-isa/docs`).

> The `npu-coding` **MCP server itself** (the `npu_coding_mcp` package + venv) is a
> separate repo and is **not** vendored here — `MCP_PY` must point at a working install.

Then start a new Claude session in `PROJECT_DIR`. Verify:

```bash
ls ~/.claude/skills/                 # the skill dirs
claude mcp list                      # npu-coding ... ✔ Connected
```

Skills only take effect at the **start** of a session.

## Why skills, not "skills inside the MCP"

Skills and MCP are different layers: MCP serves tools/resources (here, PTO-ISA docs
search); skills are auto-loaded `SKILL.md` instructions Claude reads every session. You
don't register skills with an MCP server — dropping them in `~/.claude/skills/` is enough
for Claude to see them, and a project `CLAUDE.md` directive makes it use them proactively.

## Cross-container persistence

See [`DOCKER_SETUP.md`](DOCKER_SETUP.md). Short version: if the container bind-mounts the
host's `~/.claude` and your repos dir, everything here persists automatically; otherwise
clone this repo in the new container and run `./install.sh`.

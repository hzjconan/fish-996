# 🎣 fish-996

> **Automate the boring stuff, escape 996, and go fishing.**  
> 用自动化和 AI 技能消灭重复劳动，把省下来的时间留给摸鱼和生活。

## 💡 这是什么？
这里存放了我在日常编程与项目开发中沉淀下来的 **Agent Skills / 模板 / 自动化脚本**。  
核心准则只有一条：**能交给脚本和 AI 干的活，绝不自己加班手敲。**

## 📁 目录结构
* **`/skills`**：遵循 Agent Skills 规范、可独立安装的共享技能（支持 Antigravity / Claude Code / Codex / Cursor 等）
* **`/templates`**：开箱即用的项目规则片段（`AGENTS.md` 接入模板等）与脚手架
* **`/scripts`**：技能安装脚本与日常防加班自动化小脚本
* **`/tests`**：脚本与模板一致性的跨平台回归测试

## 🧰 技能清单 (Skills)

| Skill | 说明 | 适用场景 |
| :--- | :--- | :--- |
| [`task-handoff`](./skills/task-handoff/SKILL.md) | 选任务前置 + 按需轻量 Scout 预摸底 + 高思考模型渐进式精读起草单源真相执行单 → 休眠承接修订 → 默认推荐态由主会话零唤醒直定稿 | 规划下一步任务、在大/中型仓库低上下文起草/修订/定稿零歧义施工单，供较轻/经济模型照图施工 |
| [`task-review-loop`](./skills/task-review-loop/SKILL.md) | 实施后留存仓外临时索引整树快照 `T_CUR` → 派发隔离高思考只读审查员（加载精简独立协议）→ `HEAD..T_CUR` / `T_PREV..T_CUR` 精确增量复审 + 6 类攻击面核查 → 最多 5 轮收敛与验收收口台账衔接 | 任务实现或外部评审返工完成后、汇报验收与 commit 前的高效独立质量闭环 |

> **零配置向后兼容**：两个 skill 可**成套使用**，也可**单独安装使用**；自动读取目标项目根目录的 `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` 继承红线、门禁与收口策略。老项目无需新增 `CODEBASE_MAP.md` / `HANDOFF_LEDGER.md` 即可直接平滑升级（无台账时按任务依赖定向读取上游单关键节，绝不自动误读老仓库 `ARCHITECTURE.md`，亦不移动历史执行单）。

## 🚀 安装与升级方式

### 方式 1：使用 `npx skills` 一键安装（推荐，跨工具/跨平台通用）
```bash
# 安装本仓库全部 skills
npx skills add hzjconan/fish-996

# 或仅安装单个 skill
npx skills add hzjconan/fish-996 --skill task-handoff
npx skills add hzjconan/fish-996 --skill task-review-loop
```

### 方式 2：Antigravity 原生 `skills.json` 零拷贝引用（`git pull` 即全局更新）
本地 clone 本仓库后，在全局 `~/.gemini/config/skills.json` 或单个项目的 `.agents/skills.json` 中加入：
```json
{
  "entries": [
    {
      "path": "~/workspace/fish-996/skills",
      "include_only": ["task-handoff", "task-review-loop"]
    }
  ]
}
```

### 方式 3：使用本地安装脚本（软链或拷贝，支持 macOS / Linux / Git Bash & WSL）
```bash
# 查看可安装技能
./scripts/install-skills.sh --list

# 软链安装到 Antigravity 全局（支持 agy-global / agy-project / claude-global / claude-project / codex-global / cursor-project 或自定义路径）
./scripts/install-skills.sh --target agy-global

# 仅拷贝安装单个 skill 到指定项目
./scripts/install-skills.sh --target /path/to/repo/.agents/skills --skill task-handoff --mode copy

# 安装并把触发规则幂等追加到目标项目的 AGENTS.md（跨工具通用，免手动复制）
./scripts/install-skills.sh --target /path/to/repo/.agents/skills --with-rules /path/to/repo/AGENTS.md

# 已有项目仅原地刷新受管规则块（保留块外用户自定义配置，适配 skills.json / npx skills 用户）
./scripts/install-skills.sh --with-rules /path/to/repo/AGENTS.md --update-rules
```

> **关于 `--with-rules` 边缘匹配行为说明**：脚本现统一按“仅剥离行尾 `\r`/空白、保留行首缩进的整行匹配”校验受管标记——① 若目标文件存在损坏标记（如缺配对结束标记），将 Fail-Closed 报错退出（`exit 1`）并保持原文件零改动，不再静默 `skipped`；② 若正文仅在行内代码或缩进代码块中引用了标记示例文本，不再误判跳过，而是正常追加受管区块。

### ⚙️ 模型档位与大仓库上下文索引（均可选）
- **默认模型策略**：`designer` / `reviewer` 节点默认选用同系列 **`High`** 思考档位，**不会**默认自动升级到 `XHigh`；可在项目规范文件（`AGENTS.md` / `CLAUDE.md` / `GEMINI.md`）按需覆写（纯可选，不强制写死），或在对话中口头临时指定。
- **可选上下文外存（大仓库降本）**：在项目中可选维护 `docs/CODEBASE_MAP.md`（≤ 250 行架构地图）与 `docs/HANDOFF_LEDGER.md`（≤ 100 行滚动台账）；老项目可显式让 Agent“初始化本项目上下文索引”按需生成，也可在项目规范文件中声明 `上下文台账：不启用` 永久关闭提示。完整可复制配置见 [`templates/AGENTS-handoff-snippet.md`](./templates/AGENTS-handoff-snippet.md)。

---
*Made with ☕ and the desire to clock out on time.*

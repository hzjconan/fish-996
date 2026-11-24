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

## 🧰 技能清单 (Skills)

| Skill | 说明 | 适用场景 |
| :--- | :--- | :--- |
| [`task-handoff`](./skills/task-handoff/SKILL.md) | 高思考模型深度摸底 + 起草人机分层单源真相执行单 → 休眠保上下文承接修订 → 拍板折叠定稿 | 规划下一步任务、起草/修订/定稿零歧义施工单，供较轻/经济模型照图施工 |
| [`task-review-loop`](./skills/task-review-loop/SKILL.md) | 实施后留存 Git 防篡改快照 → 派发隔离上下文的高思考只读审查员 → 双重审查 + 6 类攻击面核查 → 最多 5 轮收敛与僵局早停 | 任务实现或外部评审返工完成后、汇报验收与 commit 前的独立质量闭环 |

> 两个 skill 可**成套使用**，也可**单独安装使用**；会自动读取目标项目根目录的 `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` 继承项目红线、门禁命令与收口策略。

## 🚀 安装方式

### 方式 1：使用 `npx skills` 一键安装（推荐，跨工具通用）
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

### 方式 3：使用本地安装脚本（软链或拷贝）
```bash
# 查看可安装技能
./scripts/install-skills.sh --list

# 软链安装到 Antigravity 全局（支持 agy-global / agy-project / claude-global / claude-project / codex-global / cursor-project 或自定义路径）
./scripts/install-skills.sh --target agy-global

# 仅拷贝安装单个 skill 到指定项目
./scripts/install-skills.sh --target /path/to/repo/.agents/skills --skill task-handoff --mode copy

# 安装并自动把触发规则幂等追加到目标项目的 AGENTS.md（跨工具通用，免手动复制）
./scripts/install-skills.sh --target /path/to/repo/.agents/skills --with-rules /path/to/repo/AGENTS.md
```

### ⚙️ 模型档位与项目级覆写（Override）
- **默认策略**：`designer` / `reviewer` 节点默认选用同系列 **`High`** 思考档位，**不会**默认自动升级到 `XHigh`。
- **覆写为 `XHigh` 或指定模型**：
  - **项目级持久化**：在目标项目 `AGENTS.md`（或 `CLAUDE.md` / `GEMINI.md`）中声明偏好（支持统一指定或按 `designer` / `reviewer` 分别指定），完整可复制示例见 [`templates/AGENTS-handoff-snippet.md`](./templates/AGENTS-handoff-snippet.md)；
  - **单次临时覆写**：直接在对话中口头指定即可（如“这次起草 handoff 用 `XHigh`”）。

> 如需在某个项目中**强制每次默认触发**（而非依赖模型按需识别），可用上方 `--with-rules` 一键写入，或参考 [`templates/AGENTS-handoff-snippet.md`](./templates/AGENTS-handoff-snippet.md) 按需配置。

---
*Made with ☕ and the desire to clock out on time.*

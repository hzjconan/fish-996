# 项目接入模板：`AGENTS.md` 片段

将下方片段复制到目标项目的 `AGENTS.md`（或 `CLAUDE.md` / `GEMINI.md`）中，并按项目实际情况删改占位符即可启用 `task-handoff` 与 `task-review-loop`。

```markdown
<!-- fish-996:task-handoff-rules:begin -->
## 开发工作流约定（Task Handoff & Review Loop）

- **新任务先出执行单**：收到“推进下一步”、规划任务、起草或按审稿意见修改执行单时，必须使用 `task-handoff` skill，在 `docs/handoffs/` 下起草并维护执行单；等用户审阅拍板并完成定稿后，再开始写代码。
- **验收前走独立复审闭环**：每个任务实施完成（或按外部评审返工完成）、向用户汇报验收前，必须使用 `task-review-loop` skill 执行「实现 → 独立只读复审 → 核实修复/举证异议 → 再复审」闭环（最多 5 轮）。
- **收口策略**：在用户明确确认验收前，不得勾选任务清单，不得 `git commit`，不得 `git push`；待用户明确确认验收进入收口时，若项目启用了 `HANDOFF_LEDGER.md`（或需同步 `CODEBASE_MAP.md`），须先一并落盘更新台账与地图后再提交。
<!-- fish-996:task-handoff-rules:end -->

### 本项目专属覆盖（供上述 skill 自动继承）

- **任务追踪源**：<!-- 如 `specs/001-xxx/tasks.md` 或 `TODO.md`；无则删除此行 -->
- **项目红线**：
  - <!-- 如：严禁读取 `inputs/` 目录下的任何文件 -->
  - <!-- 如：`artifacts/` 下的历史基线产物只读，审查员严禁运行会写盘的命令 -->
- **验收门禁命令**：
  - 测试：`<!-- 如 pytest / npm test / go test ./... -->`
  - Lint / 类型检查：`<!-- 如 ruff check src tests / npm run lint -->`
  - 只读基线校验（可选）：`<!-- 如 shasum -a 256 -c ... -->`
- **附加产出（可选）**：<!-- 如同步更新 `CHANGELOG.md` / `docs/architecture.md` / 学习笔记 -->
- **项目架构地图（可选）**：<!-- 如 `docs/CODEBASE_MAP.md`；未声明时仅自动探测默认 `docs/CODEBASE_MAP.md` -->
- **上下文台账（可选）**：<!-- 如 `docs/HANDOFF_LEDGER.md`；填 `不启用` 可永久关闭超阈值提示 -->
- **符号大纲命令（可选，零依赖可省略）**：<!-- 如项目自有骨架脚本 / `ctags` 命令；未声明时自动使用内置搜索或 `rg`/`git grep` -->
- **高思考模型偏好（可选，默认同系列 `High` 档位，不默认升 `XHigh`）**：
  - <!-- 统一用 XHigh 示例：`designer` 与 `reviewer` 节点优先使用同系列 `XHigh` 档位（如 `gemini-4-neon-xhigh`）。 -->
  - <!-- 按角色分别指定示例：`designer` 用 `gemini-4-neon-xhigh`，`reviewer` 用 `gemini-4-neon-high`。 -->
```

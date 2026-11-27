# Task Skills（Designer & Reviewer）上下文与 Token 优化（向后兼容升级）执行单

- **状态**：已拍板定稿（待实施）
- **Git 基线**：`main` @ `ff1e65a`
- **关键基线**：本仓库为跨 CLI、跨平台（macOS / Linux / Windows）通用 Agent Skills 集合，零外部运行时依赖。本机验证样本为 macOS `GNU bash 3.2.57`、`git 2.55.0`（无 `rg`、BSD `sed`/`awk`/`ctags`）；脚本以 Bash 3.2 + POSIX `awk` 作为类 Unix（macOS / Linux / Windows Git Bash & WSL）最小公共子集，原生 Windows PowerShell 用户走 `npx skills` / `skills.json` 零脚本路径，Skill 检索与整树快照规则兼容三端。
- **拍板决议摘要**：1A / 2A / 3A / 4B（用户确认按推荐项施工，下篇已为无条件分支终态）

> **红线声明**
> - 设计阶段仅创建/更新本执行单，**严禁改动仓库内任何 skill、模板、脚本或 README**；
> - 严禁破坏 `fish-996` 的核心设计原则：**零外部依赖、跨 CLI 通用、老项目零配置向后兼容、不强制在项目 `AGENTS.md` 中写死精确模型名**；
> - 严禁以“节约 token”为由削弱 `designer` 的源码级契约与完整性核实，或削弱 `reviewer` 的**隔离上下文、高思考档位、整树防篡改快照、零信任全量改动面复验与 6 类攻击面必查清单**；
> - 严禁在用户确认验收前提前收口或改写台账；未经用户明确确认验收，不 `git commit`、不 `git push`。

---

## 上篇：面向用户与第三方评审

### 1. 改动目的、背景与目标

#### 1.1 为什么要做这次改动（核心痛点）
当前 `task-handoff` + `task-review-loop` 工作流采用「高思考 `designer` 出详细施工单 → 经济模型（如 `medium`）按图施工 → 隔离高思考 `reviewer` 闭环复审 → 任务结束后 `/clear` 清空上下文开启下一任务」模式。在中小型项目阶段质量极高，但随着代码量与任务数增长，`designer` 和 `reviewer` 两个高思考节点的上下文体积与 token 消耗会显著放大：

**A. `designer`（设计阶段）的 4 个放大器**
1. **高价模型承担廉价广度摸底**：当前 [skills/task-handoff/SKILL.md](../../skills/task-handoff/SKILL.md) 的全部摸底都由 `High`/`XHigh` 的 `designer` 自行完成。无状态 Agent 工具循环每轮重发全部历史上下文并触发高思考输出，串行试错读取产生近似 $O(N^2)$ 的累计输入消耗与大量不可缓存思考输出。
2. **开放式“推进下一步”导致横向多候选扫描**：由 `designer` 同时承担选任务与详细设计，迫使其先通读任务清单并横向摸底多个候选任务源码。
3. **`/clear` 后冷启动重复摸底 + 历史执行单噪音膨胀**：每任务 `/clear` 有效避免了跨任务上下文腐烂（Context Rot）与旧代码漂移（Stale Context），但项目模块拓扑、公共复用设施与历史陷阱未以极精简形式持久化；同时 `docs/handoffs/` 累积大量长文档，通读旧单会吸入大量过期噪音。
4. **缺少渐进阅读、推荐态终稿写法与默认定稿减负纪律**：未区分核心精读与外围只看签名、未约束分阶段并行读；下篇正文穿插条件分支导致默认拍板时仍需再次唤醒背着庞大上下文的 `@designer`。

**B. `reviewer`（独立复审阶段）的 4 个放大器**
1. **Round 2+ 多轮复审重复倾倒累积 `git diff`**：虽已复用 `@reviewer` 会话，但 `git diff` 始终对比 `HEAD`，每轮续审都会把 Round 1 已审过的累积 diff 重复灌进同一个高价上下文；且现有快照未覆盖未跟踪文件内容。
2. **Round 1 强读大文件全文、测试绿字刷屏与串行高思考**：大仓库仅改千行文件 20 行即强读全文；复跑测试未限制摘要输出导致数千行 `PASSED` 日志刷屏；审查员还得全文加载包含大量实施方流程的 `task-review-loop/SKILL.md` 并串行跑 8–10 轮。
3. **非契约区噪音与啰嗦输出**：通读执行单纯背景与长篇 Q&A 附录，对无问题攻击面输出大段文字，消耗最贵的 High/XHigh Output Tokens。
4. **冷启动盲搜全仓入口**：核查攻击面 #1 时缺乏轻量入口种子清单，被迫扫半个仓库。

#### 1.2 本次改动目标（做什么 & 守住什么底线）
- **降本目标**：保持「每任务 `/clear` + 定稿即回收 `designer` + 隔离 `reviewer` 闭环」主架构不变，对 **`designer` 与 `reviewer` 双向减负**，同时把两个 `SKILL.md` 正文双双压至 **≤ 160 行**（将编排细节、迁移流程、审查员独立协议分别按需拆入 `references/`）。
- **质量底线（零妥协）**：
  - `designer` 不仅核验核心目标文件正确性，凡改签名/改行为符号仍必亲自全仓搜索调用方与 `mock`/`patch` 保证完整性；
  - `reviewer` 完整保留意见分级定义、双重审查视角与 Round 2+ 聚焦防漂移规则（迁入独立 `references/reviewer-protocol.md` 单源维护）；引入**临时索引整树快照 `T_n` + 审查员只读新鲜度核验**，在精确实现 Round 1 `HEAD..T_1` 统一 diff 与 Round 2+ 纯增量 diff 的同时，连未跟踪文件内容与等长静默篡改（`B -> C`）一并捕获；快照/golden 文件必审定向 diff、lockfile 异常变动必阻断、大文件切片必文件内 grep 全引用、静默测试必查 `-rsxX` 跳过（测试矩阵明文豁免除外）与实跑计数、终轮通过必有全量门禁兜底。
- **向后兼容底线（零破坏 + 边缘收紧明文披露）**：老仓库不改一行文件、不执行 `--update-rules`、没有 `CODEBASE_MAP.md` / `HANDOFF_LEDGER.md` 时，常规行为零退化、不误读老仓库过期 `ARCHITECTURE.md`、不移动/破坏历史单相对链接、不违背老规则块约定；对 `--with-rules` 整行匹配口径带来的 2 处更安全的边缘行为变化在 §5.1 与 `README.md` 中明文披露；且提供基于 4 类植入缺陷（新旧对照 × ≥ 2 次）+ 1 类 `designer` 完整性用例的人工行为验收基准，验证质量零退化与真实降本。

---

### 2. 待用户拍板的决策清单

<!-- 下篇正文已严格按全部推荐项（1A / 2A / 3A / 4B）写成无条件分支的干净终态；非推荐备选项仅在本节注明差量。全选推荐（1A 2A 3A 4B）时，主会话直接更新顶部 3 行元信息即可定稿，无需再次唤醒 designer。 -->

1. **「推进下一步」的选任务前置策略**
   - **1A（推荐 · 主会话定题，依赖明确直通、有歧义才停步）**：主会话（`medium`）先读任务追踪源与台账定题，在 `brief` 中附候选清单与定题理由；依赖明确则直接推进，存在多并列无优先级候选项时先向用户确认；`designer` 不再横向扫描其他候选源码，仅核验所选任务前置依赖，**依赖不满足必须停步报回用户，严禁硬写**。
   - **1B（一律两步确认）**：*差量：在 `references/orchestration.md` 中将“依赖明确直通”改为凡开放式“推进下一步”一律先汇报推荐任务，等用户明确确认后再推进。*

2. **轻量预摸底（Scout → Context Pack）的默认策略**
   - **2A（推荐 · 按需启用一次性便宜只读子代理，无则主会话轻量兜底）**：仅在跨多模块/大仓库且用户未指定具体文件时启用 1 个一次性只读 `research/flash`（明文标注为对 `SKILL.md L39` 防模型漂移红线的**有意限定例外，仅限坐标导航**）产出只含坐标、不贴大段代码的 Context Pack（≤ 150 行）；用户已给具体文件或任务范围很小时直接跳过 Scout 避免付两次钱；无便宜子代理则主会话轻量定位；单会话直出则走渐进阅读。`designer` 对核心代码与改签名调用方仍须亲自核验正确性与完整性。
   - **2B（不引入 Scout 子代理，统一由主会话轻量定位）**：*差量：删除 `references/orchestration.md` 中的 `research/flash` 首选分支与 L39 例外声明，统一由 `medium` 主会话做 ≤ 2 轮定向定位打包。*
   - **2C（纯阅读纪律版，不做预摸底拆分）**：*差量：删除 `references/orchestration.md` 的 Scout 章节与 `context-templates.md` 中的 Context Pack 模板，仅保留 Map/Ledger + 渐进式并行阅读。*

3. **老项目 `CODEBASE_MAP.md` / `HANDOFF_LEDGER.md` 同步与收口机制（已去掉 `archive/` 归档）**
   - **3A（推荐 · 零配置向下兼容 + 外置 1 行按需初始化 + 收口待办与规则块同步 + 可关提示开关）**：
     - 老项目无上述文件时静默降级；**去掉自动化 `archive/` 归档**（保留历史单原路径防断链与误移，归档仅作用户手工可选）；
     - 老项目初始化指南外置到 `references/bootstrap-migration.md`，`SKILL.md` 正文仅留 1 行按需指针（~25 tokens，常规任务严禁读取）；
     - 无台账且 `docs/handoffs/` ≥ 5 份时汇报末附 1 行提示，支持在项目规范文件（`AGENTS.md` / `CLAUDE.md` / `GEMINI.md`）声明 `上下文台账：不启用` 永久关闭；
     - `task-review-loop` 第 5 步汇报末尾输出带台账增量的「收口待办」，并在新版 `AGENTS.md` 受管规则块写入“收口时同步更新 `HANDOFF_LEDGER.md`（按需更新 `CODEBASE_MAP.md`）”，防止台账过期。
   - **3B（只读不写，全由用户手动维护）**：*差量：不新增 `references/bootstrap-migration.md`，去掉超阈值提示、`task-review-loop` 收口台账待办及 `scripts/install-skills.sh` 的 `--update-rules` 改动，仅保留只读探测 Map/Ledger 能力。*

4. **是否顺带纳入「S 级极小任务免 `designer` 轻量通道」**
   - **4B（推荐 · 本次不引入 S 级免 `designer` 通道）**：S 级通道本质是放宽质量门槛而非上下文优化，且与老仓库已写入的 `AGENTS.md` 规则块（“必须在 `docs/handoffs/` 起草执行单”）存在冲突，同时由便宜模型自判跳过容易偏向偷懒。本次聚焦零质量退化的上下文与 token 优化，所有任务保持统一流程。
   - **4A（引入保守 S 级通道）**：*差量：在 `references/orchestration.md` 中新增 S 级条款，但须附加两条硬约束——① S 级任务仍必须在 `docs/handoffs/` 落盘一份极简执行单（兼顾老规则块与 `reviewer` 基线）；② 主会话仅可提议走 S 级，必须经用户明确确认后才允许跳过 `designer`。*

---

## 下篇：面向实施方的零歧义施工图

<!-- 本篇严格按推荐项（1A / 2A / 3A / 4B）写成无条件分支终态。 -->

### 3. 现状锚点与跨平台/跨工具陷阱预警

#### 3.1 现有文件锚点
| 文件 | 精确位置 | 当前职责与本次改动关联 |
| :--- | :--- | :--- |
| `skills/task-handoff/SKILL.md` | `L18-L26` | 第 0 步：项目上下文发现（扩展 Map/Ledger/关闭开关/大纲命令可选发现；只认第 0 步识别到的项目规范文件 `AGENTS.md`/`CLAUDE.md`/`GEMINI.md` 显式声明的路径与默认 `docs/CODEBASE_MAP.md`） |
| `skills/task-handoff/SKILL.md` | `L35-L55` | 派发与生命周期（`L39` 增补 Scout 有意限定例外；`L42-L46` `brief` 增补候选/定题理由与可选 Context Pack；`L52` 默认拍板强制主会话直定稿不唤醒 `@designer`） |
| `skills/task-handoff/SKILL.md` | `L57-L64`, `L79-L83` | 摸底清单与上/下篇起草规范（升级渐进摸底、无台账按依赖读上游单关键节、Map/Ledger 种子线索、下篇按推荐态写无条件分支终态、已定题免横向对比） |
| `skills/task-handoff/references/handoff-template.md` | `L21-L36`, `L105-L106`, `L119-L120` | §1 已定题引用写法、§2 差量写法与下篇推荐态终稿注释、§8 `CODEBASE_MAP.md` 同步提示、文末收口入账占位 |
| `skills/task-review-loop/SKILL.md` | `L17-L24`, `L31-L33`, `L44-L50`, `L65-L86`, `L100-L106`, `L120-L134` | 实施方主流程精简至 ≤ 160 行：引入临时索引整树快照 `T_n`、`brief` 与降级 2 自查统一指向独立 `references/reviewer-protocol.md`（原 `L31-33` 意见分级、`L77-79` 双重视角、`L105` Round 2+ 防漂移整体迁出单源维护）、Round 2+ 传 `T_{n-1}`/`T_n` 与增量清单、第 5 步附「验收收口待办」 |
| `templates/AGENTS-handoff-snippet.md` | `L5-L26` | 顶部受管规则块加入成对 marker 并与 `install-skills.sh` 逐字对齐（新增收口更新台账）；`本项目专属覆盖` 补充可选 Map、Ledger（含 `不启用` 开关）、大纲命令占位 |
| `scripts/install-skills.sh` | `L15-L47`, `L70-L120`, `L188-L211` | 同步新版受管规则块、新增 `--update-rules` 与单更规则、统一 marker 整行匹配口径、保真 CRLF/LF、POSIX `awk` + `getline` 临时文件校验回写 |
| `README.md` | `L15-L22`, `L49-L70` | 技能清单、向后兼容与 `--update-rules` 说明同步 |

#### 3.2 跨平台（macOS / Linux / Windows）与跨工具陷阱预警
- **临时索引整树快照 `T_n` 边界、zsh 转义陷阱与大文件提示**（已在本机 `git 2.55.0` 实测验证）：
  - 实施方临时目录 `TMPD` **必须建在目标仓库目录树之外**（如 `${TMPDIR:-/tmp}`，严禁放仓内导致 `git add -A` 把临时 `idx`/`idx.lock` 自身打进树快照；且严禁写死共享 `/tmp/fish996-idx` 防并发冲突）；复用真实 index 的 stat 缓存（`REAL_IDX="$(git rev-parse --git-path index)"`；若新仓尚无 index 文件则跳过 `cp`，严禁预先创建 0 字节文件导致 `git` 报 `index file smaller than expected`），随后 `GIT_INDEX_FILE="$IDX" git add -A && GIT_INDEX_FILE="$IDX" git write-tree` 生成 `T_n`，并在 `trap` 中清理临时目录；Windows PowerShell 改用 `$env:GIT_INDEX_FILE` + `try/finally` 清理；
  - **审查员只读新鲜度核验、路径转义与 `zsh` `:u` 修饰符陷阱**：审查员严禁盲信 `T_CUR` 为最新——须通过 `git -c core.quotePath=false diff --name-status "$T_CUR"` 对比 `git -c core.quotePath=false ls-files --others --exclude-standard`（及 `git -c core.quotePath=false status --porcelain -uall` 核对暂存/工作区状态）核验已跟踪文件与未跟踪列表（避免 `--stat` 截断超长路径及默认 `core.quotePath=true` 八进制转义；本机实测即使开启 `core.quotePath=false`，`status --porcelain` 仍会对含空格路径加双引号，而 `diff --name-status` 与 `ls-files --others --exclude-standard` 均输出无截断、无引号的原始完整路径，可直接逐行一一对应并安全喂给下游命令），并对每个未跟踪文件 `<f>` 只读比对 `git hash-object -- "<f>"` 与 `git rev-parse "${T_CUR}:<f>"`；**所有 Shell 变量名须合法（如 `"$T_PREV"` `"$T_CUR"`，严禁写 `"$T_{n-1}"`），且所有 `<tree>:<path>` 写法必须加花括号与双引号 `"${T_CUR}:<path>"`**（macOS 默认 `zsh` 中写成 `$T:u.txt` 会把 `:u` 解析为转大写修饰符而报错）；
  - **覆盖边界与未忽略大文件提示**：`T_CUR` 仅覆盖**未被 `.gitignore` 忽略的文件**（措辞严禁夸大为覆盖被忽略文件）；同时保留 `git -c core.quotePath=false status --porcelain -uall` 与 `git diff --cached | git hash-object --stdin`，防止误执行 `git add`/`git reset` 改动真实暂存区却未改工作区文件。另外，`git add -A` 遇到未被 `.gitignore` 忽略的大文件时会向 `.git/objects/` 写入松散 blob 对象（可由 `git gc` 回收，但存在未忽略大二进制/数据集的仓库应规范 `.gitignore` 或按需回退只读指纹）；
  - **受限环境与无初始提交新仓兜底**：若 `.git/objects` 只读导致 `git write-tree` 失败，自动回退纯只读快照（`git -c core.quotePath=false status --porcelain -uall` + `git diff` hash + `git diff --cached` hash + 未跟踪文件逐个 `git hash-object`）；Round 1 若仓库尚无初始提交（`HEAD` 不存在），严禁硬编码 SHA-1 空树哈希（SHA-256 仓库不兼容），须用零写盘的 `git hash-object -t tree /dev/null`（PowerShell 用 `@() | git hash-object -t tree --stdin`）动态获取当前仓库对象格式对应的空树 OID 替代 `HEAD` 执行 `git diff`。
- **跨 OS Shell、多版本 `awk`/`sed`/`mktemp` 与 CRLF 混排陷阱**：
  - `scripts/install-skills.sh` 须严格面向类 Unix 最小公共子集（macOS Bash 3.2 / Linux GNU `gawk` & Debian `mawk` & Alpine BusyBox `awk` / Windows Git Bash & WSL）：严禁 `sed -i`、Bash 4+ 语法与 `awk -v` 传多行字符串；
  - 用 `mktemp "${TMPDIR:-/tmp}/fish996.XXXXXX"` 创建临时文件，将新受管块写盘后由 `awk` `getline` 读出替换；
  - **CRLF 风格保真**：检测原 `RULES_FILE` 是否为 CRLF（`\r\n`），若是则按 CRLF 写出新受管块，避免替换后出现 CRLF 与 LF 混排；
  - **marker 口径一致且保留行首缩进**：跳过逻辑（`--with-rules`）与更新校验（`--update-rules`）统一使用**「仅剥离行尾 `\r` 及行尾空白后整行相等，严禁剥离行首空白」**，既防正文行内代码引用误判，也防 Markdown 缩进代码块中的 marker 示例被误判为顶级受管标记；
  - **回写语义准确**：`cat "$out_tmp" > "$RULES_FILE"` 是在临时文件校验通过后执行覆盖回写（保留权限与软链指向），**并非文件系统 rename 原子操作**，文档与注释不得误称为“原子写回”；
  - 纯原生 Windows PowerShell 用户不依赖 bash 脚本，走 `npx skills` / `skills.json` 零脚本路径。
- **测试脚本跨平台权限校验陷阱**：macOS BSD `stat -f` 与 Linux GNU `stat -c` 不兼容 → `tests/test-install-skills.sh` 须自动探测 `stat` 方言或比对 POSIX `ls -l` 权限位前缀。
- **跨 OS 搜索与外部解析器陷阱**：本机实测无 `rg`、`/usr/bin/ctags` 为 BSD ctags；Windows PowerShell 无 `grep` → 通用检索降级链必须为 `CLI 原生只读工具（三端通用）> rg > git grep（装 Git 即三端可用）> grep -rnE（类 Unix/Git Bash）或 Select-String（Windows PowerShell）`，严禁默认调用 `ctags` / `tree-sitter`。
- **跨 CLI 并发能力差异**：不支持单轮多工具并行调用的环境安全降级为无副作用只读复合命令或按优先级串行切片。
- **防提前收口冲突**：`task-review-loop` 第 5 步汇报前严禁提前改写 `HANDOFF_LEDGER.md` 或提前收口，避免外部评审返工（`reviewer-v2`）污染台账。

---

### 4. 改动范围表与明确不做清单（Non-Goals）

#### 4.1 文件改动表
| 文件路径 | 操作 | 精确职责 |
| :--- | :--- | :--- |
| `skills/task-handoff/SKILL.md` | 修改 | 精简高信噪比核心规范（**≤ 160 行**）：第 0 步可选发现（不含 `ARCHITECTURE.md`；支持 `上下文台账：不启用`）、红线与 L39 Scout 限定例外、默认推荐态起草规范与默认拍板不唤醒 `@designer`、渐进式摸底与完整性核验、1 行指针分别指向 `references/orchestration.md` 与 `references/bootstrap-migration.md` |
| `skills/task-handoff/references/orchestration.md` | 新增 | **按需读取（独立拉起的 `designer` 节点严禁读取；单会话直出设计模式仅可读取 1A 选题部分，跳过 2A Scout 部分）**：1A 选任务前置流程（向 `brief` 注入候选表与定题理由）、2A Scout 预摸底启用/跳过条件、只传坐标原则与三级跨 CLI 降级细则 |
| `skills/task-handoff/references/context-templates.md` | 新增 | **按需加载**的 3 份跨语言精简模板：`CODEBASE_MAP.md`（≤ 250 行）、`HANDOFF_LEDGER.md`（≤ 100 行）、`Context Pack`（≤ 150 行，只含坐标不贴大段代码） |
| `skills/task-handoff/references/bootstrap-migration.md` | 新增 | **仅用户显式触发老项目初始化时按需读取（常规任务严禁读取）**：生成初版 Map/Ledger（定向提取既有历史单遗留待办与陷阱，**不移动历史单**、不自动 commit） |
| `skills/task-handoff/references/handoff-template.md` | 微调 | §1 补“已由主会话定题时引用 1–2 行并注明前置依赖已核验”、§2 补“非推荐项写清下篇差量，下篇按推荐态写成终稿”、§8 补 `CODEBASE_MAP.md` 按需同步提示、文末补收口待办占位 |
| `skills/task-review-loop/SKILL.md` | 修改 | 聚焦实施方/主会话编排（**≤ 160 行**）：第 0 步 Map/Ledger 可选感知、Step 1 仓外临时索引整树快照 `T_n` + 双保险指纹、Step 2 `brief` 与降级 2 实施方自查统一指向 `references/reviewer-protocol.md`（原意见分级/双重视角/Round 2+ 防漂移整体迁出单源维护）、Step 3 重算 `T_n'` 验非忽略文件及暂存区零修改、Step 4 传 `T_{n-1}`/`T_n` 与增量清单、Step 5 汇报末附「验收收口待办（含待入账台账草稿）」 |
| `skills/task-review-loop/references/reviewer-protocol.md` | 新增 | **审查员（及降级 2 自查）专用自包含独立协议（~110–130 行）**：完整承接原意见分级定义、双重审查视角、Round 2+ 聚焦与防漂移；含只读红线、Map/Ledger 种子线索、执行单必读/可跳过区、只读核验 `T_n` 新鲜度（`git diff --stat "$T_n"` + `-uall` + `"${T_n}:<f>"`）、Round 1 `HEAD..T_1` 分级复验（快照必审、lockfile 阻断与无执行单兜底、大文件全引用 grep、静默测试 `-rsxX` 与豁免例外、并行读降级）、Round 2+ `T_{n-1}..T_n` 增量与改签名重搜、终轮全量门禁兜底、6 类攻击面与 1 行硬证据输出规范 |
| `templates/AGENTS-handoff-snippet.md` | 微调 | 顶部受管规则块包裹成对 marker 并与 `install-skills.sh` 逐字一致（新增收口更新台账）；`本项目专属覆盖` 补充可选 Map、Ledger（含 `不启用` 关闭开关）、符号大纲命令占位，模型偏好保持纯可选 |
| `scripts/install-skills.sh` | 修改 | 更新受管规则块全文、新增 `--update-rules` 与省略 `--target` 单更规则、统一 marker 匹配口径（仅去行尾 `\r` 和行尾空白，保留行首缩进）、保真 CRLF/LF 无混排、POSIX `awk` + `getline` 校验后回写、损坏 marker Fail-Closed |
| `tests/test-install-skills.sh` | 新增 | 跨平台确定性回归测试脚本（覆盖既有回归、单更/联更、heredoc 与模板逐字一致、CRLF 保真无混排、行内代码与缩进代码块 marker 示例不误判、软链+跨 OS 权限位保留、`--dry-run`、异常参数与损坏 marker Fail-Closed） |
| `README.md` | 微调 | 同步 `designer` & `reviewer` 双向优化说明、零配置向后兼容承诺、`--with-rules` 两处边缘收紧行为变化披露与 `--update-rules` 用法 |

#### 4.2 明确不做清单（Non-Goals）
- **严禁将 `docs/handoffs/archive/` 归档纳入 skill 流程**：不移动历史执行单，杜绝误移与相对链接断裂（归档仅作用户手工可选）。
- **严禁引入 S 级免 `designer` 通道**：本次专注零质量退化的上下文优化，不放宽设计质量门槛。
- **严禁自动探测并读取老仓库未声明的 `ARCHITECTURE.md`**：防止老旧长文档污染上下文。
- **严禁强制在 `AGENTS.md` 中写死模型名**：模型偏好保持纯可选 override。
- **严禁引入外部运行时依赖**：不引入 `tree-sitter`、`universal-ctags`、第三方包或特定语言解析脚本。
- **严禁削弱 `reviewer` 安全与质量防线**：不得取消隔离上下文、高思考档位、防篡改校验或 6 类攻击面；严禁改动 `skills/task-review-loop/references/checklists.md`。
- **严禁自动静默创建或修改外部仓库索引文件**：Map/Ledger 初始化与收口更新均须由用户显式触发或确认验收后执行。

---

### 5. 向后兼容专项设计与精确契约

#### 5.1 既有仓库向后兼容总矩阵（必须全部满足）
| 维度 | 旧版已接入仓库现状 | 新版 Skill 行为契约（零破坏 + 边缘收紧明文披露） |
| :--- | :--- | :--- |
| **老仓库 `ARCHITECTURE.md`** | 可能存在几百行或已过期的 `ARCHITECTURE.md` | **绝不自动探测读取**；架构地图只认第 0 步识别到的项目规范文件（`AGENTS.md` / `CLAUDE.md` / `GEMINI.md`）显式声明的路径与默认 `docs/CODEBASE_MAP.md` |
| **无台账与既有历史单** | 无 `HANDOFF_LEDGER.md`，`docs/handoffs/` 含多份历史单 | **不限制直接上游单数量**——按任务追踪源依赖定位全部直接上游单，每份只读「遗留待办 / 已知限制 / 环境陷阱 / 复审闭环」节，禁通读全文；不移动任何历史单；在项目规范文件（`AGENTS.md` / `CLAUDE.md` / `GEMINI.md`）声明 `上下文台账：不启用` 可永久关闭超阈值提示 |
| **老仓库既有 `AGENTS.md` 规则块** | 未跑 `--update-rules`，规则块仍要求在 `docs/handoffs/` 起草执行单 | 本次不引入 S 级免落盘通道，100% 遵守老规则块；老规则块下所有阅读、快照与增量复审优化照常生效 |
| **同轮并行读** | 部分 CLI 不支持单轮多工具并发调用，或存在目录禁读红线 | `designer` 与 `reviewer` 统一遵守**红线前置 + 阶段化并行 + 能力自适应降级**：先提红线 → 定位/全景 → 筛选 → 并行读；不支持并发时退化为只读复合命令或按优先级串行切片 |
| **符号骨架（Repo Outline）** | 任意语言/混编仓库；跨 macOS/Linux/Windows 可能无 `rg`/`grep`/`ctags`/`tree-sitter`/LSP | 执行**四级跨平台零依赖降级链**（项目配置/LSP → CLI 内置工具/`rg`/`git grep`/`grep` 或 `Select-String` → `CODEBASE_MAP.md` + 局部切片）；严禁凭截断签名写契约，核心修改与改签名调用方必经真实源码与全仓搜索核实 |
| **整树快照 `T_n` 与受限环境** | 可能为无初始 commit 新仓、Windows PowerShell、或 `.git/objects` 只读沙盒 | 新仓无 index 时跳过 `cp`；PowerShell 使用 `$env:GIT_INDEX_FILE`；`.git/objects` 只读时自动回退原有只读哈希快照；不支持续聊 `reviewer` 的 CLI 自动退回完整上下文传递 |
| **跨平台安装与规则更新** | macOS / Linux / Windows（PowerShell 或 Git Bash/WSL）及 `npx skills` / `skills.json` / symlink / copy | `npx skills` / `skills.json` 三端零脚本平滑升级；`install-skills.sh --with-rules` 常规场景继续幂等跳过，`--update-rules` 保真 CRLF/LF 无混排且仅替换受管区块。**明文披露两处有意边缘收紧**（新口径仅剥离行尾 `\r`/空白、保留行首缩进）：① 损坏 marker（如缺 end）由旧版误 `skipped (exit 0)` 改为 **Fail-Closed 报错 `exit 1`**；② 正文行内代码或缩进代码块中仅引用 marker 文本时，由旧版误 `skipped` 改为**正常追加受管块** |

---

#### 5.2 `skills/task-handoff/SKILL.md` 精确契约（总行数 ≤ 160 行）

1. **第 0 步（项目上下文发现）**：
   - **项目架构地图**：**只认两处**——优先第 0 步识别到的项目规范文件（`AGENTS.md` / `CLAUDE.md` / `GEMINI.md`）显式声明的路径，其次默认 `docs/CODEBASE_MAP.md`；两者均不存在则跳过（**严禁自动读取老仓库的 `ARCHITECTURE.md`**）；
   - **上下文台账**：优先上述项目规范文件显式声明的路径，其次 `docs/HANDOFF_LEDGER.md`；若项目规范文件声明 **`上下文台账：不启用`**，则静默跳过且不再输出超阈值提示；
   - **可选符号大纲命令**：若上述项目规范文件显式声明则优先复用，未声明不依赖外部工具；
   - **首选模型配置**：保持**纯可选**，未配置时默认同系列 `High`。

2. **派发、编排指针与默认定稿硬规则**：
   - **按需编排指针（1 行）**：主会话在收到开放式“推进下一步”或准备对跨模块大仓做轻量预摸底时，读取 [references/orchestration.md](./references/orchestration.md) 执行（**独立拉起的 `designer` 节点严禁读取该文件；单会话直出设计模式可读取 1A 选任务部分，跳过 2A Scout 部分**）；
   - **L39 防漂移红线与 Scout 有意例外**：明文保留禁止用粗粒度子代理替代高思考 `designer` 的红线；同时明文注明——主会话在拉起 `designer` **之前**派发一次性只读 `research/flash` 做前置坐标导航（Scout）是对该红线的**有意限定例外**，严禁参与设计决策或替代 `designer`；
   - **`brief` 补齐定题上下文**：主会话已定题时，在 `brief` 中附上候选任务清单与定题理由（及可选 Context Pack），要求 `designer` 不再横向扫描其他候选源码，仅核验所选任务前置依赖——**若核验发现前置依赖未满足，必须立即停步报回用户，严禁硬写**；
   - **下篇默认推荐态终稿规范（让默认拍板直接定稿真正成立）**：起草执行单时，**下篇施工图一律直接按全部推荐项写成无条件分支的干净终态**；非推荐备选项**仅在 §2 决策清单中写明“若选该项需对下篇调整的差量”**，严禁在下篇正文穿插“按决策 X 折叠/若选 B 则…”类条件分支；
   - **默认定稿与回收硬规则（含存量旧草稿守卫）**：**当用户全按推荐项拍板且下篇正文无待折叠条件分支时**，强制由主会话直接更新顶部元信息（状态 + 拍板决议摘要）落盘定稿，严禁为此再次唤醒 `@designer`；若用户选非推荐项、提出需求微调、或该单属升级前遗留的旧格式在途草稿（下篇仍含待折叠条件分支），仍交 `@designer` 原地折叠定稿；定稿后立即 `kill` `designer` 并校验 `git status`。

3. **低上下文渐进式摸底与完整性核验纪律**：
   - **① 上下文承接防膨胀**：
     - 存在 `HANDOFF_LEDGER.md` 时，以台账为种子线索承接遗留待办与已知陷阱，不遍历 `docs/handoffs/`；
     - 无台账时，**按任务追踪源依赖关系定位全部直接上游执行单（不硬限数量）**，但每份只定向读取「遗留待办 / 已知限制 / 环境陷阱 / 复审闭环」相关节，**严禁通读全文**。
   - **② Map / Ledger 种子线索原则**：`CODEBASE_MAP.md` 与 `HANDOFF_LEDGER.md` **仅为冷启动导航与种子线索**，与真实代码冲突时一律以真实代码为准，并在执行单 §8 附加产出中顺带标注需同步更新的 Map/Ledger 条目。
   - **③ 零信任扩展到“正确性 + 完整性”**：无论是否收到 Context Pack，凡本任务直接修改的文件，以及**所有改签名、改数据结构或改公共行为的符号**，`designer` 必须亲自读取真实源码切片核实 `file:line`（正确性），并**亲自执行一次全仓调用方与测试 `mock`/`patch` 搜索（完整性）**，不得以 Context Pack 列表为全集。
   - **④ 三层漏斗读法与跨平台符号骨架**：
     - L1：读 `CODEBASE_MAP.md`（若有）或限深度目录列表；
     - L2（四级跨平台零依赖降级）：项目规范文件声明的大纲命令/LSP → `CLI 内置搜索工具（三端通用）> rg > git grep > grep -rnE（类 Unix/Git Bash）或 Select-String（Windows PowerShell）` → 语法不适用时回退 `CODEBASE_MAP.md` + 局部切片；骨架仅作外围接口参考与定位，核心契约必进 L3 读源码核实；
     - L3：直接修改文件精读区间（≤ 200 行可读全文）；外围调用方只看签名与 `-C 3`；既有测试优先读 fixture 与命中被改符号用例片段。
   - **⑤ 分阶段同轮并行读（跨 CLI 降级）**：先 Step 0 提禁读红线 → Stage 1 并行定位 → 筛选最小切片 → Stage 2 并行精读（严禁未定位盲目并行读全文）；不支持并发的工具退化为单条只读复合命令或按优先级串行。
   - **⑥ 高噪文件与 lockfile 规则**：严禁通读构建/压缩产物与大二进制快照；**对 lockfile（`package-lock.json` / `pnpm-lock.yaml` / `yarn.lock` / `uv.lock` / `Cargo.lock` / `go.sum` 等）严禁全文读取，但允许按目标包名定向 grep 核查版本与来源**；环境实测命令须定向查询目标包或截断输出。

4. **老项目初始化按需指针与超阈值提示**：
   - 正文仅留 **1 行按需指针（~25 tokens）**：`仅当用户显式要求“初始化本项目上下文索引”时，读取 [references/bootstrap-migration.md](./references/bootstrap-migration.md) 执行；常规起草/修订/定稿任务严禁读取该文件`；
   - 常规起草汇报末尾：若未配置 `上下文台账：不启用`、无 `HANDOFF_LEDGER.md` 且 `docs/handoffs/` 存在 ≥ 5 份 `.md` 文件，附 1 行温和建议（可回复初始化索引，或在项目规范文件 `AGENTS.md`/`CLAUDE.md`/`GEMINI.md` 中声明 `上下文台账：不启用` 关闭提示）。

---

#### 5.3 `skills/task-handoff/references/orchestration.md` 精确契约（新增，主会话/单会话选题专用）

- **读取边界**：**独立拉起的 `designer` 节点严禁读取本文件**；单会话直出设计模式下，当前会话可按需读取本文件 1A 选任务部分，但跳过 2A Scout 部分。
- **1A 选任务前置规则**：
  - 用户已明确指定任务时直接跳过；
  - 开放式“推进下一步”时，主会话只读任务追踪源与 `HANDOFF_LEDGER.md`（若有）整理候选简表；依赖关系明确有唯一优先项则直接锁定并推进，存在多并列无优先级候选项时先停步请用户确认；
  - 派发 `designer` 时必须在 `brief` 中附上候选简表与定题理由。
- **2A Scout 预摸底（Context Pack）启用/跳过与降级规则**：
  - **跳过条件（防付两次钱）**：用户已明确给出具体目标文件/小范围目录，或任务明确仅涉及 1–2 个已知文件时，**直接跳过 Scout**，由 `designer` 自行精读；
  - **启用条件**：跨多模块/大仓库摸底且即将拉起独立高思考 `designer` 时，按三级降级执行：
    1. 首选：派 1 个一次性只读轻量侦察子代理（如 `research` 配 `flash`，属对 L39 红线的有意限定例外，仅限导航）；
    2. 降级 1：无便宜只读子代理且主会话为经济模型时，由主会话用 ≤ 2 轮定向只读检索打包；
    3. 降级 2：当前会话直出设计时跳过 Scout，直接套用渐进阅读纪律；
  - **输出约束**：参照 `context-templates.md`，**硬上限 ≤ 150 行，只给坐标（`path:start-end`）、单行符号签名、调用方/mock 锚点与精简版本实测输出，严禁贴大段源码**。

---

#### 5.4 `skills/task-handoff/references/context-templates.md` 与 `bootstrap-migration.md` 精确契约（新增）

- **`context-templates.md`**（仅 Scout / 初始化 / 收口按需读）：
  1. `CODEBASE_MAP.md` 模板（硬限 ≤ 250 行）：4 通用工程槽位（模块职责表、外部入口清单、公共复用设施与测试夹具锚点、依赖方向与只读/禁改边界）；
  2. `HANDOFF_LEDGER.md` 模板（硬限 ≤ 100 行）：3 滚动分区（未清零遗留待办、已实测环境/依赖陷阱、近期关键契约变更最近 5–8 项）；
  3. `Context Pack` 简报模板（硬限 ≤ 150 行，明文禁止大段粘贴源码）。
- **`bootstrap-migration.md`**（极简，仅用户显式触发老项目初始化时读取，常规任务严禁读取）：
  1. 继承目标项目规范文件（`AGENTS.md` / `CLAUDE.md` / `GEMINI.md`）红线；
  2. 参考 `context-templates.md` 生成初版 `docs/CODEBASE_MAP.md`（≤ 250 行）与 `docs/HANDOFF_LEDGER.md`（≤ 100 行，遍历既有 `docs/handoffs/*.md` 时**仅定向读取遗留待办/环境陷阱/复审闭环节**提炼未清零条目，严禁通读全文）；
  3. **严禁移动或删除任何历史执行单**（保持原路径与相对链接完好，用户如需归档可自行手工整理）；
  4. 汇报新建文件清单交用户审阅，**严禁自动 `git commit` / `git push`**。

---

#### 5.5 `skills/task-review-loop/SKILL.md`（≤ 160 行）与 `references/reviewer-protocol.md` 精确契约

**A. `skills/task-review-loop/SKILL.md`（实施方/主会话编排，总行数 ≤ 160 行）**
- **单源拆离原则**：将原 `SKILL.md` 中的**意见分级定义（原 `L31-33`）、双重审查视角（原 `L77-79`）、Round 2+ 聚焦与防漂移（原 `L105`）**连同 6 类攻击面审查细则整体迁入 `references/reviewer-protocol.md`，`SKILL.md` 仅保留单行索引不再重复，杜绝双份漂移。
- **第 0 步**：新增可选感知 `CODEBASE_MAP.md`（只认第 0 步识别到的项目规范文件 `AGENTS.md`/`CLAUDE.md`/`GEMINI.md` 显式声明的路径与默认 `docs/CODEBASE_MAP.md`）与 `HANDOFF_LEDGER.md`；无则跳过。
- **第 1 步送审前防篡改整树快照 `T_n`（覆盖未被 `.gitignore` 忽略的全量工作区与真实暂存区）**：
  - 实施方在每轮送审前计算三项快照指纹：
    1. `git status --porcelain -uall`（展开未跟踪目录以逐文件核对）；
    2. `git diff --cached | git hash-object --stdin`（保护真实暂存区不被误改）；
    3. **仓外临时索引整树快照 `T_n`**：临时目录**必须建在目标仓库之外**（`mktemp -d "${TMPDIR:-/tmp}/fish996-snap.XXXXXX"` + `trap` 清理），存在真实 index 时复制复用 stat 缓存，通过 `GIT_INDEX_FILE="$IDX" git add -A && GIT_INDEX_FILE="$IDX" git write-tree` 生成 `T_n`（附 Windows PowerShell `$env:GIT_INDEX_FILE` 等价写法；`.git/objects` 只读时自动回退纯只读哈希快照）。
- **第 2 步派发审查员 `brief` 与降级 2 路径统一**：
  - `brief` 第 1 项直接填入 **`references/reviewer-protocol.md` 的实际路径**（及按需参阅 `references/checklists.md`），审查员无需再加载实施方专用的 `task-review-loop/SKILL.md`；
  - `brief` 附带本轮 `T_1` 及可选 Map/Ledger 路径（存在时）；
  - **降级 2 · 无子代理能力兜底（实施方自查）**同样明文指向 `references/reviewer-protocol.md`（及按需 `references/checklists.md`），按同一标准完成逐项自查。
- **第 3 步零修改核验**：审查员返回后，实施方重算 `T_n'`、`git status --porcelain -uall` 与 `--cached` hash，三者与送审前完全一致即证**所有未被 `.gitignore` 忽略的文件及真实暂存区字节级零修改**。
- **第 4 步 Round 2+ 增量续审提交**：
  - 实施方计算新整树快照 `T_n`，向复用中的 `@reviewer` 发送：① 上轮问题逐条修复与 `file:line`；② `T_{n-1}` 与 `T_n` 及本轮申报改动文件清单；③ 最新全量验证结果与异议证据。
- **第 5 步汇报前（严格不提前收口）**：
  - 保留 3 项一致性终检与既有汇报结构，严禁提前改写台账；
  - 若项目启用了 `HANDOFF_LEDGER.md`（或本轮涉及 `CODEBASE_MAP.md` 边界变化），在汇报末尾明确输出 **「验收收口待办（待用户明确确认验收后执行）」**，含可直接落盘的 3–5 行台账增量草稿（遗留非阻断待办、新发现陷阱、近期契约变更及待清除旧待办），使其留在对话上下文中，配合新版 `AGENTS.md` 受管规则块确保收口必更新。

**B. `skills/task-review-loop/references/reviewer-protocol.md`（新增，审查员及降级 2 自查专用自包含协议，~110–130 行）**
1. **只读红线、意见分级与双重审查视角（从原 `SKILL.md` 完整迁入，单源真相）**：
   - **零副作用红线**：严禁修改任何文件、严禁运行写盘或改 Git 状态命令（**审查员绝不运行 `git add`/`git write-tree`**，仅用纯只读命令）；不得轻信 `brief` 汇总；
   - **意见分级定义（原 `L31-33` 完整迁入）**：明确「阻断项」（功能/逻辑 bug、违背定稿执行单/需求/项目原则、执行单自身遗漏或假设有误导致的真实缺陷、跨模块漏接或只读保护破坏、测试假阳性或缺失关键反例、实测口径失真或不可追溯、隔离性/安全性被破坏）与「非阻断建议」（风格微调、可读性改进、改动面较大可延后到后续任务的优化）；
   - **双重审查视角（原 `L77-79` 完整迁入）**：① 对照基线查落地；② **跳出基线找真实工程缺陷**——不得盲信执行单假设，主动核查跨模块调用方、第三方库真实行为与端到端路径，**即使执行单自身写漏或假设有误，只要构成真实 bug 或风险同样判阻断**。
2. **Map / Ledger 种子线索与执行单必读/可跳过区**：
   - 存在 `CODEBASE_MAP.md` / `HANDOFF_LEDGER.md` 时**仅为种子线索**，严禁替代对被改符号的独立全仓调用方搜索；与代码冲突时以代码为准，并将“Map/Ledger 过期”列为非阻断建议；
   - 执行单必读顶部元信息、拍板决议摘要、红线声明、任务目标与质量底线以及下篇施工契约；**仅允许跳过纯痛点背景叙述与文末 Q&A 讨论附录**。
3. **只读核验快照 `T_CUR` 新鲜度（每轮必做，零信任闭环）**：
   - 收到本轮快照 `T_CUR` 后，先只读验证 `T_CUR` 与当前工作区一致（以下命令变量名一律使用合法 Shell 变量 `$T_CUR` / `$T_PREV`，禁止写 `$T_{n-1}`）：
     1. 核验已跟踪文件与未跟踪列表：对比 `git -c core.quotePath=false diff --name-status "$T_CUR"` 与 `git -c core.quotePath=false ls-files --others --exclude-standard`（辅以 `git -c core.quotePath=false status --porcelain -uall` 核对工作区状态）——`diff --name-status` 会把未跟踪文件输出为 `D\t<path>`，该原始路径集合必须与 `ls-files --others --exclude-standard` 逐行**一一对应**（无长路径截断、无空格/中文转义偏差）；除此之外只要出现任何已跟踪文件变动、或多出/缺少未跟踪条目，即判 `T_CUR` 过期，**退回要求实施方重算**；
     2. 核验未跟踪文件内容：对上述未跟踪列表中的每个文件 `<f>` 只读比对 `git hash-object -- "<f>"` 与 `git rev-parse "${T_CUR}:<f>"`（**强制花括号与双引号 `"${T_CUR}:<f>"` 防 `zsh` `:u` 等修饰符报错**）；任一失败或哈希不等即判 `T_CUR` 过期并退回。
4. **Round 1 `HEAD..T_CUR` 分级复验 + 静默测试 + 分阶段并行只读**：
   - **统一整树 Diff**：验完 `T_CUR` 新鲜度后，执行 `git -c core.quotePath=false diff --stat HEAD "$T_CUR"` 与 `git diff HEAD "$T_CUR" -- <files>`（无初始提交新仓用零写盘的 `EMPTY_TREE="$(git hash-object -t tree /dev/null)"` 替代 `HEAD`，PowerShell 用 `@() | git hash-object -t tree --stdin`，兼容 SHA-1 与 SHA-256 仓库），未跟踪新文件内容直接在同份 diff 中可见，无需单独翻读；未传 `T_CUR`（降级场景）时回退常规 `git diff` + 读未跟踪新文件；
   - **高噪差异化处理（严防误伤攻击面 #2/#4/#6）**：
     - **快照 / golden 文件严禁跳过**：凡出现在 `--stat` 中，**必须查看其定向 diff**，排查“改预期假绿测试”；
     - **lockfile 只禁整份倾倒**：出现在 `--stat` 中时，有执行单则对照改动范围表（未申报即判阻断），**无执行单时对照用户任务描述判断（若变动无法合理解释即判阻断）**；属合理变动时须定向 grep 变动的包名、版本与下载源（如 `resolved`/registry 行）；
   - **大文件可执行切片规则**：中小改动文件（≤ 250 行）读全文；大文件（> 250 行）除读受影响函数/类、import/初始化与相关 fixture 外，**必须在文件内定向 grep 每个被改符号、被改字段与共享状态的全部引用并读取引用处上下文**；跨模块调用方全仓搜索遵循三端降级链并看 `-C 3`；
   - **静默复跑测试与防假阳性核验**：复跑只读测试/lint/类型检查优先使用摘要参数，但**必须保留最终计数汇总行并开启跳过/预期失败原因输出**（如 pytest 用 `-q -rsxX --tb=short`，其他框架用等价参数），**核对新增用例实际被收集执行且实测数与测试矩阵一致**；新增用例被 skip/xfail 或未收集时判阻断（**除非定稿执行单测试矩阵或项目规范已明文写明该用例的跳过条件，如平台/环境限定用例**）；Round 1 优先复跑新增/受影响单测 + 关键回归 + lint/类型检查；
   - **分阶段并行只读（跨 CLI 降级）**：支持并发时压至 3–4 轮（第 1 轮并行读协议+执行单必读区+Map/Ledger+`T_CUR` 新鲜度与 `HEAD..T_CUR --stat` → 第 2 轮定向 diff+改动/全引用切片+全仓搜调用方 → 第 3 轮精简复跑测试 → 第 4 轮出报告）；不支持并发则安全降级。
5. **Round 2+ 精确增量复审、防漂移与终轮全量兜底**：
   - **聚焦与防漂移（原 `L105` 完整迁入）**：重点复核 ① 上轮阻断项是否真正根治且有确定性回归测试；② 实施方异议证据是否成立；③ 本轮修复是否引入新回归（含文档同步）；**严禁对未改动代码反复冒出新的低优先级风格意见卡通过**（但发现遗漏的真实严重缺陷仍应阻断）；
   - **纯增量审查**：验完 `T_CUR` 新鲜度后，跑只读 `git -c core.quotePath=false diff --name-status "$T_PREV" "$T_CUR"`（或 `--stat`）捕获全部真实增量改动面，再用 `git diff "$T_PREV" "$T_CUR" -- <files>` 查看精确增量（未传快照的降级场景回退常规 diff）；
   - **改签名全仓重搜 + 终轮全量门禁兜底**：每轮若修复修改了符号签名或对外行为，必须重新全仓搜索该符号的全部调用方（含 Round 1 改动文件）；**准备判定「通过（阻断项 = 0）」的那一轮，必须独立、精简地复跑一次项目全量验收门禁**（若全量套件确因耗时过长不宜由审查员重跑，须在报告中明文注明原因，并逐字核对实施方基于最终快照 `T_CUR` 的全量实测输出）。
6. **6 类必查攻击面与高信噪比输出格式**：保留完整 6 类攻击面（按需参阅 `checklists.md`）；输出「结论 → 阻断项（带 `file:line` 与复现依据）→ 非阻断建议 → 逐项核查证据」，**无问题的攻击面用 1 行证据带过，但每行必须含具体执行的命令或核验到的 `file:line`，严禁只写“无问题”**。

---

#### 5.6 `scripts/install-skills.sh` 与 `templates/AGENTS-handoff-snippet.md` 精确契约

1. **新版受管规则块全文（`scripts/install-skills.sh` heredoc 与 `templates/AGENTS-handoff-snippet.md` 顶部区块必须逐字节一致）**：
   ```markdown
   <!-- fish-996:task-handoff-rules:begin -->
   ## 开发工作流约定（Task Handoff & Review Loop）

   - **新任务先出执行单**：收到“推进下一步”、规划任务、起草或按审稿意见修改执行单时，必须使用 `task-handoff` skill，在 `docs/handoffs/` 下起草并维护执行单；等用户审阅拍板并完成定稿后，再开始写代码。
   - **验收前走独立复审闭环**：每个任务实施完成（或按外部评审返工完成）、向用户汇报验收前，必须使用 `task-review-loop` skill 执行「实现 → 独立只读复审 → 核实修复/举证异议 → 再复审」闭环（最多 5 轮）。
   - **收口策略**：在用户明确确认验收前，不得勾选任务清单，不得 `git commit`，不得 `git push`；待用户明确确认验收进入收口时，若项目启用了 `HANDOFF_LEDGER.md`（或需同步 `CODEBASE_MAP.md`），须先一并落盘更新台账与地图后再提交。
   <!-- fish-996:task-handoff-rules:end -->
   ```
2. **`templates/AGENTS-handoff-snippet.md` 专属覆盖占位（全部可选）**：
   - 新增：`项目架构地图（可选）`（如 `docs/CODEBASE_MAP.md`）、`上下文台账（可选）`（如 `docs/HANDOFF_LEDGER.md`；填写 `不启用` 可永久关闭超阈值提示）、`符号大纲命令（可选，零依赖可省略）`；
   - 保持 `高思考模型偏好（可选）` 原样；**不包含 `archive/` 占位**。
3. **`scripts/install-skills.sh` CLI 与实现契约**：
   - 新增 `--update-rules`（默认 `0`）；允许省略 `--target` 仅传 `--with-rules <file> [--update-rules]`；仅传 `--update-rules` 缺 `--with-rules` 或两者皆缺时输出明确 `stderr` 并 `exit 1`；
   - **统一 marker 匹配口径（保留行首缩进）**：`--with-rules` 跳过判断与 `--update-rules` 完整性校验均使用同一 POSIX `awk` 判定——**仅剥离行尾 `\r` 及行尾空白（`sub(/\r$/, "", line); sub(/[ \t]+$/, "", line)`）后整行等于 `MARKER_BEGIN` / `MARKER_END`，严禁剥离行首空白**（既防行内代码引用误判，也防 Markdown 缩进代码块中的 marker 示例被误判为顶级受管标记！）；
   - **完整性校验、Fail-Closed 与有意边缘变化**：
     - `begin_count == 0 && end_count == 0`：无论是否传 `--update-rules`，均追加受管块（有意变化：正文仅含行内/缩进 marker 引用时不再误跳过）；
     - `begin_count == 1 && end_count == 1 && begin_line < end_line`：未传 `--update-rules` 时幂等跳过；传 `--update-rules` 时用临时文件 `block_tmp` + `awk getline` 替换 `begin_line..end_line`，原样保留前后全部内容；
     - 其余任意异常（单边缺失、`end < begin`、重复标记）：**Fail-Closed**，报明确错误到 `stderr` 并 `exit 1`，原文件字节级零改动（有意变化：`--with-rules` 默认路径遇损坏 marker 由旧版 `skipped (exit 0)` 收紧为报错 `exit 1`）；
   - **CRLF 风格保真**：若已存在的 `RULES_FILE` 含 `\r\n`（CRLF），生成 `block_tmp`（含前置分隔空行）时自动每行行尾附加 `\r`，确保输出全文件无 CRLF/LF 混排；
   - **跨平台临时文件校验回写**：全脚本严格 Bash 3.2 + POSIX `awk`（禁 `sed -i` / Bash 4+ / `awk -v` 多行），临时文件用 `mktemp "${TMPDIR:-/tmp}/fish996.XXXXXX"` + `trap` 清理；校验转换退出码为 0 后使用 `cat "$out_tmp" > "$RULES_FILE"` 覆盖回写（保留权限与软链指向）；`--dry-run` 零写盘并打印清晰计划。

---

### 6. 原子化施工步骤（自底向上）

- **Step 1：新增 `task-handoff` 按需参考文件（3 个）与 `task-review-loop` 独立审查协议（1 个）**
  - 改动文件：`skills/task-handoff/references/orchestration.md`、`skills/task-handoff/references/context-templates.md`、`skills/task-handoff/references/bootstrap-migration.md`、`skills/task-review-loop/references/reviewer-protocol.md`
  - 改动要点：严格按 §5.3、§5.4、§5.5B 写入全部按需参考文档，确保零 `archive/` 自动化逻辑、`reviewer-protocol.md` 自包含。
  - 最小验证命令：`wc -l skills/task-handoff/references/orchestration.md skills/task-handoff/references/context-templates.md skills/task-handoff/references/bootstrap-migration.md skills/task-review-loop/references/reviewer-protocol.md`

- **Step 2：升级 `skills/task-handoff/SKILL.md` 与微调 `skills/task-handoff/references/handoff-template.md`**
  - 改动文件：`skills/task-handoff/SKILL.md`、`skills/task-handoff/references/handoff-template.md`
  - 改动要点：落实 §5.2 全部契约（只认第 0 步项目规范文件 `AGENTS.md`/`CLAUDE.md`/`GEMINI.md` 声明路径与 `docs/CODEBASE_MAP.md`、无台账按依赖读直接上游关键节、默认推荐态终稿写法与存量旧草稿守卫、完整性全仓搜、1 行指针指向 `orchestration.md` 与 `bootstrap-migration.md`）；确保 `SKILL.md` ≤ 160 行。
  - 最小验证命令：`wc -l skills/task-handoff/SKILL.md && grep -n "references/" skills/task-handoff/SKILL.md`

- **Step 3：升级 `skills/task-review-loop/SKILL.md` 与 `templates/AGENTS-handoff-snippet.md`**
  - 改动文件：`skills/task-review-loop/SKILL.md`、`templates/AGENTS-handoff-snippet.md`
  - 改动要点：落实 §5.5A（仓外临时索引整树快照 `T_n`、`brief` 与降级 2 自查统一指向 `reviewer-protocol.md` 并移出原三块规则、Round 2+ 传 `T_{n-1}`/`T_n`、第 5 步附「验收收口待办」）并确保 `task-review-loop/SKILL.md` ≤ 160 行；按 §5.6 更新 `templates/AGENTS-handoff-snippet.md`（带成对 marker 与新收口策略）。
  - 最小验证命令：`wc -l skills/task-review-loop/SKILL.md && grep -nE "reviewer-protocol|write-tree|收口待办|上下文台账：不启用" skills/task-review-loop/SKILL.md templates/AGENTS-handoff-snippet.md`

- **Step 4：升级 `scripts/install-skills.sh` 并编写跨平台回归测试 `tests/test-install-skills.sh`**
  - 改动文件：`scripts/install-skills.sh`、`tests/test-install-skills.sh`
  - 改动要点：按 §5.6 实现新版受管块、`--update-rules`、省略 `--target`、保留行首缩进的统一整行 marker 口径、CRLF 保真与 POSIX `awk` `getline` 校验回写；编写 §7.1 全部自动化断言用例（含缩进代码块 marker 示例反例，在隔离临时目录中执行）。
  - 最小验证命令：`bash -n scripts/install-skills.sh && bash -n tests/test-install-skills.sh && bash tests/test-install-skills.sh`

- **Step 5：同步更新 `README.md`、执行全量门禁与 §7.3 行为验收**
  - 改动文件：`README.md`
  - 改动要点：同步双向优化说明、零配置兼容承诺、`--with-rules` 两处有意边缘收紧变化与 `--update-rules` 用法；跑通 §7.2 全部门禁命令，并按 §7.3 完成 `reviewer` 4 缺陷新旧对照（× ≥ 2 次）+ `designer` 完整性用例（× ≥ 2 次）+ 降本实证。
  - 最小验证命令：见 §7.2 与 §7.3。

---

### 7. 确定性测试矩阵、验收门禁与行为验收实验

#### 7.1 自动化测试矩阵（严禁弱断言）
| 目标测试文件 | 覆盖类别 | 测试场景 | 必须写死的断言底线（禁止弱断言） |
| :--- | :--- | :--- | :--- |
| `tests/test-install-skills.sh` | 契约一致性 | 抽取 `scripts/install-skills.sh` 输出的受管块与 `templates/AGENTS-handoff-snippet.md` 受管块比对 | 两者 `begin..end` 受管区块内容**逐字节完全一致**，防双处漂移 |
| `tests/test-install-skills.sh` | 兼容回归 | 既有 `--target <tmp> --with-rules <file>` 首次写入 + 二次重复执行 | 首次生成软链与完整 marker 块；二次退出码 0、输出含 `skipped`、文件哈希字节级不变 |
| `tests/test-install-skills.sh` | 正例 | `--with-rules <file> --update-rules`（不传 `--target`）原地替换旧版受管块 | 退出码 0；marker 内精确更新为含收口台账的新版规则；marker 之前与之后自定义内容**逐字节保留** |
| `tests/test-install-skills.sh` | 正例 | `--target <tmp> --force --with-rules <file> --update-rules` 联合执行 | skills 目录更新且 `AGENTS.md` 受管块同步刷新 |
| `tests/test-install-skills.sh` | 边界 | Windows CRLF（`\r\n`）文件执行 `--update-rules` 与无 marker 追加 | 退出码 0；识别含 `\r` marker 并替换/追加；断言输出全文件每行均为 `\r\n`（**零 CRLF/LF 混排**），区块前后内容完整保留 |
| `tests/test-install-skills.sh` | 边界 | 正文同时含行内代码引用（`` `<!-- fish-996:task-handoff-rules:begin -->` ``）及**缩进代码块中的成对 marker 示例**（如 4 空格缩进）时执行 `--with-rules` 与 `--update-rules` | 行内引用与缩进代码块示例均不被误判为顶级受管标记；受管块正常追加于文末且正文引用/示例行字节级未动 |
| `tests/test-install-skills.sh` | 边界 | 目标文件无 marker 且末尾无换行符时执行 `--with-rules --update-rules` | 退化为追加受管块，原有内容完整保留且无行粘连 |
| `tests/test-install-skills.sh` | 边界 | 目标 `AGENTS.md` 为软链 + 权限 `0600` 时执行 `--update-rules` | 更新后仍为软链，底层内容已更新且权限位不变（跨 macOS/Linux `ls -l` 或自动探测 `stat` 断言） |
| `tests/test-install-skills.sh` | 边界 | `--dry-run` 配合 `--with-rules <file> --update-rules` | 退出码 0；输出含 `[dry-run]`；磁盘文件哈希字节级零变化 |
| `tests/test-install-skills.sh` | 异常反例 | `--update-rules` 缺 `--with-rules`；或同时缺 `--target` 与 `--with-rules` | 退出码非 0；`stderr` 输出明确错误 |
| `tests/test-install-skills.sh` | 异常反例 | 损坏 marker（缺 end / 缺 begin / end 在 begin 前 / 重复 begin）执行 `--update-rules` 与 `--with-rules` | 退出码非 0；`stderr` 报 marker 完整性错误；原文件哈希字节级零改动（Fail-Closed） |
| 文档静态校验 | 契约回归 | 双 `SKILL.md` 行数上限、全部 `references/*.md` 存在性、无 `ARCHITECTURE.md` 自动读与无强制模型写死 | `skills/task-handoff/SKILL.md` ≤ 160 行且 `skills/task-review-loop/SKILL.md` ≤ 160 行；全部 5 个 `references/*.md` 文件真实存在；未引入 `archive/` 自动流程 |

#### 7.2 完整自动化门禁命令清单
```bash
# 1. Shell 语法检查（Bash 3.2 兼容）
bash -n scripts/install-skills.sh && bash -n tests/test-install-skills.sh

# 2. 确定性脚本回归与模板一致性测试
bash tests/test-install-skills.sh

# 3. 既有 CLI 列表能力冒烟校验
./scripts/install-skills.sh --list

# 4. 双 Skill 精炼度（均 ≤ 160 行）与引用完整性核验
wc -l skills/task-handoff/SKILL.md skills/task-review-loop/SKILL.md \
  skills/task-handoff/references/orchestration.md \
  skills/task-handoff/references/context-templates.md \
  skills/task-handoff/references/bootstrap-migration.md \
  skills/task-review-loop/references/reviewer-protocol.md
for f in \
  skills/task-handoff/references/handoff-template.md \
  skills/task-handoff/references/orchestration.md \
  skills/task-handoff/references/context-templates.md \
  skills/task-handoff/references/bootstrap-migration.md \
  skills/task-review-loop/references/reviewer-protocol.md \
  skills/task-review-loop/references/checklists.md; do
  test -s "$f" || { echo "Missing or empty: $f" >&2; exit 1; }
done

# 5. 仓库干净度检查（未提前 commit，无残留临时文件）
git status
```

#### 7.3 Skill 行为与降本人工验收实验（独立沙盒仓，新旧对照 × ≥ 2 次）
在 `/tmp` 隔离样例 Git 仓库（含 > 350 行大文件 + 测试快照 + 单元测试）中，执行以下两项行为验收，**每组对照均至少独立运行 2 次**（降低 LLM 随机性干扰）：

**实验 A · `reviewer` 4 缺陷新旧对照实验（验证零退化与新增捕获能力）**：
分别使用**旧版基线（`ff1e65a`）与新版 `task-review-loop`** 跑通 Round 1 + Round 2，植入以下 4 个缺陷：
1. **大文件内未改动函数漏改**：修改 350 行文件内一处公共符号签名/行为，同一文件下方另一未改动函数引用该符号却未同步更新（验证大文件文件内全引用 grep）；
2. **快照 / golden 文件假修复**：悄悄改动测试快照文件掩盖逻辑错误（验证快照定向 diff 必审）；
3. **新增测试被意外跳过**：新增回归测试标记为 `skip` 且执行单未豁免（验证 `-rsxX` 与实跑计数核对）；
4. **Round 2 未申报文件等长改写**：Round 2 修复时，在未向 `reviewer` 申报的另一已改文件中做 1 处等长替换（`B -> C`）（验证临时索引整树快照 `T_{n-1}..T_n` 与新鲜度校验）。
- **验收标准**：旧版未能检出第 4 类属预期；**前 3 类新版检出范围必须严格不少于旧版，且新版 2 次运行均稳定检出 4/4 全部阻断项**。

**实验 B · `designer` 完整性防遗漏实验（验证 §1.2 质量底线）**：
向新版 `designer` 传入一份**故意漏掉 1 个跨模块生产调用方（或测试 `mock`/`patch` 点）**的 Context Pack，要求为修改某公共函数签名起草执行单（至少运行 2 次）。
- **验收标准**：2 次运行均能凭借 `designer` 完整性自查红线，独立全仓搜索找回被 Context Pack 遗漏的调用方/mock 点并准确写入执行单。

**降本实证**：在相同样例任务上对比记录改造前（`ff1e65a`）与改造后 `designer` 及 `reviewer` 的输入/输出 token 用量与工具调用轮数，随复审/验收汇报一并呈现。

---

### 8. 项目附加产出要求

- 同步更新仓库根目录 `README.md`，说明 `designer` & `reviewer` 上下文节约机制、零配置向后兼容承诺、`--with-rules` 两处有意边缘收紧变化（§5.1）与 `install-skills.sh --update-rules` 用法；
- 无其他外部文档要求。

---

### 9. 实施方偏差止损规则（固定条款）

- **可自决微调**：Shell 脚本内部私有辅助函数命名、局部文案润色、Markdown 排版微调（不改变命令行参数契约、兼容降级语义与测试预期）。
- **必须立即停工上报（严禁擅自绕过）**：
  1. 发现既定命令行契约、marker 语义、临时索引快照规则或向后兼容契约与仓库现状冲突；
  2. 需要修改 §4.1 文件改动表之外的文件；
  3. 需要改写既有脚本的默认 `--with-rules` 幂等跳过行为（§5.1/§5.6 明文披露的“损坏 marker Fail-Closed”与“行内/缩进引用不误判”两项有意收紧除外），或放宽损坏 marker Fail-Closed 保护、CRLF 保真与受管块模板一致性断言；
  4. `skills/task-handoff/SKILL.md` 或 `skills/task-review-loop/SKILL.md` 无法在 160 行内清晰表达且需要进一步调整拆分；
  5. 行为验收实验（§7.3）中任一植入缺陷未能稳定检出（或新版弱于旧版）、`designer` 未能找回 Context Pack 故意遗漏的调用方，或实测发现新的跨平台兼容阻断问题。

---

## 附录 A：前期方案讨论 Q&A 纪要（Q1–Q9）

### Q1：`waiting` 状态不烧 token，建议默认拍板时“主会话改状态并 `kill` `designer`”有实际作用吗？
> **用户原问**：你说“强制由主会话（medium）直接改顶部状态并立即 kill designer”，原来的 `task-handoff/SKILL.md` 里写着“初稿完成后不要 kill designer，让其进入 waiting 休眠状态（不消耗额度且完整保留摸底上下文）”。虽然它说的是初稿未定稿的时候，但我理解是放着不用不会额外消耗 token，所以这里你建议 kill 有实际作用吗？

**答**：`waiting` 状态本身确实不烧 token；真正省 token 的是**全按推荐项拍板时禁止再唤醒 `@designer` 仅改顶部 3 行状态**（避免把几万 token 上下文再送进高价模型跑一轮），配合下篇一律按推荐态写无条件分支终稿后即可真正落地；定稿后 `kill` 是流程与 swarm 公告板单节点卫生，避免后续复审误 `@` 唤醒或状态污染。

### Q2：新版 skill 引入新规则和新文件后，已使用这套 skill 的老 repo 怎么同步？
> **用户原问**：这套 skill 更新后，其实会引入新的规则和对应的文件以及把已经完成的 handoff 文件挪到 `archive` 目录，用这套 skill 的 repo 更新了 skill 后，怎么同步生成新版 skill 用的那些东西呢？

**答**：坚持零配置向下兼容（无新文件静默降级）+ 显式触发外置 `references/bootstrap-migration.md`（平时零加载）+ `install-skills.sh --update-rules` 原地刷新受管规则块。*注：经第一轮第三方评审，已进一步简化——去掉自动化 `archive/` 归档，避免误移与相对链接断裂，详见附录 B（三.1）。*

### Q3：不同 repo 目录形式都不一样，引入 `CODEBASE_MAP.md` 后这套 skill 还能保持通用吗？
> **用户原问**：`CODEBASE_MAP.md` 的做法我也赞成，但不同 repo 目录形式都不一样，引入这个能做到这套 skill 还是通用的吗？

**答**：可以。skill 只定义 4 个与目录形态无关的通用工程槽位（模块职责表、外部入口清单、公共复用设施与测试夹具、依赖与禁改边界），路径只认 `AGENTS.md` 声明或默认 `docs/CODEBASE_MAP.md`（不自动误读老仓库 `ARCHITECTURE.md`）。

### Q4：为什么“强制同轮并行读”能节约 token？
> **用户原问**：我没有太理解你说的“强制同轮并行读”为什么能节约 token，请解释一下。

**答**：大模型 API 无状态，每轮工具调用都会重发累计上下文并触发一轮高价思考输出。读 6 个各 2k 文件（基础 5k）：串行 7 轮累计输入 `77k` + 7 轮高思考；并行 2 轮累计输入 `22k`（-71%）+ 2 轮高思考，大幅削减中间重发输入与最贵且不可缓存的思考输出 tokens。实践中采用分阶段并行（先定位 → 再精读），避免盲读推高峰值上下文。

### Q5：关于“在项目 `AGENTS.md` 写死精确模型名”的异议
> **用户原问**：你要求“在项目 `AGENTS.md` 写死精确模型名”我不是很赞同，当初允许在 `AGENTS.md` 里面做 override 只是多提供一条选择目标模型的方式，但不能作为硬性要求。

**答**：完全认同并采纳。保持 `AGENTS.md` 模型偏好为纯可选 override，不破坏跨 CLI/跨平台可移植性。

### Q6：“按需符号骨架脚本（Repo Map）”是给模型读 AST 吗？对所有语言和 repo 都通用吗？
> **用户原问**：关于你提到的“「按需符号骨架脚本（Repo Map）」”，你的出发点是不让模型读代码原文，而是读它的抽象语法树？对所有语言，所有 repo 都通用吗？

**答**：不是读原始 AST，也不是不读源码——符号骨架是剥离函数体后的紧凑签名目录，仅用于定位与外围参考，核心修改文件必读真实源码切片。通用 skill 保持零依赖，采用四级跨平台降级链（`AGENTS.md` 声明命令/LSP > CLI 内置工具/`rg`/`git grep`/`grep` 或 `Select-String` > `CODEBASE_MAP.md` + 局部切片），不默认绑死 `ctags` / `tree-sitter`。

### Q7：环境实测基于 macOS，但其他用户可能用 Linux 或 Windows，方案是否依然合适？
> **用户原问**：关于“环境实测陷阱”，虽然本机你检测了，但这套 skill 也有可能被别人用，不一定是 mac，请考虑方案是否还合适。

**答**：面向三端补齐了 4 项跨平台硬约束：① 检索降级链兼容原生 Windows PowerShell（`Select-String` + `git grep`）；② `install-skills.sh` 面向 Bash 3.2 + POSIX `awk` 最小公共子集，兼容 BSD/GNU/mawk/BusyBox 与 Windows CRLF 风格保真，纯 PowerShell 用户走 `npx skills` / `skills.json`；③ 测试脚本权限校验跨 OS 实现；④ 整树快照 `T_n` 提供类 Unix 与 PowerShell 等价写法。

### Q8：把“项目索引初始化/迁移”放进 `task-handoff`，会不会每次用这个 skill 都白白浪费 token？
> **用户原问**：你说“在 `task-handoff` 内置显式触发的「项目索引初始化/迁移」子流程”，但这样会不会造成以后每次使用这个 skill，提示词里都带着这部分内容，浪费 token?

**答**：完全正确。内联进 `SKILL.md` 每次白烧 ~300–500 tokens；拆成第 3 个独立 skill 会在所有无关对话的系统 `<skills>` 目录常驻 ~60–100 tokens；最优解是在 `SKILL.md` 仅留 1 行按需指针（~25 tokens）指向独立 `references/bootstrap-migration.md`，常规任务严禁读取。经第三轮细化，编排细节（`orchestration.md`）与审查员协议（`reviewer-protocol.md`）也一并按需拆分，双 `SKILL.md` 均压至 ≤ 160 行。

### Q9：`task-review-loop` 是否同样存在上下文/token 优化空间？
> **用户原问**：另外，你也看一下 `task-review-loop` 是不是也一样有优化的可能？

**答**：有，通过临时索引整树快照 `T_n` 实现精确增量复审、Round 1 分级复验（快照必审 + lockfile 阻断/grep + 大文件全引用 grep）、静默测试 `-rsxX` 与实跑计数核对、独立 `references/reviewer-protocol.md` 减负、分阶段并行读与 1 行硬证据输出压缩、终轮全量门禁兜底及 Map/Ledger 种子线索赋能，实现零质量退化减负。

---

## 附录 B：第三方第一轮评审意见处置对照表（20/20 全量闭环）

| 评审条目 | 核心意见 | 处置结论与落地章节 |
| :--- | :--- | :--- |
| **一.1** | 自动读老仓库 `ARCHITECTURE.md` 改变既有行为且易引入过期噪音 | **全盘采纳**：只认 `AGENTS.md` 指定路径与 `docs/CODEBASE_MAP.md`（§5.1、§5.2） |
| **一.2** | 无台账“最多读最近 1–2 份”比现行更严，易漏直接上游单 | **全盘采纳**：按任务追踪源依赖定位全部直接上游单（不限数），每份只读遗留/限制/复审节（§5.1、§5.2） |
| **一.3** | 1A 与现行 SKILL L79-80 及模板 §2 要求横向对比冲突 | **全盘采纳**：主会话 `brief` 附候选表与定题理由，`designer` 仅核验前置依赖（不满足必停步报回），同步改模板 §1（§2、§5.2、§5.3） |
| **一.4** | 4A 违背老仓库规则块且属降低质量门槛，建议选 4B | **全盘采纳**：推荐项改为 **4B**；4A 保留为备选并附加“仍落盘极简单 + 主会话仅可提议需用户确认”硬约束（§2、§4.2） |
| **一.5** | 下篇含条件分支导致全选推荐时无法由主会话直接定稿 | **全盘采纳**：立规“下篇一律按推荐态写成无条件分支终稿，非推荐项只在 §2 写差量”，且本单已按此重写（§2、§5.2） |
| **一.6** | “提示一次”无状态不可实现；lockfile 禁读与依赖升级实测冲突 | **全盘采纳**：新增 `上下文台账：不启用` 永久关闭开关；lockfile 改为“禁全文读，允许按包名定向 grep”（§5.2、§5.6） |
| **二.1** | 过滤高噪 diff 误伤快照/golden（#4）与 lockfile（#2/#6） | **全盘采纳**：快照/golden 必看定向 diff；lockfile 未申报判阻断，已申报 grep 包名与下载源（§5.5B） |
| **二.2** | 大文件切片过依赖主观判断，易漏同文件未改函数引用 | **全盘采纳**：大文件 > 250 行须文件内 grep 每个被改符号/字段全部引用并读上下文（§5.5B） |
| **二.3** | 静默测试易掩盖 skip/xfail/未收集用例 | **全盘采纳**：保留计数汇总行、强制 `-rsxX` 等价参数、核对新增用例实跑数与测试矩阵一致（§5.5B） |
| **二.4** | Round 2+ `git diff` 仍对 `HEAD`、等长改写核验可选、未覆盖未跟踪内容 | **全盘采纳并实测验证**：升级为实施方临时索引整树快照 `T_n` + `git status`/`--cached` hash 双保险，`reviewer` 跑 `git diff --stat/diff T_{n-1} T_n`（§3.2、§5.5A/B） |
| **二.5** | 增量复审缺终轮全量兜底，改签名可能漏 Round 1 调用方 | **全盘采纳**：改签名每轮重搜全仓调用方；判定“通过”轮独立静默复跑全量门禁或注明原因并核对 `T_n` 实测输出（§5.5B） |
| **二.6** | 跳过整个上篇丢掉意图，妨碍“跳出基线找缺陷” | **全盘采纳**：顶部元信息、拍板决议、红线、目标与底线必读，仅跳过纯痛点背景与 Q&A 附录（§5.5B） |
| **二.7** | Map/Ledger 易过期，不得缩小攻击面 #1 搜索范围 | **全盘采纳**：`designer`/`reviewer` 双侧写死仅为种子线索，仍须独立全仓搜调用方，冲突以代码为准并报过期（§5.2、§5.5B） |
| **二.8** | 无问题项 1 行证据防敷衍 | **全盘采纳**：每行必须含具体命令或 `file:line`，严禁只写“无问题”（§5.5B） |
| **三.1** | 去掉 `archive/` 归档避免误移、断链与复杂度 | **全盘采纳**：彻底移出 skill 流程，改为用户手动可选，大幅精简 `bootstrap-migration.md`（§2、§4.2、§5.4） |
| **三.2** | 第 6 步收口不易触发导致 Ledger 过期 | **全盘采纳**：第 5 步汇报输出带增量草稿的「验收收口待办」留在上下文，并在新版受管规则块写入收口更新台账（§5.5A、§5.6） |
| **三.3** | 明确 `--update-rules` 新受管块、对齐模板、保真 CRLF、统一 marker 口径、修正“原子写回”措辞 | **全盘采纳**：全部写入 §5.6 精确契约与 §7.1 自动化断言（含模板逐字节一致性、零 CRLF/LF 混排、行内 marker 文本不误判） |
| **三.4** | 双 `SKILL.md` 预算偏松且审查员被迫读实施方章节 | **全盘采纳**：拆分 `references/reviewer-protocol.md` 与 `references/orchestration.md`，双 `SKILL.md` 均压至 **≤ 160 行**（§4.1、§5.2–5.5、§7.1） |
| **三.5** | Scout 按需启用、只给坐标、零信任扩至完整性、明示 L39 例外 | **全盘采纳**：全部写入 §5.2 与 §5.3 精确契约 |
| **三.6** | 缺 skill 行为本身与降本验收 | **全盘采纳**：新增 §7.3「4 缺陷植入沙盒行为验收实验 + 改造前后 token 对比」（§7.3） |

---

## 附录 C：第三方第二轮评审意见处置对照表（6/6 全量闭环）

| 评审条目 | 核心意见 | 处置结论与落地章节 |
| :--- | :--- | :--- |
| **二轮.1** | 拆分 `reviewer-protocol.md` 漏搬意见分级、双重审查视角、Round 2+ 聚焦防漂移三块规则；降级 2 实施方自查亦需指向该协议 | **全盘采纳**：三块原文从 `SKILL.md` 整体迁入 `reviewer-protocol.md` 单源维护；`SKILL.md` 降级 2 同步指向 `reviewer-protocol.md`（§4.1、§5.5A/B） |
| **二轮.2** | 审查员须只读核验 `T_n` 新鲜度（`git diff --stat "$T_n"` + 未跟踪 `git hash-object` vs `git rev-parse "${T_n}:<f>"`，防 zsh `:u` 报错）；Round 1 亦用 `HEAD..T_1`；收窄“字节级零修改”至非 `.gitignore` 忽略文件；补大文件 blob 提示 | **全盘采纳并实测补强**：完整写入 §3.2 与 §5.5A/B，并补充本机实测发现的两个关键守卫——① `TMPD` 必须建在仓外防 `idx`/`idx.lock` 被打进 `T_n`；② 用 `git status --porcelain -uall` 展开未跟踪目录以实现逐文件一一对应；无 `HEAD` 新仓用空树对象兜底 |
| **二轮.3** | `--with-rules` 边缘行为有 2 处有意变化须明文披露并恢复 §9 止损红线；marker 匹配只去行尾 `\r`/空白、严禁去行首缩进（防代码块缩进示例误判） | **全盘采纳**：在 §5.1、§5.6 与 §8（README）明文披露两处边缘收紧；§9 恢复默认幂等止损并单列这两项例外；marker 改为保留行首缩进并在 §7.1 新增缩进代码块反例断言 |
| **二轮.4** | `orchestration.md` “`designer` 严禁读取”与单会话直出设计执行 1A 选题冲突 | **全盘采纳**：精确限定为“独立拉起的 `designer` 节点严禁读取；单会话直出模式可读 1A 选题部分、跳过 2A Scout 部分”（§4.1、§5.2、§5.3） |
| **二轮.5** | 测试 skip/xfail 阻断须豁免执行单写明的合理条件；lockfile 未申报阻断须补充无执行单场景判定规则 | **全盘采纳**：两条阻断例外均写入 §5.5B |
| **二轮.6** | §7.3 行为验收需做新旧对照、每组至少跑 2 次，并补 1 个 `designer` 完整性验收用例（Context Pack 故意漏调用方） | **全盘采纳**：§7.3 升级为实验 A（`reviewer` 4 缺陷新旧对照 × ≥ 2 次）+ 实验 B（`designer` 完整性防遗漏 × ≥ 2 次）+ 降本实证 |

---

## 附录 D：第三方第三轮评审意见处置对照表（4/4 全量闭环）

| 评审条目 | 核心意见 | 处置结论与落地章节 |
| :--- | :--- | :--- |
| **三轮.1** | `git diff --stat "$T_n"` 存在超长路径截断，且默认 `core.quotePath=true` 会对空格/中文路径转义导致后续命令报错 | **全盘采纳并实测补强**：改用 `git -c core.quotePath=false diff --name-status "$T_CUR"` 对比 `git -c core.quotePath=false ls-files --others --exclude-standard`（本机实测即使开启 `core.quotePath=false`，`status --porcelain` 仍给含空格路径加双引号，而 `diff --name-status` 与 `ls-files --others --exclude-standard` 均输出无截断、无引号的原始完整路径；同时辅以 `status --porcelain -uall` 核对状态）（§3.2、§5.5B） |
| **三轮.2** | Shell 示例中 `"$T_{n-1}"` 变量名不合法；硬编码 SHA-1 空树 `4b825dc...` 不兼容 SHA-256 仓库 | **全盘采纳**：所有命令变量统一为合法命名 `"$T_PREV"` / `"$T_CUR"`；空树 OID 改为零写盘动态计算 `git hash-object -t tree /dev/null`（PowerShell 用 `@() \| git hash-object -t tree --stdin`）（§3.2、§5.5B） |
| **三轮.3** | 默认拍板直定稿漏掉“升级前存量旧格式在途草稿（含条件分支）”守卫 | **全盘采纳**：恢复守卫条件“全按推荐项拍板**且下篇正文无待折叠条件分支**”才由主会话直改顶部 3 行定稿；存量旧草稿仍交 `@designer` 折叠（顶部注释、§5.2） |
| **三轮.4** | 第 0 步配置发现误写死 `AGENTS.md`，遗漏 `CLAUDE.md` / `GEMINI.md` | **全盘采纳**：全文涉及第 0 步配置发现处统一改为「第 0 步识别到的项目规范文件（`AGENTS.md` / `CLAUDE.md` / `GEMINI.md`）显式声明的路径」（§2、§3.1、§5.1、§5.2、§5.4、§5.5A、§6） |

---

## 复审闭环记录（实施后由 task-review-loop 追加）

- **闭环结论**：共 **2 轮**独立只读复审，**一致通过（代码/脚本/测试/文档阻断项 = 0；§7.3 多轮 LLM 沙盒对照实验显式交用户裁决是否补跑或豁免）**。
- **审查通道与模型**：Antigravity 单节点 `swarm`（`name="reviewer"`, `workspace="inherit"`）· **`gemini-4-neon-high`（Gemini 4 Neon High）**；因沙盒 `.git/objects` 只读，送审前/后快照按降级条款采用纯只读指纹（`status --porcelain -uall` + `git diff` / `--cached` hash + 全量未跟踪文件 `git hash-object`），两轮复审均核验字节级零修改，闭环结束后已 `kill` 回收。
- **Round 1 发现与处置**：
  - 阻断项 #1（T8 软链测试复用已更新文件致假阳性）→ 改为先写旧值 `OLD_SYMLINK_BLOCK` 并 `cmp -s` 逐字节校验；
  - 阻断项 #2（T10 退出码未严格拒收 `exit 0`）→ 改为 `if bash ...; then fail; fi` 强断言非 0 退出码与 `stderr`；
  - 阻断项 #3（T3 / T5b / T6 弱断言）→ 升级为构造精确期望文件 `cmp -s` 逐字节校验，T6 改旧顶级块验证仅替换顶级块；
  - 阻断项 #4（§7.3 独立沙盒仓多轮 LLM 行为对照实验尚未运行）→ 诚实披露并在汇报中交由用户裁决（立刻补跑 vs 明确豁免/拆至后续任务）；
  - 4 条非阻断建议（`handoff-template.md:11` 旧文案清理、`install-skills.sh:306` `getline < 0` 防御、`task-review-loop/SKILL.md:43` 未忽略大文件 blob 提示、`bootstrap-migration.md:8,11` 优先规范声明路径）全部采纳落地。
- **Round 2 复核结果**：`reviewer` 逐项复核增量改动并独立复跑全量门禁，判定**代码/脚本/测试/文档阻断项 = 0、非阻断建议 = 0**。
- **验收实测证据（最终代码）**：
  - `bash -n scripts/install-skills.sh && bash -n tests/test-install-skills.sh` → 退出码 0
  - `bash tests/test-install-skills.sh` → `ALL 11 TESTS PASSED`（`GNU bash 3.2.57`）
  - `./scripts/install-skills.sh --list` → `task-handoff` / `task-review-loop`
  - `wc -l`：`skills/task-handoff/SKILL.md` = `83` 行（≤ 160），`skills/task-review-loop/SKILL.md` = `86` 行（≤ 160），6 个 `references/*.md` 全部非空，`skills/task-review-loop/references/checklists.md` 零改动。
- **§7.3 独立沙盒仓行为与降本对照实证（`gemini-4-hydrogen-low`，6 个并行独立节点，已全部回收并清理 `/tmp` 沙盒）**：
  - **实验 A（`reviewer` 4 缺陷新旧对照 × 2 次）**：
    - 旧版基线（`ff1e65a`，读 `SKILL.md` 134 行）：Run 1 检出 4/4（10 次工具调用、读 3 文件）；Run 2 检出 **3/4（漏检缺陷 #4 Round 2 未申报等长改写 `v2-B → v2-C` 并误判“通过”**，10 次工具调用、读 6–7 文件）；
    - 新版（读 `reviewer-protocol.md` 55 行，协议输入行减 **59%**）：Run 1 与 Run 2 **2/2 稳定检出 4/4 全部阻断项**（含 `T_PREV..T_CUR` 精确捕获未申报的 `src/audit.py` 等长改写与 `rg → git grep` 自动降级），工具调用降为 8–9 次、直接读文件降为 2 个。
  - **实验 B（`designer` 完整性防遗漏 × 2 次）**：向新版 `designer` 传入故意遗漏 `src/cli/export.py:4` 的 Context Pack，Run 1 与 Run 2 **2/2 均通过独立全仓搜索找回被遗漏的 `src/cli/export.py:4`（`export_row`）** 并完整写入执行单（同时验证 `rg → grep` 自动降级）。

# SubRadar 工程开发规范 (`AGENTS.md`)

> 本文档为 **SubRadar** 项目的强制性工程开发规范。所有参与本项目的开发者与 AI Agent 在设计、编码、重构与提交前均须严格遵守。

---

## 〇、需求洞察、文档先行与阶段追加规范（Insight-First, Docs-First & Phase Append）

1. **需求洞察、方案归档与确认前置门禁（强制）**：
   * 每次用户提出需求修改或功能实现时，**严禁直接动手修改代码**，必须先完成以下流程，并在**收到用户明确确认指令后**才可分 Phase 执行：
     1. **影响面洞察与代码实证**：先深入分析本次需求会对哪些模块产生影响、具体影响是什么，并给出仓库中**具体的现有代码（文件路径、行号与真实代码片段）进行证实**。
     2. **实现思路与分 Phase 实施方案**：给出清晰的实现思路，以及拆解合理、可验证的分 Phase 实施方案。
     3. **写入 `docs/phases/` 并忽略提交**：将完整的实施方案写入 `docs/phases/` 文件夹下；`docs/phases/` 必须保持在 `.gitignore` 中，不纳入 Git 版本控制。
     4. **方案文件命名规范**：文件名须体现本次创建文档对应的实现与需求内容，并附带精确到分钟的时间戳（`YYYYMMDDHHMM`），格式为 `phase_<需求或实现简述>_<YYYYMMDDHHMM>.md`（例如 `phase_login_fix_bug_202601091814.md`）。
     5. **确认后分 Phase 执行**：向用户汇报影响分析、代码实证、实现思路、分 Phase 方案及方案文件路径；**只有收到用户明确确认的指令后，才能分 Phase 开始执行**。
2. **文档必须绝对先行**：
   * 确认开始执行后，任何需求变更、界面调整或功能扩展，**必须先修改 [docs/PRD.md](docs/PRD.md) 与 [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md)**，确认需求与架构一致后，才能进行代码修改与开发。
   * **严禁文档与代码脱节**：所有已实现的功能、默认路径、UI 风格与技术方案必须在文档中同步体现。
3. **已完成 Phase 禁止回改污染，必须追加新 Phase**：
   * 若当前所处的 Phase 已经开发并验收完成，任何新的修改、优化或补充需求**不得直接塞入已完成的历史 Phase**，而必须在 `docs/DEVELOPMENT_PLAN.md` 的当前已完成 Phase 之后**追加一个新的 Phase**（并顺延后续未开始 Phase 的编号），再按 TDD 流程执行。

---

## 一、核心开发方法论：TDD（测试驱动开发）

本项目在所有核心引擎、数据仓库、服务层与 ViewModel 状态逻辑开发中，严格遵循 **Red → Green → Refactor** 循环：

1. **Red（先写失败测试）**：
   * 在编写任何新业务函数、状态转换或修复 Bug 之前，必须先在 `Tests/SubRadarCoreTests/` 中编写对应的 Swift Testing (`@Suite` / `@Test`) 单元测试，并确认新测试在实现前失败或无法编译。
   * 重点测试覆盖范围：
     * `BillingEngine`：跨年历史周期推算、闰年/月底边界无漂移、一次性买断、确认续订推进。
     * `SQLiteSubscriptionRepository`：表迁移、事务原子性、自定义时间段流水聚合、外键级联删除、敏感字段加密隔离。
     * `ViewModels`（Phase 2+）：列表搜索过滤、模版动态字段切换、历史计费实时预览、响应式大盘统计汇总、Mock/Production 一致性。
2. **Green（最小化实现通过测试）**：
   * 仅编写恰好使测试通过的最简洁实现代码，禁止跳过失败断言或弱化测试条件。
3. **Refactor（安全重构）**：
   * 在测试全部通过的前提下优化代码结构、提炼公共 Helper 与组件，重构后再次运行完整测试集确保全绿。

---

## 二、核心编码准则：YAGNI / DRY / KISS

### 1. YAGNI（You Aren't Gonna Need It — 如无必要，勿增实体）
* **只做当前 PRD 与当前 Phase 明确要求的功能**。
* 禁止提前开发“未来可能会用到”的后台接口、冗余配置开关、过度泛化的抽象基类或未被调用的扩展参数。
* 外部依赖坚持极简：当前 `Package.swift` 保持零第三方库依赖，不引入不必要的 SPM 包。

### 2. DRY（Don't Repeat Yourself — 不要重复自己）
* **单一数据源与逻辑复用**：
  * 任何相同的业务规则（日期格式化、货币符号与金额格式化、校验规则、SSH 拼接）必须抽离为统一工具函数或模型计算属性。
  * SwiftUI 视图中重复出现的卡片容器、微光描边、Hover 高亮、复制 Toast、标签 Badge 必须抽离为统一的 `DesignSystem` 组件或 `ViewModifier`，禁止在多个 View 文件里复制粘贴样式代码。
  * SQLite 列名映射、Schema 字段与校验逻辑保持单一定义，防止前后端模型或迁移脚本出现两套不一致逻辑。

### 3. KISS（Keep It Simple, Stupid — 保持简洁直白）
* **浅层嵌套与早返回（Early Return）**：优先使用 `guard ... else { return }`，控制单个函数长度和嵌套深度（建议不超过 3 层）。
* **单一职责**：文件、类与函数职责清晰单一；Model 负责结构与自校验，Engine 负责纯计算，Repository 负责数据落盘，ViewModel 负责状态驱动，View 仅负责声明式渲染与意图转发。
* **优先使用系统原生能力**：优先采用 Swift 6 标准库、原生 `SQLite3`、`SwiftUI`、`Swift Charts`、`URLSession`、`NSOpenPanel` 与 `UserNotifications`，避免复杂黑魔法。

---

## 三、架构与技术约束（Project Guardrails）

### 3.1 Swift 6 严格并发安全
* 开启 Swift 6 语言模式（`swift-tools-version: 6.0`），所有跨越并发边界的模型须实现 `Sendable`。
* 数据库连接使用 `actor SQLiteDatabase` 串行隔离；UI 状态与 `AppContainer` 标记 `@MainActor`。

### 3.2 面向协议解耦（依赖倒置）
* UI 与 ViewModel 只能依赖 `Protocols/` 中定义的抽象协议，禁止在 View 或 ViewModel 中直接操作 `SQLiteDatabase` 或硬编码外部 HTTP 请求。
* 所有依赖切换统一由 `AppContainer.makeMock()` 与 `AppContainer.makeProduction()` 管理。

### 3.3 数据隐私与安全红线
* **敏感字段隔离**：`CustomFieldType.secret`（VPS 密码、软件激活码）严禁明文存入 SQLite 表中，必须经由 `SecretStoreProtocol`（生产环境为 macOS Keychain）存储，SQLite 中仅保留引用标识。
* **开源仓库安全（GNU GPL v3.0）**：严禁将任何个人真实密码、私钥、签名证书（`.p12`）、真实服务器 IP 或 API Secret 提交至 Git；测试与 Mock 数据一律使用 RFC 保留地址（如 `198.51.100.x`、`2001:db8::1`）和明显占位符。

### 3.4 交互与视觉规范
* **本机应用导入约束**：仅支持调用 `NSOpenPanel` 打开 `/Applications` 目录选择 `.app` 应用包提取图标与名称，**不支持拖拽 `.app`**。
* **VPS SSH 连接**：通过系统标准 `ssh://` 协议拉起终端，并提供一键复制完整 `ssh` 命令。
* **去原生化定制 UI + 暗黑主题 + 响应式**：
  * **严禁使用简陋的默认原生控件样式**（如默认蓝色 Sidebar 高亮框、系统默认 `.roundedBorder` 输入框、原生 `.bordered` 按钮及传统分段选择器），所有交互控件须通过 `DesignSystem` 统一自定义渲染。
  * **默认首页与左下角入口**：启动默认进入 **费用统计大盘（Analytics）**；侧边栏左下角为 **设置（Settings）** 入口。
  * **双主题支持**：完整支持 **暗黑主题（Dark Theme）** 与 **浅色主题（Light Theme）**（及跟随系统），具备独立的色彩 Token 体系。
  * 支持窗口最小尺寸 `680×520`，适配宽屏（`≥1080px`）、中等分屏（`760~1079px`）与极窄自适应（`<760px`）；金额、日期、倒计时与网络端口/IP 必须使用等宽数字（`.monospacedDigit()` / `.fontDesign(.monospaced)`）。

---

## 四、代码规范、静态校验与单文件上限（Ruff / Mypy 等效标准）

1. **单文件行数上限（强制 ≤ 300 行）**：
   * `Sources/` 与 `Tests/` 下**任意 `.swift` 源文件不得超过 300 行**（含空行与注释）。
   * 若单一模块职责膨胀，必须按功能或子模块拆分到独立文件中，保持高内聚、低耦合。
2. **文件命名规范（UpperCamelCase，禁止 `+` 号）**：
   * 所有 `.swift` 文件必须采用**纯大驼峰命名（UpperCamelCase）**，清晰体现所属模块与功能职责（例如 `MainViewModelActions.swift`、`AnalyticsChartsSection.swift`）。
   * **禁止使用 `Type+Ext.swift`（如 `+Results`、`+Upgrades` 等带 `+` 号的命名）**。
3. **代码格式与静态 Lint（对标 Python `ruff`，使用 Apple 官方 `swift-format`）**：
   * 仓库根目录配置文件 [`.swift-format`](file:///Users/tianyang/MyProject/SubRadar/.swift-format) 定义统一格式与 Lint 规则（4 空格缩进、单行 120 字符、有序分组 `OrderedImports`、显式 `nil` 判断、ASCII 标识符等）。
   * 自动格式化：`xcrun swift-format format --in-place --configuration .swift-format -r -p Sources Tests`
   * 严格 Lint 检查：`xcrun swift-format lint --strict --configuration .swift-format -r -p Sources Tests`
4. **严格静态类型与 Swift 6 并发检查（对标 Python `mypy`）**：
   * 开启 Swift 6 语言模式并将全部编译器警告提升为错误：
     `swift build --build-tests -Xswiftc -warnings-as-errors`

---

## 五、构建、测试与提交门禁

1. 每次修改代码后，提交前必须运行全量质检脚本（覆盖 **300 行限制 + 命名规范 + swift-format 严格 Lint + Swift 6 `-warnings-as-errors` 类型检查 + 全部单元测试**）：
   ```bash
   ./scripts/check_quality.sh
   # 需要顺带自动格式化时：
   ./scripts/check_quality.sh --fix
   ```
2. 必须保证**零文件越界、零格式与 Lint 告警、零编译错误、零并发警告、全部单元测试通过**。
3. 涉及网络 API 变更时，需在本机联网环境下执行 `./scripts/check_quality.sh --with-live` 或 `swift test --filter LiveHealthCheckTests` 验证真实连通性。
4. **增量按批提交与回滚保护（强制）**：
   * 严禁将大量跨模块改动长期堆积在未提交工作区；每完成一个逻辑清晰的功能批次或阶段文档/测试/代码并验证质检脚本全绿后，**必须立即按功能/阶段分批执行 `git commit`**，保证任意节点均可精确回滚与追溯。
   * `.build/`、`DerivedData/`、`docs/phases/` 等构建/本地规划产物及密钥/证书文件须始终写入 `.gitignore`，禁止进入 Git 版本历史。

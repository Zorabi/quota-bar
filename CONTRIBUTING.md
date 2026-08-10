# 参与贡献

感谢您帮助改进 QuotaBar。QuotaBar 是一款 macOS 菜单栏应用，用于以只读方式展示当前 Codex 账号的用量窗口、重置时间、Plan、Credits 和 Reset credits。

## 开始之前

- 提交新 Issue 前，请先搜索是否已有相同或相关问题。
- 涉及重要产品行为、数据来源、公开 API、持久化格式、应用架构或隐私边界的改动，请先通过 Issue 讨论。
- Issue、Pull Request、测试夹具和截图中不得包含真实 access token、账号凭据、任务内容、私有用量数据或其他未经脱敏的信息。
- 开始开发前请阅读 [AGENTS.md](AGENTS.md)，并检查 `docs/superpowers/specs/` 与 `docs/superpowers/plans/` 中已批准的设计和实施记录。

## 开发环境

- Apple Silicon Mac
- macOS 14 Sonoma 或更高版本
- Swift 6.2
- Xcode Command Line Tools
- ImageMagick，用于生成应用图标和完整 `.app` 包

安装 ImageMagick：

```bash
brew install imagemagick
```

## 开发流程

1. Fork 仓库并创建范围明确的分支。
2. 保持改动聚焦，遵循现有 Swift Package、SwiftUI、AppKit 和 WidgetKit 目录结构。
3. 功能实现和缺陷修复遵循测试驱动开发：先添加失败测试，再实现使其通过的最小改动。
4. 行为、配置、数据来源、持久化格式、构建方式或用户操作流程变化时，同步更新相关文档。
5. 运行完整验证：

   ```bash
   zsh Tests/BuildAppBundleIdentifierTests.sh
   swift test
   swift build
   Scripts/build-app.sh
   git diff --check
   ```

6. 打包后确认主应用 Bundle ID 为 `org.dongx.quota.bar`，Widget 扩展 Bundle ID 为 `org.dongx.quota.bar.native-widget`。
7. 创建 Pull Request，说明问题、解决方案、验证结果、兼容性影响；界面改动还应提供修改前后的截图。

## 项目不变量

- 常规用量只通过本机 ChatGPT / 旧版 Codex App 内的 `codex app-server --stdio` 读取，不访问应用私有数据库。
- Reset credits 过期时间只在用户手动触发时查询，结果仅保留在当前运行会话中。
- 不提供登录、购买、批准、拒绝、额度重置或其他账号写操作。
- 不持久化任务内容；仅应用设置和供 WidgetKit 使用的最近一次用量快照可写入 `Application Support/QuotaBar`。
- 无法确认的数据必须显示为未知、不可用或降级，不得伪造额度、来源或能力。
- 修改共享设置、模型或快照结构时，应保持旧版本数据可兼容解码。
- 修改任一 Bundle ID 时，必须同步更新主应用、Widget 扩展、注册逻辑、打包脚本和回归测试。
- 新增或修改的代码注释、文档注释和用户可见文案默认使用中文。

## 提交规范

每个提交只处理一个明确主题，并使用 Conventional Commits 风格：

```text
type(scope): 简明描述
```

例如：`feat(settings): 增加刷新间隔选项`、`fix(widget): 修复快照兼容解码`、`docs: 更新构建说明`。

## 许可证

提交贡献即表示您同意相关内容按照本仓库的 [GNU Affero General Public License v3.0](LICENSE)（`AGPL-3.0-only`）授权。

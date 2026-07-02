# Codex 用量小组件 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个全新的 macOS Codex 用量菜单栏与桌面小组件原型。  
**Architecture:** SwiftPM 包含一个可测试的 `CodexUsageCore` library 和一个 `CodexUsageWidgetApp` executable。核心层负责快照、设置和格式化；应用层用 SwiftUI/AppKit 展示菜单栏文本、桌面浮窗和详情设置。  
**Tech Stack:** Swift 6.2、Swift Package Manager、SwiftUI、AppKit、XCTest、macOS 14+。

## Global Constraints

- 全部沟通、文档和新增代码注释使用中文。
- 菜单栏默认文本必须是 `5h 52% | 7d 42%` 这种竖线分隔格式。
- 菜单栏不显示应用图标。
- 不读取 Codex Desktop 私有数据库。
- 当前数据源使用可替换模拟数据，不伪造真实在线额度。
- 实现遵循 TDD：先写失败测试，再写最小实现。

---

## Final File Map

```text
Package.swift
Sources/
  CodexUsageCore/
    UsageModels.swift
    MenuBarUsageFormatter.swift
    MockUsageProvider.swift
  CodexUsageWidgetApp/
    CodexUsageWidgetApp.swift
    AppModel.swift
    DesktopWidgetController.swift
    UsageViews.swift
Tests/
  CodexUsageCoreTests/
    MenuBarUsageFormatterTests.swift
    UsageModelTests.swift
Scripts/
  build-app.sh
README.md
```

## Task 1: 核心模型与菜单栏格式化

**Files:**
- Create: `Package.swift`
- Create: `Tests/CodexUsageCoreTests/MenuBarUsageFormatterTests.swift`
- Create: `Tests/CodexUsageCoreTests/UsageModelTests.swift`
- Create: `Sources/CodexUsageCore/UsageModels.swift`
- Create: `Sources/CodexUsageCore/MenuBarUsageFormatter.swift`

**Interfaces:**
- Produces: `UsageWindowKind`、`UsageWindowSnapshot`、`CodexUsageSnapshot`、`WidgetSettings`、`MenuBarUsageFormatter.format(_:settings:)`。

- [ ] **Step 1: 写失败测试**
- [ ] **Step 2: 运行测试确认缺少类型失败**
- [ ] **Step 3: 实现最小核心模型和格式化器**
- [ ] **Step 4: 运行核心测试确认通过**

## Task 2: 模拟数据源

**Files:**
- Create: `Sources/CodexUsageCore/MockUsageProvider.swift`
- Modify: `Tests/CodexUsageCoreTests/UsageModelTests.swift`

**Interfaces:**
- Produces: `UsageProviding`、`MockUsageProvider.fetchUsage()`。

- [ ] **Step 1: 写失败测试，验证模拟数据包含 5h 和 7d 窗口**
- [ ] **Step 2: 运行测试确认缺少数据源失败**
- [ ] **Step 3: 实现模拟数据源**
- [ ] **Step 4: 运行核心测试确认通过**

## Task 3: macOS 菜单栏与桌面小组件 UI

**Files:**
- Create: `Sources/CodexUsageWidgetApp/CodexUsageWidgetApp.swift`
- Create: `Sources/CodexUsageWidgetApp/AppModel.swift`
- Create: `Sources/CodexUsageWidgetApp/DesktopWidgetController.swift`
- Create: `Sources/CodexUsageWidgetApp/UsageViews.swift`

**Interfaces:**
- Consumes: `CodexUsageSnapshot`、`WidgetSettings`、`MenuBarUsageFormatter`、`MockUsageProvider`。
- Produces: 可构建的 macOS 菜单栏应用和桌面浮动小组件。

- [ ] **Step 1: 添加应用入口和 `AppModel`**
- [ ] **Step 2: 添加无图标 `MenuBarExtra` label**
- [ ] **Step 3: 添加桌面浮窗控制器**
- [ ] **Step 4: 添加小组件、详情和设置视图**
- [ ] **Step 5: 运行 `swift build` 确认通过**

## Task 4: 构建脚本与说明

**Files:**
- Create: `Scripts/build-app.sh`
- Create: `README.md`

**Interfaces:**
- Produces: `.build/CodexUsageWidget.app`。

- [ ] **Step 1: 添加构建脚本**
- [ ] **Step 2: 添加 README 使用说明**
- [ ] **Step 3: 运行 `swift test` 和 `swift build`**


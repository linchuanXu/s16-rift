# S16 峡谷 / S16 Rift

阅星曈 X4 Pro 上的 XTApp 示例，供交流学习。

An XTApp example for the XTEINK X4 Pro, shared for study and discussion.

2026 全球总决赛观战沙盘：对位征召、分路推演、整局转播。横屏，Lua API 0.8，当前版本 0.7.3。

A 2026 World Championship viewing sandbox: draft, lane projection, and full-match broadcast. Landscape, Lua API 0.8, version 0.7.3.

英雄、战队与选手名称仅用于这款粉丝向观战演示，相关权利归原权利人所有。

Champion, team, and player names appear only in this fan-made viewing demo. All related rights belong to their owners.

## 界面 / Screens

### 征召 / Draft

![征召 Draft](screenshots/draft.jpg)

T1 对 BLG 的征召盘：按分路筛选英雄，已禁用的英雄画叉，底部显示选用进度。

Draft board for T1 versus BLG. Filter champions by role, banned champions are crossed out, and the footer shows pick progress.

### 对线转播 / Lane broadcast

![对线转播 Lane broadcast](screenshots/broadcast.jpg)

对线期沙盘：左侧是峡谷站位，右侧是比分、资源与事件时间线。

Laning-phase board: Rift positions on the left, score, objectives, and the event timeline on the right.

## 目录 / Layout

- `project-files/`：应用源码。入口是 `index.lua`，逻辑在 `domain/`，英雄池在 `data/champ_pool.json`。
- `project-files/`：application source. Entry is `index.lua`, logic lives in `domain/`, and the champion pool is `data/champ_pool.json`.
- `assets/xic/`：运行时点阵素材。 / Runtime bitmap assets.
- `screenshots/`：README 里的界面图。 / Screenshots used in this README.
- `xtapp-studio/project.json`：Studio 项目归档。 / Studio project archive.
- `presentation/store_cover.jpg`：封面图。 / Store cover.

## 在 Studio 里打开 / Open in Studio

把本仓库打成 ZIP，在 XTApp Studio 里选择「导入项目 ZIP」，即可恢复为一份新的项目副本。归档只含代码和素材，不含 AI 对话、模型设置或临时运行状态。

Zip this repository and choose “Import project ZIP” in XTApp Studio to restore a new project copy. The archive contains code and assets only: no AI chat, model settings, or temporary runtime state.

导出时间 / Exported: 2026-09-29。

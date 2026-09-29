# S16 峡谷

![S16 峡谷](presentation/store_cover.jpg)

把全球总决赛塞进一块墨水屏。

选一支队伍，走进淘汰赛。征召盘上给对手画叉，再看一血、小龙和击杀从迷你转播里滚过去。这是跑在阅星曈 X4 Pro 上的粉丝观战沙盘，源码公开，欢迎翻着玩。

Stuff the World Championship into an e-ink screen.

Pick a side. Walk the bracket. Cross out their bans. Then watch first blood, dragons, and kills tick past on a pocket broadcast. A fan-made viewing sandbox for the XTEINK X4 Pro. Source is open. Poke around.

## 先看两眼 / Look first

### 征召，开始耍阴的 / Draft. Time to be mean.

![征召 Draft](screenshots/draft.jpg)

T1 对 BLG。上野中下辅一排滤镜，画了叉的已经进不了场，底下还在数你选了几个。

T1 versus BLG. Filter by role, the crossed-out faces are gone, and the footer is still counting your picks.

### 09:00，峡谷已经打起来了 / 09:00. The Rift is live.

![对线转播 Lane broadcast](screenshots/broadcast.jpg)

左边是谁站在哪，右边是比分、龙和一条不会停的事件条。烬拿下一血的时候，墨水屏也跟着响一下。

Positions on the left. Score, dragons, and a feed that will not sit still on the right. When Jhin takes first blood, the screen notices.

## 里面有什么 / What's in the box

- 选队，签表，一路打到最后
- 按分路禁选，禁用的英雄直接画叉
- 一整局迷你转播：站位、资源、击杀
- 抽卡、图鉴，打完还有评分

- Pick a team and ride the bracket
- Ban and pick by role
- A full-match mini broadcast: positions, objectives, kills
- Gacha, a champion book, and a score when it's over

横屏 · Lua API 0.8 · v0.7.3

## 想自己跑 / Run it yourself

把仓库打成 ZIP，在 XTApp Studio 里选「导入项目 ZIP」。进来的是代码和素材，没有聊天记录。

Zip the repo and choose “Import project ZIP” in XTApp Studio. You get the code and the art, not the chat history.

源码在 `project-files/`，入口是 `index.lua`。点阵图在 `assets/xic/`。

Source lives in `project-files/`, entry is `index.lua`. Bitmaps are in `assets/xic/`.

粉丝作品，非官方。英雄、战队、选手和上面这张官方图的权利都归原权利人，这里只作交流学习。

Fan work, not official. Champions, teams, players, and the official art above belong to their owners. Shared here for study and discussion.

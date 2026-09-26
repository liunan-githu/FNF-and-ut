# 尘埃传说 / DustLegend

Undertale 同人游戏。基于 **Godot 4.7** + **UT-Godot-Engine** 框架开发，
战斗时会**无缝嵌入**运行另一个游戏 —— FNF（Friday Night Funkin'）**Codename Engine**。

---

## ⚠️ 本仓库不包含 FNF 引擎与 mod

为了让仓库轻量，`fnf\` 目录已加入 `.gitignore`，请自行下载后放到项目根目录：

```
DustLegend\
└─ fnf\                ← 自己创建这个目录
   ├─ CodenameEngine.exe
   ├─ *.dll
   ├─ assets\ manifest\ ...
   └─ mods\dustin\     ← 见下方「mod 下载」
```

### 1) FNF 引擎：Codename Engine

| 来源 | 地址 |
|---|---|
| GitHub 仓库 | https://github.com/CodenameCrew/CodenameEngine |
| 官方下载（各平台） | https://github.com/CodenameCrew/CodenameEngine/releases |
| 官方网站 | https://codename-engine.com/ |

> 本项目实测使用的版本：**Codename Engine v1.0.1（experimental build）**

### 2) mod：Friday Night Dustin'

| 来源 | 地址 |
|---|---|
| GameBanana | https://gamebanana.com/mods/613322 |
| GameJolt | https://gamejolt.com/games/fridaynightdustinFULL/1012008 |

- 上面两个下载**自带 exe**，拿到后把整个文件夹的内容放进 `fnf\` 即可
- mod 本体的目录名应为 `fnf\mods\dustin\`
- 注意：GameBanana / GameJolt 的下载可能带的是完整游戏（含引擎），二选一即可，不要重复放

### 3) FNF 侧必需的脚本（本仓库已备份在 `installer\fnf_scripts\`）

拷进 mod 里，缺了就不会自动进歌 / 不会回传胜负：

| 文件 | 放到 |
|---|---|
| `zz_dustlink.hx` | `fnf\mods\dustin\data\global\` |
| `zz_dustlink_exit.hx` | `fnf\mods\dustin\songs\` |

---

## 快速开始（开发）

1. 装 Godot 4.7（本项目用 4.7 stable）
2. 按上面下载 FNF 引擎 + mod，放到 `fnf\`
3. Godot 打开本目录，F5 运行
4. 走到 sans → 选第 1 项 → 红心过场 → 进入 FNF

## 打包成可玩版 / 安装包

见 [`PACKAGING.md`](PACKAGING.md)

---

## 注意事项

| 事项 | 说明 |
|---|---|
| **路径必须纯英文** | ⚠️ FNF（Codename Engine）在含中文的路径下会卡死。项目路径、`fnf\` 路径都要英文 |
| **平台** | 仅 Windows（桥接会调用 PowerShell 做窗口嵌入；其他平台自动跳过） |
| **`fnf\` 目录名** | 必须是 `fnf`，桥接会自动找「exe 同级的 `fnf\`」 |
| **换歌 / 换 mod** | 改 `script/fnf_bridge.gd` 的 `CNE_ARGS` |
| **哪些战斗触发 FNF** | 改 `script/fnf_bridge.gd` 的 `TRIGGER_ENCOUNTERS`（如 `"SANS_CPP"`） |

---

## 致谢

- 框架：[UT-Godot-Engine](https://github.com/WDUT-Dev/UT-Godot-Engine)（MIT）
- FNF 引擎：[Codename Engine](https://github.com/CodenameCrew/CodenameEngine)
- FNF mod：[Friday Night Dustin'](https://gamebanana.com/mods/613322)
- Undertale 原作者：Toby Fox

> 本项目为同人作品，仅供学习交流，不得商用。

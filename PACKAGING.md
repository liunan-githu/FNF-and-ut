# 「尘埃传说」打包指南

本指南说明如何把 **Godot 游戏** 和 **FNF（Codename Engine + dustin 模组）** 打成一个可分发的安装包。

---

## 零、FNF 引擎与 mod 从哪来（本仓库不含）

| 东西 | 下载地址 |
|---|---|
| **引擎** Codename Engine | GitHub：https://github.com/CodenameCrew/CodenameEngine ／ releases：https://github.com/CodenameCrew/CodenameEngine/releases |
| **mod** Friday Night Dustin' | GameBanana：https://gamebanana.com/mods/613322 ／ GameJolt：https://gamejolt.com/games/fridaynightdustinFULL/1012008 |

- 引擎实测版本：**Codename Engine v1.0.1（experimental build）**
- 下载后放到项目根目录的 `fnf\`：`fnf\CodenameEngine.exe`、`fnf\mods\dustin\`
- 两个下载地址自带 exe 的，选一个即可，别重复放
- FNF 侧必须的两个脚本已备份在 `installer\fnf_scripts\`：
  - `zz_dustlink.hx` → `fnf\mods\dustin\data\global\`
  - `zz_dustlink_exit.hx` → `fnf\mods\dustin\songs\`

---

## ⚠️ 最重要的一条：安装路径必须是纯英文

FNF（Codename Engine）**在中文路径下会卡死**（黑屏、CPU 接近 0，永远加载不出来）。
所以：

- ✅ 可以：`D:\Games\DustLegend\`、`C:\Games\DustLegend\`
- ❌ 不行：`D:\尘埃传说\...`、`D:\游戏\...`

游戏内部名字、窗口标题、快捷方式显示名都可以是中文，**只有磁盘路径要是英文**。

---

## 一、最终目录结构

```
DustLegend\                   ← 玩家安装后看到的文件夹（路径必须英文）
├─ DustLegend.exe             ← Godot 导出的主程序
├─ DustLegend.pck             ← 若导出时没有内嵌 pck
├─ lib.UndertaleEngine.windows_release.x86_64.dll   ← GDExtension 依赖，别删
└─ fnf\                       ← FNF 整个文件夹（原来 D:\FNF\CHENAI1 的内容）
   ├─ CodenameEngine.exe
   ├─ lime.ndll / libvlc.dll / ...
   ├─ assets\
   ├─ manifest\
   └─ mods\dustin\...         ← 必须包含这个 mod
      ├─ data\global\zz_dustlink.hx      ← 自启动进歌 + 关失焦暂停
      └─ songs\zz_dustlink_exit.hx       ← 歌末/死亡写结果并退出
```

> 桥接代码会自动去找「**exe 同级的 `fnf\` 目录**」，
> 所以 **子目录名必须是 `fnf`**，不要改。

---

## 二、打包步骤

### 第 1 步：安装 Godot 导出模板（只需一次）

Godot 编辑器 → 菜单 `编辑器` → `管理导出模板` → `下载并安装`（约 1.3 GB）。

或者手动：
1. 下载 `Godot_v4.7-stable_export_templates.tpz`
2. 解压，把里面的 `templates\*` 全部放到：
   `%APPDATA%\Godot\export_templates\4.7.stable\`

### 第 2 步：导出 Godot 游戏

1. Godot 打开 `D:\DustLegend`
2. 菜单 `项目` → `导出…`
3. 选择预设 **Windows**
4. 导出路径填：`D:\Games\DustLegend\DustLegend.exe`（**路径必须英文**）
5. 点 `导出项目`

> `tools/embed_window.ps1` 已经加进导出过滤（`export_presets.cfg` 的 `include_filter=tools/*.ps1`），
> 别把它删掉，否则窗口嵌入会失效（会自动降级为无边框全屏叠加）。

### 第 3 步：把 FNF 放进 `fnf\`

把项目里的 `D:\DustLegend\fnf` **整个文件夹**复制到导出目录并改名为 `fnf`（用**实体复制**，不要用目录联接，Inno Setup 可能不认）：

```
D:\Games\DustLegend\fnf\CodenameEngine.exe
D:\Games\DustLegend\fnf\mods\dustin\...
```

> ⚠️ 复制要**完整**（约 2.7 GB / 3570 个文件）。少文件的话 FNF 会在启动检查时弹一个
> 看不见的提示框然后卡死（黑屏、CPU 接近 0）。

确认这两个文件存在（缺了就会没有自动进歌 / 不会回传胜负）：
- `fnf\mods\dustin\data\global\zz_dustlink.hx`
- `fnf\mods\dustin\songs\zz_dustlink_exit.hx`

### 第 4 步：本地测试

双击 `DustLegend.exe` → 走到 sans → 选第 1 项：
- 应该：红心过场 → 黑屏 → FNF 全屏嵌入（黑屏约 40 秒是正常的，mod 在加载）
- FNF 打完后：回到大地图；如果死了：红心碎裂 + GAME OVER，按 Z 回大地图

### 第 5 步：编译安装包（Inno Setup）

1. 安装 Inno Setup（已装过可跳过）：
   ```
   winget install JRSoftware.InnoSetup
   ```
2. 打开 `installer\尘埃传说.iss`，确认最上面的 `#define GameDir` 指向你的导出目录：
   ```
   #define GameDir "D:\Games\DustLegend"
   ```
3. 用 Inno Setup Compiler 打开该 `.iss` → `Build` → `Compile`
4. 产物：`installer\output\DustLegend_Setup.exe`

---

## 三、注意事项

| 事项 | 说明 |
|---|---|
| **路径** | ⚠️ **必须纯英文**（中文路径会让 FNF 卡死）。内部名称/窗口标题可以是中文 |
| **体积** | FNF 侧约 2.7 GB，Inno 压缩后约 1.5~2 GB，编译需几分钟 |
| **平台** | 仅 Windows。Android/iOS 无法运行这个 exe（桥接已自动跳过） |
| **PowerShell** | 嵌入依赖系统自带 PowerShell。若被组策略禁用，会自动降级为「无边框全屏叠加」，体验几乎一样 |
| **换歌 / 换 mod** | 改 `script/fnf_bridge.gd` 顶部的 `CNE_ARGS`（`-mod <模组名> -dustlink <歌名> <难度>`） |
| **哪些战斗触发** | 改 `script/fnf_bridge.gd` 的 `TRIGGER_ENCOUNTERS`（填 encounter_name，如 `"SANS_CPP"`） |
| **加新歌曲** | 新歌的 `mods\<模组>\songs\<歌名>\scripts\` 无需额外脚本，`songs\zz_dustlink_exit.hx` 对所有歌生效 |

---

## 四、开发期（用 Godot 编辑器直接运行）

桥接会自动使用开发路径 `DEV_FNF_DIR`（默认 `D:\DustLegend\fnf`，即项目内的 `fnf\`）。
如果你把 FNF 挪了位置，改 `script/fnf_bridge.gd` 里的 `DEV_FNF_DIR` 即可。

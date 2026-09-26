; ------------------------------------------------------------------
;  「尘埃传说」安装包脚本（Inno Setup 6）
;  用法：把下面 GameDir 改成你的导出目录，然后用 Inno Setup 编译
;
;  ⚠️ 重要：整个安装路径必须是纯英文！
;     FNF（Codename Engine）在中文路径下会卡死加载不出来，
;     所以 DefaultDirName 用 {autopf}\DustLegend（快捷方式显示中文名）。
;
;  ⚠️ GameDir\fnf 必须是「实体文件夹」（从 D:\DustLegend\fnf 复制过去），
;     不要用目录联接（junction），Inno Setup 可能不会打包联接目标里的内容。
; ------------------------------------------------------------------

#define GameDir "D:\Games\DustLegend"
#define MyAppName "尘埃传说"
#define MyAppVersion "0.1.0"
#define MyAppExeName "DustLegend.exe"

[Setup]
AppId={{8B3F2A64-2E3D-4F1A-9C77-0F5A1E2B7C10}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=尘埃传说
; ⚠️ 必须是纯英文目录，否则 FNF 会卡死
DefaultDirName={autopf}\DustLegend
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=DustLegend_Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
; 如需中文界面：把中文语言文件放到 Inno Setup 的 Languages 目录，
; 再取消下面一行的注释
; Name: "chinese"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式（名为 尘埃传说）"; GroupDescription: "附加任务:"

[Files]
; 整个游戏目录（含 fnf 子目录）一起打包
Source: "{#GameDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; 快捷方式显示中文名，指向英文 exe
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "运行 {#MyAppName}"; Flags: nowait postinstall skipifsilent

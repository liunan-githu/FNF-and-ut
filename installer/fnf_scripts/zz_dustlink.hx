import Sys;
import flixel.FlxG;
import funkin.game.PlayState;

// 仅当由「尘埃传说」以 -dustlink 启动时才接管；正常单独玩 mod 不受影响
var __dustlink_started = false;
var __dustlink_args:Array<String> = Sys.args();
var __dustlink_mode = false;
for (i in 0...__dustlink_args.length) if (__dustlink_args[i] == "-dustlink") __dustlink_mode = true;

if (__dustlink_mode) {
	// 嵌入子窗口运行时会被判定为「失焦」，关掉自动暂停，否则画面卡死
	FlxG.autoPause = false;
	FlxG.game.focusLostFramerate = 60;
}

function postStateSwitch() {
	if (__dustlink_started || !__dustlink_mode) return;
	var a = __dustlink_args;
	var idx = -1;
	for (i in 0...a.length) if (a[i] == "-dustlink") idx = i;
	if (idx == -1) return;
	__dustlink_started = true;

	var song = "broken-reality";
	var diff = "hard";
	if (idx + 1 < a.length) song = a[idx + 1];
	if (idx + 2 < a.length) diff = a[idx + 2];

	PlayState.loadSong(song, diff, null, false);
	FlxG.switchState(new PlayState());
}

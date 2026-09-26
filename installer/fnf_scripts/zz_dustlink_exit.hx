import Sys;

// 放在 songs/ 根目录 -> 对所有歌曲生效。
// 只有被「尘埃传说」以 -dustlink 启动时才生效，把胜负写进结果文件并退出。
function __dustlinkMode():Bool {
	var a = Sys.args();
	for (i in 0...a.length) if (a[i] == "-dustlink") return true;
	return false;
}

function __writeResult(r:String) {
	try {
		sys.io.File.saveContent("dustlink_result.txt", r);
	} catch (e:Any) {
		// 写文件失败也不影响退出，Godot 侧会退回用退出码判断
	}
}

// 通关 -> 胜利
function onSongEnd() {
	if (!__dustlinkMode()) return;
	__writeResult("win");
	Sys.exit(0);
}

// 死亡/GameOver -> 失败
function onGameOver(_) {
	if (!__dustlinkMode()) return;
	__writeResult("lose");
	Sys.exit(2);
}

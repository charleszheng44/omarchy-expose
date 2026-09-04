.pragma library

function ipcFor(toplevel) {
    var ipc = toplevel && toplevel.lastIpcObject;
    return ipc && typeof ipc === "object" ? ipc : {};
}

function waylandFor(toplevel) {
    return toplevel && toplevel.wayland ? toplevel.wayland : null;
}

function appIdFor(toplevel) {
    var wayland = waylandFor(toplevel);
    if (wayland && wayland.appId)
        return String(wayland.appId);
    var ipc = ipcFor(toplevel);
    return String(ipc.class || ipc.initialClass || "");
}

function addressFor(toplevel) {
    var address = String((toplevel && toplevel.address) || "");
    return /^[0-9a-fA-F]+$/.test(address) ? "0x" + address : "";
}

function isEligible(toplevel) {
    return Boolean(waylandFor(toplevel)) && ipcFor(toplevel).mapped !== false;
}

function workspaceName(toplevel) {
    var workspace = toplevel && toplevel.workspace ? toplevel.workspace : null;
    return workspace ? String(workspace.name || workspace.id || "—") : "—";
}

function isOnScreen(toplevel, screenName, perMonitor) {
    if (!perMonitor)
        return true;
    var monitor = toplevel && toplevel.monitor ? toplevel.monitor : null;
    return Boolean(monitor) && String(monitor.name || "") === String(screenName || "");
}

function isOnWorkspace(toplevel, workspace) {
    var toplevelWorkspace = toplevel && toplevel.workspace ? toplevel.workspace : null;
    if (!toplevelWorkspace || !workspace)
        return false;
    if (ipcFor(toplevel).pinned === true || toplevelWorkspace === workspace)
        return true;

    var toplevelId = Number(toplevelWorkspace.id);
    var workspaceId = Number(workspace.id);
    if (isFinite(toplevelId) && isFinite(workspaceId) && toplevelId !== 0 && workspaceId !== 0)
        return toplevelId === workspaceId;

    var workspaceName = String(workspace.name || "");
    return Boolean(workspaceName) && String(toplevelWorkspace.name || "") === workspaceName;
}

function aspectRatioFor(toplevel) {
    var size = ipcFor(toplevel).size || [];
    var width = Number(size[0]);
    var height = Number(size[1]);
    if (size.length < 2 || !isFinite(width) || !isFinite(height) || width <= 0 || height <= 0)
        return 1.6;
    return Math.max(0.45, Math.min(4, width / height));
}

function needsPreviewWarmup(toplevel) {
    var ipc = ipcFor(toplevel);
    var monitor = toplevel && toplevel.monitor ? toplevel.monitor : null;
    var at = ipc.at || [];
    var size = ipc.size || [];
    if (!monitor || at.length < 2 || size.length < 2)
        return false;

    var scale = Number(monitor.scale);
    var monitorX = Number(monitor.x);
    var monitorY = Number(monitor.y);
    var monitorWidth = Number(monitor.width) / (isFinite(scale) && scale > 0 ? scale : 1);
    var monitorHeight = Number(monitor.height) / (isFinite(scale) && scale > 0 ? scale : 1);
    var windowX = Number(at[0]);
    var windowY = Number(at[1]);
    var windowWidth = Number(size[0]);
    var windowHeight = Number(size[1]);
    if (![monitorX, monitorY, monitorWidth, monitorHeight, windowX, windowY, windowWidth, windowHeight]
            .every(isFinite))
        return false;

    return windowX + windowWidth <= monitorX
        || windowX >= monitorX + monitorWidth
        || windowY + windowHeight <= monitorY
        || windowY >= monitorY + monitorHeight;
}

function uniformGrid(count, width, height, gap) {
    if (count <= 0 || width <= 0 || height <= 0)
        return [];

    var targetRatio = 1.6;
    var best = null;
    for (var columns = 1; columns <= count; columns++) {
        var rows = Math.ceil(count / columns);
        var cardWidth = (width - Math.max(0, columns - 1) * gap) / columns;
        var cardHeight = (height - Math.max(0, rows - 1) * gap) / rows;
        if (cardWidth <= 0 || cardHeight <= 0)
            continue;
        var scale = Math.min(cardWidth / targetRatio, cardHeight);
        var emptySlots = columns * rows - count;
        if (!best || scale > best.scale + 0.01
                || (Math.abs(scale - best.scale) <= 0.01 && emptySlots < best.emptySlots)) {
            best = {
                columns: columns,
                rows: rows,
                width: cardWidth,
                height: cardHeight,
                scale: scale,
                emptySlots: emptySlots
            };
        }
    }
    if (!best)
        return [];

    var gridHeight = best.rows * best.height + Math.max(0, best.rows - 1) * gap;
    var originY = (height - gridHeight) / 2;
    var result = [];
    for (var index = 0; index < count; index++) {
        var row = Math.floor(index / best.columns);
        var column = index % best.columns;
        var rowCount = Math.min(best.columns, count - row * best.columns);
        var rowWidth = rowCount * best.width + Math.max(0, rowCount - 1) * gap;
        var originX = (width - rowWidth) / 2;
        result.push({
            x: originX + column * (best.width + gap),
            y: originY + row * (best.height + gap),
            width: best.width,
            height: best.height
        });
    }
    return result;
}

function searchTextFor(toplevel) {
    var ipc = ipcFor(toplevel);
    return (appIdFor(toplevel) + " " + String(ipc.class || "") + " "
        + String(ipc.initialClass || "") + " " + String((toplevel && toplevel.title) || "")).toLowerCase();
}

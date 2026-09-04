import QtQuick
import QtTest
import "../WindowModel.js" as WindowModel

TestCase {
    id: testCase
    name: "NativeWindowModel"

    Component {
        id: toplevelComponent

        QtObject {
            property string address: "abc123"
            property string title: "Window title"
            property var lastIpcObject: ({
                mapped: true,
                class: "native.class",
                initialClass: "native.initial",
                at: [0, 0],
                size: [1600, 1000],
                pinned: false
            })
            property var workspace: ({id: 2, name: "2"})
            property var monitor: ({id: 0, name: "DP-1", x: 0, y: 0, width: 3200, height: 1800, scale: 2})
            property var wayland: ({appId: "wayland.app"})
        }
    }

    function createToplevel(properties) {
        var toplevel = toplevelComponent.createObject(testCase, properties || {});
        verify(toplevel !== null);
        return toplevel;
    }

    function test_usesStableNativeAddress() {
        var toplevel = createToplevel();
        compare(WindowModel.addressFor(toplevel), "0xabc123");
        toplevel.address = "not-an-address";
        compare(WindowModel.addressFor(toplevel), "");
        toplevel.destroy();
    }

    function test_prefersWaylandAppIdWithNativeFallback() {
        var toplevel = createToplevel();
        compare(WindowModel.appIdFor(toplevel), "wayland.app");
        toplevel.wayland.appId = "";
        compare(WindowModel.appIdFor(toplevel), "native.class");
        toplevel.lastIpcObject = ({initialClass: "native.initial"});
        compare(WindowModel.appIdFor(toplevel), "native.initial");
        toplevel.destroy();
    }

    function test_excludesUnmappedOrUncapturableWindows() {
        var toplevel = createToplevel();
        verify(WindowModel.isEligible(toplevel));
        toplevel.lastIpcObject = ({mapped: false});
        verify(!WindowModel.isEligible(toplevel));
        toplevel.lastIpcObject = ({mapped: true});
        toplevel.wayland = null;
        verify(!WindowModel.isEligible(toplevel));
        toplevel.destroy();
    }

    function test_matchesWorkspaceIdentityAndPinnedWindows() {
        var toplevel = createToplevel();
        verify(WindowModel.isOnWorkspace(toplevel, {id: 2, name: "2"}));
        verify(!WindowModel.isOnWorkspace(toplevel, {id: 3, name: "3"}));
        toplevel.lastIpcObject = ({pinned: true});
        verify(WindowModel.isOnWorkspace(toplevel, {id: 3, name: "3"}));
        toplevel.destroy();
    }

    function test_matchesScreenOnlyInPerMonitorMode() {
        var toplevel = createToplevel();
        verify(WindowModel.isOnScreen(toplevel, "DP-1", true));
        verify(!WindowModel.isOnScreen(toplevel, "HDMI-A-1", true));
        verify(WindowModel.isOnScreen(toplevel, "HDMI-A-1", false));
        toplevel.monitor = null;
        verify(!WindowModel.isOnScreen(toplevel, "DP-1", true));
        verify(WindowModel.isOnScreen(toplevel, "DP-1", false));
        toplevel.destroy();
    }

    function test_readsAndClampsNativeAspectRatio() {
        var toplevel = createToplevel();
        compare(WindowModel.aspectRatioFor(toplevel), 1.6);
        toplevel.lastIpcObject = ({size: [10000, 100]});
        compare(WindowModel.aspectRatioFor(toplevel), 4);
        toplevel.lastIpcObject = ({size: [100, 10000]});
        compare(WindowModel.aspectRatioFor(toplevel), 0.45);
        toplevel.lastIpcObject = ({size: [0, 0]});
        compare(WindowModel.aspectRatioFor(toplevel), 1.6);
        toplevel.lastIpcObject = ({size: [NaN, 100]});
        compare(WindowModel.aspectRatioFor(toplevel), 1.6);
        toplevel.lastIpcObject = ({size: [100, Infinity]});
        compare(WindowModel.aspectRatioFor(toplevel), 1.6);
        toplevel.destroy();
    }

    function test_detectsWindowsOutsideTheVisibleScrollingViewport() {
        var toplevel = createToplevel();
        verify(!WindowModel.needsPreviewWarmup(toplevel));
        toplevel.lastIpcObject = ({at: [-1700, 0], size: [1600, 1000]});
        verify(WindowModel.needsPreviewWarmup(toplevel));
        toplevel.lastIpcObject = ({at: [-100, 0], size: [1600, 1000]});
        verify(!WindowModel.needsPreviewWarmup(toplevel));
        toplevel.destroy();
    }

    function test_buildsUniformCenteredRows() {
        var grid = WindowModel.uniformGrid(5, 1000, 600, 20);
        compare(grid.length, 5);
        for (var index = 1; index < grid.length; index++) {
            compare(grid[index].width, grid[0].width);
            compare(grid[index].height, grid[0].height);
        }
        compare(grid[3].y, grid[4].y);
        verify(grid[3].x > grid[0].x);
        verify(grid[4].x > grid[3].x);
    }

    function test_searchesAllNativeIdentityFields() {
        var toplevel = createToplevel();
        verify(WindowModel.searchTextFor(toplevel).includes("wayland.app"));
        verify(WindowModel.searchTextFor(toplevel).includes("native.class"));
        verify(WindowModel.searchTextFor(toplevel).includes("native.initial"));
        verify(WindowModel.searchTextFor(toplevel).includes("window title"));
        toplevel.destroy();
    }
}

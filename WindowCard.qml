import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Wayland
import "WindowModel.js" as WindowModel
import qs.Commons

Rectangle {
    id: card

    required property var modelData
    required property var controller
    required property var screenToplevels
    required property bool acceptsKeyboard
    required property var windowLayout
    required property real layoutAreaWidth
    required property real layoutAreaHeight
    // Position in the filtered list; -1 hides the card.
    readonly property int slot: card.screenToplevels.indexOf(modelData)
    readonly property bool inLayout: slot >= 0
    property bool hovered: false
    readonly property bool selected: card.acceptsKeyboard && inLayout && slot === card.controller.selectedIndex
    readonly property bool focusedWindow: !card.controller.previewWarmupActive
        && modelData === Hyprland.activeToplevel
    readonly property bool previewed: card.acceptsKeyboard && inLayout && slot === card.controller.previewIndex
    readonly property bool exitingPreview: card.acceptsKeyboard && inLayout && slot === card.controller.previewExitIndex
    readonly property bool floatingFooter: card.controller.windowFooterStyle === "floating"
    readonly property bool integratedFooter: card.controller.windowFooterStyle === "integrated"
    readonly property bool overlayFooter: card.controller.windowFooterStyle === "overlay"
    readonly property bool centeredFooter: card.controller.windowFooterStyle === "centered"
    readonly property string windowTitle: String(modelData.title || WindowModel.appIdFor(modelData) || "Untitled window")
    readonly property string applicationName: WindowModel.appIdFor(modelData) || "Application"
    readonly property string workspaceName: card.controller.workspaceName(modelData)
    readonly property string iconSource: card.controller.iconFor(modelData)
    property var cachedPreview: null
    // Match Omarchy's panel borders, while keeping every card outline to one
    // physical pixel as requested.
    readonly property var outlineSpec: focusedWindow || selected
        ? Border.withWidth(Border.hyprlandActiveSpec(Color.accent, 1), 1)
        : (hovered
            ? Border.withWidth(Border.controlSpec("hover-cursor", Color.menu.text, Color.accent), 1)
            : Border.withWidth(Border.surfaceSpec("menu", "border", Color.menu.border, 1), 1))
    // An excluded card keeps its last rectangle, so it neither
    // animates toward the origin nor flies back in from it.
    readonly property var packedRectSource: inLayout ? card.windowLayout[slot] : null
    property var packedRect: Qt.rect(0, 0, 1, 1)
    readonly property var previewRect: card.controller.previewRectFor(modelData, packedRect, card.layoutAreaWidth, card.layoutAreaHeight, Style.spacing.sm, card.controller.windowFooterHeight)
    readonly property var layoutRect: previewed ? previewRect : packedRect

    onPackedRectSourceChanged: {
        if (packedRectSource)
            packedRect = packedRectSource;

    }
    Component.onCompleted: {
        if (packedRectSource)
            packedRect = packedRectSource;

    }
    function cacheLivePreview() {
        if (!livePreview.hasContent)
            return;
        livePreview.grabToImage(function(result) {
            if (result)
                card.cachedPreview = result;
        });
    }
    visible: inLayout
    x: layoutRect.x
    y: layoutRect.y
    width: layoutRect.width
    height: layoutRect.height
    z: previewed ? 11 : (exitingPreview ? 10 : 0)
    radius: integratedFooter ? Style.cornerRadius : 0
    color: integratedFooter ? Color.menu.background : "transparent"
    border.color: integratedFooter ? Border.color(outlineSpec) : "transparent"
    border.width: integratedFooter ? 1 : 0
    opacity: card.controller.previewIndex < 0 || previewed ? 1 : 0.28

    MouseArea {
        anchors.fill: parent
        enabled: !card.controller.settingsOpen && (card.controller.previewIndex < 0 || card.previewed)
        hoverEnabled: true
        onEnabledChanged: {
            if (!enabled) {
                card.hovered = false;
                if (card.controller.hoveredIndex === card.slot)
                    card.controller.hoveredIndex = -1;

            }
        }
        onEntered: {
            card.hovered = true;
            if (card.acceptsKeyboard) {
                card.controller.hoveredIndex = card.slot;
                card.controller.selectedIndex = card.slot;
            }
        }
        onExited: {
            card.hovered = false;
            if (card.acceptsKeyboard && card.controller.hoveredIndex === card.slot)
                card.controller.hoveredIndex = -1;

        }
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton)
                card.controller.requestClose(card.modelData);
            else
                card.controller.activate(card.modelData);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.spacing.sm
        spacing: card.overlayFooter ? 0 : Style.spacing.sm

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: previewFrame

                readonly property real windowAspectRatio: card.controller.aspectRatioFor(card.modelData)

                anchors.fill: parent
                radius: Math.max(0, Style.cornerRadius - Style.spacing.xs)
                color: Color.background
                clip: true
                layer.enabled: true

                CardText {
                    anchors.centerIn: parent
                    visible: !livePreview.hasContent && !card.cachedPreview
                    text: "Live preview unavailable"
                    opacity: 0.45
                }

                Item {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height * previewFrame.windowAspectRatio)
                    height: Math.min(parent.height, parent.width / previewFrame.windowAspectRatio)
                    layer.enabled: true
                    layer.smooth: true

                    Image {
                        anchors.fill: parent
                        visible: !livePreview.hasContent && card.cachedPreview !== null
                        source: card.cachedPreview ? card.cachedPreview.url : ""
                        fillMode: Image.Stretch
                        smooth: true
                        cache: false
                    }

                    ScreencopyView {
                        id: livePreview
                        anchors.fill: parent
                        captureSource: card.modelData ? card.modelData.wayland : null
                        live: (card.controller.opened || card.controller.openingPending) && card.inLayout
                        paintCursor: false
                        onHasContentChanged: {
                            if (hasContent)
                                Qt.callLater(card.cacheLivePreview);
                        }
                    }

                }

                Loader {
                    anchors.fill: parent
                    z: 2
                    active: card.overlayFooter
                    sourceComponent: overlayFooter
                }

                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: previewMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

            }

            Rectangle {
                anchors.fill: previewFrame
                visible: !card.integratedFooter
                z: 5
                radius: previewFrame.radius
                color: "transparent"
                border.color: Border.color(card.outlineSpec)
                border.width: 1
            }

            Rectangle {
                id: previewMask

                anchors.fill: previewFrame
                radius: previewFrame.radius
                color: "black"
                visible: false
                layer.enabled: true
                layer.smooth: true
            }

        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(32)
            visible: !card.overlayFooter

            Loader {
                anchors.fill: parent
                sourceComponent: card.floatingFooter ? floatingFooter : (card.integratedFooter ? integratedFooter : (card.centeredFooter ? centeredFooter : null))
            }

        }

    }

    // Shared footer building blocks; each footer style overrides only what differs.
    component CardText: Text {
        textFormat: Text.PlainText
        color: Color.menu.text
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
    }

    component FooterTitle: CardText {
        text: card.windowTitle
        font.bold: card.selected || card.focusedWindow
        elide: Text.ElideRight
    }

    component FooterIcon: Image {
        property int iconSize: 18
        Layout.preferredWidth: Style.space(iconSize)
        Layout.preferredHeight: Style.space(iconSize)
        source: card.iconSource
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    component ApplicationLabel: CardText {
        text: "· " + card.applicationName
        opacity: 0.48
        elide: Text.ElideRight
    }

    component WorkspaceLabel: CardText {
        text: "[" + card.workspaceName + "]"
        color: card.focusedWindow ? Color.accent : Color.menu.text
        opacity: card.focusedWindow ? 1 : 0.56
        font.pixelSize: Style.font.caption
        font.bold: card.focusedWindow
    }

    // Only the configured footer style is instantiated per card.
    Component {
        id: overlayFooter

        Item {
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.min(parent.height, Style.space(32))
                color: Color.menu.background

                Rectangle {
                    anchors.fill: parent
                    visible: card.selected
                    color: Color.menu.selectedBackground
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: Style.spacing.hairline
                    color: Util.alpha(Color.menu.text, 0.22)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.spacing.lg
                    anchors.rightMargin: Style.spacing.lg
                    spacing: Style.spacing.md

                    FooterIcon {}

                    FooterTitle { Layout.fillWidth: true }

                    ApplicationLabel {
                        Layout.maximumWidth: parent.width * 0.32
                    }

                    WorkspaceLabel {}
                }
            }
        }
    }

    Component {
        id: floatingFooter

        RowLayout {
            spacing: Style.spacing.md

            FooterIcon {}
            FooterTitle { Layout.fillWidth: true }
            ApplicationLabel { Layout.maximumWidth: parent.width * 0.3 }
            WorkspaceLabel {}
        }
    }

    Component {
        id: integratedFooter

        RowLayout {
            spacing: Style.spacing.md

            FooterIcon {}

            FooterTitle { Layout.fillWidth: true }

            WorkspaceLabel {}
        }
    }

    Component {
        id: centeredFooter

        RowLayout {
            spacing: Style.spacing.md

            Item { Layout.fillWidth: true }
            FooterIcon {}
            FooterTitle { Layout.maximumWidth: Math.max(1, card.width * 0.54) }
            WorkspaceLabel {}
            Item { Layout.fillWidth: true }
        }
    }

    Behavior on x {
        enabled: card.controller.motionSettled

        NumberAnimation {
            duration: card.controller.previewAnimationDuration
            easing.type: card.controller.previewAnimationEasing
        }

    }

    Behavior on y {
        enabled: card.controller.motionSettled

        NumberAnimation {
            duration: card.controller.previewAnimationDuration
            easing.type: card.controller.previewAnimationEasing
        }

    }

    Behavior on width {
        enabled: card.controller.motionSettled

        NumberAnimation {
            duration: card.controller.previewAnimationDuration
            easing.type: card.controller.previewAnimationEasing
        }

    }

    Behavior on height {
        enabled: card.controller.motionSettled

        NumberAnimation {
            duration: card.controller.previewAnimationDuration
            easing.type: card.controller.previewAnimationEasing
        }

    }

    Behavior on opacity {
        enabled: card.controller.motionSettled

        NumberAnimation {
            duration: card.controller.previewFadeDuration
        }

    }

}

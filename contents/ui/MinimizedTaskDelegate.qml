import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

Item {
    id: minTaskItem

    required property var model
    required property int index
    required property var tasksModel
    property Item plasmoidRoot: null
    property bool vertical: false
    property QtObject contextMenu: null

    readonly property Item appletRoot: plasmoidRoot || (typeof root !== "undefined" ? root : null)
    readonly property var targetModelIndex: tasksModel ? tasksModel.makeModelIndex(index) : null
    readonly property bool isGroup: model.IsGroupParent ?? false
    readonly property int groupCount: Math.max(model.ChildCount ?? 1, 1)
    readonly property bool groupByApplication: Plasmoid?.configuration?.groupMinimizedByApplication ?? false

    // Compact square icon-only button sizing
    implicitWidth: vertical ? parent.width : parent.height
    implicitHeight: vertical ? parent.width : parent.height

    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical

    function publishGeometry(): void {
        if (!tasksModel || index < 0 || !visible) {
            return;
        }
        const pt = mapToGlobal(0, 0);
        const rect = Qt.rect(pt.x, pt.y, width, height);
        if (targetModelIndex && typeof tasksModel.requestPublishDelegateGeometry === "function") {
            tasksModel.requestPublishDelegateGeometry(targetModelIndex, rect, minTaskItem);
        }
    }

    onXChanged: publishGeometry()
    onYChanged: publishGeometry()
    onWidthChanged: publishGeometry()
    onHeightChanged: publishGeometry()
    Component.onCompleted: publishGeometry()

    function showContextMenu(): void {
        if (contextMenu) {
            contextMenu.destroy();
            contextMenu = null;
        }
        const rootItem = minTaskItem.appletRoot;
        if (!rootItem) {
            return;
        }
        contextMenu = rootItem.createContextMenu(minTaskItem, minTaskItem.targetModelIndex, minTaskItem.tasksModel);
        if (contextMenu) {
            contextMenu.show();
        }
    }

    function bringAllToForegroundAndCycle(): void {
        if (!tasksModel || !targetModelIndex) {
            return;
        }
        const count = tasksModel.rowCount(targetModelIndex);
        if (count <= 0) {
            tasksModel.requestToggleMinimized(targetModelIndex);
            tasksModel.requestActivate(targetModelIndex);
            return;
        }

        let activeChildIndex = -1;
        for (let i = 0; i < count; ++i) {
            const childIdx = tasksModel.makeModelIndex(index, i);
            if (tasksModel.data(childIdx, TaskManager.AbstractTasksModel.IsActive)) {
                activeChildIndex = i;
                break;
            }
        }

        if (activeChildIndex !== -1) {
            const nextIndex = (activeChildIndex + 1) % count;
            const targetChild = tasksModel.makeModelIndex(index, nextIndex);
            tasksModel.requestToggleMinimized(targetChild);
            tasksModel.requestActivate(targetChild);
        } else {
            for (let i = count - 1; i >= 0; --i) {
                const childIdx = tasksModel.makeModelIndex(index, i);
                tasksModel.requestToggleMinimized(childIdx);
                tasksModel.requestActivate(childIdx);
            }
        }
    }

    function activateGroup(): void {
        const count = tasksModel.rowCount(targetModelIndex);
        const strategy = Plasmoid?.configuration?.openGroupingStrategy ?? 1;
        if (strategy === 1) {
            appletRoot?.groupDialog?.openForTask(minTaskItem);
        } else if (strategy === 2) {
            const winIds = model.WinIdList;
            if (appletRoot?.effectWatcherRegistered && winIds && winIds.length > 0) {
                appletRoot.activatePresentWindows(winIds);
            } else {
                appletRoot?.groupDialog?.openForTask(minTaskItem);
            }
        } else if (strategy === 3) {
            if (count > 0) {
                bringAllToForegroundAndCycle();
            } else {
                tasksModel.requestToggleMinimized(targetModelIndex);
                tasksModel.requestActivate(targetModelIndex);
            }
        } else if (count > 0) {
            const firstChild = tasksModel.makeModelIndex(index, 0);
            tasksModel.requestToggleMinimized(firstChild);
            tasksModel.requestActivate(firstChild);
        } else {
            tasksModel.requestToggleMinimized(targetModelIndex);
            tasksModel.requestActivate(targetModelIndex);
        }
    }

    // Breeze SVG background frame
    KSvg.FrameSvgItem {
        id: frame
        anchors.fill: parent
        imagePath: "widgets/tasks"
        prefix: {
            if (minTaskItem.model.IsDemandingAttention) {
                return "attention";
            }
            if (mouseArea.containsMouse) {
                return "hover";
            }
            return "minimized";
        }
    }

    // Minimized icon
    Kirigami.Icon {
        id: taskIcon
        anchors.centerIn: parent
        width: Math.min(parent.width - Kirigami.Units.smallSpacing * 2, Kirigami.Units.iconSizes.medium)
        height: width
        source: minTaskItem.model.decoration
        active: mouseArea.containsMouse
        opacity: (mouseArea.containsMouse || !(Plasmoid?.configuration?.dimMinimizedIcons ?? true)) ? 1.0 : 0.8

        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    Rectangle {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 2
            rightMargin: 2
        }
        width: Math.max(groupBadgeLabel.implicitWidth + 6, 14)
        height: 14
        radius: 7
        color: Kirigami.Theme.highlightColor
        visible: minTaskItem.groupByApplication

        PlasmaComponents3.Label {
            id: groupBadgeLabel
            anchors.centerIn: parent
            text: minTaskItem.groupCount.toString()
            font.pixelSize: Kirigami.Units.gridUnit * 0.65
            font.weight: Font.Bold
            color: Kirigami.Theme.highlightedTextColor
        }
    }

    // Subtle minimized dot/bar indicator
    Rectangle {
        id: minimizedDot
        anchors {
            bottom: parent.bottom
            bottomMargin: 3
            horizontalCenter: parent.horizontalCenter
        }
        width: Math.max(4, Kirigami.Units.gridUnit * 0.6)
        height: 2
        radius: 1
        color: Kirigami.Theme.highlightColor
        opacity: mouseArea.containsMouse ? 1.0 : 0.6
        visible: !vertical
    }

    // Minimized indicator for vertical panels
    Rectangle {
        id: minimizedDotVertical
        anchors {
            right: parent.right
            rightMargin: 3
            verticalCenter: parent.verticalCenter
        }
        width: 2
        height: Math.max(4, Kirigami.Units.gridUnit * 0.6)
        radius: 1
        color: Kirigami.Theme.highlightColor
        opacity: mouseArea.containsMouse ? 1.0 : 0.6
        visible: vertical
    }

    // Tooltip Area - critical for icon-only representation
    PlasmaCore.ToolTipArea {
        id: toolTipArea
        anchors.fill: parent
        active: (Plasmoid?.configuration?.showToolTips ?? true)
            && (!contextMenu || contextMenu.status !== PlasmaExtras.Menu.Open)
        mainText: minTaskItem.model.AppName || minTaskItem.model.display || ""
        subText: minTaskItem.groupByApplication
            ? i18n("%1 minimized windows", minTaskItem.groupCount)
            : ((minTaskItem.model.AppName && minTaskItem.model.AppName !== minTaskItem.model.display) ? minTaskItem.model.display : "")
        icon: minTaskItem.model.decoration
    }

    // Mouse interactions
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                if (minTaskItem.groupByApplication) {
                    minTaskItem.activateGroup();
                } else {
                    minTaskItem.tasksModel.requestToggleMinimized(minTaskItem.targetModelIndex);
                    minTaskItem.tasksModel.requestActivate(minTaskItem.targetModelIndex);
                }
            } else if (mouse.button === Qt.MiddleButton) {
                const action = Plasmoid?.configuration?.middleClickAction ?? 0;
                if (action === 0) {
                    minTaskItem.tasksModel.requestClose(minTaskItem.targetModelIndex);
                } else if (action === 1) {
                    minTaskItem.tasksModel.requestToggleMinimized(minTaskItem.targetModelIndex);
                } else if (action === 2) {
                    minTaskItem.tasksModel.requestNewInstance(minTaskItem.targetModelIndex);
                }
            } else if (mouse.button === Qt.RightButton) {
                minTaskItem.showContextMenu();
            }
        }
    }

    Keys.onMenuPressed: event => {
        minTaskItem.showContextMenu();
        event.accepted = true;
    }
}

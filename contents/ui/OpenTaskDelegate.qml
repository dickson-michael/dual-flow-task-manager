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
    id: openTaskItem

    required property var model
    required property int index
    required property var tasksModel
    property Item plasmoidRoot: null
    property bool vertical: false
    property QtObject contextMenu: null

    readonly property Item appletRoot: plasmoidRoot || (typeof root !== "undefined" ? root : null)
    readonly property var targetModelIndex: tasksModel ? tasksModel.makeModelIndex(index) : null
    readonly property bool isGroup: model.IsGroupParent ?? false
    readonly property int groupCount: model.ChildCount ?? 1

    // Sizing: fill equal share of the row's width (horizontal), or full width (vertical)
    Layout.fillHeight: !vertical
    Layout.fillWidth: true
    Layout.minimumWidth: vertical ? -1 : (Plasmoid?.configuration?.minTaskWidth ?? 48)
    Layout.maximumWidth: vertical ? -1 : (Plasmoid?.configuration?.maxTaskWidth ?? 220)
    Layout.preferredWidth: vertical ? -1 : (Plasmoid?.configuration?.maxTaskWidth ?? 220)
    Layout.minimumHeight: vertical ? Kirigami.Units.gridUnit * 2 : -1
    Layout.maximumHeight: vertical ? Kirigami.Units.gridUnit * 2.5 : -1
    Layout.preferredHeight: vertical ? Kirigami.Units.gridUnit * 2.2 : -1

    implicitWidth: vertical ? -1 : (Plasmoid?.configuration?.maxTaskWidth ?? 220)
    implicitHeight: vertical ? Layout.preferredHeight : parent?.height ?? Kirigami.Units.gridUnit * 2

    function publishGeometry(): void {
        if (!tasksModel || index < 0 || !visible) {
            return;
        }
        const pt = mapToGlobal(0, 0);
        const rect = Qt.rect(pt.x, pt.y, width, height);
        if (targetModelIndex && typeof tasksModel.requestPublishDelegateGeometry === "function") {
            tasksModel.requestPublishDelegateGeometry(targetModelIndex, rect, openTaskItem);
        }
    }

    onXChanged: publishGeometry()
    onYChanged: publishGeometry()
    onWidthChanged: publishGeometry()
    onHeightChanged: publishGeometry()
    Component.onCompleted: publishGeometry()

    // Bring all windows belonging to this application to the front,
    // or cycle between them if the application is already active.
    function bringAllToForegroundAndCycle(): void {
        if (!tasksModel || !targetModelIndex) {
            return;
        }
        const count = tasksModel.rowCount(targetModelIndex);
        if (count <= 0) {
            tasksModel.requestActivate(targetModelIndex);
            return;
        }

        // Check if any child window is currently active
        let activeChildIndex = -1;
        for (let i = 0; i < count; ++i) {
            const childIdx = tasksModel.makeModelIndex(openTaskItem.index, i);
            if (tasksModel.data(childIdx, TaskManager.AbstractTasksModel.IsActive)) {
                activeChildIndex = i;
                break;
            }
        }

        if (activeChildIndex !== -1) {
            // Already active in the foreground -> cycle focus to next window in group
            const nextIndex = (activeChildIndex + 1) % count;
            const targetChild = tasksModel.makeModelIndex(openTaskItem.index, nextIndex);
            tasksModel.requestActivate(targetChild);
        } else {
            // Background application -> bring ALL windows to front in reverse order,
            // so child 0 ends up frontmost with active focus.
            for (let i = count - 1; i >= 0; --i) {
                const childIdx = tasksModel.makeModelIndex(openTaskItem.index, i);
                tasksModel.requestActivate(childIdx);
            }
        }
    }

    function showContextMenu(): void {
        if (contextMenu) {
            contextMenu.destroy();
            contextMenu = null;
        }
        const rootItem = openTaskItem.appletRoot;
        if (!rootItem) {
            return;
        }
        contextMenu = rootItem.createContextMenu(openTaskItem, openTaskItem.targetModelIndex, openTaskItem.tasksModel, {
            bringAllToFrontCallback: () => openTaskItem.bringAllToForegroundAndCycle()
        });
        if (contextMenu) {
            contextMenu.bringAllToFrontRequested.connect(openTaskItem.bringAllToForegroundAndCycle);
            contextMenu.show();
        }
    }

    // Breeze SVG background frame
    KSvg.FrameSvgItem {
        id: frame
        anchors.fill: parent
        imagePath: "widgets/tasks"
        prefix: {
            if (openTaskItem.model.IsDemandingAttention) {
                return "attention";
            }
            if (openTaskItem.model.IsActive) {
                return mouseArea.containsMouse ? "active-hover" : "active";
            }
            if (mouseArea.containsMouse) {
                return "hover";
            }
            return "normal";
        }
    }

    // Active bottom line accent (for horizontal panels)
    Rectangle {
        id: activeIndicator
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: Kirigami.Units.smallSpacing
            rightMargin: Kirigami.Units.smallSpacing
        }
        height: 2
        radius: 1
        color: Kirigami.Theme.highlightColor
        visible: !vertical && openTaskItem.model.IsActive
    }

    // Active left line accent (for vertical panels)
    Rectangle {
        id: activeIndicatorVertical
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            topMargin: Kirigami.Units.smallSpacing
            bottomMargin: Kirigami.Units.smallSpacing
        }
        width: 2
        radius: 1
        color: Kirigami.Theme.highlightColor
        visible: vertical && openTaskItem.model.IsActive
    }

    // Tooltip Area
    PlasmaCore.ToolTipArea {
        id: toolTipArea
        anchors.fill: parent
        active: (Plasmoid?.configuration?.showToolTips ?? true)
            && (!contextMenu || contextMenu.status !== PlasmaExtras.Menu.Open)
            && !(openTaskItem.appletRoot?.groupDialog?.visible && openTaskItem.appletRoot?.groupDialog?.targetTaskItem === openTaskItem)
        mainText: {
            if (openTaskItem.isGroup) {
                return i18n("%1 (%2 windows)", openTaskItem.model.AppName || openTaskItem.model.display || "", openTaskItem.groupCount);
            }
            return openTaskItem.model.AppName || openTaskItem.model.display || "";
        }
        subText: {
            if (openTaskItem.isGroup) {
                const strategy = Plasmoid?.configuration?.openGroupingStrategy ?? 1;
                if (strategy === 1) return i18n("Click to open window list");
                if (strategy === 2) return i18n("Click for Exposé overview");
                if (strategy === 3) return i18n("Click to bring all windows to front");
            }
            return (openTaskItem.model.AppName && openTaskItem.model.AppName !== openTaskItem.model.display) ? openTaskItem.model.display : "";
        }
        icon: openTaskItem.model.decoration
    }

    // Task content: Icon + Text + Group Badge
    RowLayout {
        anchors {
            fill: parent
            leftMargin: Kirigami.Units.smallSpacing * 1.5
            rightMargin: Kirigami.Units.smallSpacing * 1.5
            topMargin: Kirigami.Units.smallSpacing / 2
            bottomMargin: Kirigami.Units.smallSpacing / 2
        }
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            id: taskIcon
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Math.min(parent.height, Kirigami.Units.iconSizes.medium)
            Layout.preferredHeight: Layout.preferredWidth
            source: openTaskItem.model.decoration
            active: mouseArea.containsMouse || openTaskItem.model.IsActive
        }

        PlasmaComponents3.Label {
            id: taskLabel
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: openTaskItem.model.display || openTaskItem.model.AppName || ""
            elide: Text.ElideRight
            font.weight: openTaskItem.model.IsActive ? Font.DemiBold : Font.Normal
            opacity: openTaskItem.model.IsActive ? 1.0 : 0.9
        }

        // Group Count Pill Badge
        Rectangle {
            id: groupBadge
            visible: openTaskItem.isGroup && openTaskItem.groupCount > 1
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Math.max(badgeLabel.implicitWidth + 8, 18)
            Layout.preferredHeight: 18
            radius: 9
            color: openTaskItem.model.IsActive ? Kirigami.Theme.highlightColor : Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: openTaskItem.model.IsActive ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
            opacity: 0.95

            PlasmaComponents3.Label {
                id: badgeLabel
                anchors.centerIn: parent
                text: openTaskItem.groupCount.toString()
                font.pixelSize: Kirigami.Units.gridUnit * 0.7
                font.weight: Font.Bold
                color: openTaskItem.model.IsActive ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
            }
        }

        // Small indicator icon showing it can be expanded (Strategy 1)
        Kirigami.Icon {
            id: groupExpandIcon
            visible: openTaskItem.isGroup && (Plasmoid?.configuration?.openGroupingStrategy ?? 1) === 1
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 10
            Layout.preferredHeight: 10
            source: vertical ? "arrow-right" : "arrow-up"
            opacity: 0.6
        }

        // Small Exposé icon (Strategy 2)
        Kirigami.Icon {
            id: groupExposeIcon
            visible: openTaskItem.isGroup && (Plasmoid?.configuration?.openGroupingStrategy ?? 1) === 2
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 12
            Layout.preferredHeight: 12
            source: "view-grid"
            opacity: 0.6
        }
    }

    // Mouse interactions
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                if (openTaskItem.isGroup) {
                    const strategy = Plasmoid?.configuration?.openGroupingStrategy ?? 1;

                    if (strategy === 1) {
                        // Compact window list popup
                        const dlg = openTaskItem.appletRoot?.groupDialog;
                        if (dlg) {
                            if (dlg.visible && dlg.targetTaskItem === openTaskItem) {
                                dlg.visible = false;
                            } else {
                                dlg.openForTask(openTaskItem);
                            }
                        }
                    } else if (strategy === 2) {
                        // Present Windows / Exposé effect
                        const winIds = openTaskItem.model.WinIdList;
                        const rootItem = openTaskItem.appletRoot;
                        if (rootItem?.effectWatcherRegistered && winIds && winIds.length > 0) {
                            rootItem.activatePresentWindows(winIds);
                        } else if (rootItem?.groupDialog) {
                            // Fallback to compact window list if effect unavailable
                            rootItem.groupDialog.openForTask(openTaskItem);
                        }
                    } else if (strategy === 3) {
                        // Grouped with application-to-foreground on click
                        openTaskItem.bringAllToForegroundAndCycle();
                    } else {
                        // Fallback (e.g. if single task or no grouping)
                        openTaskItem.tasksModel.requestActivate(openTaskItem.targetModelIndex);
                    }
                } else {
                    // Non-grouped individual window
                    if (openTaskItem.model.IsActive && (Plasmoid?.configuration?.minimizeActiveTaskOnClick ?? true)) {
                        openTaskItem.tasksModel.requestToggleMinimized(openTaskItem.targetModelIndex);
                    } else {
                        openTaskItem.tasksModel.requestActivate(openTaskItem.targetModelIndex);
                    }
                }
            } else if (mouse.button === Qt.MiddleButton) {
                const action = Plasmoid?.configuration?.middleClickAction ?? 0;
                if (action === 0) {
                    openTaskItem.tasksModel.requestClose(openTaskItem.targetModelIndex);
                } else if (action === 1) {
                    openTaskItem.tasksModel.requestToggleMinimized(openTaskItem.targetModelIndex);
                } else if (action === 2) {
                    openTaskItem.tasksModel.requestNewInstance(openTaskItem.targetModelIndex);
                }
            } else if (mouse.button === Qt.RightButton) {
                openTaskItem.showContextMenu();
            }
        }
    }

    Keys.onMenuPressed: event => {
        openTaskItem.showContextMenu();
        event.accepted = true;
    }
}

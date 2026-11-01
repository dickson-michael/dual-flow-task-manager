import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

PlasmaCore.PopupPlasmaWindow {
    id: groupDialog

    property var tasksModel: null
    property Item targetTaskItem: null
    property Item plasmoidRoot: null

    readonly property int effectiveLocation: plasmoidRoot?.Plasmoid?.location ?? Plasmoid?.location ?? PlasmaCore.Types.BottomEdge

    popupDirection: {
        switch (effectiveLocation) {
        case PlasmaCore.Types.TopEdge:
            return Qt.BottomEdge;
        case PlasmaCore.Types.LeftEdge:
            return Qt.RightEdge;
        case PlasmaCore.Types.RightEdge:
            return Qt.LeftEdge;
        default:
            return Qt.TopEdge;
        }
    }

    animated: true

    removeBorderStrategy: (effectiveLocation === PlasmaCore.Types.Floating)
        ? PlasmaCore.PopupPlasmaWindow.AtScreenEdges
        : (PlasmaCore.PopupPlasmaWindow.AtScreenEdges | PlasmaCore.PopupPlasmaWindow.AtPanelEdges)

    margin: {
        const hints = plasmoidRoot?.Plasmoid?.containmentDisplayHints ?? Plasmoid?.containmentDisplayHints ?? 0;
        return (hints & PlasmaCore.Types.ContainmentPrefersFloatingApplets) ? Kirigami.Units.largeSpacing : 0;
    }

    width: mainColumn.implicitWidth + leftPadding + rightPadding
    height: mainColumn.implicitHeight + topPadding + bottomPadding

    Timer {
        id: closeOnTimer
        interval: 100
        onTriggered: {
            if (!active) {
                groupDialog.visible = false;
            }
        }
    }

    onActiveChanged: {
        if (!active) {
            closeOnTimer.restart();
        }
    }

    onVisibleChanged: {
        if (!visible) {
            targetTaskItem = null;
        }
    }

    function openForTask(taskItem): void {
        if (!taskItem || !taskItem.tasksModel || !taskItem.targetModelIndex) {
            return;
        }

        targetTaskItem = taskItem;
        tasksModel = taskItem.tasksModel;
        visualParent = taskItem;

        windowsListModel.clear();
        const childCount = tasksModel.rowCount(taskItem.targetModelIndex);
        const count = childCount > 0 ? childCount : 1;

        for (let i = 0; i < count; ++i) {
            const childIdx = childCount > 0 ? tasksModel.makeModelIndex(taskItem.index, i) : taskItem.targetModelIndex;
            const title = tasksModel.data(childIdx, Qt.DisplayRole) || taskItem.model.AppName || (i18n("Window %1", i + 1));
            const iconData = tasksModel.data(childIdx, Qt.DecorationRole);
            const isActive = tasksModel.data(childIdx, TaskManager.AbstractTasksModel.IsActive) ?? false;

            windowsListModel.append({
                childRow: childCount > 0 ? i : -1,
                title: String(title),
                iconData: iconData || taskItem.model.decoration,
                isActive: Boolean(isActive)
            });
        }

        visible = true;
        requestActivate();
        windowListView.forceActiveFocus();
    }

    function activateChild(childRow: int): void {
        if (!targetTaskItem || !tasksModel) {
            return;
        }
        const childIdx = childRow < 0 ? targetTaskItem.targetModelIndex : tasksModel.makeModelIndex(targetTaskItem.index, childRow);
        if (tasksModel.data(childIdx, TaskManager.AbstractTasksModel.IsMinimized)) {
            tasksModel.requestToggleMinimized(childIdx);
        }
        tasksModel.requestActivate(childIdx);
        groupDialog.visible = false;
    }

    function closeChild(childRow: int): void {
        if (!targetTaskItem || !tasksModel) {
            return;
        }
        const childIdx = childRow < 0 ? targetTaskItem.targetModelIndex : tasksModel.makeModelIndex(targetTaskItem.index, childRow);
        tasksModel.requestClose(childIdx);

        if (windowsListModel.count <= 2) {
            groupDialog.visible = false;
        } else {
            for (let i = 0; i < windowsListModel.count; ++i) {
                if (windowsListModel.get(i).childRow === childRow) {
                    windowsListModel.remove(i);
                    break;
                }
            }
        }
    }

    function bringAllToFront(): void {
        if (targetTaskItem && targetTaskItem.bringAllToForegroundAndCycle) {
            targetTaskItem.bringAllToForegroundAndCycle();
        }
        groupDialog.visible = false;
    }

    function closeAll(): void {
        if (targetTaskItem && tasksModel) {
            tasksModel.requestClose(targetTaskItem.targetModelIndex);
        }
        groupDialog.visible = false;
    }

    mainItem: ColumnLayout {
        id: mainColumn
        spacing: Kirigami.Units.smallSpacing
        implicitWidth: Screen?.width ? Math.max(300, Math.min(Screen.width / 3, 380)) : 320

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: targetTaskItem?.model?.decoration || "preferences-system-windows"
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Layout.preferredWidth
            }

            PlasmaComponents3.Label {
                text: targetTaskItem?.model?.AppName || targetTaskItem?.model?.display || i18n("Application")
                font.weight: Font.Bold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Window count badge
            Rectangle {
                Layout.preferredWidth: Math.max(badgeText.implicitWidth + 8, 18)
                Layout.preferredHeight: 18
                radius: 9
                color: Kirigami.Theme.highlightColor
                opacity: 0.9

                PlasmaComponents3.Label {
                    id: badgeText
                    anchors.centerIn: parent
                    text: windowsListModel.count.toString()
                    font.pixelSize: Kirigami.Units.gridUnit * 0.7
                    font.weight: Font.Bold
                    color: Kirigami.Theme.highlightedTextColor
                }
            }
        }

        PlasmaComponents3.MenuSeparator {
            Layout.fillWidth: true
        }

        // Compact Window List
        ListView {
            id: windowListView
            Layout.fillWidth: true
            implicitHeight: Math.min((Screen?.height ? Screen.height / 2 : 400), Math.max(Kirigami.Units.gridUnit * 2.2, contentHeight > 0 ? contentHeight : (windowsListModel.count * Kirigami.Units.gridUnit * 2.2)))
            Layout.preferredHeight: implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {}

            Keys.onEscapePressed: event => {
                groupDialog.visible = false;
                event.accepted = true;
            }
            Keys.onUpPressed: event => {
                if (currentIndex > 0) {
                    currentIndex--;
                }
                event.accepted = true;
            }
            Keys.onDownPressed: event => {
                if (currentIndex < count - 1) {
                    currentIndex++;
                }
                event.accepted = true;
            }
            Keys.onReturnPressed: event => {
                if (currentIndex >= 0 && currentIndex < count) {
                    const item = windowsListModel.get(currentIndex);
                    if (item) {
                        groupDialog.activateChild(item.childRow);
                    }
                }
                event.accepted = true;
            }

            model: ListModel {
                id: windowsListModel
            }

            delegate: Item {
                id: delegateItem
                width: windowListView.width
                height: Kirigami.Units.gridUnit * 2.2

                readonly property bool itemHovered: itemMouseArea.containsMouse
                readonly property bool itemActive: model.isActive

                KSvg.FrameSvgItem {
                    id: itemFrame
                    anchors.fill: parent
                    imagePath: "widgets/tasks"
                    prefix: {
                        if (delegateItem.itemActive) {
                            return delegateItem.itemHovered ? "active-hover" : "active";
                        }
                        return delegateItem.itemHovered ? "hover" : "normal";
                    }
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Kirigami.Units.smallSpacing
                        rightMargin: Kirigami.Units.smallSpacing
                    }
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: model.iconData || targetTaskItem?.model?.decoration
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Layout.preferredWidth
                        active: delegateItem.itemHovered || delegateItem.itemActive
                    }

                    PlasmaComponents3.Label {
                        text: model.title
                        elide: Text.ElideRight
                        font.weight: delegateItem.itemActive ? Font.DemiBold : Font.Normal
                        Layout.fillWidth: true
                    }

                    PlasmaComponents3.ToolButton {
                        icon.name: "window-close"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Layout.preferredWidth
                        onClicked: {
                            groupDialog.closeChild(model.childRow);
                        }
                    }
                }

                MouseArea {
                    id: itemMouseArea
                    anchors {
                        fill: parent
                        rightMargin: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing
                    }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            groupDialog.activateChild(model.childRow);
                        } else if (mouse.button === Qt.RightButton) {
                            if (targetTaskItem && tasksModel && plasmoidRoot) {
                                const childIdx = model.childRow < 0
                                    ? targetTaskItem.targetModelIndex
                                    : tasksModel.makeModelIndex(targetTaskItem.index, model.childRow);
                                const ctxMenu = plasmoidRoot.createContextMenu(delegateItem, childIdx, tasksModel);
                                if (ctxMenu) {
                                    ctxMenu.show();
                                }
                            }
                        }
                    }
                }
            }
        }

        PlasmaComponents3.MenuSeparator {
            Layout.fillWidth: true
        }

        // Quick group actions at bottom
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Button {
                text: i18n("Bring All to Front")
                icon.name: "window-duplicate"
                Layout.fillWidth: true
                onClicked: groupDialog.bringAllToFront()
            }

            PlasmaComponents3.Button {
                text: i18n("Close All")
                icon.name: "window-close"
                onClicked: groupDialog.closeAll()
            }
        }
    }
}

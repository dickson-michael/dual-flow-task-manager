import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool hasTasks: openTasksModel.count > 0 || minimizedTasksModel.count > 0

    Plasmoid.constraintHints: Plasmoid.CanFillArea

    Layout.fillWidth: true
    Layout.fillHeight: true

    Layout.minimumWidth: {
        if (!hasTasks) {
            return Kirigami.Units.gridUnit;
        }
        return vertical ? Kirigami.Units.gridUnit : Kirigami.Units.gridUnit * 2;
    }

    Layout.minimumHeight: {
        if (!hasTasks) {
            return Kirigami.Units.gridUnit;
        }
        return vertical ? Kirigami.Units.gridUnit * 2 : Kirigami.Units.gridUnit;
    }

    Layout.preferredWidth: {
        if (!hasTasks) {
            return 0.01;
        }
        return -1;
    }

    Layout.preferredHeight: {
        if (!hasTasks) {
            return 0.01;
        }
        return -1;
    }

    // KWin Present Windows (WindowView1) DBus Service Watcher
    DBus.DBusServiceWatcher {
        id: effectWatcher
        busType: DBus.BusType.Session
        watchedService: "org.kde.KWin.Effect.WindowView1"
    }
    readonly property bool effectWatcherRegistered: effectWatcher.registered

    // Trigger KWin's Present Windows (Exposé) effect for a list of window IDs
    function activatePresentWindows(winIds: var): void {
        if (!winIds || winIds.length === 0) {
            return;
        }
        const strIds = winIds.map(s => String(s));
        DBus.SessionBus.asyncCall({
            service: "org.kde.KWin.Effect.WindowView1",
            path: "/org/kde/KWin/Effect/WindowView1",
            iface: "org.kde.KWin.Effect.WindowView1",
            member: "activate",
            arguments: [strIds],
            signature: "(as)"
        });
    }

    // Single shared Compact Window List Dialog
    CompactWindowListDialog {
        id: compactDialog
        tasksModel: openTasksModel
        plasmoidRoot: root
    }
    readonly property alias groupDialog: compactDialog

    // Background helper models for context menu
    Mpris.Mpris2Model {
        id: mpris2Source
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.ActivityInfo {
        id: activityInfo
    }

    // Context Menu Component & Factory
    readonly property Component contextMenuComponent: Qt.createComponent("ContextMenu.qml")

    function createContextMenu(visualItem, modelIndex, tasksModel, extraArgs = {}) {
        if (!visualItem || !modelIndex || !tasksModel) {
            return null;
        }
        const initialArgs = Object.assign(extraArgs, {
            visualParent: visualItem,
            modelIndex: modelIndex,
            tasksModel: tasksModel,
            plasmoidRoot: root,
            mpris2Source: mpris2Source,
            virtualDesktopInfo: virtualDesktopInfo,
            activityInfo: activityInfo,
        });
        return contextMenuComponent.createObject(visualItem, initialArgs);
    }

    // Model 1: Open (unminimized) windows only
    TaskManager.TasksModel {
        id: openTasksModel

        filterMinimized: true // Excludes minimized windows
        filterByCurrentVirtualDesktop: Plasmoid.configuration.showOnlyCurrentDesktop ?? true
        filterByScreen: Plasmoid.configuration.showOnlyCurrentScreen ?? false
        filterByActivity: Plasmoid.configuration.showOnlyCurrentActivity ?? true
        sortMode: TaskManager.TasksModel.SortManual

        // 0 = No grouping, 1 = Compact list, 2 = Present Windows (Exposé), 3 = Bring to foreground
        groupMode: ((Plasmoid.configuration.openGroupingStrategy ?? 1) === 0)
            ? TaskManager.TasksModel.GroupDisabled
            : TaskManager.TasksModel.GroupApplications
    }

    // Model 2: Minimized windows only
    TaskManager.TasksModel {
        id: minimizedTasksModel

        filterNotMinimized: true // Excludes open (non-minimized) windows
        groupMode: (Plasmoid.configuration.groupMinimizedByApplication ?? false)
            ? TaskManager.TasksModel.GroupApplications
            : TaskManager.TasksModel.GroupDisabled
        filterByCurrentVirtualDesktop: Plasmoid.configuration.showOnlyCurrentDesktop ?? true
        filterByScreen: Plasmoid.configuration.showOnlyCurrentScreen ?? false
        filterByActivity: Plasmoid.configuration.showOnlyCurrentActivity ?? true
        sortMode: TaskManager.TasksModel.SortManual
    }

    // Horizontal panel layout
    RowLayout {
        id: horizontalLayout
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing
        visible: !root.vertical

        // Left Section: Open Windows (Left-to-Right, Icons + Text)
        RowLayout {
            id: openTasksRow
            spacing: Kirigami.Units.smallSpacing
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.fillHeight: true
            Layout.fillWidth: true

            Repeater {
                id: openTaskRepeater
                model: openTasksModel

                delegate: OpenTaskDelegate {
                    tasksModel: openTasksModel
                    plasmoidRoot: root
                    vertical: false
                }
            }
        }

        // Center flexible spacer (pushes minimized tasks to the right)
        Item {
            id: centerSpacerHorizontal
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // Minimized windows dock at the right edge.
        RowLayout {
            id: minimizedTasksRow
            spacing: Kirigami.Units.smallSpacing
            layoutDirection: Qt.RightToLeft
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.fillHeight: true

            Repeater {
                id: minTaskRepeater
                model: minimizedTasksModel

                delegate: MinimizedTaskDelegate {
                    tasksModel: minimizedTasksModel
                    plasmoidRoot: root
                    vertical: false
                }
            }
        }

    }

    // Vertical panel layout
    ColumnLayout {
        id: verticalLayout
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing
        visible: root.vertical

        // Top Section: Open Windows (Top-to-Bottom, Icons + Text)
        ColumnLayout {
            id: openTasksColumn
            spacing: Kirigami.Units.smallSpacing
            Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.fillHeight: false

            Repeater {
                model: openTasksModel

                delegate: OpenTaskDelegate {
                    tasksModel: openTasksModel
                    plasmoidRoot: root
                    vertical: true
                }
            }
        }

        // Center spacer for vertical panel
        Item {
            id: centerSpacerVertical
            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        // Minimized windows dock at the bottom edge.
        ColumnLayout {
            id: minimizedTasksColumn
            spacing: Kirigami.Units.smallSpacing
            Layout.alignment: Qt.AlignBottom | Qt.AlignHCenter
            Layout.fillWidth: true

            Repeater {
                model: minimizedTasksModel

                delegate: MinimizedTaskDelegate {
                    tasksModel: minimizedTasksModel
                    plasmoidRoot: root
                    vertical: true
                }
            }
        }

    }

    // Shortcut activation support (Meta + number)
    function activateTaskAtIndex(index: var): void {
        if (typeof index !== "number") {
            return;
        }
        if (index < openTasksModel.count) {
            const idx = openTasksModel.makeModelIndex(index);
            const isGroupParent = openTasksModel.data(idx, TaskManager.AbstractTasksModel.IsGroupParent) ?? false;
            const strategy = Plasmoid.configuration.openGroupingStrategy ?? 1;

            if (isGroupParent) {
                if (strategy === 1) {
                    const delegateItem = openTaskRepeater.itemAt(index);
                    if (delegateItem) {
                        compactDialog.openForTask(delegateItem);
                    }
                } else if (strategy === 2) {
                    const winIds = openTasksModel.data(idx, TaskManager.AbstractTasksModel.WinIdList);
                    if (effectWatcherRegistered && winIds && winIds.length > 0) {
                        activatePresentWindows(winIds);
                    } else {
                        const delegateItem = openTaskRepeater.itemAt(index);
                        if (delegateItem) {
                            compactDialog.openForTask(delegateItem);
                        }
                    }
                } else {
                    const count = openTasksModel.rowCount(idx);
                    for (let i = count - 1; i >= 0; --i) {
                        openTasksModel.requestActivate(openTasksModel.makeModelIndex(index, i));
                    }
                }
            } else {
                openTasksModel.requestActivate(idx);
            }
        } else {
            const minIndex = index - openTasksModel.count;
            if (minIndex < minimizedTasksModel.count) {
                const idx = minimizedTasksModel.makeModelIndex(minIndex);
                minimizedTasksModel.requestToggleMinimized(idx);
                minimizedTasksModel.requestActivate(idx);
            }
        }
    }
}

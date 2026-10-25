import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.plasma.private.mpris as Mpris
import org.kde.taskmanager as TaskManager

PlasmaExtras.Menu {
    id: menu

    property var modelIndex: null
    property var tasksModel: null
    property Item plasmoidRoot: null
    property var mpris2Source: null
    property var virtualDesktopInfo: null
    property var activityInfo: null
    property var bringAllToFrontCallback: null

    signal bringAllToFrontRequested()

    function get(modelProp): var {
        if (!tasksModel || !modelIndex) {
            return undefined;
        }
        return tasksModel.data(modelIndex, modelProp);
    }

    readonly property bool isGroup: get(TaskManager.AbstractTasksModel.IsGroupParent) ?? false
    readonly property bool isMinimized: get(TaskManager.AbstractTasksModel.IsMinimized) ?? false
    readonly property bool isMaximized: get(TaskManager.AbstractTasksModel.IsMaximized) ?? false

    placement: {
        const loc = plasmoidRoot?.Plasmoid?.location ?? Plasmoid?.location ?? PlasmaCore.Types.BottomEdge;
        if (loc === PlasmaCore.Types.LeftEdge) {
            return PlasmaExtras.Menu.RightPosedTopAlignedPopup;
        } else if (loc === PlasmaCore.Types.TopEdge) {
            return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup;
        } else if (loc === PlasmaCore.Types.RightEdge) {
            return PlasmaExtras.Menu.LeftPosedTopAlignedPopup;
        } else {
            return PlasmaExtras.Menu.TopPosedLeftAlignedPopup;
        }
    }

    minimumWidth: visualParent ? visualParent.width : 0

    onStatusChanged: {
        if (status === PlasmaExtras.Menu.Closed) {
            menu.destroy();
        }
    }

    function show(): void {
        const plasmoid = plasmoidRoot?.Plasmoid ?? Plasmoid;
        if (plasmoid && typeof plasmoid.contextualActionsAboutToShow === "function") {
            plasmoid.contextualActionsAboutToShow();
        }
        openRelative();
    }

    // MPRIS Media controls
    readonly property var playerData: {
        if (!mpris2Source) return null;
        const launcherUrl = menu.get(TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon);
        const appPid = menu.get(TaskManager.AbstractTasksModel.AppPid);
        return launcherUrl ? mpris2Source.playerForLauncherUrl(launcherUrl, appPid) : null;
    }
    readonly property bool hasMediaControl: playerData !== null && playerData !== undefined && Boolean(playerData.canControl)

    PlasmaExtras.MenuItem {
        visible: menu.hasMediaControl
        text: i18nc("Play previous track", "Previous Track")
        icon: "media-skip-backward"
        enabled: menu.playerData?.canGoPrevious ?? false
        onClicked: menu.playerData?.Previous()
    }

    PlasmaExtras.MenuItem {
        visible: menu.hasMediaControl
        text: (menu.playerData?.playbackStatus === Mpris.PlaybackStatus.Playing && menu.playerData?.canPause)
            ? i18nc("Pause playback", "Pause")
            : i18nc("Start playback", "Play")
        icon: (menu.playerData?.playbackStatus === Mpris.PlaybackStatus.Playing && menu.playerData?.canPause)
            ? "media-playback-pause"
            : "media-playback-start"
        enabled: menu.playerData?.playbackStatus === Mpris.PlaybackStatus.Playing ? (menu.playerData?.canPause ?? false) : (menu.playerData?.canPlay ?? false)
        onClicked: {
            if (!menu.playerData) return;
            if (menu.playerData.playbackStatus === Mpris.PlaybackStatus.Playing) {
                menu.playerData.Pause();
            } else {
                menu.playerData.Play();
            }
        }
    }

    PlasmaExtras.MenuItem {
        visible: menu.hasMediaControl
        text: i18nc("Play next track", "Next Track")
        icon: "media-skip-forward"
        enabled: menu.playerData?.canGoNext ?? false
        onClicked: menu.playerData?.Next()
    }

    PlasmaExtras.MenuItem {
        visible: menu.hasMediaControl
        text: i18nc("Stop playback", "Stop")
        icon: "media-playback-stop"
        enabled: menu.playerData?.canStop ?? false
        onClicked: menu.playerData?.Stop()
    }

    PlasmaExtras.MenuItem {
        visible: menu.hasMediaControl
        separator: true
    }

    // Group-specific actions
    PlasmaExtras.MenuItem {
        visible: menu.isGroup
        text: i18n("Bring All to Foreground")
        icon: "window-duplicate"
        onClicked: {
            if (typeof menu.bringAllToFrontCallback === "function") {
                menu.bringAllToFrontCallback();
            }
            menu.bringAllToFrontRequested();
        }
    }

    PlasmaExtras.MenuItem {
        visible: menu.isGroup
        text: i18n("Minimize All")
        icon: "window-minimize"
        onClicked: {
            if (menu.tasksModel && menu.modelIndex) {
                menu.tasksModel.requestToggleMinimized(menu.modelIndex);
            }
        }
    }

    // Open New Window action
    PlasmaExtras.MenuItem {
        id: startNewInstanceItem
        visible: menu.get(TaskManager.AbstractTasksModel.CanLaunchNewInstance) ?? false
        text: i18n("Open New Window")
        icon: "window-new"
        onClicked: {
            if (menu.tasksModel && menu.modelIndex) {
                menu.tasksModel.requestNewInstance(menu.modelIndex);
            }
        }
    }

    PlasmaExtras.MenuItem {
        visible: menu.isGroup || startNewInstanceItem.visible
        separator: true
    }

    // Move to Desktop submenu
    PlasmaExtras.MenuItem {
        id: virtualDesktopsMenuItem
        visible: (menu.virtualDesktopInfo?.numberOfDesktops ?? 0) > 1 && (menu.get(TaskManager.AbstractTasksModel.IsVirtualDesktopsChangeable) ?? true)
        text: i18n("Move to &Desktop")
        icon: "virtual-desktops"

        readonly property PlasmaExtras.Menu virtualDesktopsMenu: PlasmaExtras.Menu {
            id: virtualDesktopsMenu
            visualParent: virtualDesktopsMenuItem.action

            function refresh(): void {
                clearMenuItems();

                if (!menu.virtualDesktopInfo || menu.virtualDesktopInfo.numberOfDesktops <= 1) {
                    return;
                }

                // All Desktops
                let allItem = Qt.createQmlObject('import org.kde.plasma.extras as PlasmaExtras; PlasmaExtras.MenuItem {}', virtualDesktopsMenu);
                allItem.text = i18n("&All Desktops");
                allItem.checkable = true;
                allItem.checked = menu.get(TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops) ?? false;
                allItem.clicked.connect(() => {
                    if (menu.tasksModel && menu.modelIndex) {
                        menu.tasksModel.requestVirtualDesktops(menu.modelIndex, []);
                    }
                });

                let sep = Qt.createQmlObject('import org.kde.plasma.extras as PlasmaExtras; PlasmaExtras.MenuItem { separator: true }', virtualDesktopsMenu);

                const currentDesktops = menu.get(TaskManager.AbstractTasksModel.VirtualDesktops) ?? [];
                const dNames = menu.virtualDesktopInfo.desktopNames || [];
                const dIds = menu.virtualDesktopInfo.desktopIds || [];
                for (let i = 0; i < dNames.length; ++i) {
                    const dId = dIds[i];
                    const dName = dNames[i];
                    let dItem = Qt.createQmlObject('import org.kde.plasma.extras as PlasmaExtras; PlasmaExtras.MenuItem {}', virtualDesktopsMenu);
                    dItem.text = dName;
                    dItem.checkable = true;
                    dItem.checked = currentDesktops.indexOf(dId) !== -1;
                    dItem.clicked.connect(() => {
                        if (menu.tasksModel && menu.modelIndex) {
                            menu.tasksModel.requestVirtualDesktops(menu.modelIndex, [dId]);
                        }
                    });
                }

                let sep2 = Qt.createQmlObject('import org.kde.plasma.extras as PlasmaExtras; PlasmaExtras.MenuItem { separator: true }', virtualDesktopsMenu);

                let newItem = Qt.createQmlObject('import org.kde.plasma.extras as PlasmaExtras; PlasmaExtras.MenuItem {}', virtualDesktopsMenu);
                newItem.text = i18n("&New Desktop");
                newItem.icon = "list-add";
                newItem.clicked.connect(() => {
                    if (menu.tasksModel && menu.modelIndex) {
                        menu.tasksModel.requestNewVirtualDesktop(menu.modelIndex);
                    }
                });
            }

            Component.onCompleted: refresh()
        }
    }

    // Show in Activities submenu
    PlasmaExtras.MenuItem {
        id: activitiesMenuItem
        visible: (menu.activityInfo?.numberOfRunningActivities ?? 0) > 1
        text: i18n("Show in &Activities")
        icon: "activities"

        readonly property PlasmaExtras.Menu activitiesMenu: PlasmaExtras.Menu {
            id: activitiesMenu
            visualParent: activitiesMenuItem.action

            function refresh(): void {
                clearMenuItems();

                if (!menu.activityInfo || menu.activityInfo.numberOfRunningActivities <= 1) {
                    return;
                }

                const actList = menu.get(TaskManager.AbstractTasksModel.Activities) ?? [];

                let allItem = Qt.createQmlObject('import org.kde.plasma.extras as PlasmaExtras; PlasmaExtras.MenuItem {}', activitiesMenu);
                allItem.text = i18n("All Activities");
                allItem.checkable = true;
                allItem.checked = actList.length === 0;
                allItem.toggled.connect(checked => {
                    if (menu.tasksModel && menu.modelIndex) {
                        menu.tasksModel.requestActivities(menu.modelIndex, checked ? [] : [menu.activityInfo.currentActivity]);
                    }
                });

                let sep = Qt.createQmlObject('import org.kde.plasma.extras as PlasmaExtras; PlasmaExtras.MenuItem { separator: true }', activitiesMenu);

                const running = menu.activityInfo.runningActivities();
                for (let i = 0; i < running.length; ++i) {
                    const aId = running[i];
                    let aItem = Qt.createQmlObject('import org.kde.plasma.extras as PlasmaExtras; PlasmaExtras.MenuItem {}', activitiesMenu);
                    aItem.text = menu.activityInfo.activityName(aId);
                    aItem.icon = menu.activityInfo.activityIcon(aId);
                    aItem.checkable = true;
                    aItem.checked = actList.indexOf(aId) !== -1;
                    aItem.toggled.connect(checked => {
                        let cur = menu.get(TaskManager.AbstractTasksModel.Activities) ?? [];
                        if (checked) {
                            cur = cur.concat(aId);
                        } else {
                            const idx = cur.indexOf(aId);
                            if (idx >= 0) cur.splice(idx, 1);
                        }
                        if (menu.tasksModel && menu.modelIndex) {
                            menu.tasksModel.requestActivities(menu.modelIndex, cur);
                        }
                    });
                }
            }

            Component.onCompleted: refresh()
        }
    }

    // Pin to Task Manager
    PlasmaExtras.MenuItem {
        id: pinItem
        readonly property url launcherUrl: menu.get(TaskManager.AbstractTasksModel.LauncherUrl) ?? ""
        readonly property url launcherUrlWithoutIcon: menu.get(TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon) ?? ""
        readonly property bool isPinned: {
            if (!launcherUrlWithoutIcon || !menu.tasksModel) return false;
            return typeof menu.tasksModel.launcherActivities === "function" && menu.tasksModel.launcherActivities(launcherUrlWithoutIcon).length > 0;
        }

        visible: launcherUrlWithoutIcon.toString() !== "" && ((plasmoidRoot?.Plasmoid?.immutability ?? Plasmoid?.immutability) !== PlasmaCore.Types.SystemImmutable)
        text: isPinned ? i18n("Unpin from Task Manager") : i18n("&Pin to Task Manager")
        icon: isPinned ? "window-unpin" : "window-pin"

        onClicked: {
            if (!menu.tasksModel) return;
            if (isPinned) {
                menu.tasksModel.requestRemoveLauncher(launcherUrlWithoutIcon);
            } else {
                menu.tasksModel.requestAddLauncher(launcherUrl);
            }
        }
    }

    // More actions submenu
    PlasmaExtras.MenuItem {
        id: moreActionsMenuItem
        visible: !menu.isGroup
        text: i18n("More")
        icon: "view-more-symbolic"

        readonly property PlasmaExtras.Menu moreMenu: PlasmaExtras.Menu {
            visualParent: moreActionsMenuItem.action

            PlasmaExtras.MenuItem {
                enabled: menu.get(TaskManager.AbstractTasksModel.IsMovable) ?? false
                text: i18n("&Move")
                icon: "transform-move"
                onClicked: menu.tasksModel?.requestMove(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.get(TaskManager.AbstractTasksModel.IsResizable) ?? false
                text: i18n("Re&size")
                icon: "transform-scale"
                onClicked: menu.tasksModel?.requestResize(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.get(TaskManager.AbstractTasksModel.IsMaximizable) ?? false
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsMaximized) ?? false
                text: i18n("Ma&ximize")
                icon: "window-maximize"
                onClicked: menu.tasksModel?.requestToggleMaximized(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.get(TaskManager.AbstractTasksModel.IsMinimizable) ?? false
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsMinimized) ?? false
                text: i18n("Mi&nimize")
                icon: "window-minimize"
                onClicked: menu.tasksModel?.requestToggleMinimized(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsKeepAbove) ?? false
                text: i18n("Keep &Above Others")
                icon: "window-keep-above"
                onClicked: menu.tasksModel?.requestToggleKeepAbove(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsKeepBelow) ?? false
                text: i18n("Keep &Below Others")
                icon: "window-keep-below"
                onClicked: menu.tasksModel?.requestToggleKeepBelow(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.get(TaskManager.AbstractTasksModel.IsFullScreenable) ?? false
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsFullScreen) ?? false
                text: i18n("&Fullscreen")
                icon: "view-fullscreen"
                onClicked: menu.tasksModel?.requestToggleFullScreen(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.get(TaskManager.AbstractTasksModel.IsShadeable) ?? false
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsShaded) ?? false
                visible: Qt.platform.pluginName !== "wayland"
                text: i18n("&Shade")
                icon: "window-shade"
                onClicked: menu.tasksModel?.requestToggleShaded(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.get(TaskManager.AbstractTasksModel.CanSetNoBoder) ?? false
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.HasNoBorder) ?? false
                text: i18n("&No Titlebar and Frame")
                icon: "edit-none-border"
                onClicked: menu.tasksModel?.requestToggleNoBorder(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsExcludedFromCapture) ?? false
                visible: Qt.platform.pluginName === "wayland"
                text: i18n("&Hide from Screencast")
                icon: "view-private"
                onClicked: menu.tasksModel?.requestToggleExcludeFromCapture(menu.modelIndex)
            }

            PlasmaExtras.MenuItem { separator: true }

            PlasmaExtras.MenuItem {
                checkable: true
                checked: menu.get(TaskManager.AbstractTasksModel.IsGroupable) ?? true
                text: i18n("Allow this program to be grouped")
                icon: "view-group"
                onClicked: menu.tasksModel?.requestToggleGrouping(menu.modelIndex)
            }
        }
    }

    PlasmaExtras.MenuItem { separator: true }

    // Plasmoid actions
    PlasmaExtras.MenuItem {
        property PlasmaCore.Action configureAction: null
        enabled: configureAction ? configureAction.enabled : true
        visible: configureAction ? configureAction.visible : true
        text: configureAction ? configureAction.text : i18n("Configure Task Manager...")
        icon: configureAction ? configureAction.icon : "configure"
        onClicked: {
            if (configureAction) {
                configureAction.trigger();
            } else {
                const plasmoid = plasmoidRoot?.Plasmoid ?? Plasmoid;
                plasmoid?.action("configure")?.trigger();
            }
        }
        Component.onCompleted: {
            const plasmoid = plasmoidRoot?.Plasmoid ?? Plasmoid;
            if (plasmoid && typeof plasmoid.internalAction === "function") {
                configureAction = plasmoid.internalAction("configure");
            }
        }
    }

    PlasmaExtras.MenuItem {
        property PlasmaCore.Action editModeAction: null
        enabled: editModeAction ? editModeAction.enabled : true
        visible: editModeAction ? editModeAction.visible : true
        text: editModeAction ? editModeAction.text : i18n("Enter Edit Mode")
        icon: editModeAction ? editModeAction.icon : "document-edit"
        onClicked: {
            if (editModeAction) {
                editModeAction.trigger();
            }
        }
        Component.onCompleted: {
            const plasmoid = plasmoidRoot?.Plasmoid ?? Plasmoid;
            if (plasmoid?.containment && typeof plasmoid.containment.internalAction === "function") {
                editModeAction = plasmoid.containment.internalAction("configure");
            }
        }
    }

    PlasmaExtras.MenuItem { separator: true }

    // Close action
    PlasmaExtras.MenuItem {
        id: closeWindowItem
        enabled: menu.get(TaskManager.AbstractTasksModel.IsClosable) ?? true
        text: menu.isGroup ? i18n("&Close All") : i18n("&Close")
        icon: "window-close"
        onClicked: {
            if (plasmoidRoot?.groupDialog && plasmoidRoot.groupDialog.targetTaskItem === menu.visualParent) {
                plasmoidRoot.groupDialog.visible = false;
            }
            if (menu.tasksModel && menu.modelIndex) {
                menu.tasksModel.requestClose(menu.modelIndex);
            }
        }
    }
}

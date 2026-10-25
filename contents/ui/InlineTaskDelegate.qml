import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

Item {
    id: inlineTask

    required property var model
    required property int index
    required property var allTasksModel
    required property var openTasksModel
    required property var minimizedTasksModel
    property Item plasmoidRoot: null
    property bool vertical: false
    property Item taskDelegate: null

    readonly property bool isMinimized: model?.IsMinimized ?? false
    readonly property bool shouldGroup: isMinimized
        ? (Plasmoid.configuration.groupMinimizedByApplication ?? false)
        : ((Plasmoid.configuration.openGroupingStrategy ?? 1) !== 0)
    readonly property var renderModel: isMinimized ? minimizedTasksModel : openTasksModel
    readonly property int renderIndex: findRenderIndex(index)
    readonly property bool isFirstInGroup: !shouldGroup || isFirstTaskForRenderIndex()

    Layout.minimumWidth: vertical ? -1 : (isMinimized ? implicitWidth : (Plasmoid.configuration.minTaskWidth ?? 48))
    Layout.maximumWidth: vertical ? -1 : (isMinimized ? implicitWidth : (Plasmoid.configuration.maxTaskWidth ?? 220))
    Layout.preferredWidth: vertical ? -1 : implicitWidth
    Layout.minimumHeight: vertical ? (isMinimized ? implicitHeight : Kirigami.Units.gridUnit * 2) : -1
    Layout.maximumHeight: vertical ? (isMinimized ? implicitHeight : Kirigami.Units.gridUnit * 2.5) : -1
    Layout.preferredHeight: vertical ? implicitHeight : -1
    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical
    implicitWidth: vertical ? parent.width : (isMinimized ? parent.height : (Plasmoid.configuration.maxTaskWidth ?? 220))
    implicitHeight: vertical ? (isMinimized ? parent.width : Kirigami.Units.gridUnit * 2.2) : parent.height
    visible: isFirstInGroup && renderIndex >= 0

    function findRenderIndex(allRow: int): int {
        if (!allTasksModel || !renderModel || allRow < 0 || allRow >= allTasksModel.count) {
            return -1;
        }
        const allIndex = allTasksModel.makeModelIndex(allRow);
        const windowIds = allTasksModel.data(allIndex, TaskManager.AbstractTasksModel.WinIdList);
        const appId = allTasksModel.data(allIndex, TaskManager.AbstractTasksModel.AppId);
        const display = allTasksModel.data(allIndex, Qt.DisplayRole);
        let appMatch = -1;
        for (let i = 0; i < renderModel.count; ++i) {
            const candidateIndex = renderModel.makeModelIndex(i);
            const candidateIds = renderModel.data(candidateIndex, TaskManager.AbstractTasksModel.WinIdList);
            if (windowIds && candidateIds
                && windowIds.some(id => candidateIds.some(candidateId => String(candidateId) === String(id)))) {
                return i;
            }

            const candidateAppId = renderModel.data(candidateIndex, TaskManager.AbstractTasksModel.AppId);
            if (!appId || candidateAppId !== appId) {
                continue;
            }
            const isGroupParent = renderModel.data(candidateIndex, TaskManager.AbstractTasksModel.IsGroupParent) ?? false;
            if (isGroupParent) {
                appMatch = i;
            } else if (renderModel.data(candidateIndex, Qt.DisplayRole) === display) {
                return i;
            }
        }
        return appMatch;
    }

    function isFirstTaskForRenderIndex(): bool {
        if (!allTasksModel || renderIndex < 0) {
            return false;
        }
        for (let i = 0; i < index; ++i) {
            const previousIndex = allTasksModel.makeModelIndex(i);
            const previousIsMinimized = allTasksModel.data(previousIndex, TaskManager.AbstractTasksModel.IsMinimized) ?? false;
            if (previousIsMinimized !== isMinimized && shouldGroup) {
                continue;
            }
            if (findRenderIndex(i) === renderIndex) {
                return false;
            }
        }
        return true;
    }

    function makeDelegateModel(): var {
        if (!renderModel || renderIndex < 0 || renderIndex >= renderModel.count) {
            return null;
        }
        const renderModelIndex = renderModel.makeModelIndex(renderIndex);
        return {
            IsDemandingAttention: renderModel.data(renderModelIndex, TaskManager.AbstractTasksModel.IsDemandingAttention) ?? false,
            IsActive: renderModel.data(renderModelIndex, TaskManager.AbstractTasksModel.IsActive) ?? false,
            IsGroupParent: renderModel.data(renderModelIndex, TaskManager.AbstractTasksModel.IsGroupParent) ?? false,
            ChildCount: renderModel.data(renderModelIndex, TaskManager.AbstractTasksModel.ChildCount) ?? 1,
            AppName: renderModel.data(renderModelIndex, TaskManager.AbstractTasksModel.AppName) ?? "",
            WinIdList: renderModel.data(renderModelIndex, TaskManager.AbstractTasksModel.WinIdList) ?? [],
            display: renderModel.data(renderModelIndex, Qt.DisplayRole) ?? "",
            decoration: renderModel.data(renderModelIndex, Qt.DecorationRole) ?? ""
        };
    }

    function createTaskDelegate(): void {
        if (taskDelegate) {
            taskDelegate.destroy();
            taskDelegate = null;
        }
        if (!visible || !renderModel || renderIndex < 0) {
            return;
        }

        const delegateModel = makeDelegateModel();
        if (!delegateModel) {
            return;
        }
        const component = isMinimized ? minimizedDelegateComponent : openDelegateComponent;
        taskDelegate = component.createObject(inlineTask, {
            model: delegateModel,
            index: renderIndex,
            tasksModel: renderModel,
            plasmoidRoot: plasmoidRoot,
            vertical: vertical
        });
        if (!taskDelegate) {
            console.error("Failed to create inline task delegate");
            return;
        }
        taskDelegate.anchors.fill = inlineTask;
    }

    function activateTask(): void {
        if (!taskDelegate) {
            return;
        }
        if (isMinimized) {
            if (taskDelegate.groupByApplication) {
                taskDelegate.activateGroup();
            } else {
                taskDelegate.tasksModel.requestToggleMinimized(taskDelegate.targetModelIndex);
                taskDelegate.tasksModel.requestActivate(taskDelegate.targetModelIndex);
            }
            return;
        }

        if (!taskDelegate.isGroup) {
            if (taskDelegate.model.IsActive && (Plasmoid.configuration.minimizeActiveTaskOnClick ?? true)) {
                taskDelegate.tasksModel.requestToggleMinimized(taskDelegate.targetModelIndex);
            } else {
                taskDelegate.tasksModel.requestActivate(taskDelegate.targetModelIndex);
            }
            return;
        }

        const strategy = Plasmoid.configuration.openGroupingStrategy ?? 1;
        if (strategy === 1) {
            plasmoidRoot?.groupDialog?.openForTask(taskDelegate);
        } else if (strategy === 2) {
            const winIds = taskDelegate.model.WinIdList;
            if (plasmoidRoot?.effectWatcherRegistered && winIds && winIds.length > 0) {
                plasmoidRoot.activatePresentWindows(winIds);
            } else {
                plasmoidRoot?.groupDialog?.openForTask(taskDelegate);
            }
        } else if (strategy === 3) {
            taskDelegate.bringAllToForegroundAndCycle();
        } else {
            taskDelegate.tasksModel.requestActivate(taskDelegate.targetModelIndex);
        }
    }

    onVisibleChanged: createTaskDelegate()
    onIsMinimizedChanged: createTaskDelegate()
    onRenderIndexChanged: createTaskDelegate()
    onIndexChanged: createTaskDelegate()
    Component.onCompleted: createTaskDelegate()

    Connections {
        target: inlineTask.allTasksModel
        function onCountChanged() { inlineTask.createTaskDelegate(); }
    }

    Connections {
        target: inlineTask.renderModel
        function onDataChanged() {
            const delegateModel = inlineTask.makeDelegateModel();
            if (inlineTask.taskDelegate && delegateModel) {
                inlineTask.taskDelegate.model = delegateModel;
            }
        }
        function onCountChanged() { inlineTask.createTaskDelegate(); }
    }

    Component {
        id: openDelegateComponent
        OpenTaskDelegate {}
    }

    Component {
        id: minimizedDelegateComponent
        MinimizedTaskDelegate {}
    }
}

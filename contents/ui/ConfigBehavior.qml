import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

KCMUtils.SimpleKCM {
    id: behaviorPage

    property alias cfg_openGroupingStrategy: openGroupingStrategyComboBox.currentIndex
    property alias cfg_showOnlyCurrentScreen: showOnlyCurrentScreenCheckBox.checked
    property alias cfg_showOnlyCurrentDesktop: showOnlyCurrentDesktopCheckBox.checked
    property alias cfg_showOnlyCurrentActivity: showOnlyCurrentActivityCheckBox.checked
    property alias cfg_minimizeActiveTaskOnClick: minimizeActiveTaskOnClickCheckBox.checked
    property alias cfg_middleClickAction: middleClickActionComboBox.currentIndex

    Kirigami.FormLayout {
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Window Grouping")
        }

        QQC2.ComboBox {
            id: openGroupingStrategyComboBox
            Kirigami.FormData.label: i18n("Open windows grouping:")
            model: [
                i18n("No grouping (each window has its own button)"),
                i18n("Compact window list (textual list popup)"),
                i18n("Present Windows / Exposé (overview of application windows)"),
                i18n("Bring application to foreground (cycles through windows)")
            ]
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: true
            type: Kirigami.MessageType.Information
            text: i18n("Note: Minimized windows always remain ungrouped as individual icons on the right side.")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Filtering")
        }

        QQC2.CheckBox {
            id: showOnlyCurrentScreenCheckBox
            Kirigami.FormData.label: i18n("Screens:")
            text: i18n("Show only tasks on the current screen")
        }

        QQC2.CheckBox {
            id: showOnlyCurrentDesktopCheckBox
            Kirigami.FormData.label: i18n("Virtual Desktops:")
            text: i18n("Show only tasks on the current virtual desktop")
        }

        QQC2.CheckBox {
            id: showOnlyCurrentActivityCheckBox
            Kirigami.FormData.label: i18n("Activities:")
            text: i18n("Show only tasks on the current activity")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Click Actions")
        }

        QQC2.CheckBox {
            id: minimizeActiveTaskOnClickCheckBox
            Kirigami.FormData.label: i18n("Left Click:")
            text: i18n("Minimize active window when clicked")
        }

        QQC2.ComboBox {
            id: middleClickActionComboBox
            Kirigami.FormData.label: i18n("Middle Click:")
            model: [
                i18n("Close window"),
                i18n("Toggle minimize"),
                i18n("Launch new instance")
            ]
        }
    }
}

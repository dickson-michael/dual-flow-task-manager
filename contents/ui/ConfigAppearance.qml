import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

KCMUtils.SimpleKCM {
    id: appearancePage

    property alias cfg_maxTaskWidth: maxTaskWidthSpinBox.value
    property alias cfg_minTaskWidth: minTaskWidthSpinBox.value
    property alias cfg_dimMinimizedIcons: dimMinimizedIconsCheckBox.checked
    property alias cfg_showToolTips: showToolTipsCheckBox.checked

    Kirigami.FormLayout {
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Task Item Sizing")
        }

        QQC2.SpinBox {
            id: minTaskWidthSpinBox
            Kirigami.FormData.label: i18n("Minimum task width:")
            from: 60
            to: 300
            stepSize: 10
            textFromValue: value => i18n("%1 px", value)
        }

        QQC2.SpinBox {
            id: maxTaskWidthSpinBox
            Kirigami.FormData.label: i18n("Maximum task width:")
            from: 100
            to: 600
            stepSize: 10
            textFromValue: value => i18n("%1 px", value)
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Visuals")
        }

        QQC2.CheckBox {
            id: dimMinimizedIconsCheckBox
            Kirigami.FormData.label: i18n("Minimized icons:")
            text: i18n("Slightly dim minimized icons until hovered")
        }

        QQC2.CheckBox {
            id: showToolTipsCheckBox
            Kirigami.FormData.label: i18n("Tooltips:")
            text: i18n("Show tooltips when hovering over tasks")
        }
    }
}

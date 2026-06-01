import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    anchors.fill: parent
    color: "#0c1014"

    property int slide: 0

    Timer {
        interval: 3500
        repeat: true
        running: true
        onTriggered: root.slide = (root.slide + 1) % 3
    }

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#0c1014" }
        GradientStop { position: 1.0; color: "#16202a" }
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 56
        anchors.verticalCenter: parent.verticalCenter
        spacing: 18

        Text {
            text: "Livio OS"
            color: "#f5f7fa"
            font.pixelSize: 34
            font.bold: true
        }

        Text {
            width: 500
            wrapMode: Text.WordWrap
            color: "#c7d0da"
            font.pixelSize: 18
            text: root.slide === 0
                ? "A clean Arch-based gaming system with a KDE live environment and a current graphics stack."
                : root.slide === 1
                    ? "Install the desktop you want, keep gaming tools by default, and avoid a bloated offline image."
                    : "Livio OS ships a stable kernel path first and keeps recovery options close instead of chasing fake tweaks."
        }
    }

    Rectangle {
        width: 220
        height: 220
        radius: 28
        anchors.right: parent.right
        anchors.rightMargin: 64
        anchors.verticalCenter: parent.verticalCenter
        color: "#9ED36A"

        Text {
            anchors.centerIn: parent
            text: "L"
            color: "#111418"
            font.pixelSize: 120
            font.bold: true
        }
    }
}

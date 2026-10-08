pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import "."
import "themes"

Item {
    id: root
    visible: false

    // Static fallback for immediate initialization
    Dark { id: defaultFallback }

    property var loadedThemes: []

    FolderListModel {
      id: folderModel
      folder: Qt.resolvedUrl("themes")
      nameFilters: ["*.qml"]
      showDirs: false
      onCountChanged: root.reloadThemes()
    }

    function reloadThemes() {
      // Clean up previous dynamic objects to avoid memory fileBaseName
      for (var j= 0; j < loadedThemes.length; j++) {
        if (loadedThemes[j].obj) loadedThemes[j].obj.destroy();
      }
      var list = [];
      for (var i = 0; i < folderModel.count; i++) {
          var fileUrl = folderModel.get(i, "fileUrl");
          var baseName = folderModel.get(i, "fileBaseName");
          var comp = Qt.createComponent(fileUrl);
          if (comp.status === Component.Ready) {
              var obj = comp.createObject(root);
              var id = baseName.toLowerCase();
              var displayName = (obj.name && obj.name !== "") ? obj.name : baseName;
              list.push({
                  id: id,
                  name: displayName,
                  fileBaseName: baseName,
                  obj: obj
              });
          }
      }
      root.loadedThemes = list;
    }

    readonly property var themesList: loadedThemes

    property string currentThemeName: Config.theme ? Config.theme.current : "dark"

    Connections {
      target: Config
      function onValuesChanged() {
        if (Config.theme && Config.theme.current) {
          root.currentThemeName = Config.theme.current;
        }
      }
    }

    function setTheme(name, persist) {
        if (persist === undefined) persist = true;
        var found = false;
        for (var i = 0; i < themesList.length; i++) {
            if (themesList[i].id === name || themesList[i].fileBaseName.toLowerCase() === name.toLowerCase()) {
                currentThemeName = themesList[i].id;
                found = true;
                break;
            }
        }
        if (found && persist) {
            Config.set("theme.current", currentThemeName);
        }
    }

    readonly property var active: {
        for (var i = 0; i < themesList.length; i++) {
            if (themesList[i].id === currentThemeName ||
                themesList[i].fileBaseName.toLowerCase() === currentThemeName.toLowerCase()) {
                return themesList[i].obj;
            }
        }
        if (themesList.length > 0) return themesList[0].obj;
        return defaultFallback;
    }

    // Reactive properties exposed to the rest of the shell
    readonly property color background: active.background
    readonly property color surface: active.surface
    readonly property color surfaceHover: active.surfaceHover
    readonly property color surfaceActive: active.surfaceActive
    readonly property color border: active.border
    readonly property color borderHover: active.borderHover
    readonly property color textPrimary: active.textPrimary
    readonly property color textSecondary: active.textSecondary
    readonly property color textMuted: active.textMuted
    readonly property color accent: active.accent
    readonly property color danger: active.danger
    readonly property color success: active.success
    readonly property color warning: active.warning
    readonly property color badgeFocusedBg: active.badgeFocusedBg
    readonly property color badgeFocusedText: active.badgeFocusedText
}

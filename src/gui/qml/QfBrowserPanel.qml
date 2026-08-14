import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield.core
import org.qfield.gui

/**
 * \ingroup qml_gui
 */
QfPopup {
  id: browserPanel

  signal cancel

  property var browserView: undefined
  property var browserCookies: []

  property string url: ''
  property bool fullscreen: false
  property bool clearCookiesOnOpen: false

  width: mainWindow.width - (browserPanel.fullscreen ? 0 : QfTheme.popupScreenEdgeHorizontalMargin * 2)
  height: mainWindow.height - (browserPanel.fullscreen ? 0 : QfTheme.popupScreenEdgeVerticalMargin * 2)
  x: browserPanel.fullscreen ? 0 : QfTheme.popupScreenEdgeHorizontalMargin
  y: browserPanel.fullscreen ? 0 : QfTheme.popupScreenEdgeVerticalMargin
  padding: fullscreen ? 0 : 5
  closePolicy: Popup.CloseOnEscape
  focus: visible

  Page {
    id: browserContainer
    anchors.fill: parent
    padding: 0

    header: QfPageHeader {
      id: pageHeader
      title: browserView && !browserView.loading && browserView.title !== '' ? browserView.title : qsTr("Browser")

      showBackButton: browserPanel.fullscreen
      showApplyButton: false
      showCancelButton: !browserPanel.fullscreen

      busyIndicatorState: webViewLoader.item && webViewLoader.item.loading ? "on" : "off"

      topMargin: browserPanel.fullscreen ? mainWindow.sceneTopMargin : 0

      onBack: {
        browserPanel.cancel();
      }

      onCancel: {
        browserPanel.cancel();
      }
    }

    Loader {
      id: webViewLoader

      anchors.fill: parent
      active: browserPanel.opened
      // By name: the file is absent on platforms built without a web view.
      source: "QfWebView.qml"

      onLoaded: {
        item.url = Qt.binding(() => browserPanel.url);
        if (browserPanel.clearCookiesOnOpen) {
          item.deleteAllCookies();
          browserPanel.clearCookiesOnOpen = false;
        }
      }
    }

    Connections {
      target: webViewLoader.item

      function onCookieAdded(domain, name) {
        browserPanel.browserCookies.push([domain, name]);
      }
    }
  }

  onAboutToHide: {
    iface.setScreenDimmerTimeout(settings.value('dimTimeoutSeconds', 60));
  }

  onAboutToShow: {
    // Disable dimming to avoid dark screens while browsing
    iface.setScreenDimmerTimeout(0);

    // Reset tracked cookies
    browserCookies = [];
  }

  function deleteCookies() {
    if (webViewLoader.item) {
      for (const [domain, name] of browserCookies) {
        webViewLoader.item.deleteCookie(domain, name);
      }
      browserCookies = [];
    }
  }
}

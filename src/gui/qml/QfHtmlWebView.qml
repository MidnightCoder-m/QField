/**
 * \ingroup qml
 *
 * A web view for an HTML snippet: it starts collapsed and grows to the rendered height.
 */

QfWebView {
  height: 0
  opacity: 0

  anchors {
    top: parent.top
    left: parent.left
    right: parent.right
  }

  onLoadingChanged: {
    if (!loading) {
      runJavaScript("document.body.offsetHeight", function (result) {
        height = result + 18;
        opacity = 1.0;
      });
    }
  }
}

import WebKit

class DraggableWebView: WKWebView {
    var dragableAreaHeight: CGFloat = 28
    let alwaysDragableLeftAreaWidth: CGFloat = 0

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        let x = event.locationInWindow.x
        let y = (window?.frame.size.height ?? 0) - event.locationInWindow.y

        if x < alwaysDragableLeftAreaWidth || y < dragableAreaHeight {
            window?.performDrag(with: event)
        }
    }
}

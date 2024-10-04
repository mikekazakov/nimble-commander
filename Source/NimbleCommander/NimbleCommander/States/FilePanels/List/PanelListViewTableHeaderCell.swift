// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
import Cocoa

@objc public class PanelListViewTableHeaderCell: NSTableHeaderCell {

    func fill(rect rc: NSRect, withColor c: NSColor) {
        c.set()
        if c.alphaComponent == 1.0 {
            rc.fill()
        } else {
            rc.fill(using: NSCompositingOperation.sourceOver)
        }
    }

    func drawBackground(cellFrame rect: NSRect) {
        nc.CurrentTheme().FilePanelsListHeaderBackgroundColor().set()
        rect.fill()

        if cellAttribute(NSCell.Attribute.cellState) != 0 {
            let original = nc.CurrentTheme().FilePanelsListHeaderBackgroundColor()
            let colorspace = NSColorSpace.genericRGB
            let brightness = original!.usingColorSpace(colorspace)!.brightnessComponent
            let new_color = NSColor(white: 1.0 - brightness, alpha: 0.1)
            fill(rect: NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width - 1, height: rect.size.height),
                 withColor: new_color)
        }
    }

    func drawHorizontalSeparator(in rect: NSRect) {
        fill(rect: NSMakeRect(rect.origin.x, NSMaxY(rect) - 1, rect.size.width, 1),
             withColor: nc.CurrentTheme().FilePanelsListHeaderSeparatorColor())
    }

    func drawVerticalSeparator(in rect: NSRect, inView view: NSView) {
        if NSMaxX(rect) < view.bounds.size.width {
            fill(rect: NSRect(x: NSMaxX(rect) - 1, y: NSMinY(rect) + 3, width: 1, height: rect.size.height - 6),
                 withColor: nc.CurrentTheme().FilePanelsListHeaderSeparatorColor())
        }
    }

    public override func draw(withFrame cellFrame: NSRect, in view: NSView) {
        drawBackground(cellFrame: cellFrame)
        drawHorizontalSeparator(in: cellFrame)
        drawVerticalSeparator(in: cellFrame, inView: view)

        // this may be really bad - to set attributes on every call. might need to figure out a better way to customize header cells
        let ps = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        ps.alignment = self.alignment
        ps.lineBreakMode = NSLineBreakMode.byClipping

        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: nc.CurrentTheme().FilePanelsListHeaderFont()!,
            NSAttributedString.Key.foregroundColor: nc.CurrentTheme().FilePanelsListHeaderTextColor()!,
            NSAttributedString.Key.paragraphStyle: ps,
        ]
        self.attributedStringValue = NSAttributedString(string: self.stringValue, attributes: attrs)

        let left_padding = Double(4)
        var trc = drawingRect(forBounds: cellFrame)
        let font_height = nc.CurrentTheme().FilePanelsListHeaderFont().pointSize
        let top = (trc.size.height - font_height) / 2
        let height = font_height + 4

        if self.alignment == NSTextAlignment.right {
            trc = NSMakeRect(trc.origin.x, top, trc.size.width, height)
        } else if self.alignment == NSTextAlignment.left {
            trc = NSMakeRect(trc.origin.x + left_padding, top, trc.size.width - left_padding, height)
        } else {  // center
            trc = NSMakeRect(trc.origin.x, top, trc.size.width, height)
        }

        drawInterior(withFrame: trc, in: view)
    }
}

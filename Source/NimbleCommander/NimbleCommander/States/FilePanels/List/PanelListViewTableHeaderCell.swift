// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
import Cocoa

@objc
public class PanelListViewTableHeaderCell: NSTableHeaderCell {
    var separatorColor: NSColor = NSColor.black
    var sortIndicator: NSImage?
    var tintedSortIndicator: NSImage?
    @objc public var leftOffset: Double = 4.0
    
    // RTFM "NSCopyObject() + NSCell + crash" to learn why this abomination is required
    public override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! PanelListViewTableHeaderCell
        let _ = Unmanaged<NSColor>.passRetained(copy.separatorColor)
        if let si = copy.sortIndicator {
            let _ = Unmanaged<NSImage>.passRetained(si)
        }
        if let tsi = copy.tintedSortIndicator {
            let _ = Unmanaged<NSImage>.passRetained(tsi)
        }
        return copy
    }
    
    func fill(rect rc: NSRect, withColor c: NSColor) {
        c.set()
        if c.alphaComponent == 1.0 {
            rc.fill()
        } else {
            rc.fill(using: NSCompositingOperation.sourceOver)
        }
    }
    
    func drawBackground(cellFrame rect: NSRect) {
        if let color = self.backgroundColor {
            color.set()
            rect.fill()
            
            if cellAttribute(NSCell.Attribute.cellState) != 0 {
                let original = color
                let colorspace = NSColorSpace.genericRGB
                let brightness = original.usingColorSpace(colorspace)!.brightnessComponent
                let new_color = NSColor(white: 1.0 - brightness, alpha: 0.1)
                fill(rect: NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width - 1, height: rect.size.height),
                     withColor: new_color)
            }
        }
    }
    
    func drawHorizontalSeparator(in rect: NSRect) {
        fill(rect: NSMakeRect(rect.origin.x, NSMaxY(rect) - 1, rect.size.width, 1), withColor: separatorColor)
    }
    
    func drawVerticalSeparator(in rect: NSRect, inView view: NSView) {
        if NSMaxX(rect) < view.bounds.size.width {
            fill(rect: NSRect(x: NSMaxX(rect) - 1, y: NSMinY(rect) + 4, width: 1, height: rect.size.height - 8),
                 withColor: separatorColor)
        }
    }
    
    public override func draw(withFrame cellFrame: NSRect, in view: NSView) {
        drawBackground(cellFrame: cellFrame)
        drawHorizontalSeparator(in: cellFrame)
        drawVerticalSeparator(in: cellFrame, inView: view)
        
        // Draw the sorting indicator
        var sortIndicatorRect:NSRect?
        
        if let headerView = view as? NSTableHeaderView,
           let tableView = headerView.tableView {
            
            let columnIndex = headerView.column(at: cellFrame.origin)
            if columnIndex != -1 {
                let tableColumn = tableView.tableColumns[columnIndex]
                if let indicator = tableView.indicatorImage(in: tableColumn) {
                    if sortIndicator == nil ||
                        tintedSortIndicator == nil ||
                        indicator != self.sortIndicator {
                        // Stale indicator image => need to update
                        sortIndicator = indicator
                        tintedSortIndicator = tintedImage(indicator, tint: self.textColor ?? NSColor.textColor)
                    }
                    
                    let img_rc = super.sortIndicatorRect(forBounds: cellFrame)
                    sortIndicatorRect = img_rc;
                    
                    if let tinted = tintedSortIndicator {
                        tinted.draw(in: img_rc)
                    }
                }
            }
        }
        
        // Now draw the column title
        var trc = drawingRect(forBounds: cellFrame)
        trc.size.height -= 1 // eaten by the horizontal separator at the bottom
        trc.size.width -= 1 // eatern by the vertical separator at the right
        
        // Clip the title it the sorting indicator is present. Allow 1px gap between the title and the indicator
        if let sortIndicatorRect {
            if  trc.maxX > sortIndicatorRect.minX - 1 {
                trc.size.width = sortIndicatorRect.minX - 1 - trc.origin.x
            }
        }
        
        // Place the title
        let font = super.font ?? NSFont.systemFont(ofSize: 11)
        let height = font.pointSize
        let top = (trc.size.height - height) / 2
        if self.alignment == NSTextAlignment.right {
            trc = NSMakeRect(trc.origin.x, top, trc.size.width, height)
        } else if self.alignment == NSTextAlignment.left {
            trc = NSMakeRect(trc.origin.x + leftOffset, top, trc.size.width - leftOffset, height)
        } else {  // center
            trc = NSMakeRect(trc.origin.x, top, trc.size.width, height)
        }
        trc.origin.y += font.ascender
        
        // Get the attributed string of the title
        var string = self.attributedStringValue
        
        // Transform the string to use the bold font if the column is used for sorting
        if sortIndicatorRect != nil {
            let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            let mutable = NSMutableAttributedString(attributedString: string)
            mutable.addAttributes([.font: bold], range: NSRange(location: 0, length: string.length))
            string = mutable
        }
        
        // Finally, draw it
        string.draw(with: trc)
    }
    
    @objc public func updateTheme(withTextFont font: NSFont,
                                  textColor: NSColor,
                                  separatorColor: NSColor,
                                  backgroundColor: NSColor) {
        super.backgroundColor = backgroundColor
        super.font = font
        super.textColor = textColor
        self.separatorColor = separatorColor
        sortIndicator = nil
        tintedSortIndicator = nil
        updateAttributedString()
    }
    
    func updateAttributedString() {
        let ps = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        ps.alignment = self.alignment
        ps.lineBreakMode = NSLineBreakMode.byClipping
        
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: font ?? NSFont.systemFont(ofSize: 11),
            NSAttributedString.Key.foregroundColor: textColor ?? NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: ps,
        ]
        self.attributedStringValue = NSAttributedString(string: self.stringValue, attributes: attrs)
    }
    
    public override var stringValue: String {
        didSet {
            updateAttributedString()
        }
    }
    
    func tintedImage(_ image: NSImage, tint: NSColor) -> NSImage {
        let image = NSImage.init(size: image.size, flipped: false) { rc in
            tint.set()
            image.draw(in: rc)
            rc.fill(using: .sourceIn)
            return true;
        }
        return image
    }
    
}

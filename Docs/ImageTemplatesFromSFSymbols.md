Nimble Commander includes template images rendered from the SF Symbols font.  
This ensures compatibility with older versions of macOS where SF Symbols are partially or completely unavailable.  
The following instructions outline the process for adding a new image template.

In the SF Symbols application:
  - Choose the desired symbol.
  - Select `Monochrome` rendering.
  - Set the colour to `Black`.
  - Set the background to `Light`.
  - Right-click on the symbol and select `Copy Image As...`
  - Choose the `PNG` format.
  - Enter the required point size.
  - Select the `Medium` symbol scale.
  - Repeat the process for pixel scale values `1` and `2`.    
  - Click `Copy Image`.

In Preview:
  - Press `Cmd+N` to paste the image from the pasteboard.
  - Verify the dimensions; sometimes there is a minor off-by-one discrepancy that needs to be trimmed.
  - Save the images as, for example, `return.left.12-1x.png` and `return.left.12-2x.png`.

In Xcode:
  - Open the Media Assets Library.
  - Add a new asset: `Image Set`.
  - Rename the asset to, for example, `return.left.12`.
  - Set `Properties > Devices`: to `Mac` only.
  - Set `Properties > Render As`: to `Template Image`.
  - Drag the images into the `1x` and `2x` slots.
  - Done! You can now use the named image `return.left.12`.
  
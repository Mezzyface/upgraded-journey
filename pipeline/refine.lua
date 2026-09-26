-- Aseprite batch refine: quantize to a small palette, write .aseprite for hand editing, re-export PNG.
--   aseprite -b --script-param in=X.png --script-param colors=16 --script pipeline/refine.lua
local src, colors = app.params["in"], tonumber(app.params["colors"] or 16)
local spr = Sprite{ fromFile = src }
app.command.ColorQuantization{ ui = false, withAlpha = true, maxColors = colors }
app.command.ChangePixelFormat{ format = "indexed", dithering = "none" }
spr:saveAs(src:gsub("%.png$", ".aseprite"))
spr:saveCopyAs(src)
print("refined", src, "palette", #spr.palettes[1])

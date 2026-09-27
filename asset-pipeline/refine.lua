-- Aseprite batch refine: remap to a palette PNG, or quantize to N colors; write .aseprite for hand edits.
--   aseprite -b --script-param in=X.png --script-param colors=16 --script asset-pipeline/refine.lua
--   aseprite -b --script-param in=X.png --script-param palette=P.png --script asset-pipeline/refine.lua
local src, colors, palpath = app.params["in"], tonumber(app.params["colors"] or 16), app.params["palette"]
local spr = Sprite{ fromFile = src }
if palpath then
  -- index 0 is the transparent slot; make it a colour no art uses (magenta) so dark outline pixels can't map to it
  -- the palette PNG is itself indexed-color; Image{fromFile=} would then hand back palette indices instead of
  -- RGBA, so load it as a sprite and force it to RGB first
  local palSpr = Sprite{ fromFile = palpath }
  if palSpr.colorMode == ColorMode.INDEXED then
    app.activeSprite = palSpr
    app.command.ChangePixelFormat{ format = "rgb" }
  end
  local img, seen, list = palSpr.cels[1].image, {}, {}
  for it in img:pixels() do
    local px = it()
    if app.pixelColor.rgbaA(px) > 0 and not seen[px] then seen[px] = true; list[#list + 1] = px end
  end
  palSpr:close()
  app.activeSprite = spr
  local pal = Palette(#list + 1)
  pal:setColor(0, Color{ r = 255, g = 0, b = 255, a = 0 })
  for i, px in ipairs(list) do
    pal:setColor(i, Color{ r = app.pixelColor.rgbaR(px), g = app.pixelColor.rgbaG(px), b = app.pixelColor.rgbaB(px), a = 255 })
  end
  spr:setPalette(pal)
  spr.transparentColor = 0
else
  app.command.ColorQuantization{ ui = false, withAlpha = true, maxColors = colors }
end
app.command.ChangePixelFormat{ format = "indexed", dithering = "none" }
spr:saveAs(src:gsub("%.png$", ".aseprite"))
spr:saveCopyAs(src)
print("refined", src, "palette", #spr.palettes[1])

-- Builds art_source/icons_v2/book.aseprite (32x32) from the layer PNGs tools/make_book_outline.py writes.
-- Run from the project root (after the .py):
--   "E:/Aseprite/Aseprite.v1.3.7/Aseprite.v1.3.7/Aseprite.exe" -b --script tools/make_book_outline.lua
-- Layers, bottom to top: pages fill, pages outline, binder fill, binder outline.

local dir = "art_source/icons_v2/"
local layers = { "pages_fill", "pages_line", "binder_fill", "binder_line" }

local spr = Sprite(32, 32, ColorMode.RGB)
for i, lname in ipairs(layers) do
  local layer
  if i == 1 then
    layer = spr.layers[1]
  else
    layer = spr:newLayer()
  end
  layer.name = lname
  local img = Image{ fromFile = dir .. "book_" .. lname .. ".png" }
  spr:newCel(layer, 1, img, Point(0, 0))
end
spr:saveAs(dir .. "book.aseprite")
spr:close()

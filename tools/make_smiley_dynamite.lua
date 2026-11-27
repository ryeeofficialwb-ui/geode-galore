-- Builds art_source/icons_v2/smiley.aseprite and dynamite.aseprite from the layer PNGs that
-- tools/make_smiley_dynamite.py writes. Run from the project root (after the .py):
--   "E:/Aseprite/Aseprite.v1.3.7/Aseprite.v1.3.7/Aseprite.exe" -b --script tools/make_smiley_dynamite.lua
-- 32x32, one layer per part (bottom to top), so each part can be edited on its own.

local dir = "art_source/icons_v2/"
local icons = {
  { name = "smiley", layers = { "outline", "face", "features" } },
  { name = "dynamite", layers = { "outline", "stick", "cap", "fuse", "spark" } },
}

for _, icon in ipairs(icons) do
  local spr = Sprite(32, 32, ColorMode.RGB)
  for i, lname in ipairs(icon.layers) do
    local layer
    if i == 1 then
      layer = spr.layers[1]
    else
      layer = spr:newLayer()
    end
    layer.name = lname
    local img = Image{ fromFile = dir .. icon.name .. "_" .. lname .. ".png" }
    spr:newCel(layer, 1, img, Point(0, 0))
  end
  spr:saveAs(dir .. icon.name .. ".aseprite")
  spr:close()
end

-- Builds art_source/gems/gem_shapes.aseprite from the PNGs make_gem_shapes.py writes:
-- layer "outline" + layer "inner outline", 32x32 grid. Run:
--   Aseprite.exe -b --script-param dir=E:/Geode_Galore/art_source/gems --script tools/gem_shapes_to_aseprite.lua
local dir = app.params.dir
local spr = Sprite{ fromFile = dir .. "/gem_shapes_outer.png" }
spr.layers[1].name = "outline"
local inner = spr:newLayer()
inner.name = "inner outline"
spr:newCel(inner, 1, Image{ fromFile = dir .. "/gem_shapes_inner.png" }, Point(0, 0))
spr.gridBounds = Rectangle(0, 0, 32, 32)
spr:saveAs(dir .. "/gem_shapes.aseprite")

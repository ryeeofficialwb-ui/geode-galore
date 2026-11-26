-- Builds art_source/hands/hands.aseprite from the hand_1..6.png cells (32x32 each, one hand per frame).
-- Run from the project root:
--   "E:/Aseprite/Aseprite.v1.3.7/Aseprite.v1.3.7/Aseprite.exe" -b --script tools/make_hands.lua
local dir = "art_source/hands/"
local COUNT = 6
local spr = Sprite(32, 32, ColorMode.RGB)
spr.filename = dir .. "hands.aseprite"
spr.layers[1].name = "hands"
for i = 2, COUNT do spr:newEmptyFrame(i) end
for i = 1, COUNT do
  spr.frames[i].duration = 0.1
  spr:newCel(spr.layers[1], i, Image{ fromFile = dir .. "hand_" .. i .. ".png" }, Point(0, 0))
end
spr:saveAs(dir .. "hands.aseprite")

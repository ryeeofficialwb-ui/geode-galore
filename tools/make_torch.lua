-- Builds art_source/torch/torch.aseprite from the PNGs tools/make_torch.py writes.
-- Run from the project root (make_torch.py's output must exist first):
--   "E:/Aseprite/Aseprite.v1.3.7/Aseprite.v1.3.7/Aseprite.exe" -b --script tools/make_torch.lua
-- Layers: "stick" (one cel linked across all 8 frames) and "flame" (one cel per frame).
-- 90 ms per frame, about the game's FLAME_FPS of 11.

local dir = "art_source/torch/"
local FRAMES = 8
local MS = 90

local stickImg = Image{ fromFile = dir .. "stick_head.png" }
local spr = Sprite(stickImg.width, stickImg.height, ColorMode.RGB)
spr.filename = dir .. "torch.aseprite"

local stick = spr.layers[1]
stick.name = "stick"
local flame = spr:newLayer()
flame.name = "flame"

for i = 2, FRAMES do spr:newEmptyFrame(i) end
for i = 1, FRAMES do spr.frames[i].duration = MS / 1000 end

local stickCel = spr:newCel(stick, 1, stickImg, Point(0, 0))
for i = 2, FRAMES do
  -- linked cel: same image on every frame, so edits to the stick apply everywhere
  spr:newCel(stick, i, stickCel.image, Point(0, 0))
end
app.range:clear()
app.activeLayer = stick
app.range.layers = { stick }
app.range.frames = (function() local t = {} for i = 1, FRAMES do t[i] = spr.frames[i] end return t end)()
app.command.LinkCels()

for i = 1, FRAMES do
  local img = Image{ fromFile = dir .. "flame_" .. (i - 1) .. ".png" }
  spr:newCel(flame, i, img, Point(0, 0))
end

local tag = spr:newTag(1, FRAMES)
tag.name = "burn"

spr:saveAs(dir .. "torch.aseprite")
print("saved " .. dir .. "torch.aseprite")

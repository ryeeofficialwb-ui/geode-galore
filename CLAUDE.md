# Geode Galore

## Art review rule (always)

Any art Claude generates or edits (sprites, icons, tiles, sheets) must be opened in Aseprite for the
user to review **before** it counts as done, gets wired into the game, or gets committed.

1. Save the result as an `.aseprite` file next to the PNG (layered if the tool builds layers), e.g.
   `"E:/Aseprite/Aseprite.v1.3.7/Aseprite.v1.3.7/Aseprite.exe" -b art.png --save-as art.aseprite`
2. Open it in the Aseprite GUI (not batch mode):
   `powershell.exe -NoProfile -Command "Start-Process -FilePath 'E:/Aseprite/Aseprite.v1.3.7/Aseprite.v1.3.7/Aseprite.exe' -ArgumentList '\"<absolute path>.aseprite\"'"`
3. Tell the user it is open and wait for their pass before going further.

Aseprite: `E:/Aseprite/Aseprite.v1.3.7/Aseprite.v1.3.7/Aseprite.exe`. Python art tools run with `py -3.12`
(it has Pillow; the default `python` does not).

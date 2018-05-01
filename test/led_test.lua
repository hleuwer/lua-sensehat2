local sense = require "sensehat"
local pretty = require "pl.pretty"
local socket = require "socket"
local X = {255, 0, 0}  -- red
local O = {0, 0, 255}  -- blue
print("#1#", sense.colors, sense.colors.white)
local W = sense.colors.white

local function p2s(pixels)
   for k,v in ipairs(pixels) do
   end
end
question_mark = {
   O, O, O, X, X, O, O, O,
   O, O, X, O, O, X, O, O,
   O, O, O, O, O, X, O, O,
   O, O, O, O, X, O, O, O,
   O, O, O, X, O, O, O, O,
   O, O, O, X, O, O, O, O,
   O, O, O, O, O, O, O, O,
   O, O, O, X, O, O, O, O
}

local function printf(fmt, ...)
   print(string.format(fmt, ...))
end
local function ppt(t)
   return pretty.write(t, "", false)
end

local function step(text, nowait)
   printf("==============================")
   printf("STEP: %s", text)
   io.stdin:read()
end

step("Some simple operations", true)
local pix1 = {255,255,255}
printf("pix1 = %s", ppt(pix1))
local s = sense.packPixel(pix1)
printf("0x%02X 0x%02X", s:byte(1,2))
local pix2 = sense.unpackPixel(s)
printf("pix2 = %s", ppt(pix2))

step("Showing question mark")
sense.setPixels(question_mark)

step("Rotation -90 = 270 degree")
sense.setRotation(270, true)

step("Rotation 0 degree")
sense.setRotation(0, true)

step("Load Image")
sense.loadImage("image001.png", true)

step("get low light")
sense.clear(sense.colors.white)
local ll, g = sense.getLowLight()
printf("   result: %s", ll)

step("set low light: true")
sense.setLowLight(true)
ll, g = sense.getLowLight()
printf("   result: %s", ll)

step("set low light: false")
sense.setLowLight(false)
ll, g = sense.getLowLight()
printf("   result: %s", ll)

step("get gamma")
sense.clear(sense.colors.white)
local t = sense.getGamma()
printf("   gamma: %s", pretty.write(t, "", false))

step("gamma reversed")
local r = {}
for i = 1, 32 do
   r[i] = t[33-i]
end
sense.setGamma(r)
local t = sense.getGamma()
printf("   reversed gamma: %s", pretty.write(t, "", false))

step("gamma reverse back")
sense.setGamma(t)
local t = sense.getGamma()
printf("   reversed gamma: %s", pretty.write(t, "", false))

step("gamma reset")
sense.resetGamma()
local t = sense.getGamma()
printf("   resetted  gamma: %s", pretty.write(t, "", false))

step("Show message")
sense.showMessage("Hello World!", 0.02, sense.colors.green, sense.colors.blue)

step("Show letter 'P'")
local pixels = sense.getLetterMap("P")
sense.showLetter("P", sense.colors.blue, sense.colors.black)

step("Rotate by 90")
sense.setRotation(90, true)

step("Rotate back to 0")
sense.setRotation(0, true)

step("Flip H")
sense.flipH()

step("Flip back")
sense.flipH()

step("Flip V")
sense.flipV()

step("Flip back")
sense.flipV()

step("Flip often")
for i = 1, 100 do
   sense.flipH()
end

step("Setting 3 pixels")
sense.clear()
sense.setPixel(0, 0, {255, 0, 0})
sense.setPixel(1, 1, {0, 255, 0})
sense.setPixel(2, 2, {0, 0, 255})
local pix = sense.getPixel(0, 0) printf("pix=%s", ppt(pix))
local pix = sense.getPixel(1, 1) printf("pix=%s", ppt(pix))
local pix = sense.getPixel(2, 2) printf("pix=%s", ppt(pix))

step("Set single pixels in different colors")
for k = 0,255,5 do
   for i = 0, 7 do
      for j = 0, 7 do
         sense.setPixel(i,j,k,0,k)
      end
   end
end

--   os.execute("sleep 1")
--   printf("clear with red")
--   clear{255, 0, 0}
for name, color in pairs(sense.colors) do
   step("Clear with color " .. name)
   local rgb = sense.packPixel(color)
   printf("color=%s %s %02x %02x", name, ppt(color), rgb:byte(1,2))
   sense.clear(color)
end

step("Show Letter 'A' in blue")
sense.showLetter("A", sense.colors.blue, sense.colors.black)

step("Shos Letter '9' w/o color spec")
sense.showLetter("9")

step("Rotate 90right")
sense.setRotation(90)

step("Rotate left")
sense.setRotation(0)

step("Show all letters")
--printf("letterMap: %s", pretty.write(sense.letterMap, "", false))
for k, v in pairs(sense.getLetterMap()) do
   if #v == 40 then
      sense.showLetter(k)
      socket.sleep(0.01)
   else
      printf("ups wrong size for %q: %d", k, #v)
   end
end

if false then
   step("Show any Letter")
   while true do
      io.stdout:write("key > ") io.stdout:flush()
      local s = io.stdin:read()
      if s == "quit" then
         break
      end
      if s ~= "" then
         sense.showLetter(s, sense.colors.green, sense.colors.black)
      end
   end
end

step("Finally - DARK !")
sense.clear(0, 0, 0)

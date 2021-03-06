local sense = require "sensehat"
local socket = require "socket"

local pixels = {
    {255, 0, 0}, {255, 0, 0}, {255, 87, 0}, {255, 196, 0}, {205, 255, 0}, {95, 255, 0}, {0, 255, 13}, {0, 255, 122},
    {255, 0, 0}, {255, 96, 0}, {255, 205, 0}, {196, 255, 0}, {87, 255, 0}, {0, 255, 22}, {0, 255, 131}, {0, 255, 240},
    {255, 105, 0}, {255, 214, 0}, {187, 255, 0}, {78, 255, 0}, {0, 255, 30}, {0, 255, 140}, {0, 255, 248}, {0, 152, 255},
    {255, 223, 0}, {178, 255, 0}, {70, 255, 0}, {0, 255, 40}, {0, 255, 148}, {0, 253, 255}, {0, 144, 255}, {0, 34, 255},
    {170, 255, 0}, {61, 255, 0}, {0, 255, 48}, {0, 255, 157}, {0, 243, 255}, {0, 134, 255}, {0, 26, 255}, {83, 0, 255},
    {52, 255, 0}, {0, 255, 57}, {0, 255, 166}, {0, 235, 255}, {0, 126, 255}, {0, 17, 255}, {92, 0, 255}, {201, 0, 255},
    {0, 255, 66}, {0, 255, 174}, {0, 226, 255}, {0, 117, 255}, {0, 8, 255}, {100, 0, 255}, {210, 0, 255}, {255, 0, 192},
    {0, 255, 183}, {0, 217, 255}, {0, 109, 255}, {0, 0, 255}, {110, 0, 255}, {218, 0, 255}, {255, 0, 183}, {255, 0, 74}
}

local function nextColor(pix)
   local r,g,b = pix[1],pix[2],pix[3]
   if r == 255 and g < 255 and b == 0 then g = g + 1 end
   if g == 255 and r > 0 and b == 0 then r = r - 1 end
   if g == 255 and b < 255 and r == 0 then b = b + 1 end
   if b == 255 and g > 0 and r == 0 then g = g - 1 end
   if b == 255 and r < 255 and g == 0 then r = r + 1 end
   if r == 255 and b > 0 and g == 0 then b = b - 1 end
   pix[1],pix[2],pix[3] = r, g, b
--   return {r,g,b}
end

while true do
   for i, pix in ipairs(pixels) do
      nextColor(pix)
     -- pixels[i] = nextColor(pix)
   end
   sense.setPixels(pixels)
   socket.sleep(0.001)
end

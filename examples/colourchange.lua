local sense = require "sensehat2"
local socket = require "socket"

local r,g,b = 255,0,0

local function nextColor()
   if r == 255 and g < 255 and b == 0 then g = g + 1 end
   if g == 255 and r > 0 and b == 0 then r = r - 1 end
   if g == 255 and b < 255 and r == 0 then b = b + 1 end
   if b == 255 and g > 0 and r == 0 then g = g - 1 end
   if b == 255 and r < 255 and g == 0 then r = r + 1 end
   if r == 255 and b > 0 and g == 0 then b = b - 1 end
end

while true do
   sense.clear{r,g,b}
   socket.sleep(0.002)
   nextColor()
end

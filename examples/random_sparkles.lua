local sense = require "sensehat"
local socket = require "socket"
local random = math.random

math.randomseed(os.time())
while true do
   x = random(0,7)
   y = random(0,7)
   r = random(0,255)
   g = random(0,255)
   b = random(0,255)
   sense.setPixel(x,y,{r,g,b})
   socket.sleep(0.01)
end

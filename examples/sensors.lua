sense = require "sensehat"

local sense = require "sensehat"
local fmt = string.format

local stemp = 0
local N = tonumber(arg[1]) or 1000

print("=== SENSORS ===")
print(fmt("relative humidity: %.2f %%", sense.getHumidity()))
print(fmt("pressure         : %.2f mbar", sense.getPressure()))
print(fmt("temperature      : %.2f °C", sense.getTemperature()))
print(fmt("  from mhumidity : %.2f °C", sense.getTemperatureFromHumidity()))
print(fmt("  from pressure  : %.2f °C", sense.getTemperatureFromPressure()))
t1 = os.time()
for i = 1, N do
	local temp = sense.getTemperature()
	stemp = stemp + temp
end
local t2 = os.time()
local dt = (t2 - t1)*1000/N
print(fmt("average temp.    : %.2f °C", stemp/N))
print(fmt("samples: %d time: %d sec speed: %.3f msec", N, t2 - t1, dt))


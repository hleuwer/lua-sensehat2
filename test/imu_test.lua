sense = require "sensehat"
local socket = require "socket"
local function printf(fmt, ...)
   print(string.format(fmt, ...))
end

print("=== IMU ===")
--sense.initImu()
--sense.configImu(true, true, true)
local perftest = (os.getenv("perf") or "no") == "yes"
local perftype = os.getenv("type")
local N = tonumber(os.getenv("N"))
if perftest == true then
   local sum = 0
   local t1 = os.time()
   for i = 1, N do
      if perftype == "compass-raw" then
         local val = sense.getCompassRaw().x
         sum = sum + val
      elseif perftype == "gyro-raw" then
         local val = sense.getGyroscopeRaw().x
         sum = sum + val
      elseif perftype == "accel-raw" then
         local val = sense.getAccelerometerRaw().x
         sum = sum + val
      end
   end
   local t2 = os.time()
   printf("performance %q: mean = %.3f (%d values) dt=%d sec time=%.2f msec", perftype, sum/N, N, t2-t1, (t2-t1)*1000/N) 
end
local orientation_rad = sense.getOrientationRadians()
printf("orientation: %s rad", tostring(orientation_rad))
printf("      roll : %.4f rad", orientation_rad.roll)
printf("      pitch: %.4f rad", orientation_rad.pitch)
printf("      yaw  : %.4f rad", orientation_rad.yaw)
print()
local orientation_deg = sense.getOrientationDegrees()
printf("orientation: %s deg", tostring(orientation_deg))
printf("      roll : %.2f deg", orientation_deg.roll)
printf("      pitch: %.2f deg", orientation_deg.pitch)
printf("      yaw  : %.2f deg", orientation_deg.yaw)
print()

printf("compass: %.2f deg", sense.getCompass())
print()

local compass_raw = sense.getCompassRaw()
printf("compass raw: %s uTesla", tostring(compass_raw))
printf("          x: %.4f uTesla", compass_raw.x)
printf("          y: %.4f uTesla", compass_raw.y)
printf("          z: %.4f uTesla", compass_raw.z)
print()

local gyro = sense.getGyroscope()
printf("gyroscope: %s deg", tostring(gyro))
printf("    roll : %.2f deg", gyro.roll)
printf("    pitch: %.2f deg", gyro.pitch)
printf("    yaw  : %.2f deg", gyro.yaw)
print()

local gyro_raw = sense.getGyroscopeRaw()
printf("gyroscope raw: %s rad/s", tostring(gyro_raw))
printf("            x: %.4f rad/s", gyro_raw.x)
printf("            y: %.4f rad/s", gyro_raw.y)
printf("            z: %.4f rad/s", gyro_raw.z)
print()


local accel = sense.getAccelerometer()
printf("accelerometer: %s deg", tostring(accel))
printf("        roll : %.2f deg", accel.roll)
printf("        pitch: %.2f deg", accel.pitch)
printf("        yaw  : %.2f deg", accel.yaw)
print()

local accel_raw = sense.getAccelerometerRaw()
printf("accelerometer raw: %s G", tostring(accel_raw))
printf("                x: %.4f G", accel_raw.x)
printf("                y: %.4f G", accel_raw.y)
printf("                z: %.4f G", accel_raw.z)
print()



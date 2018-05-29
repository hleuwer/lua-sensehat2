MODULE=sensehat.lua
SNMPEXTENSION=senseHat
RTIMUBINDING=rtimu.so
LETTER_T=etc/sense_hat_text.txt
LETTER_P=etc/sense_hat_text.png
LEDOFF=ledoff
LUAV=5.2
INSTALL_LUA=/usr/local/share/lua/$(LUAV)
INSTALL_BIN=/usr/local/bin
INSTALL_LIB=/usr/local/lib/lua/$(LUAV)
INSTALL_SHARE=/usr/local/share/sense_hat

doc::
	ldoc sensehat.lua

install:
	cp $(MODULE) $(INSTALL_LUA)
	cp $(SNMPEXTENSION) $(INSTALL_BIN)
	cp $(LEDOFF) $(INSTALL_BIN)
	mkdir -p $(INSTALL_SHARE) && cp $(LETTER_T) $(INSTALL_SHARE)
	cp $(LETTER_P) $(INSTALL_SHARE)

uninstall:
	rm -rf $(INSTALL_LUA)/$(MODULE)
	rm -rf $(INSTALL_BIN)/$(SNMPEXTENSION)
	rm -rf $(INSTALL_BIN)/$(LEDOFF)

install-so:
	cp etc/$(RTIMUBINDING) $(INSTALL_LIB)

clean:
	rm -rf `find . -name "*~"`

test-led:
	lua test/led_test.lua

test-imu:
	lua test/imu_test.lua

test-joy:
	lua test/joy_test.lua

test-sensor:
	lua test/sensor_test.lua

test::
	$(MAKE) test-led
	$(MAKE) test-imu
	$(MAKE) test-sensor
	$(MAKE) test-joy

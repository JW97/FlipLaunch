include theos/makefiles/common.mk

TWEAK_NAME = FlipLaunch
FlipLaunch_FILES = Tweak.xm
FlipLaunch_FRAMEWORKS = UIKit CoreGraphics
FlipLaunch_LIBRARIES = flipswitch

ARCHS = armv7 armv7s arm64

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
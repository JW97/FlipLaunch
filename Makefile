include theos/makefiles/common.mk

TWEAK_NAME = FlipLaunch
FlipLaunch_FILES = Tweak.xm
FlipLaunch_FRAMEWORKS = UIKit CoreGraphics
FlipLaunch_LIBRARIES = flipswitch

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

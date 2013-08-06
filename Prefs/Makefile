include theos/makefiles/common.mk

BUNDLE_NAME = FlipLaunch
FlipLaunch_FILES = FlipLaunch.mm
FlipLaunch_INSTALL_PATH = /Library/PreferenceBundles
FlipLaunch_FRAMEWORKS = UIKit
FlipLaunch_PRIVATE_FRAMEWORKS = Preferences
FlipLaunch_LIBRARIES = applist

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/FlipLaunch.plist$(ECHO_END)

#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <libflipswitch/Flipswitch.h>

@interface SBApplication : NSObject
- (NSString *)displayName;
@end

@interface SBApplicationController : NSObject
+ (SBApplicationController *)sharedInstance;
- (SBApplication *)applicationWithDisplayIdentifier:(NSString *)identifier;
@end

@interface SBIcon : NSObject
- (UIImage *)getIconImage:(int)format;
@end

@interface SBIconModel : NSObject
+ (SBIconModel *)sharedInstance;
- (id)applicationIconForDisplayIdentifier:(NSString *)identifier;
@end

@interface SBIconViewMap : NSObject
+ (SBIconViewMap *)switcherMap;
+ (SBIconViewMap *)homescreenMap;
- (SBIconModel *)iconModel;
@end

@interface SBUIController : NSObject
+ (SBUIController *)sharedInstance;
- (void)activateApplicationFromSwitcher:(id)application;
@end

@interface FLDataSource : NSObject <FSSwitchDataSource>
{
	NSMutableArray *launchIDs;
}

+ (FLDataSource *)sharedInstance;
- (id)init;
- (void)registerAllApplicationIDsWithFS;
- (void)registerApplicationIDWithFS:(NSString *)applicationID;
@end

#define kBundleID @"com.jw97.fliplaunch"
#define kPrefsPath @"/var/mobile/Library/Preferences/com.jw97.fliplaunch.plist"

static NSString *applicationIDFromFSID(NSString *flipswitchID)
{
	return [flipswitchID stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@-", kBundleID] withString:@""];
}

static SBApplication *applicationForID(NSString *applicationID)
{
	return [[objc_getClass("SBApplicationController") sharedInstance] applicationWithDisplayIdentifier:applicationID];
}

static SBApplication *applicationForFSID(NSString *flipswitchID)
{
	return applicationForID(applicationIDFromFSID(flipswitchID));
}

@implementation FLDataSource

+ (instancetype)sharedInstance
{
    static FLDataSource *_sharedFactory;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _sharedFactory = [[self alloc] init];
    });

    return _sharedFactory;
}

- (id)init
{
	if ((self = [super init]))
	{
		launchIDs = [[NSDictionary dictionaryWithContentsOfFile:kPrefsPath] objectForKey:@"launchIDs"];
		[self registerAllApplicationIDsWithFS];
	}
	return self;
}

- (void)dealloc
{
	[launchIDs release];
	[super dealloc];
}

- (void)registerAllApplicationIDsWithFS
{
	for (NSString *applicationID in launchIDs)
	{
		[self registerApplicationIDWithFS:applicationID];
	}
}

- (void)registerApplicationIDWithFS:(NSString *)applicationID
{
	NSString *switchIdentifier = [NSString stringWithFormat:@"%@-%@", kBundleID, applicationID];

	if (![[[FSSwitchPanel sharedPanel] switchIdentifiers] containsObject:switchIdentifier] && applicationForFSID(switchIdentifier) != nil)
	{
		[[FSSwitchPanel sharedPanel] registerDataSource:self forSwitchIdentifier:switchIdentifier];
	}
}

//FS Methods
- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
	return [applicationForFSID(switchIdentifier) displayName];
}

- (id)glyphImageDescriptorOfState:(FSSwitchState)switchState size:(CGFloat)size scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier
{
	//TODO: Add Category based Glyphs, A La Axis
	
    return nil;
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return FSSwitchStateOn;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
	SBApplication *launchApp = applicationForFSID(switchIdentifier);
	if (launchApp != nil) [[objc_getClass("SBUIController") sharedInstance] activateApplicationFromSwitcher:launchApp];
}

@end

%ctor
{
	[FLDataSource sharedInstance];
}
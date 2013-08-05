#import <objc/runtime.h>
#import <libkern/OSAtomic.h>
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
	NSMutableDictionary *prefsDict;
	NSMutableArray *launchIDs;

	OSSpinLock spinLock;
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
		prefsDict = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefsPath] ?: [NSMutableDictionary dictionary];
		launchIDs = [prefsDict objectForKey:@"launchIDs"] ?: [NSMutableArray array];
	}
	return self;
}

- (void)dealloc
{
	[prefsDict release];
	[super dealloc];
}

- (void)registerAllApplicationIDsWithFS
{
	OSSpinLockLock(&spinLock);
	for (NSString *applicationID in launchIDs)
	{
		[self registerApplicationIDWithFS:applicationID];
	}
	OSSpinLockUnlock(&spinLock);
}

- (void)registerApplicationIDWithFS:(NSString *)applicationID
{
	NSString *switchIdentifier = [NSString stringWithFormat:@"%@-%@", kBundleID, applicationID];

	if (![[[FSSwitchPanel sharedPanel] switchIdentifiers] containsObject:switchIdentifier] && applicationForFSID(switchIdentifier) != nil)
	{
		[[FSSwitchPanel sharedPanel] registerDataSource:self forSwitchIdentifier:switchIdentifier];
	}
}

- (void)addNewLaunchID:(NSString *)applicationID
{
	if (applicationID == nil || applicationForID(applicationID) == nil) return;

	[self registerApplicationIDWithFS:applicationID];

	OSSpinLockLock(&spinLock);
	if (![launchIDs containsObject:applicationID]) [launchIDs addObject:applicationID];
	[prefsDict setObject:launchIDs forKey:@"launchIDs"];
	[prefsDict writeToFile:kPrefsPath atomically:YES];
	OSSpinLockUnlock(&spinLock);
}

//FS Methods
- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier
{
	return [applicationForFSID(switchIdentifier) displayName];
}

- (id)glyphImageDescriptorOfState:(FSSwitchState)switchState size:(CGFloat)size scale:(CGFloat)scale forSwitchIdentifier:(NSString *)switchIdentifier
{
	//TODO: Add Category based Glyphs, A La Axis
	//Meanwhile draw first two letters of App Name

	SBApplication *application = applicationForFSID(switchIdentifier);
	NSString *applicationName = [application displayName];
	NSString *drawName = [applicationName substringToIndex:2];

	CGSize contextSize = CGSizeMake(size, size);
	UIGraphicsBeginImageContextWithOptions(contextSize, NO, scale);

	[[UIColor whiteColor] set];

	int fontSize = size - 5;
	UIFont *font = [UIFont systemFontOfSize:fontSize];
	CGSize drawSize = [drawName sizeWithFont:font];
	CGPoint drawPoint = CGPointMake(roundf(contextSize.width / 2.0f - (drawSize.width / 2.0f)), roundf(contextSize.height / 2.0f - (drawSize.height / 2.0f)));
	[drawName drawAtPoint:drawPoint withFont:font];

	UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return finalImage;
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
	[[NSNotificationCenter defaultCenter] addObserver:[FLDataSource sharedInstance] selector:@selector(registerAllApplicationIDsWithFS) name:UIApplicationDidFinishLaunchingNotification object:nil];
}
#import <objc/runtime.h>
#import <libkern/OSAtomic.h>
#import <UIKit/UIKit.h>
#import <libflipswitch/Flipswitch.h>

@interface SBApplication : NSObject
- (NSString *)displayName;
- (NSString *)bundleIdentifier;
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
- (void)addNewLaunchID:(NSString *)applicationID;
- (void)reloadLaunchIDs;
@end

#define kBundleID @"com.jw97.fliplaunch"
#define kPDFsPath @"/var/mobile/Library/FlipLaunch"
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

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{    
    [(FLDataSource *)observer reloadLaunchIDs];
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
		prefsDict = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefsPath] ?: [[NSMutableDictionary alloc] init];
		launchIDs = [prefsDict objectForKey:@"launchIDs"] ?: [NSMutableArray array];

		BOOL isDirectory = YES;
        if (![[NSFileManager defaultManager] fileExistsAtPath:kPDFsPath isDirectory:&isDirectory]) [[NSFileManager defaultManager] createDirectoryAtPath:kPDFsPath withIntermediateDirectories:YES attributes:nil error:nil];

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), self, PreferencesChangedCallback, CFSTR("com.jw97.fliplaunch.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	}
	return self;
}

- (void)dealloc
{
	[prefsDict release];
	[super dealloc];
}

- (void)reloadLaunchIDs
{
	[prefsDict release];
	prefsDict = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefsPath] ?: [[NSMutableDictionary alloc] init];
	launchIDs = [prefsDict objectForKey:@"launchIDs"] ?: [NSMutableArray array];
	[self registerAllApplicationIDsWithFS];
}

- (void)registerAllApplicationIDsWithFS
{
	OSSpinLockLock(&spinLock);
	for (NSString *applicationID in launchIDs)
	{
		//[self registerApplicationIDWithFS:applicationID];
		[self performSelectorOnMainThread:@selector(registerApplicationIDWithFS:) withObject:applicationID waitUntilDone:YES];
	}

	NSArray *currentPDFs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:kPDFsPath error:nil];
    for (NSString *pdf in currentPDFs)
    {
    	if (![launchIDs containsObject:pdf]) [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", kPDFsPath, pdf] error:nil];
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
	NSString *filePath = [NSString stringWithFormat:@"%@/%@.pdf", kPDFsPath, [application bundleIdentifier]];

    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) return filePath;

	//Create PDF
	NSString *applicationName = [application displayName];
	NSString *drawName = [applicationName substringToIndex:2];

	CGRect pageRect = (CGRect){CGPointZero, {96, 96}};
    
    CFStringRef path = (CFStringRef)filePath;
    CFURLRef url = CFURLCreateWithFileSystemPath(NULL, path, kCFURLPOSIXPathStyle, 0);

    CFMutableDictionaryRef optionsDict = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CGContextRef pdfContext = CGPDFContextCreateWithURL(url, &pageRect, optionsDict);
    CFRelease(optionsDict);
    CFRelease(url);

    CGContextBeginPage(pdfContext, &pageRect);
    
    int fontSize = pageRect.size.height - 27;
    CGSize textSize = [drawName sizeWithFont:[UIFont systemFontOfSize:fontSize]];
    
    CGContextSelectFont(pdfContext, "Helvetica-Bold", fontSize, kCGEncodingMacRoman);
    CGContextSetTextDrawingMode(pdfContext, kCGTextFill);
    CGContextSetRGBFillColor(pdfContext, 0, 0, 0, 1);
    const char *text = [drawName UTF8String];
    CGContextShowTextAtPoint(pdfContext, pageRect.size.width / 2.0f - (textSize.width / 2.0f), pageRect.size.height / 2.0f - (fontSize / 3.0f), text, strlen(text));

    CGContextEndPage (pdfContext);
    CGContextRelease (pdfContext);

    return filePath;
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
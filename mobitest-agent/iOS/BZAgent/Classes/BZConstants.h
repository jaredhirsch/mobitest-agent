//
//  BZConstants.h
//  BZAgent
//
//  Created by Joshua Tessier on 10-11-17.
//  Copyright 2010 Blaze. All rights reserved.
//

//Debugging constants
#define BZ_DEBUG_REQUESTS 0
#define BZ_DEBUG_JOB 0
#define BZ_DEBUG_JOB_PARSING 0
#define BZ_DEBUG_HAR_PARSING 0
#define BZ_DEBUG_PRINT_HAR 0

//Notification Constants
#define BZNewJobReceivedNotification @"BZNewJobReceivedNotification"
#define BZNoJobsNotification @"BZNoJobsNotification"
#define BZFailedToGetJobsNotification @"BZFailedToGetJobsNotification"

#define BZJobUploadedNotification @"BZJobUploadedNotification"
#define BZFailedToUploadJobNotification @"BZFailedToUploadJobNotification"

//Data gathering notification constants
#define BZDataReceivedNotification @"BZDataReceivedNotification"
#define BZWebViewDrawRect @"BZWebViewDrawRect"
#define BZDataReceivedReq @"BZDataReceivedReq"
#define BZDataReceivedDataLength @"BZDataReceivedDataLength"
#define BZResponseReceivedNotification @"BZResponseReceivedNotification"
#define BZPassDataSourceNotification @"BZPassDataSourceNotification"
#define BZPassWebViewPrivateNotification @"BZPassWebViewPrivateNotification"

//Notification constants
#define BZResponse @"BZResponse"

#define kBZLoadCallback @"bzAgent://load"

extern const NSString *BZDateFormat;

extern const NSString *BZTestIdKey;
extern const NSString *BZURLKey;
extern const NSString *BZDOMElementKey;
extern const NSString *BZFVOnlyKey;
extern const NSString *BZImageQualityKey;
extern const NSString *BZObjectKey;
extern const NSString *BZImagesMey;
extern const NSString *BZEventNameKey;
extern const NSString *BZWeb10Key;
extern const NSString *BZIgnoreSSLKey;
extern const NSString *BZConnectionsKey;
extern const NSString *BZSpeedKey;
extern const NSString *BZHarvestLinksKey;
extern const NSString *BZHarvestCookiesKey;
extern const NSString *BZSaveHTMLKey;
extern const NSString *BZBlockKey;
extern const NSString *BZBasicAuthKey;
extern const NSString *BZRunsKey;
extern const NSString *BZCaptureVideoKey;
extern const NSString *BZBandwidthInKey;
extern const NSString *BZBandwidthOutKey;
extern const NSString *BZLatencyKey;
extern const NSString *BZPLRKey;
extern const NSString *BZHostKey;
extern const NSString *BZUserKey;
extern const NSString *BZPasswordKey;

//Settings Bundle Keys
//URL Files URL
#define kBZJobsURL1SettingsKey @"bz-jobs-url1"
#define kBZJobsURL2SettingsKey @"bz-jobs-url2"
#define kBZJobsURL3SettingsKey @"bz-jobs-url3"
#define kBZJobsURL4SettingsKey @"bz-jobs-url4"
#define kBZJobsAgentNameSettingsKey @"bz-jobs-agent-name"
#define kBZJobsLocationSettingsKey @"bz-jobs-location"
#define kBZJobsLocationKeySettingsKey @"bz-jobs-location-key"
#define kBZJobsFetchTime @"bz-jobs-fetch-time"
#define kBZAutoPollSettingsKey @"bz-auto-poll"
#define kBZRestartAfterJobSettingsKey @"bz-restart-after-job"
#define kBZMaxOfflineSecsSettingsKey @"bz-max-offline-secs"

//FPS
#define kBZFPSSettingsKey @"bz-fps"

//Image Quality parameters
#define kBZImageVideoQualitySettingsKey @"bz-vid-jpg-quality"
#define kBZImageCheckpointQualitySettingsKey @"bz-chkpoint-jpg-quality"
#define kBZImageResizeRatioSettingsKey @"bz-jpg-size"

//Timeout
#define kBZTimeoutSettingsKey @"bz-timeout"

//Headers
#define kBZUserAgentSettingsKey @"bz-user-agent"
#define kBZAcceptSettingsKey @"bz-accept"
#define kBZAcceptEncodingSettingsKey @"bz-accept-encoding"
#define kBZAcceptLanguageSettingsKey @"bz-accept-language"
#define kBZScreenSaverSettingsKey @"bz-screen-saver"

//Layout Constants
#define kBZLeftSidePadding 15
#define kBZTopPadding 15

//Image Constants
#define kBZBackground @"noise_pattern.png"
#define kBZDisabledImage @"disabled.png"
#define kBZPollingImage @"polling.png"
#define kBZWaitingImage @"waiting.png"
#define kBZUploadingImage @"upload.png"
#define kBZBrandingImage @"blaze_logo.png"

#define kBZPollButton @"poll_button.png"
#define kBZPollButtonPressed @"poll_button_pressed.png"

//Other constants
#define kBZJobsErrorKey @"bz-error-key"
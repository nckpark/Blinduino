//
//  ViewController.m
//  Blinduino
//
//  Created by Nick Park on 6/24/14.
//  Copyright (c) 2014 Nick Park. All rights reserved.
//

#import "ViewController.h"
#import "BlinduinoDeviceInterface.h"

#define INITIAL_ALARM_HOUR 8
#define INITIAL_ALARM_MINUTE 0

#define FALLBACK_SUNRISE_HOUR 7
#define FALLBACK_SUNSET_HOUR 20

#define CLOCK_INCREMENT_MINS 15
#define CLOCK_PAN_VELOCITY_THRESHOLD 300.0f
#define CLOCK_PAN_DISTANCE_THRESHOLD 20.0f

#define DAYLIGHT_ANIMATION_DURATION 0.5f
#define FADE_ANIMATION_DURATION 0.5f
#define ZOOM_ANIMATION_DURATION 0.25f
#define STATUS_ICON_DISPLAY_DURATION 2.0f
#define DEGREES_TO_RADIANS(angle) ((angle) / 180.0 * M_PI)

@interface ViewController ()

// UI Elements
@property (weak, nonatomic) IBOutlet UILabel *alarmClockLabel;
@property (weak, nonatomic) IBOutlet UIImageView *sunIcon;
@property (weak, nonatomic) IBOutlet UIImageView *moonIcon;
@property (weak, nonatomic) IBOutlet UIButton *openBlindsButton;
@property (weak, nonatomic) IBOutlet UIButton *closeBlindsButton;
@property (weak, nonatomic) IBOutlet UILabel *openCloseLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *requestActivityIndicator;
@property (weak, nonatomic) IBOutlet UIImageView *requestSucceededIcon;
@property (weak, nonatomic) IBOutlet UIImageView *requestFailedIcon;

// Private Variables
@property (strong, nonatomic) NSDateComponents *alarmTimeComponents;
@property (strong, nonatomic) NSCalendar *localCalendar;
@property (nonatomic) CGFloat lastClockChangePanXPos;

@property (strong, nonatomic) LocalSunTimesHelper *sunTimesHelper;
@property (nonatomic) CGPoint displayDaylightIconPosition;
@property (nonatomic) CGPoint hideDaylightIconPosition;
@property (strong, nonatomic) CAKeyframeAnimation* enterSceneAnimation;
@property (strong, nonatomic) CAKeyframeAnimation* exitSceneAnimation;

// Private Methods
- (void)incrementAlarmTimeBy:(NSInteger)minutes;
- (NSDate *)nextDateTimeFor:(NSDateComponents *)hrMinComponents;
- (void)updateClockUI;

- (void)placeDaylightIcons;
- (void)initializeDaylightAnimation;
- (void)updateDaylightAnimation;

- (void)showRequestPendingUI;
- (void)restoreOpenCloseUI;
- (void)handleRequestSucceededNotification:(NSNotification *)notification;
- (void)handleRequestFailedNotification:(NSNotification *)notification;

- (void)fadeViews:(NSArray *)views toAlpha:(CGFloat)alpha withDuration:(CGFloat)duration;
- (void)zoomInIcon:(UIImageView *)icon withDuration:(CGFloat)duration onCompletion:(void (^)(BOOL finished))completion;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self initializeDaylightAnimation];
    
    // Initialize vars for tracking clock panning
    self.lastClockChangePanXPos = 0.0f;
    
    // Subscribe to request status notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRequestSucceededNotification:)
                                                 name:(NSString *)BlinduinoRequestSucceededNotification
                                               object:[BlinduinoDeviceInterface sharedInstance]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRequestFailedNotification:)
                                                 name:(NSString *)BlinduinoRequestFailedNotification
                                               object:[BlinduinoDeviceInterface sharedInstance]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self placeDaylightIcons];
    [self updateClockUI];
}

- (void)didReceiveMemoryWarning
{
    [self.sunTimesHelper clearCache];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/* Getters + Setters */

- (NSCalendar *)localCalendar
{
    if (_localCalendar == nil) {
        _localCalendar = [NSCalendar autoupdatingCurrentCalendar];
    }
    return _localCalendar;
}

- (NSDateComponents *)alarmTimeComponents
{
    if (_alarmTimeComponents == nil) {
        // Initialize unset alarm time to 8 AM by default
        _alarmTimeComponents = [[NSDateComponents alloc] init];
        [_alarmTimeComponents setHour:INITIAL_ALARM_HOUR];
        [_alarmTimeComponents setMinute:INITIAL_ALARM_MINUTE];
    }
    return _alarmTimeComponents;
}

- (LocalSunTimesHelper *)sunTimesHelper
{
    if (_sunTimesHelper == nil) {
        _sunTimesHelper = [[LocalSunTimesHelper alloc] init];
        // Initialize fallback sunrise / sunset times in case location services are unavailable
        NSDateComponents *sunriseComponents = [[NSDateComponents alloc] init];
        [sunriseComponents setHour:FALLBACK_SUNRISE_HOUR];
        NSDateComponents *sunsetComponents = [[NSDateComponents alloc] init];
        [sunsetComponents setHour:FALLBACK_SUNSET_HOUR];
        [_sunTimesHelper setFallbackSunriseTime:sunriseComponents andSunsetTime:sunsetComponents];
    }
    return _sunTimesHelper;
}

/* UI Action Handlers */

- (IBAction)openBlinds:(id)sender
{
    if ([[BlinduinoDeviceInterface sharedInstance] openBlinds]) {
        [self showRequestPendingUI];
    }
    else {
        [self handleRequestFailedNotification:nil];
    }
}

- (IBAction)closeBlinds:(id)sender
{
    if ([[BlinduinoDeviceInterface sharedInstance] closeBlinds]) {
        [self showRequestPendingUI];
    }
    else {
        [self handleRequestFailedNotification:nil];
    }
}

- (IBAction)setAlarm:(id)sender
{
    // Sets the device open alarm to the next occurrence of the time selected in the UI.
    
    NSDate *alarmDateTime = [self nextDateTimeFor:self.alarmTimeComponents];
    if ([[BlinduinoDeviceInterface sharedInstance] setOpenTime:alarmDateTime]) {
        [self showRequestPendingUI];
    }
    else {
        [self handleRequestFailedNotification:nil];
    }
}

- (IBAction)clockPanGestureRecognized:(UIPanGestureRecognizer *)sender
{
    CGFloat currentPanXPos = [sender translationInView:self.view].x;
    CGFloat panSinceLastClockChange = abs(currentPanXPos - self.lastClockChangePanXPos);
    CGFloat horizontalVelocity = [sender velocityInView:self.view].x;
    
    if (panSinceLastClockChange > CLOCK_PAN_DISTANCE_THRESHOLD) {
        NSInteger incrementMinutes = CLOCK_INCREMENT_MINS;
        NSInteger incrementMultiplier = ceilf(fabsf(horizontalVelocity / CLOCK_PAN_VELOCITY_THRESHOLD));
        if (horizontalVelocity > 0) {
            incrementMultiplier *= -1;
        }
        incrementMinutes *= incrementMultiplier;

        [self incrementAlarmTimeBy:incrementMinutes];
        [self updateClockUI];
        
        self.lastClockChangePanXPos = currentPanXPos;
    }
}

/* Private Methods */

- (void)incrementAlarmTimeBy:(NSInteger)minutes
{
    NSDateComponents *incrementComponents = [[NSDateComponents alloc] init];
    [incrementComponents setMinute: minutes];
    
    NSDate *currentAlarmTime = [self.localCalendar dateFromComponents:self.alarmTimeComponents];
    NSDate *updatedAlarmTime = [self.localCalendar dateByAddingComponents:incrementComponents toDate:currentAlarmTime options:0];
    
    self.alarmTimeComponents = [self.localCalendar components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:updatedAlarmTime];
}

- (NSDate *)nextDateTimeFor:(NSDateComponents *)hrMinComponents
{
    NSDateComponents *dateComponents = [self.localCalendar components:(NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear)
                                                             fromDate:[NSDate date]];
    [dateComponents setHour:hrMinComponents.hour];
    [dateComponents setMinute:hrMinComponents.minute];
    NSDate *nextDateTime = [self.localCalendar dateFromComponents:dateComponents];
    
    // The alarm should be for the next occurence of the selected time. Either today or tomorrow depending on the current time.
    NSDate *now = [NSDate date];
    if (now == [now laterDate:nextDateTime]) {
        NSDateComponents *oneDay = [[NSDateComponents alloc] init];
        [oneDay setDay:1];
        nextDateTime = [self.localCalendar dateByAddingComponents:oneDay toDate:nextDateTime options:0];
    }
    
    return nextDateTime;
}

- (void)updateClockUI
{
    NSString *amPM = (self.alarmTimeComponents.hour < 12 ? @"AM" : @"PM");
    NSInteger twelveHrAdjustment = (self.alarmTimeComponents.hour > 12 ? 12 : 0);
    if (self.alarmTimeComponents.hour == 0) {
        twelveHrAdjustment = -12;
    }
    NSString *updatedClockText = [NSString stringWithFormat:@"%ld:%02ld %@", (long)self.alarmTimeComponents.hour - twelveHrAdjustment, (long)self.alarmTimeComponents.minute, amPM];
    [self.alarmClockLabel setText:updatedClockText];
    
    [self updateDaylightAnimation];
}

- (void)initializeDaylightAnimation
{
    // Establish display/hide positions and animation arc properties
    CGFloat animationArcRadius = 88.0f;
    self.displayDaylightIconPosition = self.sunIcon.center;
    CGPoint animationArcCenter = CGPointMake(self.displayDaylightIconPosition.x, self.displayDaylightIconPosition.y + animationArcRadius);
    self.hideDaylightIconPosition = CGPointMake(animationArcCenter.x, animationArcCenter.y + animationArcRadius);
    
    // Create a entry + exit animation paths
    self.enterSceneAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    CGMutablePathRef entryPath = CGPathCreateMutable();
    CGPathAddArc(entryPath, NULL, animationArcCenter.x, animationArcCenter.y, animationArcRadius, DEGREES_TO_RADIANS(90), DEGREES_TO_RADIANS(270), false);
    self.enterSceneAnimation.path = entryPath;
    self.enterSceneAnimation.duration = DAYLIGHT_ANIMATION_DURATION;

    self.exitSceneAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    CGMutablePathRef exitPath = CGPathCreateMutable();
    CGPathAddArc(exitPath, NULL, animationArcCenter.x, animationArcCenter.y, animationArcRadius, DEGREES_TO_RADIANS(270), DEGREES_TO_RADIANS(90), false);
    self.exitSceneAnimation.path = exitPath;
    self.exitSceneAnimation.duration = DAYLIGHT_ANIMATION_DURATION;
}

- (void)placeDaylightIcons
{
    // Place the sun + moon icons in the correct visible/hidden position based on the current time
    // Used to intialize the icon positions without iOS's auto layout moving them to the position's set in the storybard
    
    // Ensure we've intitialized placement data
    assert(self.enterSceneAnimation != nil && self.exitSceneAnimation != nil);

    // Store icon sizes then remove them from superviews in order to remove iOS autlayout positioning
    UIView *sunIconContainerView = self.sunIcon.superview;
    CGSize sunIconSize = self.sunIcon.frame.size;
    [self.sunIcon removeFromSuperview];
    
    UIView *moonIconContainerView = self.moonIcon.superview;
    CGSize moonIconSize = self.moonIcon.frame.size;
    [self.moonIcon removeFromSuperview];
    
    // Set the new positions based on whether the current alarm time is a daylight time
    // (the display/hide positions are stored as center positions for animation purposes, so must be offset to top left for frame construction)
    NSDate *alarmTime = [self nextDateTimeFor:self.alarmTimeComponents];
    CGRect sunFrame, moonFrame;
    if ([self.sunTimesHelper timeIsInDaylight:alarmTime]) {
        sunFrame = CGRectMake(self.displayDaylightIconPosition.x - (sunIconSize.width/2.0f),
                              self.displayDaylightIconPosition.y - (sunIconSize.height/2.0f),
                              sunIconSize.width, sunIconSize.height);
        moonFrame = CGRectMake(self.hideDaylightIconPosition.x - (moonIconSize.width/2.0f),
                               self.hideDaylightIconPosition.y - (moonIconSize.height/2.0f),
                               moonIconSize.width, moonIconSize.height);
    }
    else {
        moonFrame = CGRectMake(self.displayDaylightIconPosition.x - (moonIconSize.width/2.0f),
                               self.displayDaylightIconPosition.y - (moonIconSize.height/2.0f),
                               moonIconSize.width, moonIconSize.height);
        sunFrame = CGRectMake(self.hideDaylightIconPosition.x - (sunIconSize.width/2.0f),
                              self.hideDaylightIconPosition.y - (sunIconSize.width/2.0f),
                              sunIconSize.width, sunIconSize.height);
    }
    [self.sunIcon setFrame:sunFrame];
    [self.moonIcon setFrame:moonFrame];
    
    // Place icons back in superviews and move them to the back of the view hierarchy so masking works as expected
    [sunIconContainerView addSubview:self.sunIcon];
    [sunIconContainerView sendSubviewToBack:self.sunIcon];
    [moonIconContainerView addSubview:self.moonIcon];
    [moonIconContainerView sendSubviewToBack:self.moonIcon];
}

- (void)updateDaylightAnimation
{
    // Check if the sun & moon icons need to swap positions, and begin animations if they do.
    
    // If the animations have not been intiailzed, there's nothing we can do. Bail early.
    if (self.enterSceneAnimation == nil || self.exitSceneAnimation == nil) {
        return;
    }
    
    // Check if the dateTime represented by the alarm is in daylight
    NSDate *alarmTime = [self nextDateTimeFor:self.alarmTimeComponents];
    BOOL alarmTimeInDaylight = [self.sunTimesHelper timeIsInDaylight:alarmTime];
    
    // Determine if the icons need to be swapped
    if (alarmTimeInDaylight == NO && CGPointEqualToPoint(self.sunIcon.center, self.displayDaylightIconPosition)) {
        // Retain positions after animations
        self.sunIcon.layer.position = self.hideDaylightIconPosition;
        self.moonIcon.layer.position = self.displayDaylightIconPosition;
        // Start animation
        [UIView animateWithDuration:DAYLIGHT_ANIMATION_DURATION animations:^{
            [self.sunIcon.layer addAnimation:self.exitSceneAnimation forKey:@"position"];
            [self.moonIcon.layer addAnimation:self.enterSceneAnimation forKey:@"position"];
        }];
    }
    else if (alarmTimeInDaylight == YES && CGPointEqualToPoint(self.moonIcon.center, self.displayDaylightIconPosition)) {
        // Retain positions after animations
        self.moonIcon.layer.position = self.hideDaylightIconPosition;
        self.sunIcon.layer.position = self.displayDaylightIconPosition;
        // Start animation
        [UIView animateWithDuration:DAYLIGHT_ANIMATION_DURATION animations:^{
            [self.moonIcon.layer addAnimation:self.exitSceneAnimation forKey:@"position"];
            [self.sunIcon.layer addAnimation:self.enterSceneAnimation forKey:@"position"];
        }];
    }
}

- (void)showRequestPendingUI
{
    NSArray *fadeOutViews = @[self.openBlindsButton, self.closeBlindsButton, self.openCloseLabel];
    NSArray *fadeInViews = @[self.requestActivityIndicator];

    [self fadeViews:fadeOutViews toAlpha:0.0f withDuration:FADE_ANIMATION_DURATION];
    [self fadeViews:fadeInViews toAlpha:1.0f withDuration:FADE_ANIMATION_DURATION];
}

- (void)restoreOpenCloseUI
{
    // Only one of the fade out views should be visible, but applying the animation to all is harmless.
    NSArray *fadeOutViews = @[self.requestSucceededIcon, self.requestFailedIcon, self.requestActivityIndicator];
    NSArray *fadeInViews = @[self.openBlindsButton, self.closeBlindsButton, self.openCloseLabel] ;
    
    [self fadeViews:fadeOutViews toAlpha:0.0f withDuration:FADE_ANIMATION_DURATION];
    [self fadeViews:fadeInViews toAlpha:1.0f withDuration:FADE_ANIMATION_DURATION];
}

- (void)handleRequestSucceededNotification:(NSNotification *)notification
{
    [self fadeViews:@[self.requestActivityIndicator] toAlpha:0.0f withDuration:FADE_ANIMATION_DURATION];
    [self zoomInIcon:self.requestSucceededIcon withDuration:ZOOM_ANIMATION_DURATION onCompletion:^(BOOL finished) {
        [self performSelector:@selector(restoreOpenCloseUI) withObject:nil afterDelay:STATUS_ICON_DISPLAY_DURATION];
    }];
}

- (void)handleRequestFailedNotification:(NSNotification *)notification
{
    // Fade out indicator and open/close ui. Typically the indicator should be the only visible item, but
    // if this is indicating a request that was never made, the open/close buttons will be visible.
    // Fading already invisible views is harmless.
    NSArray *fadeOutViews = @[self.requestActivityIndicator, self.openBlindsButton, self.closeBlindsButton, self.openCloseLabel];
    [self fadeViews:fadeOutViews toAlpha:0.0f withDuration:FADE_ANIMATION_DURATION];
    [self zoomInIcon:self.requestFailedIcon withDuration:ZOOM_ANIMATION_DURATION onCompletion:^(BOOL finished) {
        [self performSelector:@selector(restoreOpenCloseUI) withObject:nil afterDelay:STATUS_ICON_DISPLAY_DURATION];
    }];
}

/* Animation Helper Methods */

- (void)fadeViews:(NSArray *)views toAlpha:(CGFloat)alpha withDuration:(CGFloat)duration
{
    [UIView animateWithDuration:duration animations:^{
        for (UIView *viewToFade in views) {
            viewToFade.alpha = alpha;
        }
    }];
}

- (void)zoomInIcon:(UIImageView *)icon withDuration:(CGFloat)duration onCompletion:(void (^)(BOOL finished))completion
{
    CGSize iconSize = icon.frame.size;
    CGRect finishZoomFrame = icon.frame;
    CGRect startZoomFrame = CGRectMake(icon.frame.origin.x + (iconSize.width / 2.0f),
                                       icon.frame.origin.y + (iconSize.height / 2.0f),
                                       0.0f, 0.0f);

    icon.frame = startZoomFrame;
    icon.alpha = 1.0f;
    [UIView animateWithDuration:duration animations:^{
        icon.frame = finishZoomFrame;
    } completion:completion];
}

/* LocalSunTimesHelperDelegate Methods */

- (void)sunTimesUpdatedFor:(LocalSunTimesHelper *)sunTimeHelper
{
    // Sunrise / Sunset times have changed (due to new location information)
    
    [self updateClockUI];
}

@end

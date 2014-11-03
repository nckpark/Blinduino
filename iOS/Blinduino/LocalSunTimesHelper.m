//
//  LocalSunTimesHelper.m
//  Blinduino
//
//  Created by Nick Park on 7/4/14.
//  Copyright (c) 2014 Nick Park. All rights reserved.
//

#import "LocalSunTimesHelper.h"
#import <EDSunriseSet.h>

typedef enum {
    kSunriseEvent,
    kSunsetEvent
} SunEvent;

/* Private Interface */

@interface LocalSunTimesHelper()

- (NSArray *)sunriseSunsetForDate:(NSDate *)date;
- (NSDate *)fallbackDateTimeFor:(SunEvent)event andDate:(NSDate *)date;

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (nonatomic) BOOL deviceLocationResolved;
@property (nonatomic) CLLocationCoordinate2D deviceCoordinates;

@property (strong, nonatomic) NSMutableDictionary *cachedSunTimesByDate;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;

@property (strong, nonatomic) NSDateComponents *fallbackSunriseTime;
@property (strong, nonatomic) NSDateComponents *fallbackSunsetTime;
@property (strong, nonatomic) NSCalendar *localCalendar;

@end

/* Implmentation */

@implementation LocalSunTimesHelper

- (id)init
{
    self = [super init];
    if (self) {
        // Initialize location manager & request the current location to use in sunrise/sunset calculations
        if ([CLLocationManager locationServicesEnabled]) {
            self.locationManager = [[CLLocationManager alloc] init];
            self.locationManager.delegate = self;
            self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
            [self.locationManager startUpdatingLocation];
        }
        
        // Initialize date formatter used for generating cache dictionary date key strings
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        
        // Initialize cache
        self.cachedSunTimesByDate = [[NSMutableDictionary alloc] init];
    }
    return self;
}

/* Getters & Setters */

- (NSCalendar *)localCalendar
{
    // Lazy load localCalendar

    if (_localCalendar == nil) {
        _localCalendar = [NSCalendar autoupdatingCurrentCalendar];
    }
    return _localCalendar;
}

/* Public Methods */

- (void)setFallbackSunriseTime:(NSDateComponents *)sunriseTimeComponents andSunsetTime:(NSDateComponents *)sunsetTimeComponents
{
    // Set fallback sunrise / sunset times to use if LocalSunTimesHelper is unable to determine the devices current location.
    
    self.fallbackSunriseTime = sunriseTimeComponents;
    self.fallbackSunsetTime = sunsetTimeComponents;
}

- (NSDate *)localSunriseForDate:(NSDate *)date
{
    // Return local sunrise time for date
    
    if (self.deviceLocationResolved) {
        return [self sunriseSunsetForDate:date][0];
    }
    else {
        return [self fallbackDateTimeFor:kSunriseEvent andDate:date];
    }
}

- (NSDate *)localSunsetForDate:(NSDate *)date
{
    // Return local sunset time for date
    
    if (self.deviceLocationResolved) {
        return [self sunriseSunsetForDate:date][1];
    }
    else {
        return [self fallbackDateTimeFor:kSunsetEvent andDate:date];
    }
}

- (BOOL)timeIsInDaylight:(NSDate *)dateTime
{
    // Check if dateTime is during daylight hours
    
    NSDate *sunriseTime = [self localSunriseForDate:dateTime];
    NSDate *sunsetTime = [self localSunsetForDate:dateTime];
    
    BOOL timeIsAfterSunrise = (dateTime == [dateTime laterDate:sunriseTime]);
    BOOL timeIsBeforeSunset = (sunsetTime == [sunsetTime laterDate:dateTime]);
    
    return (timeIsAfterSunrise && timeIsBeforeSunset);
}

- (void)clearCache
{
    [self.cachedSunTimesByDate removeAllObjects];
}

/* Private Methods */

- (NSArray *)sunriseSunsetForDate:(NSDate *)date
{
    // Attempt to fetch sun times from cache
    NSString *cacheDateKey = [self.dateFormatter stringFromDate:date];
    NSArray *cachedTimes = [self.cachedSunTimesByDate valueForKey:cacheDateKey];
    if (cachedTimes != nil) {
        return cachedTimes;
    }
    
    // Sun times not found and returned from cache. Calculate info using the EDSunriseSet library
    EDSunriseSet *sunInfo = [EDSunriseSet sunrisesetWithTimezone:[NSTimeZone systemTimeZone]
                                                        latitude:self.deviceCoordinates.latitude
                                                       longitude:self.deviceCoordinates.longitude];
    [sunInfo calculateSunriseSunset:date];
    NSArray *sunTimes = @[sunInfo.sunrise, sunInfo.sunset];
    [self.cachedSunTimesByDate setValue:sunTimes forKey:cacheDateKey];
    
    return sunTimes;
}

- (NSDate *)fallbackDateTimeFor:(SunEvent)event andDate:(NSDate *)date
{
    // Get fallback hour / minute for event
    NSDateComponents *timeComponents;
    if (event == kSunriseEvent) {
        timeComponents = self.fallbackSunriseTime;
    }
    else if (event == kSunsetEvent) {
        timeComponents = self.fallbackSunsetTime;
    }
    else {
        return nil; // Unknown sun event
    }
 
    // Check if the fallback components were set, and return nil if not
    if (timeComponents == nil) {
        return nil;
    }
    
    // Construct & return date time
    NSDateComponents *dateComponents = [self.localCalendar components:(NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear)
                                                             fromDate:date];
    
    [dateComponents setHour:timeComponents.hour];
    [dateComponents setMinute:timeComponents.minute];
    
    return [self.localCalendar dateFromComponents:dateComponents];
}

/* CLLocationManagerDelegate Methods */

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [manager stopUpdatingLocation]; // We only need one piece of location information.
    
    // Store device coordinates
    CLLocation* location = [locations lastObject];
    self.deviceCoordinates = location.coordinate;
    
    self.deviceLocationResolved = YES;
    
    // Clear cache - not strictly necessary as we should only be transitioning from using uncached fallback reponses to actual responses
    // But useful in case we later support updates as user location changes.
    [self.cachedSunTimesByDate removeAllObjects];
    
    // Notify delegate that we now have new information
    [self.delegate sunTimesUpdatedFor:self];
}

@end

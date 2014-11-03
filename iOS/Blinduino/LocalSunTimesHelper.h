//
//  LocalSunTimesHelper.h
//  Blinduino
//
//  Created by Nick Park on 7/4/14.
//  Copyright (c) 2014 Nick Park. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@protocol LocalSunTimesHelperDelegate;

// LocalSunTimesHelper

@interface LocalSunTimesHelper : NSObject <CLLocationManagerDelegate>

@property (strong, nonatomic) id<LocalSunTimesHelperDelegate> delegate;

// Set fallback sunrise / sunset times to use if LocalSunTimesHelper is unable to determine the devices current location.
// If no fallback times are set, LocalSunTimesHelper will return nil when the location is unknown.
- (void)setFallbackSunriseTime:(NSDateComponents *)sunriseTimeComponents andSunsetTime:(NSDateComponents *)sunsetTimeComponents;

// Get sunrise / sunset times by date for the devices current location
- (NSDate *)localSunriseForDate:(NSDate *)date;
- (NSDate *)localSunsetForDate:(NSDate *)date;

// Check if a dateTime is during daylight hours
- (BOOL)timeIsInDaylight:(NSDate *)dateTime;

// Clear cached sun times information
- (void)clearCache;

@end

// LocalSunTimesHelperDelegate

@protocol LocalSunTimesHelperDelegate <NSObject>

@optional

- (void)sunTimesUpdatedFor:(LocalSunTimesHelper *)sunTimeHelper;

@end
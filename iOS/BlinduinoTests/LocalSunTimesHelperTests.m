//
//  LocalSunTimesHelperTests.m
//  Blinduino
//
//  Created by Nick Park on 11/2/14.
//  Copyright (c) 2014 Nick Park. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "LocalSunTimesHelper.h"

@interface LocalSunTimesHelperTests : XCTestCase

@property (strong, nonatomic) id locationManagerMock; // Suite wide mock of CLLocationManager

@end

@implementation LocalSunTimesHelperTests

- (void)setUp
{
    [super setUp];
    self.locationManagerMock = [OCMockObject niceMockForClass:[CLLocationManager class]];
}

- (void)tearDown
{
    [super tearDown];
}

// Helpers

- (void)simulateLocation:(CLLocation *)location forSunTimesHelper:(LocalSunTimesHelper *)sunTimesHelper
{
    [sunTimesHelper locationManager:self.locationManagerMock didUpdateLocations:@[location]];
}

// Tests

- (void)test_delegate_sunTimesUpdated_calledAfterLocationFound
{
    LocalSunTimesHelper *sunTimesHelper = [[LocalSunTimesHelper alloc] init];
    id delegateMock = [OCMockObject mockForProtocol:@protocol(LocalSunTimesHelperDelegate)];
    sunTimesHelper.delegate = delegateMock;
    
    CLLocation *NYCLocation = [[CLLocation alloc] initWithLatitude:40.7127 longitude:-74.0059];
    
    [[delegateMock expect] sunTimesUpdatedFor:sunTimesHelper];
    [self simulateLocation:NYCLocation forSunTimesHelper:sunTimesHelper];
    [delegateMock verify];
}

- (void)test_fallbackSunriseSunset_usedWhenNoLocation
{
    LocalSunTimesHelper *sunTimesHelper = [[LocalSunTimesHelper alloc] init];

    NSInteger fallbackSunriseHour = 7;
    NSInteger fallbackSunsetHour = 20;
    NSInteger fallbackSunsetMinute = 30;
    
    NSDateComponents *fallbackSunriseComponents = [[NSDateComponents alloc] init];
    NSDateComponents *fallbackSunsetComponents = [[NSDateComponents alloc] init];
    [fallbackSunriseComponents setHour:fallbackSunriseHour];
    [fallbackSunsetComponents setHour:fallbackSunsetHour];
    [fallbackSunsetComponents setMinute:fallbackSunsetMinute];
    [sunTimesHelper setFallbackSunriseTime:fallbackSunriseComponents andSunsetTime:fallbackSunsetComponents];
    
    NSDate *today = [NSDate date];
    NSCalendar *localCalendar = [NSCalendar autoupdatingCurrentCalendar];
    
    NSDate *sunriseTime = [sunTimesHelper localSunriseForDate:today];
    NSDateComponents *sunriseComponents = [localCalendar components:(NSCalendarUnitHour|NSCalendarUnitMinute) fromDate:sunriseTime];
    XCTAssertEqual([sunriseComponents hour], fallbackSunriseHour);
    XCTAssertEqual([sunriseComponents minute], 0);
    
    NSDate *sunsetTime = [sunTimesHelper localSunsetForDate:today];
    NSDateComponents *sunsetComponents = [localCalendar components:(NSCalendarUnitHour|NSCalendarUnitMinute) fromDate:sunsetTime];
    XCTAssertEqual([sunsetComponents hour], fallbackSunsetHour);
    XCTAssertEqual([sunsetComponents minute], fallbackSunsetMinute);
}

- (void)test_localSunriseSunsetForDate_nilWhenNoLocation
{
    LocalSunTimesHelper *sunTimesHelper = [[LocalSunTimesHelper alloc] init];

    NSDate *today = [NSDate date];
    NSDate *sunriseTime = [sunTimesHelper localSunriseForDate:today];
    XCTAssertEqualObjects(sunriseTime, nil);
    NSDate *sunsetTime = [sunTimesHelper localSunsetForDate:today];
    XCTAssertEqualObjects(sunsetTime, nil);
}

- (void)test_localSunriseForDate
{
    LocalSunTimesHelper *sunTimesHelper = [[LocalSunTimesHelper alloc] init];
    CLLocation *NYCLocation = [[CLLocation alloc] initWithLatitude:40.7127 longitude:-74.0059];
    
    [self simulateLocation:NYCLocation forSunTimesHelper:sunTimesHelper];
    
    NSCalendarUnit calendarUnits = (NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitYear|NSCalendarUnitHour|NSCalendarUnitMinute);
    NSCalendar *localCalendar = [NSCalendar autoupdatingCurrentCalendar];
    NSDate *today = [NSDate date];
    NSDateComponents *todayComponents = [localCalendar components:calendarUnits fromDate:today];
    
    NSDate *sunriseTime = [sunTimesHelper localSunriseForDate:today];
    NSDateComponents *sunriseComponents = [localCalendar components:calendarUnits fromDate:sunriseTime];
    
    XCTAssertEqual([todayComponents year], [sunriseComponents year]);
    XCTAssertEqual([todayComponents month], [sunriseComponents month]);
    XCTAssertEqual([todayComponents day], [sunriseComponents day]);
    
    XCTAssertTrue([sunriseComponents hour] >= 5);
    XCTAssertTrue([sunriseComponents hour] <= 7);
}

- (void)test_localSunsetForDate
{
    LocalSunTimesHelper *sunTimesHelper = [[LocalSunTimesHelper alloc] init];
    CLLocation *NYCLocation = [[CLLocation alloc] initWithLatitude:40.7127 longitude:-74.0059];
    
    [self simulateLocation:NYCLocation forSunTimesHelper:sunTimesHelper];
    
    NSCalendarUnit calendarUnits = (NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitYear|NSCalendarUnitHour|NSCalendarUnitMinute);
    NSCalendar *localCalendar = [NSCalendar autoupdatingCurrentCalendar];
    NSDate *today = [NSDate date];
    NSDateComponents *todayComponents = [localCalendar components:calendarUnits fromDate:today];
    
    NSDate *sunsetTime = [sunTimesHelper localSunsetForDate:today];
    NSDateComponents *sunsetComponents = [localCalendar components:calendarUnits fromDate:sunsetTime];
    
    XCTAssertEqual([todayComponents year], [sunsetComponents year]);
    XCTAssertEqual([todayComponents month], [sunsetComponents month]);
    XCTAssertEqual([todayComponents day], [sunsetComponents day]);
    
    XCTAssertTrue([sunsetComponents hour] >= 16);
    XCTAssertTrue([sunsetComponents hour] <= 22);
}

- (void)test_timeIsInDaylight
{
    LocalSunTimesHelper *sunTimesHelper = [[LocalSunTimesHelper alloc] init];
    CLLocation *NYCLocation = [[CLLocation alloc] initWithLatitude:40.7127 longitude:-74.0059];
    
    [self simulateLocation:NYCLocation forSunTimesHelper:sunTimesHelper];
    
    NSDate *today = [NSDate date];
    NSDate *sunriseTime = [sunTimesHelper localSunriseForDate:today];
    NSDate *sunsetTime = [sunTimesHelper localSunsetForDate:today];
    
    NSDate *beforeSunrise = [sunriseTime dateByAddingTimeInterval:-60.0];
    XCTAssertFalse([sunTimesHelper timeIsInDaylight:beforeSunrise]);
    NSDate *afterSunrise = [sunriseTime dateByAddingTimeInterval:60.0];
    XCTAssertTrue([sunTimesHelper timeIsInDaylight:afterSunrise]);
    XCTAssertTrue([sunTimesHelper timeIsInDaylight:sunriseTime]);
    
    NSDate *beforeSunset = [sunsetTime dateByAddingTimeInterval:-60.0];
    XCTAssertTrue([sunTimesHelper timeIsInDaylight:beforeSunset]);
    NSDate *afterSunset = [sunsetTime dateByAddingTimeInterval:60.0];
    XCTAssertFalse([sunTimesHelper timeIsInDaylight:afterSunset]);
    XCTAssertTrue([sunTimesHelper timeIsInDaylight:sunsetTime]);
}

@end


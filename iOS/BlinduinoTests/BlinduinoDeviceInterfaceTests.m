//
//  BlinduinoDeviceInterfaceTests.m
//  BlinduinoDeviceInterfaceTests
//
//  Created by Nick Park on 6/24/14.
//  Copyright (c) 2014 Nick Park. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "BlinduinoDeviceInterface.h"

@interface BlinduinoDeviceInterfaceTests : XCTestCase

@property (strong, nonatomic) id timerMock; // Suite wide mock of NSTimer
@property (strong, nonatomic) id simplePingMock; // Suite wide mock of SimplePing

@property (strong, nonatomic) NSString *expectedDeviceHostname;

@end

@interface BlinduinoDeviceInterfaceTestsHelper : NSObject

+ (BlinduinoDeviceInterface *)getDeviceInterfaceWithDeviceAvailable:(BOOL)deviceAvailable;

@end

@implementation BlinduinoDeviceInterfaceTests

- (void)setUp
{
    [super setUp];
 
    self.expectedDeviceHostname = @"target.local";
    
    // Always mock NSTimer so tests don't wait for timer events to fire.
    // Tests that rely on the BlinduinoDeviceInterface pingTimer to fire events should manually make calls instead.
    self.timerMock = [OCMockObject niceMockForClass:[NSTimer class]];
    
    // Always mock SimplePing so tests don't rely on network access + hostname resolution
    self.simplePingMock = [OCMockObject niceMockForClass:[SimplePing class]];
    [[[self.simplePingMock stub] andReturn:self.simplePingMock] simplePingWithHostName:[OCMArg any]];
}

- (void)tearDown
{
    [super tearDown];
}

// Tests

- (void)test_deviceAvailable_isYESWhenZeroPingsFails
{
    BlinduinoDeviceInterface *deviceInterface = [[BlinduinoDeviceInterface alloc] init];
    NSInteger simulatedPingCount = 5;
    for (int i = 0; i < simulatedPingCount; i++) {
        [deviceInterface simplePing:self.simplePingMock didSendPacket:nil]; // Packet is not inspected, nil should be fine
        [deviceInterface simplePing:self.simplePingMock didReceivePingResponsePacket:nil];
    }
    
    XCTAssertTrue(deviceInterface.deviceAvailable, @"Successful pings to device hostname should set deviceAvailable to YES.");
}

- (void)test_deviceAvailable_isYESWhenSinglePingFails
{
    BlinduinoDeviceInterface *deviceInterface = [[BlinduinoDeviceInterface alloc] init];
    // Successful ping - device online
    [deviceInterface simplePing:self.simplePingMock didSendPacket:nil];
    [deviceInterface simplePing:self.simplePingMock didReceivePingResponsePacket:nil];
    // Failed ping
    [deviceInterface simplePing:self.simplePingMock didSendPacket:nil];
    [deviceInterface simplePing:self.simplePingMock didSendPacket:nil];
    
    XCTAssertTrue(deviceInterface.deviceAvailable, @"deviceAvailable should be YES if only a single ping fails.");
}

- (void)test_deviceAvailable_isNOWhenMultiplePingsFail
{
    BlinduinoDeviceInterface *deviceInterface = [[BlinduinoDeviceInterface alloc] init];
    // Successful ping - device online
    [deviceInterface simplePing:self.simplePingMock didSendPacket:nil];
    [deviceInterface simplePing:self.simplePingMock didReceivePingResponsePacket:nil];
    // Multiple failed pings - device offline
    NSInteger simulatedPingCount = 3;
    for (int i = 0; i < simulatedPingCount; i++) {
        [deviceInterface simplePing:self.simplePingMock didSendPacket:nil];
        // No response recieved
    }
    
    XCTAssertFalse(deviceInterface.deviceAvailable, @"deviceAvailable should be NO if multiple pings fail consecutively.");
}

- (void)test_deviceAvailable_pingerStartsTimer
{
    [(SimplePing *)[self.simplePingMock expect] start];
    BlinduinoDeviceInterface *deviceInterface = [[BlinduinoDeviceInterface alloc] init];
    [self.simplePingMock verify];

    [[self.timerMock expect] scheduledTimerWithTimeInterval:2.0f target:[OCMArg any] selector:[OCMArg anySelector] userInfo:[OCMArg any] repeats:YES];
    [deviceInterface simplePing:self.simplePingMock didStartWithAddress:nil];
    [self.timerMock verify];
}

- (void)test_deviceAvailable_pingsRestartIfPingerFails
{
    BlinduinoDeviceInterface *deviceInterface = [[BlinduinoDeviceInterface alloc] init];
    
    [(SimplePing *)[self.simplePingMock expect] start];
    [deviceInterface simplePing:self.simplePingMock didFailWithError:nil];
    [self.simplePingMock verify];
}

- (void)test_openBlinds_checksDeviceIsAvailable
{
    BlinduinoDeviceInterface *deviceInterface = [[BlinduinoDeviceInterface alloc] init];
    id deviceInterfaceMock = [OCMockObject partialMockForObject:deviceInterface];

    [[deviceInterfaceMock expect] deviceAvailable]; // NO - no pings - device offline.
    BOOL return_value = [deviceInterfaceMock openBlinds];
    [deviceInterfaceMock verify];
    
    XCTAssertFalse(return_value, @"openBlinds should return NO when the device is unavailable.");
}

- (void)test_openBlinds_makesOpenRequest
{
    NSURL *expectedRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/open", self.expectedDeviceHostname]];
    
    id urlSessionMock = [OCMockObject niceMockForClass:[NSURLSession class]];
    id dataTaskMock = [OCMockObject niceMockForClass:[NSURLSessionDataTask class]];
    
    [[[urlSessionMock expect] andReturn:urlSessionMock] sharedSession];
    [[[urlSessionMock expect] andReturn:dataTaskMock] dataTaskWithURL:expectedRequestURL completionHandler:[OCMArg any]];
    [[dataTaskMock expect] resume];
    
    BlinduinoDeviceInterface *deviceInterface = [BlinduinoDeviceInterfaceTestsHelper getDeviceInterfaceWithDeviceAvailable:YES];
    BOOL return_value = [deviceInterface openBlinds];
    XCTAssertTrue(return_value, @"openBlinds should return YES after the request is made.");
    
    [urlSessionMock verify];
    [dataTaskMock verify];
}

- (void)test_closeBlinds_checksDeviceIsAvailable
{
    BlinduinoDeviceInterface *deviceInterface = [[BlinduinoDeviceInterface alloc] init];
    id deviceInterfaceMock = [OCMockObject partialMockForObject:deviceInterface];
    
    [[deviceInterfaceMock expect] deviceAvailable]; // NO - no pings - device offline.
    BOOL return_value = [deviceInterfaceMock closeBlinds];
    [deviceInterfaceMock verify];
    
    XCTAssertFalse(return_value, @"closeBlinds should return NO when the device is unavailable.");
}

- (void)test_closeBlinds_makesCloseRequest
{
    NSURL *expectedRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/close", self.expectedDeviceHostname]];
    
    id urlSessionMock = [OCMockObject niceMockForClass:[NSURLSession class]];
    id dataTaskMock = [OCMockObject niceMockForClass:[NSURLSessionDataTask class]];
    
    [[[urlSessionMock expect] andReturn:urlSessionMock] sharedSession];
    [[[urlSessionMock expect] andReturn:dataTaskMock] dataTaskWithURL:expectedRequestURL completionHandler:[OCMArg any]];
    [[dataTaskMock expect] resume];
    
    BlinduinoDeviceInterface *deviceInterface = [BlinduinoDeviceInterfaceTestsHelper getDeviceInterfaceWithDeviceAvailable:YES];
    BOOL return_value = [deviceInterface closeBlinds];
    XCTAssertTrue(return_value, @"closeBlinds should return YES after the request is made.");
    
    [urlSessionMock verify];
    [dataTaskMock verify];
}

- (void)test_setOpenTime_checksDeviceIsAvailable
{
    BlinduinoDeviceInterface *deviceInterface = [[BlinduinoDeviceInterface alloc] init];
    id deviceInterfaceMock = [OCMockObject partialMockForObject:deviceInterface];
    
    [[deviceInterfaceMock expect] deviceAvailable]; // NO - no pings - device offline.
    BOOL return_value = [deviceInterfaceMock setOpenTime:[NSDate date]];
    [deviceInterfaceMock verify];
    
    XCTAssertFalse(return_value, @"setAlarmOpenTime should return NO when the device is unavailable.");
}

- (void)test_setOpenTime_sendsCorrectEpochTime
{
    NSDate *openTime = [NSDate date];
    long long expectedEpochOpenTime = (long long)[openTime timeIntervalSince1970];
    NSURL *expectedRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/set?%lld", self.expectedDeviceHostname, expectedEpochOpenTime]];
    
    id urlSessionMock = [OCMockObject niceMockForClass:[NSURLSession class]];
    id dataTaskMock = [OCMockObject niceMockForClass:[NSURLSessionDataTask class]];
    
    [[[urlSessionMock expect] andReturn:urlSessionMock] sharedSession];
    [[[urlSessionMock expect] andReturn:dataTaskMock] dataTaskWithURL:expectedRequestURL completionHandler:[OCMArg any]];
    [[dataTaskMock expect] resume];
    
    BlinduinoDeviceInterface *deviceInterface = [BlinduinoDeviceInterfaceTestsHelper getDeviceInterfaceWithDeviceAvailable:YES];
    BOOL return_value = [deviceInterface setOpenTime:openTime];
    XCTAssertTrue(return_value, @"setOpenTime should return YES after the request is made.");
    
    [urlSessionMock verify];
    [dataTaskMock verify];
}

- (void)test_sharedInstance_allocatesSingleInstance
{
    BlinduinoDeviceInterface *sharedInterface = [BlinduinoDeviceInterface sharedInstance];
    BlinduinoDeviceInterface *secondInstance = [BlinduinoDeviceInterface sharedInstance];
    XCTAssertEqualObjects(sharedInterface, secondInstance);
}

@end

/* Tests Helper Implementation */

@implementation BlinduinoDeviceInterfaceTestsHelper

+ (BlinduinoDeviceInterface *)getDeviceInterfaceWithDeviceAvailable:(BOOL)deviceAvailable
{
    BlinduinoDeviceInterface *deviceInterface = [[BlinduinoDeviceInterface alloc] init];
    if (deviceAvailable) {
        [deviceInterface simplePing:nil didSendPacket:nil]; // SimplePing reference + packet data are unused. nil is fine.
        [deviceInterface simplePing:nil didReceivePingResponsePacket:nil];
    }
    return deviceInterface;
}

@end

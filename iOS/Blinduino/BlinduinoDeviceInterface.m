//
//  BlinduinoDeviceInterface.m
//  Blinduino
//
//  Created by Nick Park on 6/24/14.
//  Copyright (c) 2014 Nick Park. All rights reserved.
//

#import "BlinduinoDeviceInterface.h"

// Every PING_INTERVAL_SECONDS we ping the device to confirm it is available on the network.
// If we don't recieve responses for FAILED_PING_THRESHOLD consecutive pings, consider the device offline.
#define PING_INTERVAL_SECONDS 2.0f
#define FAILED_PING_THRESHOLD 2

/* Notification Strings */
const NSString *BlinduinoDeviceConnectionStatusChangedNotification = @"BlinduinoDeviceConnectionStatusChangedNotification";
const NSString *BlinduinoRequestSucceededNotification = @"BlinduinoRequestSucceededNotification";
const NSString *BlinduinoRequestFailedNotification = @"BlinduinoRequestFailedNotification";

/* Private Interface */

@interface BlinduinoDeviceInterface()

@property (nonatomic, readwrite) BOOL deviceAvailable; // privately writable
@property (strong, nonatomic) NSString *deviceHostname;

@property (strong, nonatomic) SimplePing *devicePinger;
@property (strong, nonatomic) NSTimer *pingTimer;
@property (nonatomic) BOOL waitingForPingResponse;
@property (nonatomic) NSInteger failedPingCount;

- (void)pingDevice;

- (void)postResponseNotificationForRequest:(NSString *)requestType withURLResponse:(NSURLResponse *)response andError:(NSError *)error;

@end

@implementation BlinduinoDeviceInterface

- (id)init
{
    self = [super init];
    if (self) {
        self.deviceHostname = @"target.local";
        
        self.devicePinger = [SimplePing simplePingWithHostName:self.deviceHostname];
        self.devicePinger.delegate = self;
        [self.devicePinger start];
    }
    return self;
}

+ (instancetype)sharedInstance
{
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    
    return _sharedInstance;
}

- (void)dealloc
{
    [self.devicePinger stop];
    [self.pingTimer invalidate];
}

/* Public Methods */

- (BOOL)openBlinds
{
    if (self.deviceAvailable == NO) {
        return NO;
    }
    
    NSURL *openRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/open", self.deviceHostname]];
    NSURLSessionDataTask *openRequestTask = [[NSURLSession sharedSession] dataTaskWithURL:openRequestURL
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self postResponseNotificationForRequest:@"open" withURLResponse:response andError:error];
        }];
    [openRequestTask resume];

    return YES;
}

- (BOOL)closeBlinds
{
    if (self.deviceAvailable == NO) {
        return NO;
    }
    
    NSURL *closeRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/close", self.deviceHostname]];
    NSURLSessionDataTask *closeRequestTask = [[NSURLSession sharedSession] dataTaskWithURL:closeRequestURL
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self postResponseNotificationForRequest:@"close" withURLResponse:response andError:error];
        }];
    [closeRequestTask resume];
    
    return YES;
}

- (BOOL)setOpenTime:(NSDate *)openTime
{
    if (self.deviceAvailable == NO) {
        return NO;
    }
    
    long long epochOpenTime = (long long)[openTime timeIntervalSince1970];
    NSURL *setAlarmURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/set?%lld", self.deviceHostname, epochOpenTime]];
    NSURLSessionDataTask *setAlarmTask = [[NSURLSession sharedSession] dataTaskWithURL:setAlarmURL
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self postResponseNotificationForRequest:@"set" withURLResponse:response andError:error];
        }];
    [setAlarmTask resume];

    return YES;
}

/* Private Methods */

- (void)pingDevice
{
    [self.devicePinger sendPingWithData:nil];
}

- (void)postResponseNotificationForRequest:(NSString *)requestType withURLResponse:(NSURLResponse *)response andError:(NSError *)error
{
    if (!error) {
        NSNumber *statusCode = [NSNumber numberWithInteger: ((NSHTTPURLResponse*)response).statusCode];
        NSLog(@"%@ returned status %@.", requestType, statusCode);
        
        if ([statusCode isEqualToNumber:@200]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)BlinduinoRequestSucceededNotification
                                                                object:self userInfo:@{@"requestType":requestType}];
        }
        else {
            [[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)BlinduinoRequestSucceededNotification
                                                                object:self userInfo:@{@"requestType":requestType, @"errorCode":statusCode}];
        }
    }
    else {
        NSLog(@"%@ encountered error: %@", requestType, [error description]);
        [[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)BlinduinoRequestFailedNotification
                                                            object:self userInfo:@{@"requestType":requestType, @"error_code":@0}];
    }
}

/* Simple Ping Delegate */

// SimplePing has started up. Ready to start sending pings.
- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address
{
    if (self.pingTimer != nil) {
        [self.pingTimer invalidate];
        self.pingTimer = nil;
    }
    
    [self pingDevice];
    self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:PING_INTERVAL_SECONDS
                                                      target:self
                                                    selector:@selector(pingDevice)
                                                    userInfo:nil
                                                     repeats:YES];
}

// The devicePinger failed and shut itself down. Start it up again.
- (void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error
{
    // Stop the pingTimer from attempting to send more packets
    [self.pingTimer invalidate];
    self.pingTimer = nil;
    
    // Restart the devicePinger.
    // When the restart is complete, [simplePing: didStartWithAddress:] will restart the ping timer.
    [self.devicePinger start];
}

- (void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet
{
    if (self.waitingForPingResponse == YES) {
        // We didn't recieve a response from our previous ping packet.
        self.failedPingCount++;
        if (self.failedPingCount >= FAILED_PING_THRESHOLD && self.deviceAvailable) {
            NSLog(@"Device went offline!");
            self.deviceAvailable = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)BlinduinoDeviceConnectionStatusChangedNotification
                                                                object:self];
        }
    }
    
    self.waitingForPingResponse = YES;
}

- (void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet
{
    if (self.deviceAvailable == NO) {
        NSLog(@"Device came online!");
        self.deviceAvailable = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)BlinduinoDeviceConnectionStatusChangedNotification
                                                            object:self];
    }
    
    // The device is online and has sent us a response.
    self.waitingForPingResponse = NO;
    self.failedPingCount = 0;
}

@end

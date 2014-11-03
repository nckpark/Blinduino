//
//  DeviceConnectingViewController.m
//  Blinduino
//
//  Created by Nick Park on 7/1/14.
//  Copyright (c) 2014 Nick Park. All rights reserved.
//

#import "DeviceConnectingViewController.h"
#import "BlinduinoDeviceInterface.h"

/* Segue Identifiers */

const NSString *DeviceConnectedSegue = @"DeviceConnectedSegue";

/* Private Interface */

@interface DeviceConnectingViewController ()

@property (strong, nonatomic) UIViewController *presentedDeviceControlsViewController;

- (void)handleDeviceConnectionStatusChange;

@end

/* Class Implementation */

@implementation DeviceConnectingViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDeviceConnectionStatusChange)
                                                 name:(NSString *)BlinduinoDeviceConnectionStatusChangedNotification
                                               object:[BlinduinoDeviceInterface sharedInstance]];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)startDemoMode:(id)sender
{
    // Skip waiting for the device to become available, and jump straight to the control interface.
    // Allows showing off the app even when not at home with the device.
    [self performSegueWithIdentifier:(NSString *)DeviceConnectedSegue sender:self];
    // Unsubscribe from notifications so the views don't get confused if the device suddenly pops online.
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/* Navigation */

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:(NSString *)DeviceConnectedSegue]) {
        self.presentedDeviceControlsViewController = segue.destinationViewController;
    }
}

/* Private Methods */

- (void)handleDeviceConnectionStatusChange
{
    // TODO: fix 'Attempt to present ... while presentation is in progress' bug
    BlinduinoDeviceInterface *deviceInterface = [BlinduinoDeviceInterface sharedInstance];
    if (deviceInterface.deviceAvailable) {
        [self performSegueWithIdentifier:(NSString *)DeviceConnectedSegue sender:self];
    }
    else {
        [self.presentedDeviceControlsViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

@end

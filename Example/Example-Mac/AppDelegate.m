//
//  AppDelegate.m
//  Tor_Example_Mac
//
//  Created by Benjamin Erhart on 13.01.22.
//  Copyright © 2022 Benjamin Erhart. All rights reserved.
//

#import "AppDelegate.h"
#import <Anon/NSBundle+GeoIP.h>
#import <Anon/TORConfiguration.h>
#import <Anon/TORController.h>

#ifdef USE_ARTI
    #import <Anon/TORArti.h>
#else
    #ifdef USE_ONIONMASQ
        #import <Anon/Onionmasq.h>
    #else
        #import <Anon/TORThread.h>
    #endif
#endif

@interface AppDelegate ()


@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *appSuppDir = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;

    TORConfiguration *configuration = [TORConfiguration new];
    configuration.ignoreMissingTorrc = YES;
    configuration.avoidDiskWrites = YES;
    configuration.clientOnly = YES;
    configuration.cookieAuthentication = YES;
    configuration.autoControlPort = YES;
    configuration.dataDirectory = [appSuppDir URLByAppendingPathComponent:@"tor"];
    configuration.geoipFile = NSBundle.geoIpBundle.geoipFile;
    configuration.geoip6File = NSBundle.geoIpBundle.geoip6File;

    NSURL *cacheDir = [fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;


#ifdef USE_ARTI

    configuration.socksPort = 9150;
    configuration.dnsPort = 1951;
    configuration.dataDirectory = [appSuppDir URLByAppendingPathComponent:@"org.torproject.Arti"];
    configuration.logfile = [cacheDir URLByAppendingPathComponent:@"arti.log"];
    configuration.cacheDirectory = [cacheDir URLByAppendingPathComponent:@"org.torproject.Arti"];

    NSLog(@"Configuration:\n%@", [configuration compile]);

    [TORArti startWithConfiguration:configuration completed:^{
        NSLog(@"established");
    }];

#else

    #ifdef USE_ONIONMASQ

    [Onionmasq startWithReader:^{
        NSLog(@"[Read]");

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [Onionmasq receive:@[]];
        });
    }
                        writer:^_Bool(NSData * _Nonnull packet, NSNumber * _Nonnull version) {
        NSLog(@"[Write] version=%@, packet=%@", version, packet);

        return false;
    }
                      stateDir:appSuppDir
                      cacheDir:cacheDir
                      pcapFile:nil
                       onEvent:^(id event) {
        NSLog(@"[Event] %@", event);
    }
                         onLog:^(NSString * _Nonnull message) {
        NSLog(@"[Log] %@", message);
    }];

    #else

    TORThread *thread = [[TORThread alloc] initWithConfiguration:configuration];
    [thread start];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSData *cookie = configuration.cookie;
        TORController *controller = [[TORController alloc] initWithControlPortFile:configuration.controlPortFile];
        [controller authenticateWithData:cookie completion:^(BOOL success, NSError *error) {
            __weak TORController *c = controller;

            NSLog(@"authenticated success=%d", success);

            if (!success)
            {
                return;
            }

            [c addObserverForCircuitEstablished:^(BOOL established) {
                NSLog(@"established=%d", established);

                if (!established)
                {
                    return;
                }

                CFTimeInterval startTime = CACurrentMediaTime();

                [c getCircuits:^(NSArray<TORCircuit *> * _Nonnull circuits) {
                    NSLog(@"Circuits: %@", circuits);

                    NSLog(@"Elapsed Time: %f", CACurrentMediaTime() - startTime);
                }];
            }];
        }];
    });

    #endif

#endif
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}


@end

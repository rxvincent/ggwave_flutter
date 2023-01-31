#import "GgwaveFlutterPlugin.h"
#import "GgWaveUtil.h"

@interface GgwaveFlutterPlugin() {
    GgWaveUtil *ggWave;
    FlutterMethodChannel *channel;
}

@end

@implementation GgwaveFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"ggwave_flutter" binaryMessenger:registrar.messenger];
    
    GgWaveUtil *ggWave = [[GgWaveUtil alloc] init];
    
    ggWave.onStatusChanged = ^(NSString *status) {
        [channel invokeMethod:status arguments:nil];
    };
    
    ggWave.onReceivedMessage = ^(NSString *message) {
        [channel invokeMethod:@"onMessageReceived" arguments:message];
    };
    
    [ggWave setup];
    
    GgwaveFlutterPlugin *instance = [[GgwaveFlutterPlugin alloc] initWithChannel:channel ggWave:ggWave];
    
    [registrar addMethodCallDelegate:instance channel:channel];
    [registrar addApplicationDelegate:instance];
}

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel ggWave:(GgWaveUtil*)ggWave
{
    self = [super init];
    if (self) {
        self->ggWave = ggWave;
        self->channel = channel;
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    
    if ([call.method isEqualToString:@"togglePlayback"]) {
        [ggWave togglePlaybackWithMessage:call.arguments[0] mode:[call.arguments[1] intValue]  volume:[call.arguments[2] intValue]];
    } else if ([call.method isEqualToString:@"toggleCapture"]) {
        [ggWave toggleCapture];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end

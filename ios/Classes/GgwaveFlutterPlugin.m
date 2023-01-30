#import "GgwaveFlutterPlugin.h"
#if __has_include(<ggwave_flutter/ggwave_flutter-Swift.h>)
#import <ggwave_flutter/ggwave_flutter-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "ggwave_flutter-Swift.h"
#endif

@implementation GgwaveFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftGgwaveFlutterPlugin registerWithRegistrar:registrar];
}
@end

//
//  ViewController.h
//  ggwave-objc
//
//  Created by Georgi Gerganov on 24.04.21.
//
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioQueue.h>

#define NUM_BUFFERS 3

typedef struct
{
    int ggwaveId;
    bool isCapturing;
    void (^onReceivedMessage)(NSString* message);
    AudioQueueRef queue;
    AudioStreamBasicDescription dataFormat;
    AudioQueueBufferRef buffers[NUM_BUFFERS];
} StateInp;

typedef struct
{
    bool isPlaying;
    int ggwaveId;
    int offset;
    int totalBytes;
    NSMutableData * waveform;
    void (^onStatusChanged)(NSString* status);
    AudioQueueRef queue;
    AudioStreamBasicDescription dataFormat;
    AudioQueueBufferRef buffers[NUM_BUFFERS];
} StateOut;

@interface GgWaveUtil : NSObject
{
    StateInp stateInp;
    StateOut stateOut;
}

@property (nonatomic, copy) void (^onStatusChanged)(NSString* status);
@property (nonatomic, copy) void (^onReceivedMessage)(NSString* message);

- (void)setup;
- (void)toggleCapture;
- (void)togglePlaybackWithMessage:(NSString *)message;

@end

//
//  ViewController.m
//  ggwave-objc
//
//  Created by Georgi Gerganov on 24.04.21.
//

#import "GgWaveUtil.h"

#import "ggwave/ggwave.h"

#define NUM_BYTES_PER_BUFFER 16*1024

// the text message to transmit:
const char* kDefaultMessageToSend = "Hello iOS!";

// callback used to process captured audio
void AudioInputCallback(void * inUserData,
                        AudioQueueRef inAQ,
                        AudioQueueBufferRef inBuffer,
                        const AudioTimeStamp * inStartTime,
                        UInt32 inNumberPacketDescriptions,
                        const AudioStreamPacketDescription * inPacketDescs);

// callback used to playback generated audio
void AudioOutputCallback(void * inUserData,
                         AudioQueueRef outAQ,
                         AudioQueueBufferRef outBuffer);

@interface GgWaveUtil ()

@end

@implementation GgWaveUtil

- (void)setupAudioFormat:(AudioStreamBasicDescription*)format
{
    //format->mSampleRate = 48000.0; // it seems that sometimes 48kHz is not supported by the device
    format->mSampleRate = 44100.0;
	format->mFormatID = kAudioFormatLinearPCM;
	format->mFramesPerPacket = 1;
	format->mChannelsPerFrame = 1;
	format->mBytesPerFrame = 2;
	format->mBytesPerPacket = 2;
	format->mBitsPerChannel = 16;
	format->mReserved = 0;
	format->mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;
}

- (void)setup {
    // initialize audio format

    [self setupAudioFormat:&stateInp.dataFormat];
    [self setupAudioFormat:&stateOut.dataFormat];

    // initialize the GGWave instances:

    // RX
    {
        ggwave_Parameters parameters = ggwave_getDefaultParameters();

        // this will cause the ggwave instance to resample the input to the default sample rate (48kHz)
        parameters.sampleRateInp   = stateInp.dataFormat.mSampleRate;

        parameters.sampleFormatInp = GGWAVE_SAMPLE_FORMAT_I16;
        parameters.sampleFormatOut = GGWAVE_SAMPLE_FORMAT_I16;

        stateInp.ggwaveId = ggwave_init(parameters);

        printf("GGWave capture instance initialized - instance id = %d\n", stateInp.ggwaveId);
    }

    // TX
    {
        ggwave_Parameters parameters = ggwave_getDefaultParameters();

        // this will cause the ggwave instance to resample the output to the configured sample rate
        parameters.sampleRateOut   = stateOut.dataFormat.mSampleRate;

        parameters.sampleFormatInp = GGWAVE_SAMPLE_FORMAT_I16;
        parameters.sampleFormatOut = GGWAVE_SAMPLE_FORMAT_I16;

        stateOut.ggwaveId = ggwave_init(parameters);

        printf("GGWave playback instance initialized - instance id = %d\n", stateOut.ggwaveId);
    }

    // uncomment to disable internal logging from ggwave
    //ggwave_setLogFile(NULL);
    
    stateInp.onReceivedMessage = _onReceivedMessage;
    stateOut.onStatusChanged = _onStatusChanged;
}

-(void) stopCapturing
{
    printf("Stop capturing\n");
    
    self.onStatusChanged(@"onCaptureStop");
//    _labelStatusInp.text = @"Status: Idle";
//    _labelReceived.text = @"Received: ";

    stateInp.isCapturing = false;

    AudioQueueStop(stateInp.queue, true);
    for (int i = 0; i < NUM_BUFFERS; i++) {
        AudioQueueFreeBuffer(stateInp.queue, stateInp.buffers[i]);
    }

    AudioQueueDispose(stateInp.queue, true);
}

- (void)toggleCapture {
    if (stateInp.isCapturing) {
        [self stopCapturing];
        return;
    }

    // initiate audio capturing
    // the GGWave analysis is performed in the capture callback

    printf("Start capturing\n");

    OSStatus status = AudioQueueNewInput(&stateInp.dataFormat,
                                         AudioInputCallback,
                                         &stateInp,
                                         CFRunLoopGetCurrent(),
                                         kCFRunLoopCommonModes,
                                         0,
                                         &stateInp.queue);

    if (status == 0) {
        for (int i = 0; i < NUM_BUFFERS; i++) {
            AudioQueueAllocateBuffer(stateInp.queue, NUM_BYTES_PER_BUFFER, &stateInp.buffers[i]);
            AudioQueueEnqueueBuffer (stateInp.queue, stateInp.buffers[i], 0, NULL);
        }

        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
        stateInp.isCapturing = true;
        status = AudioQueueStart(stateInp.queue, NULL);
        if (status == 0) {
            self.onStatusChanged(@"onCaptureStart");
        }
    }

    if (status != 0) {
        [self stopCapturing];
    }
}

- (void) stopPlayback
{
    printf("Stop playback\n");

    self.onStatusChanged(@"onPlaybackStop");

    stateOut.isPlaying = false;

    for (int i = 0; i < NUM_BUFFERS; i++) {
        AudioQueueFreeBuffer(stateOut.queue, stateOut.buffers[i]);
    }

    AudioQueueDispose(stateOut.queue, true);
}


- (void)togglePlaybackWithMessage:(NSString *)message mode:(int)mode volume:(int)volume {
    if (stateOut.isPlaying) {
        [self stopPlayback];
        return;
    }

    // prepare audio message using GGWave
    {
        const char * payload = [message cStringUsingEncoding:NSUTF8StringEncoding];
        const int len = (int) strlen(payload);

        const int n = ggwave_encode(stateOut.ggwaveId, payload, len, mode, volume, NULL, 1);

        stateOut.waveform = [NSMutableData dataWithLength:sizeof(char)*n];

        const int ret = ggwave_encode(stateOut.ggwaveId, payload, len, mode, volume, [stateOut.waveform mutableBytes], 0);

        if (ret > n) {
            printf("failed to encode the message '%s', n = %d, ret = %d\n", payload, n, ret);
            return;
        }

        stateOut.offset = 0;
        stateOut.totalBytes = n;
    }

    // initiate playback

    printf("Send message\n");

    OSStatus status = AudioQueueNewOutput(&stateOut.dataFormat,
                                          AudioOutputCallback,
                                          &stateOut,
                                          CFRunLoopGetCurrent(),
                                          kCFRunLoopCommonModes,
                                          0,
                                          &stateOut.queue);

    if (status == 0) {
        stateOut.isPlaying = true;
        for (int i = 0; i < NUM_BUFFERS && stateOut.isPlaying; i++) {
            AudioQueueAllocateBuffer(stateOut.queue, NUM_BYTES_PER_BUFFER, &stateOut.buffers[i]);
            AudioOutputCallback(&stateOut, stateOut.queue, stateOut.buffers[i]);
        }
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        status = AudioQueueStart(stateOut.queue, NULL);
        if (status == 0) {
            self.onStatusChanged(@"onPlaybackStart");
        }
    }

    if (status != 0) {
        [self stopPlayback];
    }
}

@end


//
// Callback implmentation
//

void AudioInputCallback(void * inUserData,
                        AudioQueueRef inAQ,
                        AudioQueueBufferRef inBuffer,
                        const AudioTimeStamp * inStartTime,
                        UInt32 inNumberPacketDescriptions,
                        const AudioStreamPacketDescription * inPacketDescs)
{
	StateInp * stateInp = (StateInp*)inUserData;

    if (!stateInp->isCapturing) {
        printf("Not capturing, returning\n");
        return;
    }

    char decoded[256];

    // analyze captured audio
    int ret = ggwave_ndecode(stateInp->ggwaveId, (char *)inBuffer->mAudioData, inBuffer->mAudioDataByteSize, decoded, 256);

    // check if a message has been received
    if (ret > 0) {
        decoded[ret] = 0; // null terminate the string
        stateInp->onReceivedMessage([NSString stringWithFormat:@"%s", decoded]);
    }

    // put the buffer back in the queue
    AudioQueueEnqueueBuffer(stateInp->queue, inBuffer, 0, NULL);
}

void AudioOutputCallback(void * inUserData,
                         AudioQueueRef outAQ,
                         AudioQueueBufferRef outBuffer)
{
	StateOut* stateOut = (StateOut*)inUserData;
    if (!stateOut->isPlaying) {
        printf("Not playing, returning\n");
        return;
    }

    int nRemainingBytes = stateOut->totalBytes - stateOut->offset;

    // check if there is any audio left to play
    if (nRemainingBytes > 0) {
        int nBytesToPush = MIN(nRemainingBytes, NUM_BYTES_PER_BUFFER);

        memcpy(outBuffer->mAudioData, [stateOut->waveform mutableBytes] + stateOut->offset, nBytesToPush);
        outBuffer->mAudioDataByteSize = nBytesToPush;

        OSStatus status = AudioQueueEnqueueBuffer(stateOut->queue, outBuffer, 0, NULL);
        if (status != 0) {
            printf("Failed to enqueue audio data\n");
        }

        stateOut->offset += nBytesToPush;
    } else {
        // no audio left - stop playback
        if (stateOut->isPlaying) {
            printf("Stopping playback\n");
            AudioQueueStop(stateOut->queue, false);
            stateOut->isPlaying = false;
            stateOut->onStatusChanged(@"onPlaybackComplete");
        }

        AudioQueueFreeBuffer(stateOut->queue, outBuffer);
    }
}

//
//  AUv3_instrument_Sine_AppexAudioUnit.m
//  AUv3-instrument-Sine-Appex
//
//  Created by John Carlson on 7/14/19.
//  Copyright © 2019 John Carlson. All rights reserved.
//

#import "AUv3_instrument_Sine_AppexAudioUnit.h"

#import <AVFoundation/AVFoundation.h>

#import "BufferedAudioBus.hpp"
#import "InstrumentDSPKernel.hpp"

#import "maximilian.hpp"

///////////////////////////////////////////////////////////////////////////////////////////////////////

// Define parameter addresses.
//const AudioUnitParameterID myParam1 = 0;
const AUParameterAddress PARAMETER_1 = 0;

///////////////////////////////////////////////////////////////////////////////////////////////////////

@interface AUv3_instrument_Sine_AppexAudioUnit ()

@property (nonatomic, readwrite) AUParameterTree* parameterTree;

@property AUAudioUnitBus* outputBus; // https://developer.apple.com/documentation/audiotoolbox/auaudiounitbus?language=objc

@property AUAudioUnitBusArray *outputBusArray; // https://developer.apple.com/documentation/audiotoolbox/auaudiounitbusarray?language=objc

@end

///////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation AUv3_instrument_Sine_AppexAudioUnit

@synthesize parameterTree = _parameterTree;

AUParameter *_parameter_1;

AudioStreamBasicDescription _streamBasicDescription; // local copy of the asbd that block can capture
// https://developer.apple.com/documentation/coreaudio/audiostreambasicdescription?language=objc

UInt64 _totalFrames;

AUValue _paramteter1Value;  // https://developer.apple.com/documentation/audiotoolbox/auvalue?language=objc

AudioBufferList _renderAudioBufferList; // https://developer.apple.com/documentation/coreaudio/audiobufferlist?language=objc

AVAudioPCMBuffer* _pcmBuffer;  // https://developer.apple.com/documentation/avfoundation/avaudiopcmbuffer?language=objc

const AudioBufferList* _immutableAudioBufferList; // https://developer.apple.com/documentation/avfoundation/avaudiobuffer/1385579-audiobufferlist?language=objc

AudioBufferList* _mutableAudioBufferList;

InstrumentDSPKernel _kernel;
BufferedOutputBus _outputBusBuffer;


///////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Initialization
- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) {
        return nil;
    }
    
    // Create parameter objects.
    _parameter_1 = [AUParameterTree createParameterWithIdentifier:@"param1"
                                                             name:@"Parameter 1"
                                                          address:PARAMETER_1
                                                              min:0
                                                              max:100
                                                             unit:kAudioUnitParameterUnit_Percent
                                                         unitName:nil
                                                            flags:0
                                                     valueStrings:nil
                                              dependentParameters:nil];
    
    // Initialize the parameter values.
    _parameter_1.value = 0.5;
    
    // Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:@[ _parameter_1 ]];
    
    // Initialize a default format for the busses.
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0
                                                                                  channels:2]; // https://developer.apple.com/documentation/avfoundation/avaudioformat?language=objc
    
    _streamBasicDescription = *defaultFormat.streamDescription;
    
    // Create the input and output busses (AUAudioUnitBus).
    //_outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
    _outputBusBuffer.init(defaultFormat, 2);
    _outputBus = _outputBusBuffer.bus;
    
    // Create the input and output bus arrays (AUAudioUnitBusArray).
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                             busType:AUAudioUnitBusTypeOutput
                                                              busses: @[_outputBus]];
    
    // Make a local pointer to the kernel to avoid capturing self.
    __block InstrumentDSPKernel *instrumentKernel = &_kernel;
    
    // implementorValueObserver is called when a parameter changes value.
    _parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        switch (param.address) {
            case PARAMETER_1:
                _paramteter1Value = value;
                break;
            default:
                break;
        }
    };
    
    // implementorValueProvider is called when the value needs to be refreshed.
    _parameterTree.implementorValueProvider = ^(AUParameter *param) {
        switch (param.address) {
            case PARAMETER_1:
                return _paramteter1Value; // TODO: is this capturing self?
            default:
                return (AUValue) 0.0;
        }
    };
    
    // A function to provide string representations of parameter values.
    _parameterTree.implementorStringFromValueCallback = ^(AUParameter *param,
                                                          const AUValue *__nullable valuePtr) {
        
        AUValue value = valuePtr == nil ? param.value : *valuePtr;
        
        switch (param.address) {
            case PARAMETER_1:
                return [NSString stringWithFormat:@"%.f", value];
            default:
                return @"?";
        }
    };
    
    self.maximumFramesToRender = 512;
    
    return self;
}

#pragma mark - AUAudioUnit Overrides

// If an audio unit has input, an audio unit's audio input connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
/*
- (AUAudioUnitBusArray *)inputBusses {
#pragma message("implementation must return non-nil AUAudioUnitBusArray")
    return nil;
}
 */

// An audio unit's audio output connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray *)outputBusses {
//#pragma message("implementation must return non-nil AUAudioUnitBusArray")
    //return nil;
    return _outputBusArray;
}

// Allocate resources required to render.
// Subclassers should call the superclass implementation.
- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    if (![super allocateRenderResourcesAndReturnError:outError]) {
        return NO;
    }
    
    // Validate that the bus formats are compatible.
    // Allocate your resources.
    
    _renderAudioBufferList.mNumberBuffers = 2; // stereo
    
    _totalFrames = 0;
    
    // http://www.rockhoppertech.com/blog/writing-an-audio-unit-v3-instrument/
    /*
    _pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat: _outputBus.format
                                               frameCapacity: self.maximumFramesToRender];
    
    _immutableAudioBufferList = _pcmBuffer.audioBufferList;
    _mutableAudioBufferList = _pcmBuffer.mutableAudioBufferList;
    */
    
    _outputBusBuffer.allocateRenderResources(self.maximumFramesToRender);
    
    _kernel.init(self.outputBus.format.channelCount, self.outputBus.format.sampleRate);
    _kernel.reset();
    
    return YES;
}

// Deallocate resources allocated in allocateRenderResourcesAndReturnError:
// Subclassers should call the superclass implementation.
- (void)deallocateRenderResources {
    // Deallocate your resources.
    [super deallocateRenderResources];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

// Block which subclassers must provide to implement rendering.
- (AUInternalRenderBlock)internalRenderBlock {
    
    // Capture in locals to avoid ObjC member lookups. If "self" is captured in render, we're doing it wrong. See sample code.
    
    __block InstrumentDSPKernel *state = &_kernel;
    
    AUValue* parameter1Capture = &_paramteter1Value;
    AudioStreamBasicDescription *streamBasicDescriptionCapture = &_streamBasicDescription;
    __block UInt64 *totalFramesCapture = &_totalFrames;
    AudioBufferList *renderAudioBufferListCapture = &_renderAudioBufferList;
    
    http://www.rockhoppertech.com/blog/writing-an-audio-unit-v3-instrument/
    //__block AVAudioPCMBuffer* pcm = _pcmBuffer;
    
    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags,
                                    const AudioTimeStamp *timestamp,
                                       AVAudioFrameCount frameCount,
                                               NSInteger outputBusNumber,
                                         AudioBufferList *outputData,
                                     const AURenderEvent *realtimeEventListHead,
                                  AURenderPullInputBlock pullInputBlock) {
        // Do event handling and signal processing here.
        
        //http://www.rockhoppertech.com/blog/auv3-midi/
        /*
        while (realtimeEventListHead != NULL) {
            switch (realtimeEventListHead->head.eventType) {
                case AURenderEventParameter:
                {
                    break;
                }
                case AURenderEventParameterRamp:
                {
                    break;
                }
                case AURenderEventMIDI:
                {
                    AUMIDIEvent midiEvent = realtimeEventListHead->MIDI;
                    uint8_t message = midiEvent.data[0] & 0xF0;
                    uint8_t channel = midiEvent.data[0] & 0x0F;
                    uint8_t data1 = midiEvent.data[1];
                    uint8_t data2 = midiEvent.data[2];
                    
                    // do stuff
                    
                    realtimeEventListHead = realtimeEventListHead->head.next;
                    
                    break;
                }
                case AURenderEventMIDISysEx:
                {
                    break;
                }
            }
         */
        
            
        // http://www.rockhoppertech.com/blog/writing-an-audio-unit-v3-instrument/
        /*
        AudioBufferList *outAudioBufferList = outputData;
        if (outAudioBufferList->mBuffers[0].mData == nullptr) {
            
            for (UInt32 i = 0; i < outAudioBufferList->mNumberBuffers; ++i) {
                
                outAudioBufferList->mBuffers[i].mData = pcm.mutableAudioBufferList->mBuffers[i].mData;
        }
         */
        
            
        // copy samples from AudioBufferList, apply gain multiplier, write to outputData
        /*
        size_t sampleSize = sizeof(Float32);
        for (int frame = 0; frame < frameCount; frame++) {
            
            *totalFramesCapture += 1;
            
            for (int renderBuf = 0; renderBuf < renderAudioBufferListCapture->mNumberBuffers; renderBuf++) {
                
                Float32 *sample = renderAudioBufferListCapture->mBuffers[renderBuf].mData + (frame * streamBasicDescriptionCapture->mBytesPerFrame);
                
                // apply gain multiplier
                *sample = ( (*sample) * (*parameter1Capture/100.0) );
                
                // https://developer.apple.com/documentation/kernel/1579338-memcpy?language=occ
                memcpy(outputData->mBuffers[renderBuf].mData + (frame * streamBasicDescriptionCapture->mBytesPerFrame),
                       sample,
                       sampleSize);
            }
        }
         */
        
        
        _outputBusBuffer.prepareOutputBufferList(outputData, frameCount, true);
        state->setBuffers(outputData);
        state->processWithEvents(timestamp, frameCount, realtimeEventListHead);
        
        
        return noErr;
    };
}

@end

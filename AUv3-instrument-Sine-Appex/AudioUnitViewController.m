//
//  AudioUnitViewController.m
//  AUv3-instrument-Sine-Appex
//
//  Created by John Carlson on 7/14/19.
//  Copyright © 2019 John Carlson. All rights reserved.
//

#import "AudioUnitViewController.h"
#import "AUv3_instrument_Sine_AppexAudioUnit.h"

@interface AudioUnitViewController ()

@end

@implementation AudioUnitViewController {
    AUAudioUnit *audioUnit;
}

- (void) viewDidLoad {
    [super viewDidLoad];
    
    if (!audioUnit) {
        return;
    }
    
    // Get the parameter tree and add observers for any parameters that the UI needs to keep in sync with the AudioUnit
}

- (AUAudioUnit *)createAudioUnitWithComponentDescription:(AudioComponentDescription)desc error:(NSError **)error {
    audioUnit = [[AUv3_instrument_Sine_AppexAudioUnit alloc] initWithComponentDescription:desc error:error];
    
    return audioUnit;
}

@end

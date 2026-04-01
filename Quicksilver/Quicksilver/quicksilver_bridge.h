//
//  quicksilver_bridge.h
//  Quicksilver
//
//  Created by Naryna Azizpour on 4/1/26.
//

#ifndef quicksilver_bridge_h
#define quicksilver_bridge_h

#include <stdint.h>

float qs_run_inference(const float *samples_ptr, uintptr_t samples_len, uint32_t sample_rate);

#endif

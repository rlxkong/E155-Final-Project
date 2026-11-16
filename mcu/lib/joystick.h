#ifndef JOYSTICK_H
#define JOYSTICK_H

#include <stdint.h>

// Calibration constants from the proposal calculations
#define JOY_CENTER      2048    // Midpoint of 12-bit ADC (0..4095)
#define JOY_DEADZONE    200     // Ignore jitter within +/-200 counts (~10% travel)
#define JOY_SPEED_SHIFT 9       // Divide deflection by 2^9 = 512 -> max 4 px/frame
#define SCREEN_W        640     // VGA active width in pixels
#define SCREEN_H        480     // VGA active height in pixels
#define DOT_SIZE        16      // Matches 16x16 maze tile size

// Holds raw ADC averages and current screen coordinates of the dot
typedef struct {
    uint16_t raw_x;
    uint16_t raw_y;
    int16_t  dot_x;
    int16_t  dot_y;
} PlayerState;

// Resets the dot to the center of the screen
void joystickInitState(PlayerState *state);

// Samples each joystick 4 times, applies dead-zone/scaling, and updates (dot_x, dot_y)
void joystickUpdate(PlayerState *state, uint8_t enable_y_axis);

#endif // JOYSTICK_H
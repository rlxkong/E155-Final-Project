#include "joystick.h"
#include "adc.h"
#include <stdlib.h>

void joystickInitState(PlayerState *state) {
    state->raw_x = JOY_CENTER;
    state->raw_y = JOY_CENTER;
    // Start dot near the center of the 640x480 screen
    state->dot_x = (SCREEN_W - DOT_SIZE) / 2;
    state->dot_y = (SCREEN_H - DOT_SIZE) / 2;
}

// Helper: converts a 12-bit ADC reading into pixel velocity (px/frame)
static int16_t computeVelocity(uint16_t adc_val) {
    // Compute signed deflection d from center (-2048 to +2047)
    int16_t d = (int16_t)adc_val - JOY_CENTER;

    // Apply dead zone so resting joystick noise causes zero movement
    if (abs(d) < JOY_DEADZONE) {
        return 0;
    }

    // Scale deflection by d / 512 (arithmetic shift right by 9)
    return (int16_t)(d / 512);
}

void joystickUpdate(PlayerState *state, uint8_t enable_y_axis) {
    uint32_t sum_x = 0;
    uint32_t sum_y = 0;

    // Take 4 samples per joystick per 60 Hz frame and average them to filter noise
    for (int i = 0; i < 4; i++) {
        sum_x += adcRead(JOY_X_CH);
        if (enable_y_axis) {
            sum_y += adcRead(JOY_Y_CH);
        }
    }

    state->raw_x = (uint16_t)(sum_x >> 2); // Divide by 4
    state->raw_y = enable_y_axis ? (uint16_t)(sum_y >> 2) : JOY_CENTER;

    // Update dot position using computed velocities
    state->dot_x += computeVelocity(state->raw_x);
    if (enable_y_axis) {
        state->dot_y += computeVelocity(state->raw_y);
    }

    // Clamp dot position so it stays completely inside the 640x480 visible screen
    if (state->dot_x < 0) state->dot_x = 0;
    if (state->dot_x > (SCREEN_W - DOT_SIZE)) state->dot_x = SCREEN_W - DOT_SIZE;

    if (state->dot_y < 0) state->dot_y = 0;
    if (state->dot_y > (SCREEN_H - DOT_SIZE)) state->dot_y = SCREEN_H - DOT_SIZE;
}
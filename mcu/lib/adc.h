#ifndef ADC_H
#define ADC_H

#include <stdint.h>

// STM32L432KC ADC1 channel mapping for PA0 and PA1
#define JOY_X_CH 5   // PA0 maps to ADC1_IN5
#define JOY_Y_CH 6   // PA1 maps to ADC1_IN6

// Initializes GPIOA pins (PA0, PA1) and configures ADC1 for 12-bit conversions
void adcInit(void);

// Performs a single 12-bit conversion (0 to 4095) on the given ADC1 channel
uint16_t adcRead(uint8_t channel);

#endif // ADC_H
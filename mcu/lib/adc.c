#include "adc.h"
#include "stm32l432xx.h" // Standard CMSIS device header included in E155 projects

void adcInit(void) {
    // 1. Enable peripheral clocks for GPIOA and ADC1
    RCC->AHB2ENR |= RCC_AHB2ENR_GPIOAEN;
    RCC->AHB2ENR |= RCC_AHB2ENR_ADCEN;

    // 2. Select System Clock (SYSCLK) as the ADC clock source (defaults to No Clock on STM32L4)
    RCC->CCIPR |= (0b11 << RCC_CCIPR_ADCSEL_Pos);

    // 3. Configure PA0 and PA1 as Analog Inputs (MODER = 0b11)
    GPIOA->MODER |= (0b11 << (0 * 2)) | (0b11 << (1 * 2));

    // 4. Exit ADC deep-power-down mode and turn on the internal voltage regulator
    ADC1->CR &= ~ADC_CR_DEEPPWD;
    ADC1->CR |= ADC_CR_ADVREGEN;

    // 5. Wait ~20 us for the ADC voltage regulator to stabilize
    for (volatile int i = 0; i < 1000; i++);

    // 6. Run single-ended calibration to minimize offset error
    ADC1->CR &= ~ADC_CR_ADCALDIF;
    ADC1->CR |= ADC_CR_ADCAL;
    while (ADC1->CR & ADC_CR_ADCAL); // Wait until calibration completes

    // 7. Set sampling time to 24.5 ADC clock cycles for channels 5 (PA0) and 6 (PA1)
    // Longer sample time ensures high-impedance joystick potentiometers settle accurately
    ADC1->SMPR1 &= ~((0b111 << (JOY_X_CH * 3)) | (0b111 << (JOY_Y_CH * 3)));
    ADC1->SMPR1 |=  ((0b011 << (JOY_X_CH * 3)) | (0b011 << (JOY_Y_CH * 3)));

    // 8. Clear the ADRDY flag, enable ADC1, and wait until it is ready
    ADC1->ISR |= ADC_ISR_ADRDY;
    ADC1->CR  |= ADC_CR_ADEN;
    while (!(ADC1->ISR & ADC_ISR_ADRDY));
}

uint16_t adcRead(uint8_t channel) {
    // Set regular conversion sequence length to 1 (L[3:0] = 0) and select target channel in SQ1
    ADC1->SQR1 = ((uint32_t)(channel & 0x1F) << ADC_SQR1_SQ1_Pos);

    // Start the conversion
    ADC1->CR |= ADC_CR_ADSTART;

    // Wait until the End of Conversion (EOC) flag is set
    while (!(ADC1->ISR & ADC_ISR_EOC));

    // Reading the Data Register (DR) returns the 12-bit result and automatically clears EOC
    return (uint16_t)(ADC1->DR & 0x0FFF);
}
/*
File: Final_Proj.c
Author: Rebecca Kong and Emily Ing
Email: rkong@hmc.edu and eing@hmc.edu
Date: 11/16/26
*/

#include "stm32l432xx.h"
#include "adc.h"
#include "joystick.h"
#include "spi_link.h"

// ============================================================================
// MIDPOINT TEST MODE SELECTOR:
//   Set to 1 for Milestone 11/16 (sweeps dot automatically across VGA via SPI)
//   Set to 0 for Milestone 11/17 (joystick controls dot position in real time)
// ============================================================================
#define TEST_MODE_SPI_SWEEP 0

// Initializes TIM2 as a free-running 1 MHz (1 us per tick) microsecond timer
static void timerInit(void) {
    RCC->APB1ENR1 |= RCC_APB1ENR1_TIM2EN;
    // Assuming default 4 MHz MSI clock on reset -> PSC = 3 gives 1 MHz (adjust if SYSCLK = 80 MHz -> PSC = 79)
    TIM2->PSC = (SystemCoreClock / 1000000U) - 1U;
    TIM2->ARR = 0xFFFFFFFF;
    TIM2->EGR = TIM_EGR_UG;
    TIM2->CR1 = TIM_CR1_CEN;
}

int main(void) {
    SystemCoreClockUpdate(); // Ensure SystemCoreClock matches current clock tree
    timerInit();
    adcInit();
    spiLinkInit();

    PlayerState player;
    joystickInitState(&player);

    uint32_t last_frame_us = TIM2->CNT;
    const uint32_t FRAME_PERIOD_US = 16667; // 60 Hz frame rate (~16.67 ms per tick)

    while (1) {
        // Wait until 16.67 ms has elapsed to maintain a steady 60 Hz update rate
        if ((TIM2->CNT - last_frame_us) >= FRAME_PERIOD_US) {
            last_frame_us += FRAME_PERIOD_US;

#if TEST_MODE_SPI_SWEEP
            // Milestone 11/16: Sweep dot horizontally across screen to verify SPI -> VGA link
            player.dot_x += 2;
            if (player.dot_x > (SCREEN_W - DOT_SIZE)) {
                player.dot_x = 0;
            }
#else
            // Milestone 11/14 & 11/17: Read joystick ADC and move dot
            // Pass 0 for 1-joystick X-axis check (High Risk Item), or 1 to enable both axes
            joystickUpdate(&player, 0);
#endif

            // Send updated 48-bit packet to the FPGA over SPI
            spiSendPacket48((uint16_t)player.dot_x, (uint16_t)player.dot_y, 60, 0);
        }
    }
}
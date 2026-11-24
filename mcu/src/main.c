/*
File: main.c
Author: Rebecca Kong and Emily Ing
Email: rkong@hmc.edu and eing@hmc.edu
Date: 11/16/26
*/

#include "stm32l432xx.h"
#include <stdint.h>

// 150-byte (40x30 tile) maze stored in STM32 Flash via 'const' (5 bytes per row, MSB = left tile)
const uint8_t maze_level1[150] = {
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF,  // Row  0
    0x80, 0x00, 0x00, 0x00, 0x01,  // Row  1
    0xBF, 0x7F, 0xBF, 0xF7, 0xFD,  // Row  2
    0xA1, 0x00, 0x80, 0x14, 0x05,  // Row  3
    0xAD, 0xFE, 0xFF, 0xD5, 0xF5,  // Row  4
    0x8C, 0x00, 0x80, 0x11, 0x11,  // Row  5
    0xEF, 0xFF, 0xBF, 0xF7, 0x5D,  // Row  6
    0x88, 0x00, 0x20, 0x04, 0x41,  // Row  7
    0xBB, 0xFF, 0xEF, 0xFD, 0xFD,  // Row  8
    0xA2, 0x00, 0x20, 0x04, 0x05,  // Row  9
    0xAE, 0xFF, 0xAF, 0xF7, 0xF5,  // Row 10
    0xA0, 0x80, 0xA8, 0x10, 0x11,  // Row 11
    0xBF, 0xBE, 0xAB, 0xDF, 0xDD,  // Row 12
    0x80, 0x22, 0x22, 0x40, 0x41,  // Row 13
    0xFF, 0xEB, 0xFE, 0xFF, 0xDD,  // Row 14
    0x80, 0x08, 0x00, 0x80, 0x11,  // Row 15
    0xBF, 0xFF, 0xFE, 0xBF, 0xF7,  // Row 16
    0xA0, 0x00, 0x02, 0x80, 0x11,  // Row 17
    0xAF, 0xFF, 0xFA, 0xFF, 0xDD,  // Row 18
    0x88, 0x00, 0x0A, 0x00, 0x41,  // Row 19
    0xEB, 0xFF, 0xEB, 0xFF, 0x7D,  // Row 20
    0x8A, 0x00, 0x28, 0x01, 0x05,  // Row 21
    0xBA, 0xFF, 0xAF, 0xFD, 0xF5,  // Row 22
    0x82, 0x80, 0x88, 0x04, 0x11,  // Row 23
    0xBE, 0xBE, 0xFB, 0xF7, 0xDD,  // Row 24
    0xA0, 0xA2, 0x08, 0x10, 0x41,  // Row 25
    0xAF, 0xAB, 0xEF, 0xDF, 0x7D,  // Row 26
    0x88, 0x28, 0x20, 0x41, 0x05,  // Row 27
    0xEB, 0xEF, 0xBF, 0x7D, 0xF4,  // Row 28
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF   // Row 29
};

// Initialize SPI1 in Mode 0 (CPOL=0, CPHA=0, 8-bit MSB first) on PA4..PA7
void spi1_init(void) {
    // 1. Enable GPIOA and SPI1 peripheral clocks
    RCC->AHB2ENR |= RCC_AHB2ENR_GPIOAEN;
    RCC->APB2ENR |= RCC_APB2ENR_SPI1EN;

    // 2. Configure PA4 (CS) as manual push-pull output, initialized HIGH (idle)
    GPIOA->MODER &= ~(3U << (4 * 2));
    GPIOA->MODER |=  (1U << (4 * 2));   // 01 = General-purpose output
    GPIOA->BSRR   =  GPIO_BSRR_BS4;     // Set PA4 = 1 (CS inactive)

    // 3. Configure PA5 (SCK), PA6 (MISO), PA7 (MOSI) as Alternate Function AF5
    GPIOA->MODER &= ~((3U << (5 * 2)) | (3U << (6 * 2)) | (3U << (7 * 2)));
    GPIOA->MODER |=  ((2U << (5 * 2)) | (2U << (6 * 2)) | (2U << (7 * 2))); // 10 = AF

    GPIOA->AFR[0] &= ~((0xFU << (5 * 4)) | (0xFU << (6 * 4)) | (0xFU << (7 * 4)));
    GPIOA->AFR[0] |=  ((5U   << (5 * 4)) | (5U   << (6 * 4)) | (5U   << (7 * 4))); // AF5

    // High-speed slew rate on SCK and MOSI for clean edges
    GPIOA->OSPEEDR |= (3U << (5 * 2)) | (3U << (7 * 2));

    // 4. Configure SPI1: Master mode, Mode 0 (CPOL=0, CPHA=0), f_PCLK / 32 (<= 2.5 MHz)
    SPI1->CR1 = 0;
    SPI1->CR1 |= SPI_CR1_MSTR             // Master mode
              |  SPI_CR1_SSM              // Software slave management
              |  SPI_CR1_SSI              // Internal slave select = 1
              |  (4U << SPI_CR1_BR_Pos);  // Baud rate = f_PCLK / 32 (2.5 MHz @ 80 MHz SYSCLK)

    // 8-bit data size (DS = 0b0111) and 8-bit RX FIFO threshold (FRXTH = 1)
    SPI1->CR2 = (7U << SPI_CR2_DS_Pos) | SPI_CR2_FRXTH;

    // Enable SPI1
    SPI1->CR1 |= SPI_CR1_SPE;
}

// Transmit and receive 1 byte over SPI1
uint8_t spi1_transfer(uint8_t data) {
    // Wait until TX FIFO has space
    while (!(SPI1->SR & SPI_SR_TXE));

    // CRITICAL: Cast DR to (uint8_t *) so STM32L4 writes 8 bits instead of 16 bits
    *(volatile uint8_t *)&SPI1->DR = data;

    // Wait until byte finishes shifting and RX FIFO has 1 byte
    while (!(SPI1->SR & SPI_SR_RXNE));
    return *(volatile uint8_t *)&SPI1->DR;
}

// Send Command 0x01 + 150 maze bytes to load FPGA Block RAM
void fpga_load_maze(const uint8_t *maze) {
    GPIOA->BSRR = GPIO_BSRR_BR4;        // Pull CS (PA4) LOW to start transaction

    spi1_transfer(0x01);                // Command 0x01: Load Maze
    for (int i = 0; i < 150; i++) {
        spi1_transfer(maze[i]);         // Send all 150 bytes (1,200 bits)
    }

    while (SPI1->SR & SPI_SR_BSY);      // Ensure final SCK edge completes
    GPIOA->BSRR = GPIO_BSRR_BS4;        // Pull CS (PA4) HIGH to finish transaction
}

// Send Command 0x02 + 6 bytes (48-bit runtime packet: dot X, dot Y, timer, flags)
void fpga_send_game_state(uint16_t dot_x, uint16_t dot_y, uint8_t timer_sec, uint8_t flags) {
    GPIOA->BSRR = GPIO_BSRR_BR4;        // Pull CS (PA4) LOW

    spi1_transfer(0x02);                // Command 0x02: Update Game State
    spi1_transfer((dot_x >> 8) & 0xFF); // Byte 1: Dot X MSB
    spi1_transfer(dot_x & 0xFF);        // Byte 2: Dot X LSB
    spi1_transfer((dot_y >> 8) & 0xFF); // Byte 3: Dot Y MSB
    spi1_transfer(dot_y & 0xFF);        // Byte 4: Dot Y LSB
    spi1_transfer(timer_sec);           // Byte 5: Countdown timer (seconds)
    spi1_transfer(flags);               // Byte 6: Status flags (e.g., game over)

    while (SPI1->SR & SPI_SR_BSY);
    GPIOA->BSRR = GPIO_BSRR_BS4;        // Pull CS (PA4) HIGH
}

int main(void) {
    spi1_init();

    // Load the 150-byte maze into the FPGA's Block RAM at startup (or on restart)
    fpga_load_maze(maze_level1);

    // Example initial game state: dot at center (320, 240), 60s timer, flags = 0
    fpga_send_game_state(320, 240, 60, 0x00);

    while (1) {
        // Your 60 Hz game loop will sample joysticks, check wall collisions,
        // update dot_x / dot_y / timer_sec, and call fpga_send_game_state(...)
    }
}
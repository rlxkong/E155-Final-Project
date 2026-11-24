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
    // 1. Turn on clocks for GPIOA and SPI1
    RCC->AHB2ENR |= RCC_AHB2ENR_GPIOAEN;
    RCC->APB2ENR |= RCC_APB2ENR_SPI1EN;

    // 2. PA4 (CS): Set to Output (01 at bit 8) and drive HIGH
    GPIOA->MODER &= ~(0b11 << 8);       // PA4
    GPIOA->MODER |=  (0b01 << 8);       // 01 = General-purpose output
    GPIOA->BSRR   =  (0b1  << 4);       // Set PA4 = 1 (CS idle high)

    // 3. PA5 (SCK), PA6 (MISO), PA7 (MOSI): Set to Alternate Function (10)
    GPIOA->MODER &= ~(0b11 << 10);      // Clear PA5 (bits 11:10)
    GPIOA->MODER |=  (0b10 << 10);      // 10 = Alternate Function

    GPIOA->MODER &= ~(0b11 << 12);      // Clear PA6 (bits 13:12)
    GPIOA->MODER |=  (0b10 << 12);      // 10 = Alternate Function

    GPIOA->MODER &= ~(0b11 << 14);      // Clear PA7 (bits 15:14)
    GPIOA->MODER |=  (0b10 << 14);      // 10 = Alternate Function

    // 4. Connect PA5, PA6, PA7 to SPI1 (AF5 = 0101)
    GPIOA->AFR[0] &= ~(0b1111 << 20);   // Clear PA5 (bits 23:20)
    GPIOA->AFR[0] |=  (0b0101 << 20);   // 0101 = AF5 (SPI1_SCK)

    GPIOA->AFR[0] &= ~(0b1111 << 24);   // Clear PA6 (bits 27:24)
    GPIOA->AFR[0] |=  (0b0101 << 24);   // 0101 = AF5 (SPI1_MISO)

    GPIOA->AFR[0] &= ~(0b1111 << 28);   // Clear PA7 (bits 31:28)
    GPIOA->AFR[0] |=  (0b0101 << 28);   // 0101 = AF5 (SPI1_MOSI)

    // 5. Very high edge speed (11) on SCK (PA5) and MOSI (PA7)
    // need this because it controls the slew rate (how fast the pin's internal transistors
    // slam voltage from 0V to 3.3 V and back down)
    // setting to very high speed (0b11) opens the pin's drive transistors so that
    // sck and mosi snap vertically between the voltage range
    GPIOA->OSPEEDR |= (0b11 << 10) | (0b11 << 14);

    // 6. Configure SPI1: Master mode, Mode 0, baud rate = /32 (BR = 100 at bit 3)
    SPI1->CR1 = SPI_CR1_MSTR | SPI_CR1_SSM | SPI_CR1_SSI | (0b100 << 3);

    // 7. 8-bit data size (DS = 0111 at bit 8) + 8-bit RX threshold (FRXTH = 1 at bit 12)
    // controls packet size and receive buffer
    // DS | FRXTH (defaults to 16-bit mode, so it waits for 2 bytes before raising RXNE flag. but spi1_transfer sends 1 byte at a time so we need to set FRXTH to what we have here)
    SPI1->CR2 = (0b0111 << 8) | (0b1 << 12);

    // 8. Turn SPI1 ON
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
// handles the Chip Select (CS) framing and 48-bit packet packing on top of it.

#include "spi_link.h"
#include "STM32L432KC_SPI.h"  // Uses your existing initSPI() and spiSendReceive()[cite: 7]
#include "STM32L432KC_GPIO.h" // Uses your existing pinMode() and digitalWrite()

#define SPI_CS_PIN PA4        // Chip Select pin wired to FPGA spi_cs_n

void spiLinkInit(void) {
    // Configure CS as a digital output and idle it HIGH
    pinMode(SPI_CS_PIN, GPIO_OUTPUT);
    digitalWrite(SPI_CS_PIN, 1);

    // Initialize SPI1: baud rate divider = 3 (fPCLK/16), CPOL = 0, CPHA = 0 (Mode 0)[cite: 1]
    initSPI(3, 0, 0);
}

void spiSendPacket48(uint16_t dot_x, uint16_t dot_y, uint8_t timer_sec, uint8_t game_state) {
    // Pack the 48-bit (6-byte) frame MSB-first to match spi_receiver.sv[cite: 2]
    uint8_t pkt[6];
    pkt[0] = (uint8_t)((dot_x >> 2) & 0xFF);
    pkt[1] = (uint8_t)(((dot_x & 0x03) << 6) | ((dot_y >> 4) & 0x3F));
    pkt[2] = (uint8_t)(((dot_y & 0x0F) << 4) | ((timer_sec >> 4) & 0x0F));
    pkt[3] = (uint8_t)(((timer_sec & 0x0F) << 4) | (game_state & 0x0F));
    pkt[4] = 0x00;
    pkt[5] = 0x00;

    // Pull CS low, send all 6 bytes (48 bits) via your library, then pull CS high to latch[cite: 2]
    digitalWrite(SPI_CS_PIN, 0);
    for (int i = 0; i < 6; i++) {
        spiSendReceive((char)pkt[i]);
    }
    digitalWrite(SPI_CS_PIN, 1);
}
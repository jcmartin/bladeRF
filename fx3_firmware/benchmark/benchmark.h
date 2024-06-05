#include "cyu3types.h"
#include "cyu3usbconst.h"
#include "cyu3externcstart.h"

#define DMA_TX_SIZE        0
#define THREAD_STACK       0x1000
#define THREAD_PRIORITY    8

#define CY_FX_EP_CONSUMER               0x81    /* EP 1 IN */
#define CY_FX_EP_CONSUMER_SOCKET        CY_U3P_UIB_SOCKET_CONS_1    /* Socket 1 is consumer */
#define CY_FX_GPIF_PRODUCER_SOCKET_0    CY_U3P_PIB_SOCKET_0
#define CY_FX_GPIF_PRODUCER_SOCKET_1    CY_U3P_PIB_SOCKET_1
#define CY_FX_EP_DEBUG                  0x82
#define CY_FX_EP_DEBUG_SOCKET           CY_U3P_UIB_SOCKET_CONS_2

#define CY_FX_EP_BURST_LENGTH           16
#define CY_FX_DMA_BUF_SIZE              16384
#define CY_FX_DMA_BUF_COUNT             3

/* Extern definitions for the USB Descriptors */
extern const uint8_t CyFxUSBDeviceQualDscr[];
extern const uint8_t CyFxUSBFSConfigDscr[];
extern const uint8_t CyFxUSBHSConfigDscr[];
extern const uint8_t CyFxUSBBOSDscr[];
extern const uint8_t CyFxUSBSSConfigDscr[];
extern const uint8_t CyFxUSBStringLangIDDscr[];
extern const uint8_t CyFxUSBManufactureDscr[];
extern const uint8_t CyFxUSB20DeviceDscr[];
extern const uint8_t CyFxUSB30DeviceDscr[];
extern const uint8_t CyFxUSBProductDscr[];
extern const uint8_t CyFxUSB20DeviceDscr[];
extern const uint8_t CyFxUSB30DeviceDscr[];
extern const uint8_t CyFxUSBProductDscr[];

#include "cyu3externcend.h"

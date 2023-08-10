#include <stdlib.h>
#include <libusb.h>
#include <stdbool.h>
#include <stdint.h>

#define VID     0x0
#define PID     0x0

#define N_ITER      100
#define N_XFERS     2
#define XFER_SIZE   1024
#define EP_IN       0x81
#define EP_DEBUG    0x82

struct stream {
    bool canceled;
    int n_in_flight;
    int n_completed;
    struct libusb_transfer **transfers;
    unsigned char **buffers;
};

void cancel_all_transfers(struct stream *s) {
    s->canceled = true;
    int ret;

    for (int i = 0; i < N_XFERS; i++) {
        ret = libusb_cancel_transfer(s->transfers[i]);
        // NOT_FOUND if the transfer is not in progress, already complete, or already cancelled
        if (ret && ret != LIBUSB_ERROR_NOT_FOUND) {
            printf("Error canceling transfer %d: %s\n", i, libusb_error_name(ret));
        }
    }
}

static void LIBUSB_CALL bulk_rx_cb(struct libusb_transfer *transfer) {
    struct stream *s = transfer->user_data;
    s->n_in_flight--;

    if (transfer->status == LIBUSB_TRANSFER_CANCELLED || s->canceled) {
        return;
    }

    if (transfer->actual_length != transfer->length) {
        printf("Error: unexpected transfer length: %d (expected %d)\n",
               transfer->actual_length, transfer->length);
        cancel_all_transfers(s);
        return;
    }
    
    s->n_completed++;
    if (s->n_completed + s->n_in_flight < N_ITER) {
        int ret = libusb_submit_transfer(transfer);
        if (ret) {
            printf("Error resubmitting transfer %s\n", libusb_error_name(ret));
            cancel_all_transfers(s);
            return;
        }
        s->n_in_flight++;
    }
}

int main(int argc, char **argv) {
    int ret;

    ret = libusb_init(NULL);
    if (ret) {
        printf("Error initializing libusb: %s\n", libusb_error_name(ret));
        return ret;
    }

    libusb_device_handle *hd = libusb_open_device_with_vid_pid(NULL, VID, PID);
    if (hd == NULL) {
        printf("No device found\n");
        return -1;
    }

    libusb_device *dev = libusb_get_device(hd);
    ret = libusb_claim_interface(hd, 0);
    if (ret) {
        printf("Error claiming interface: %s\n", libusb_error_name(ret));
        goto exit_dev;
    }

    // TODO: ensure expected endpoints exist
    // struct libusb_config_descriptor *config;
    // ret = libusb_get_config_descriptor(dev, 0, &config);
    
    ret = -1;
    struct libusb_transfer **transfers = calloc(N_XFERS, sizeof(struct libusb_transfer *));
    if (transfers == NULL) {
        printf("Error allocating libusb transfers\n");
        goto exit_dev;
    }
    unsigned char **buffers = (unsigned char **) calloc(N_XFERS, sizeof(unsigned char *));
    if (buffers == NULL) {
        printf("Error allocating buffers\n");
        goto exit_transfers;
    }
    
    struct stream *s = malloc(sizeof(struct stream));
    if (s == NULL) {
        printf("Error allocating stream\n");
        goto exit_buffers;
    }

    s->n_completed = 0;
    s->n_in_flight = 0;

    for (int i = 0; i < N_XFERS; i++) {
        transfers[i] = libusb_alloc_transfer(0);

        if (transfers[i] == NULL) {
            printf("Error allocating a libusb transfer\n");
            goto exit;
        }
        
        buffers[i] = malloc(XFER_SIZE);
        
        if (buffers[i] == NULL) {
            printf("Error allocating a buffer\n");
            goto exit;
        }

        libusb_fill_bulk_transfer(transfers[i], hd, EP_IN, buffers[i],
                                  XFER_SIZE, bulk_rx_cb, s, 1000);
    }
    s->transfers = transfers;
    s->buffers = buffers;

    for (int i = 0; i < N_XFERS && s->n_in_flight < N_ITER; i++) {
        ret = libusb_submit_transfer(transfers[i]);
        if (ret) {
            printf("Error submitting transfer %d: %s\n", i, libusb_error_name(ret));
            cancel_all_transfers(s);
            goto exit;
        }
        s->n_in_flight++;
    }

    while (s->n_in_flight) {
        ret = libusb_handle_events(NULL);
        if (ret) {
            printf("Error handling events %s\n", libusb_error_name(ret));
            cancel_all_transfers(s);
            goto exit;
        }
    }
    ret = 0;

exit:
    for (int i = 0; i < N_XFERS; i++) {
        if (transfers[i] != NULL) {
            libusb_free_transfer(transfers[i]);
        }
        if (buffers[i] != NULL) {
            free(buffers[i]);
        }
    }
exit_buffers:
    free(buffers);
exit_transfers:
    free(transfers);
    // libusb_free_config_descriptor(config);
exit_dev:
    libusb_close(hd);
    libusb_exit(NULL);
    return ret;
}
/**
 * Reset USB device in case of problems
 *
 * Idea from http://askubuntu.com/a/661
 *
 * Compile
 * $ cc usbreset.c -o usbreset && strip usbreset && ./usbreset
 */
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <linux/usbdevice_fs.h>

int main(int argc, char **argv)
{
    const char *filename;
    int fd;
    int rc;

    if (argc != 2) {
        fprintf(stderr, "\nUsage: %s <device filename>\n\n", argv[0]);
        fprintf(stderr, "Find your device with:\n\n$ lsusb\n...\n");
        fprintf(stderr, "Bus 001 Device 002: ID 0403:6001 Future Technology Devices ...\n...\n\n");
        fprintf(stderr, "The device filename is: /dev/bus/usb/<Bus>/<Device>\n");
        fprintf(stderr, "here: /dev/bus/usb/001/002\n");
        return 1;
    }

    filename = argv[1];

    printf("Reset %s ...\n", filename);

    fd = open(filename, O_WRONLY);
    if (fd < 0) {
        perror("Error opening device");
        return 2;
    }

    rc = ioctl(fd, USBDEVFS_RESET, 0);

    if (rc < 0) {
        perror("Error in ioctl");
        return 3;
    }

    printf("Reset successful\n");

    close(fd);

    return 0;
}

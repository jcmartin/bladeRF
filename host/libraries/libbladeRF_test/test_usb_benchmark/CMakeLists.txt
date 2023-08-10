cmake_minimum_required(VERSION 2.8.12)
project(libbladeRF_test_usb_benchmark C)

add_executable(libbladeRF_test_usb_benchmark src/main.c)
target_include_directories(libbladeRF_test_usb_benchmark PRIVATE ${LIBUSB_INCLUDE_DIRS})
target_link_libraries(libbladeRF_test_usb_benchmark ${LIBUSB_LIBRARIES})

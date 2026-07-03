# CategoryHIDAPI

Header file for SDL HIDAPI functions.

This is an adaptation of the original HIDAPI interface by Alan Ott, and
includes source code licensed under the following license:

    HIDAPI - Multi-Platform library for
    communication with HID devices.

    Copyright 2009, Alan Ott, Signal 11 Software.
    All Rights Reserved.

    This software may be used by anyone for any reason so
    long as the copyright notice in the source files
    remains intact.

(Note that this license is the same as item three of SDL's zlib license,
so it adds no new requirements on the user.)

If you would like a version of SDL without this code, you can build SDL
with [SDL_HIDAPI_DISABLED](SDL_HIDAPI_DISABLED.html) defined to 1. You
might want to do this for example on iOS or tvOS to avoid a dependency
on the CoreBluetooth framework.

## Functions

- [SDL_hid_ble_scan](SDL_hid_ble_scan.html)
- [SDL_hid_close](SDL_hid_close.html)
- [SDL_hid_device_change_count](SDL_hid_device_change_count.html)
- [SDL_hid_enumerate](SDL_hid_enumerate.html)
- [SDL_hid_exit](SDL_hid_exit.html)
- [SDL_hid_free_enumeration](SDL_hid_free_enumeration.html)
- [SDL_hid_get_device_info](SDL_hid_get_device_info.html)
- [SDL_hid_get_feature_report](SDL_hid_get_feature_report.html)
- [SDL_hid_get_indexed_string](SDL_hid_get_indexed_string.html)
- [SDL_hid_get_input_report](SDL_hid_get_input_report.html)
- [SDL_hid_get_manufacturer_string](SDL_hid_get_manufacturer_string.html)
- [SDL_hid_get_product_string](SDL_hid_get_product_string.html)
- [SDL_hid_get_properties](SDL_hid_get_properties.html)
- [SDL_hid_get_report_descriptor](SDL_hid_get_report_descriptor.html)
- [SDL_hid_get_serial_number_string](SDL_hid_get_serial_number_string.html)
- [SDL_hid_init](SDL_hid_init.html)
- [SDL_hid_open](SDL_hid_open.html)
- [SDL_hid_open_path](SDL_hid_open_path.html)
- [SDL_hid_read](SDL_hid_read.html)
- [SDL_hid_read_timeout](SDL_hid_read_timeout.html)
- [SDL_hid_send_feature_report](SDL_hid_send_feature_report.html)
- [SDL_hid_set_nonblocking](SDL_hid_set_nonblocking.html)
- [SDL_hid_write](SDL_hid_write.html)

## Datatypes

- [SDL_hid_device](SDL_hid_device.html)

## Structs

- [SDL_hid_device_info](SDL_hid_device_info.html)

## Enums

- [SDL_hid_bus_type](SDL_hid_bus_type.html)

## Macros

- (none.)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)

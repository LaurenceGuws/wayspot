#include <stddef.h>
#include <stdint.h>

#define STBI_ONLY_JPEG
#define STBI_NO_STDIO
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

uint8_t *wayspot_jpeg_decode(
    const uint8_t *bytes,
    size_t length,
    uint32_t side_limit,
    uint64_t pixel_limit,
    uint32_t *width_out,
    uint32_t *height_out)
{
    int width;
    int height;
    int channels;
    if (length > INT32_MAX ||
        !stbi_info_from_memory(bytes, (int)length, &width, &height, &channels) ||
        width <= 0 || height <= 0 ||
        (uint32_t)width > side_limit || (uint32_t)height > side_limit ||
        (uint64_t)(uint32_t)width * (uint32_t)height > pixel_limit)
        return NULL;

    int decoded_width;
    int decoded_height;
    uint8_t *pixels = stbi_load_from_memory(
        bytes,
        (int)length,
        &decoded_width,
        &decoded_height,
        &channels,
        4);
    if (pixels == NULL)
        return NULL;
    if (decoded_width != width || decoded_height != height) {
        stbi_image_free(pixels);
        return NULL;
    }
    *width_out = (uint32_t)width;
    *height_out = (uint32_t)height;
    return pixels;
}

void wayspot_jpeg_free(void *pixels)
{
    stbi_image_free(pixels);
}

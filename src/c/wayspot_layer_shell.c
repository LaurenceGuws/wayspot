#define _GNU_SOURCE

#include "sdl.h"

#include <sys/mman.h>
#include <string.h>
#include <unistd.h>

struct zwlr_layer_shell_v1;

static const struct wl_interface xdg_popup_interface;
static const struct wl_interface zwlr_layer_surface_v1_interface;

static const struct wl_interface *wayspot_layer_types[] = {
    NULL,
    NULL,
    NULL,
    NULL,
    &zwlr_layer_surface_v1_interface,
    &wl_surface_interface,
    &wl_output_interface,
    NULL,
    NULL,
    &xdg_popup_interface,
};

static const struct wl_message wayspot_layer_shell_requests[] = {
    {"get_layer_surface", "no?ous", wayspot_layer_types + 4},
    {"destroy", "3", wayspot_layer_types + 0},
};

static const struct wl_interface zwlr_layer_shell_v1_interface = {
    "zwlr_layer_shell_v1",
    5,
    2,
    wayspot_layer_shell_requests,
    0,
    NULL,
};

static const struct wl_message wayspot_layer_surface_requests[] = {
    {"set_size", "uu", wayspot_layer_types + 0},
    {"set_anchor", "u", wayspot_layer_types + 0},
    {"set_exclusive_zone", "i", wayspot_layer_types + 0},
    {"set_margin", "iiii", wayspot_layer_types + 0},
    {"set_keyboard_interactivity", "u", wayspot_layer_types + 0},
    {"get_popup", "o", wayspot_layer_types + 9},
    {"ack_configure", "u", wayspot_layer_types + 0},
    {"destroy", "", wayspot_layer_types + 0},
    {"set_layer", "2u", wayspot_layer_types + 0},
    {"set_exclusive_edge", "5u", wayspot_layer_types + 0},
};

static const struct wl_message wayspot_layer_surface_events[] = {
    {"configure", "uuu", wayspot_layer_types + 0},
    {"closed", "", wayspot_layer_types + 0},
};

static const struct wl_interface zwlr_layer_surface_v1_interface = {
    "zwlr_layer_surface_v1",
    5,
    10,
    wayspot_layer_surface_requests,
    2,
    wayspot_layer_surface_events,
};

static uint32_t wayspot_min_u32(uint32_t a, uint32_t b)
{
    return a < b ? a : b;
}

static int wayspot_has_extension(const char *path, const char *extension)
{
    size_t path_len = strlen(path);
    size_t extension_len = strlen(extension);
    if (path_len < extension_len) {
        return 0;
    }
    return SDL_strcasecmp(path + path_len - extension_len, extension) == 0;
}

static int wayspot_cover_source_rect(int source_width, int source_height, int target_width, int target_height, SDL_Rect *rect)
{
    if (source_width <= 0 || source_height <= 0 || target_width <= 0 || target_height <= 0) {
        return -1;
    }

    int64_t source_as_target_wide = (int64_t)source_width * target_height;
    int64_t target_as_source_wide = (int64_t)target_width * source_height;
    if (source_as_target_wide > target_as_source_wide) {
        int crop_width = (int)((int64_t)source_height * target_width / target_height);
        rect->x = (source_width - crop_width) / 2;
        rect->y = 0;
        rect->w = crop_width;
        rect->h = source_height;
    } else {
        int crop_height = (int)((int64_t)source_width * target_height / target_width);
        rect->x = 0;
        rect->y = (source_height - crop_height) / 2;
        rect->w = source_width;
        rect->h = crop_height;
    }
    return rect->w <= 0 || rect->h <= 0 ? -1 : 0;
}

static int wayspot_shm_buffer_create_empty(struct wayspot_layer_globals *globals, struct wayspot_shm_buffer *buffer, uint32_t width, uint32_t height, uint32_t format, const char *name)
{
    if (width == 0 || height == 0 || width > UINT32_MAX / 4 || height > UINT32_MAX / (width * 4)) {
        return -1;
    }
    uint32_t stride = width * 4;
    uint32_t byte_len = stride * height;
    int fd = memfd_create(name, MFD_CLOEXEC);
    if (fd < 0) {
        return -1;
    }
    if (ftruncate(fd, byte_len) != 0) {
        close(fd);
        return -1;
    }
    void *data = mmap(NULL, byte_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (data == MAP_FAILED) {
        close(fd);
        return -1;
    }
    struct wl_shm_pool *pool = wl_shm_create_pool(globals->shm, fd, (int32_t)byte_len);
    if (pool == NULL) {
        munmap(data, byte_len);
        close(fd);
        return -1;
    }
    struct wl_buffer *wl_buffer = wl_shm_pool_create_buffer(pool, 0, (int32_t)width, (int32_t)height, (int32_t)stride, format);
    wl_shm_pool_destroy(pool);
    close(fd);
    if (wl_buffer == NULL) {
        munmap(data, byte_len);
        return -1;
    }
    buffer->buffer = wl_buffer;
    buffer->data = data;
    buffer->byte_len = byte_len;
    return 0;
}

static void wayspot_output_geometry(void *data, struct wl_output *output, int32_t x, int32_t y, int32_t physical_width, int32_t physical_height, int32_t subpixel, const char *make, const char *model, int32_t transform)
{
    (void)data;
    (void)output;
    (void)x;
    (void)y;
    (void)physical_width;
    (void)physical_height;
    (void)subpixel;
    (void)make;
    (void)model;
    (void)transform;
}

static void wayspot_output_mode(void *data, struct wl_output *output, uint32_t flags, int32_t width, int32_t height, int32_t refresh)
{
    (void)data;
    (void)output;
    (void)flags;
    (void)width;
    (void)height;
    (void)refresh;
}

static void wayspot_output_done(void *data, struct wl_output *output)
{
    (void)data;
    (void)output;
}

static void wayspot_output_scale(void *data, struct wl_output *output, int32_t factor)
{
    (void)data;
    (void)output;
    (void)factor;
}

static void wayspot_output_name(void *data, struct wl_output *output, const char *name)
{
    struct wayspot_layer_output *slot = data;
    size_t len = strlen(name);
    (void)output;
    if (len >= WAYSPOT_LAYER_MAX_OUTPUT_NAME) {
        len = WAYSPOT_LAYER_MAX_OUTPUT_NAME - 1;
    }
    memcpy(slot->name, name, len);
    slot->name[len] = 0;
    slot->name_len = (uint32_t)len;
}

static void wayspot_output_description(void *data, struct wl_output *output, const char *description)
{
    (void)data;
    (void)output;
    (void)description;
}

static const struct wl_output_listener wayspot_output_listener = {
    wayspot_output_geometry,
    wayspot_output_mode,
    wayspot_output_done,
    wayspot_output_scale,
    wayspot_output_name,
    wayspot_output_description,
};

static void wayspot_registry_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version)
{
    struct wayspot_layer_globals *globals = data;
    if (strcmp(interface, "zwlr_layer_shell_v1") == 0) {
        uint32_t bind_version = wayspot_min_u32(version, 5);
        globals->layer_shell = wl_registry_bind(registry, name, &zwlr_layer_shell_v1_interface, bind_version);
        return;
    }
    if (strcmp(interface, "wl_compositor") == 0) {
        uint32_t bind_version = wayspot_min_u32(version, 4);
        globals->compositor = wl_registry_bind(registry, name, &wl_compositor_interface, bind_version);
        return;
    }
    if (strcmp(interface, "wl_shm") == 0) {
        uint32_t bind_version = wayspot_min_u32(version, 2);
        globals->shm = wl_registry_bind(registry, name, &wl_shm_interface, bind_version);
        return;
    }
    if (strcmp(interface, "wl_output") == 0 && globals->output_count < WAYSPOT_LAYER_MAX_OUTPUTS) {
        uint32_t bind_version = wayspot_min_u32(version, 4);
        struct wl_output *output = wl_registry_bind(registry, name, &wl_output_interface, bind_version);
        if (output == NULL) {
            return;
        }
        struct wayspot_layer_output *slot = &globals->outputs[globals->output_count];
        memset(slot, 0, sizeof(*slot));
        slot->output = output;
        globals->output_count += 1;
        wl_output_add_listener(output, &wayspot_output_listener, slot);
    }
}

static void wayspot_registry_global_remove(void *data, struct wl_registry *registry, uint32_t name)
{
    (void)data;
    (void)registry;
    (void)name;
}

static const struct wl_registry_listener wayspot_registry_listener = {
    wayspot_registry_global,
    wayspot_registry_global_remove,
};

static void wayspot_layer_surface_configure(void *data, struct zwlr_layer_surface_v1 *surface, uint32_t serial, uint32_t width, uint32_t height)
{
    struct wayspot_layer_configure_state *state = data;
    (void)surface;
    state->configured = 1;
    state->serial = serial;
    state->width = width;
    state->height = height;
}

static void wayspot_layer_surface_closed(void *data, struct zwlr_layer_surface_v1 *surface)
{
    struct wayspot_layer_configure_state *state = data;
    (void)surface;
    state->closed = 1;
}

static const struct {
    void (*configure)(void *, struct zwlr_layer_surface_v1 *, uint32_t, uint32_t, uint32_t);
    void (*closed)(void *, struct zwlr_layer_surface_v1 *);
} wayspot_layer_surface_listener = {
    wayspot_layer_surface_configure,
    wayspot_layer_surface_closed,
};

int wayspot_layer_globals_init(struct wayspot_layer_globals *globals, struct wl_display *display)
{
    memset(globals, 0, sizeof(*globals));
    globals->display = display;
    globals->registry = wl_display_get_registry(display);
    if (globals->registry == NULL) {
        return -1;
    }
    if (wl_registry_add_listener(globals->registry, &wayspot_registry_listener, globals) != 0) {
        return -1;
    }
    if (wl_display_roundtrip(display) < 0) {
        return -1;
    }
    if (wl_display_roundtrip(display) < 0) {
        return -1;
    }
    return globals->layer_shell == NULL || globals->compositor == NULL || globals->shm == NULL ? -1 : 0;
}

void wayspot_layer_globals_deinit(struct wayspot_layer_globals *globals)
{
    uint32_t index = globals->output_count;
    while (index > 0) {
        index -= 1;
        if (globals->outputs[index].output != NULL) {
            wl_output_destroy(globals->outputs[index].output);
            globals->outputs[index].output = NULL;
        }
    }
    globals->output_count = 0;
    if (globals->layer_shell != NULL) {
        wl_proxy_marshal_flags((struct wl_proxy *)globals->layer_shell, 1, NULL, wl_proxy_get_version((struct wl_proxy *)globals->layer_shell), WL_MARSHAL_FLAG_DESTROY);
        globals->layer_shell = NULL;
    }
    if (globals->compositor != NULL) {
        wl_compositor_destroy(globals->compositor);
        globals->compositor = NULL;
    }
    if (globals->shm != NULL) {
        wl_shm_destroy(globals->shm);
        globals->shm = NULL;
    }
    if (globals->registry != NULL) {
        wl_registry_destroy(globals->registry);
        globals->registry = NULL;
    }
}

struct wl_output *wayspot_layer_find_output(struct wayspot_layer_globals *globals, const char *name)
{
    uint32_t index = 0;
    while (index < globals->output_count) {
        struct wayspot_layer_output *slot = &globals->outputs[index];
        if (strcmp(slot->name, name) == 0) {
            return slot->output;
        }
        index += 1;
    }
    return NULL;
}

struct zwlr_layer_surface_v1 *wayspot_layer_get_surface(struct wayspot_layer_globals *globals, struct wl_surface *surface, struct wl_output *output, const char *namespace_name)
{
    return (struct zwlr_layer_surface_v1 *)wl_proxy_marshal_flags((struct wl_proxy *)globals->layer_shell, 0, &zwlr_layer_surface_v1_interface, wl_proxy_get_version((struct wl_proxy *)globals->layer_shell), 0, NULL, surface, output, (uint32_t)0, namespace_name);
}

struct zwlr_layer_surface_v1 *wayspot_layer_get_surface_on_layer(struct wayspot_layer_globals *globals, struct wl_surface *surface, struct wl_output *output, uint32_t layer, const char *namespace_name)
{
    return (struct zwlr_layer_surface_v1 *)wl_proxy_marshal_flags((struct wl_proxy *)globals->layer_shell, 0, &zwlr_layer_surface_v1_interface, wl_proxy_get_version((struct wl_proxy *)globals->layer_shell), 0, NULL, surface, output, layer, namespace_name);
}

void wayspot_layer_surface_add_listener(struct zwlr_layer_surface_v1 *surface, struct wayspot_layer_configure_state *state)
{
    wl_proxy_add_listener((struct wl_proxy *)surface, (void (**)(void))&wayspot_layer_surface_listener, state);
}

void wayspot_layer_surface_set_size(struct zwlr_layer_surface_v1 *surface, uint32_t width, uint32_t height)
{
    wl_proxy_marshal_flags((struct wl_proxy *)surface, 0, NULL, wl_proxy_get_version((struct wl_proxy *)surface), 0, width, height);
}

void wayspot_layer_surface_set_anchor(struct zwlr_layer_surface_v1 *surface, uint32_t anchor)
{
    wl_proxy_marshal_flags((struct wl_proxy *)surface, 1, NULL, wl_proxy_get_version((struct wl_proxy *)surface), 0, anchor);
}

void wayspot_layer_surface_set_exclusive_zone(struct zwlr_layer_surface_v1 *surface, int32_t zone)
{
    wl_proxy_marshal_flags((struct wl_proxy *)surface, 2, NULL, wl_proxy_get_version((struct wl_proxy *)surface), 0, zone);
}

void wayspot_layer_surface_set_keyboard_interactivity(struct zwlr_layer_surface_v1 *surface, uint32_t interactivity)
{
    wl_proxy_marshal_flags((struct wl_proxy *)surface, 4, NULL, wl_proxy_get_version((struct wl_proxy *)surface), 0, interactivity);
}

void wayspot_layer_surface_ack_configure(struct zwlr_layer_surface_v1 *surface, uint32_t serial)
{
    wl_proxy_marshal_flags((struct wl_proxy *)surface, 6, NULL, wl_proxy_get_version((struct wl_proxy *)surface), 0, serial);
}

void wayspot_layer_surface_destroy(struct zwlr_layer_surface_v1 *surface)
{
    wl_proxy_marshal_flags((struct wl_proxy *)surface, 7, NULL, wl_proxy_get_version((struct wl_proxy *)surface), WL_MARSHAL_FLAG_DESTROY);
}

void wayspot_wl_surface_commit(struct wl_surface *surface)
{
    wl_surface_commit(surface);
}

int wayspot_wl_display_roundtrip(struct wl_display *display)
{
    return wl_display_roundtrip(display);
}

void wayspot_wl_display_roundtrip_cleanup(struct wl_display *display)
{
    (void)wl_display_roundtrip(display);
}

int wayspot_shm_buffer_create_image(struct wayspot_layer_globals *globals, struct wayspot_shm_buffer *buffer, uint32_t width, uint32_t height, const char *path)
{
    if (wayspot_shm_buffer_create_empty(globals, buffer, width, height, WL_SHM_FORMAT_XRGB8888, "wayspot-wallpaper") != 0) {
        return -1;
    }

    SDL_Surface *loaded = NULL;
    if (wayspot_has_extension(path, ".png")) {
        loaded = SDL_LoadPNG(path);
    } else if (wayspot_has_extension(path, ".bmp")) {
        loaded = SDL_LoadBMP(path);
    }
    if (loaded == NULL) {
        wayspot_shm_buffer_destroy(buffer);
        return -1;
    }

    SDL_Surface *source = SDL_ConvertSurface(loaded, SDL_PIXELFORMAT_XRGB8888);
    SDL_DestroySurface(loaded);
    if (source == NULL) {
        wayspot_shm_buffer_destroy(buffer);
        return -1;
    }

    SDL_Surface *target = SDL_CreateSurfaceFrom((int)width, (int)height, SDL_PIXELFORMAT_XRGB8888, buffer->data, (int)(width * 4));
    if (target == NULL) {
        SDL_DestroySurface(source);
        wayspot_shm_buffer_destroy(buffer);
        return -1;
    }

    SDL_Rect source_rect;
    int crop_ok = wayspot_cover_source_rect(source->w, source->h, (int)width, (int)height, &source_rect);
    if (crop_ok != 0 || !SDL_BlitSurfaceScaled(source, &source_rect, target, NULL, SDL_SCALEMODE_LINEAR)) {
        SDL_DestroySurface(target);
        SDL_DestroySurface(source);
        wayspot_shm_buffer_destroy(buffer);
        return -1;
    }

    SDL_DestroySurface(target);
    SDL_DestroySurface(source);
    return 0;
}

int wayspot_shm_buffer_create_tint(struct wayspot_layer_globals *globals, struct wayspot_shm_buffer *buffer, uint32_t width, uint32_t height, uint32_t argb)
{
    if (wayspot_shm_buffer_create_empty(globals, buffer, width, height, WL_SHM_FORMAT_ARGB8888, "wayspot-sunglasses") != 0) {
        return -1;
    }

    uint32_t pixel_count = width * height;
    uint32_t *pixels = buffer->data;
    uint32_t index = 0;
    while (index < pixel_count) {
        pixels[index] = argb;
        index += 1;
    }
    return 0;
}

void wayspot_shm_buffer_destroy(struct wayspot_shm_buffer *buffer)
{
    if (buffer->buffer != NULL) {
        wl_buffer_destroy(buffer->buffer);
        buffer->buffer = NULL;
    }
    if (buffer->data != NULL) {
        munmap(buffer->data, buffer->byte_len);
        buffer->data = NULL;
    }
    buffer->byte_len = 0;
}

void wayspot_wl_surface_attach_buffer(struct wl_surface *surface, struct wayspot_shm_buffer *buffer, uint32_t width, uint32_t height)
{
    wl_surface_attach(surface, buffer->buffer, 0, 0);
    wl_surface_damage_buffer(surface, 0, 0, (int32_t)width, (int32_t)height);
}

void wayspot_wl_surface_detach_buffer(struct wl_surface *surface)
{
    wl_surface_attach(surface, NULL, 0, 0);
}

int wayspot_wl_surface_set_empty_input_region(struct wayspot_layer_globals *globals, struct wl_surface *surface)
{
    struct wl_region *region = wl_compositor_create_region(globals->compositor);
    if (region == NULL) {
        return -1;
    }
    wl_surface_set_input_region(surface, region);
    wl_region_destroy(region);
    return 0;
}

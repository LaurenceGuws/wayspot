#include <SDL3/SDL.h>
#include <stdint.h>
#include <wayland-client.h>

#define WAYSPOT_LAYER_MAX_OUTPUTS 8
#define WAYSPOT_LAYER_MAX_OUTPUT_NAME 96

struct zwlr_layer_surface_v1;

struct wayspot_layer_output {
    struct wl_output *output;
    char name[WAYSPOT_LAYER_MAX_OUTPUT_NAME];
    uint32_t name_len;
};

struct wayspot_layer_globals {
    struct wl_display *display;
    struct wl_registry *registry;
    struct wl_shm *shm;
    void *layer_shell;
    struct wayspot_layer_output outputs[WAYSPOT_LAYER_MAX_OUTPUTS];
    uint32_t output_count;
};

struct wayspot_layer_configure_state {
    uint32_t configured;
    uint32_t closed;
    uint32_t serial;
    uint32_t width;
    uint32_t height;
};

struct wayspot_shm_buffer {
    struct wl_buffer *buffer;
    void *data;
    uint32_t byte_len;
};

int wayspot_layer_globals_init(struct wayspot_layer_globals *globals, struct wl_display *display);
void wayspot_layer_globals_deinit(struct wayspot_layer_globals *globals);
struct wl_output *wayspot_layer_find_output(struct wayspot_layer_globals *globals, const char *name);
struct zwlr_layer_surface_v1 *wayspot_layer_get_surface(struct wayspot_layer_globals *globals, struct wl_surface *surface, struct wl_output *output, const char *namespace_name);
void wayspot_layer_surface_add_listener(struct zwlr_layer_surface_v1 *surface, struct wayspot_layer_configure_state *state);
void wayspot_layer_surface_set_size(struct zwlr_layer_surface_v1 *surface, uint32_t width, uint32_t height);
void wayspot_layer_surface_set_anchor(struct zwlr_layer_surface_v1 *surface, uint32_t anchor);
void wayspot_layer_surface_set_exclusive_zone(struct zwlr_layer_surface_v1 *surface, int32_t zone);
void wayspot_layer_surface_set_keyboard_interactivity(struct zwlr_layer_surface_v1 *surface, uint32_t interactivity);
void wayspot_layer_surface_ack_configure(struct zwlr_layer_surface_v1 *surface, uint32_t serial);
void wayspot_layer_surface_destroy(struct zwlr_layer_surface_v1 *surface);
void wayspot_wl_surface_commit(struct wl_surface *surface);
int wayspot_wl_display_roundtrip(struct wl_display *display);
void wayspot_wl_display_roundtrip_cleanup(struct wl_display *display);
int wayspot_shm_buffer_create_solid(struct wayspot_layer_globals *globals, struct wayspot_shm_buffer *buffer, uint32_t width, uint32_t height, uint32_t red, uint32_t green, uint32_t blue);
void wayspot_shm_buffer_destroy(struct wayspot_shm_buffer *buffer);
void wayspot_wl_surface_attach_buffer(struct wl_surface *surface, struct wayspot_shm_buffer *buffer, uint32_t width, uint32_t height);
void wayspot_wl_surface_detach_buffer(struct wl_surface *surface);

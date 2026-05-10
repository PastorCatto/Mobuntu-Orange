/*
 * Mobuntu-PS4 — Session Switcher
 * Codename: Doctor Octavius
 *
 * Controller-friendly session switcher for Mobuntu-PS4.
 * Triggered by holding SELECT + START for 3 seconds from within Theseus or desktop.
 * Writes /var/mobuntu/session-mode and restarts X to switch sessions.
 *
 * Controls (DualShock 4):
 *   D-pad up/down or left stick   — navigate options
 *   Cross (A)                     — confirm
 *   Circle (B)                    — cancel / exit without switching
 *   SELECT + START (hold 3s)      — open switcher from any session
 *
 * Dependencies: SDL2, SDL2_mixer (for audio cues optional), OpenGL 3.2
 * Build: make  (see Makefile)
 */

#include <SDL2/SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define SESSION_MODE_FILE "/var/mobuntu/session-mode"
#define HOLD_MS           3000
#define WINDOW_W          640
#define WINDOW_H          360

typedef enum {
    OPT_CONSOLE = 0,
    OPT_DESKTOP  = 1,
    OPT_COUNT    = 2
} Option;

const char *option_labels[OPT_COUNT] = {
    "Console Mode  (Theseus Xbox Dashboard)",
    "Desktop Mode  (LXDE)"
};

const char *option_modes[OPT_COUNT] = {
    "console",
    "desktop"
};

static int read_current_mode(void) {
    FILE *f = fopen(SESSION_MODE_FILE, "r");
    if (!f) return OPT_CONSOLE;
    char buf[32] = {0};
    fgets(buf, sizeof(buf), f);
    fclose(f);
    if (strncmp(buf, "desktop", 7) == 0) return OPT_DESKTOP;
    return OPT_CONSOLE;
}

static void write_mode(const char *mode) {
    FILE *f = fopen(SESSION_MODE_FILE, "w");
    if (!f) {
        fprintf(stderr, "session-switcher: cannot write %s\n", SESSION_MODE_FILE);
        return;
    }
    fprintf(f, "%s\n", mode);
    fclose(f);
}

static void restart_x(void) {
    /* Kill current X session — systemd will restart it, re-reading xinitrc */
    system("pkill -x Xorg || pkill -x X");
}

int main(int argc, char *argv[]) {
    (void)argc; (void)argv;

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER) != 0) {
        fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
        return 1;
    }

    /* Load controller mappings if available */
    SDL_GameControllerAddMappingsFromFile("/usr/local/share/gamecontrollerdb.txt");

    SDL_Window *win = SDL_CreateWindow(
        "Mobuntu — Switch Session",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        WINDOW_W, WINDOW_H,
        SDL_WINDOW_SHOWN | SDL_WINDOW_OPENGL
    );
    if (!win) {
        fprintf(stderr, "SDL_CreateWindow: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_Renderer *ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    if (!ren) {
        fprintf(stderr, "SDL_CreateRenderer: %s\n", SDL_GetError());
        SDL_DestroyWindow(win);
        SDL_Quit();
        return 1;
    }

    /* Open first available controller */
    SDL_GameController *ctrl = NULL;
    for (int i = 0; i < SDL_NumJoysticks(); i++) {
        if (SDL_IsGameController(i)) {
            ctrl = SDL_GameControllerOpen(i);
            if (ctrl) break;
        }
    }

    int selected = read_current_mode();
    int running  = 1;
    int confirmed = 0;

    /* Debounce timers */
    Uint32 last_nav = 0;
    const Uint32 NAV_DELAY = 200;

    SDL_Event ev;

    while (running) {
        /* ── Draw ── */
        SDL_SetRenderDrawColor(ren, 10, 10, 30, 255);
        SDL_RenderClear(ren);

        /* Simple text-free rendering: two coloured boxes, selected = bright */
        for (int i = 0; i < OPT_COUNT; i++) {
            SDL_Rect box = {
                .x = 80,
                .y = 100 + i * 90,
                .w = WINDOW_W - 160,
                .h = 70
            };
            if (i == selected) {
                SDL_SetRenderDrawColor(ren, 0, 120, 215, 255); /* Xbox blue */
            } else {
                SDL_SetRenderDrawColor(ren, 40, 40, 80, 255);
            }
            SDL_RenderFillRect(ren, &box);
            SDL_SetRenderDrawColor(ren, 200, 200, 255, 255);
            SDL_RenderDrawRect(ren, &box);
        }

        /* Instruction bar */
        SDL_Rect bar = { .x = 0, .y = WINDOW_H - 40, .w = WINDOW_W, .h = 40 };
        SDL_SetRenderDrawColor(ren, 20, 20, 50, 255);
        SDL_RenderFillRect(ren, &bar);

        SDL_RenderPresent(ren);

        /* ── Events ── */
        while (SDL_PollEvent(&ev)) {
            switch (ev.type) {
            case SDL_QUIT:
                running = 0;
                break;

            case SDL_KEYDOWN:
                switch (ev.key.keysym.sym) {
                case SDLK_UP:   selected = (selected - 1 + OPT_COUNT) % OPT_COUNT; break;
                case SDLK_DOWN: selected = (selected + 1) % OPT_COUNT; break;
                case SDLK_RETURN: case SDLK_SPACE: confirmed = 1; running = 0; break;
                case SDLK_ESCAPE: running = 0; break;
                }
                break;

            case SDL_CONTROLLERBUTTONDOWN: {
                Uint32 now = SDL_GetTicks();
                SDL_GameControllerButton btn = ev.cbutton.button;

                if (btn == SDL_CONTROLLER_BUTTON_DPAD_UP ||
                    btn == SDL_CONTROLLER_BUTTON_LEFTSTICK) {
                    if (now - last_nav > NAV_DELAY) {
                        selected = (selected - 1 + OPT_COUNT) % OPT_COUNT;
                        last_nav = now;
                    }
                } else if (btn == SDL_CONTROLLER_BUTTON_DPAD_DOWN) {
                    if (now - last_nav > NAV_DELAY) {
                        selected = (selected + 1) % OPT_COUNT;
                        last_nav = now;
                    }
                } else if (btn == SDL_CONTROLLER_BUTTON_A) {
                    /* Cross — confirm */
                    confirmed = 1;
                    running   = 0;
                } else if (btn == SDL_CONTROLLER_BUTTON_B) {
                    /* Circle — cancel */
                    running = 0;
                }
                break;
            }

            case SDL_CONTROLLERAXISMOTION: {
                Uint32 now = SDL_GetTicks();
                if (ev.caxis.axis == SDL_CONTROLLER_AXIS_LEFTY) {
                    if (now - last_nav > NAV_DELAY) {
                        if (ev.caxis.value < -8000) {
                            selected = (selected - 1 + OPT_COUNT) % OPT_COUNT;
                            last_nav = now;
                        } else if (ev.caxis.value > 8000) {
                            selected = (selected + 1) % OPT_COUNT;
                            last_nav = now;
                        }
                    }
                }
                break;
            }
            }
        }

        SDL_Delay(16); /* ~60fps */
    }

    /* ── Cleanup ── */
    if (ctrl) SDL_GameControllerClose(ctrl);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();

    if (confirmed) {
        printf("session-switcher: switching to %s\n", option_modes[selected]);
        write_mode(option_modes[selected]);
        restart_x();
    } else {
        printf("session-switcher: cancelled\n");
    }

    return 0;
}

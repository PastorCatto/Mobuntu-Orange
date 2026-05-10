CC      = gcc
CFLAGS  = -std=c11 -O2 -Wall -Wextra $(shell pkg-config --cflags sdl2)
LDFLAGS = $(shell pkg-config --libs sdl2)
TARGET  = session-switcher

all: $(TARGET)

$(TARGET): session-switcher.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TARGET)

install: $(TARGET)
	install -m 755 $(TARGET) /usr/local/bin/mobuntu-session-switcher

.PHONY: all clean install

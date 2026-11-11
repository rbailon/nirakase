#!/usr/bin/env python3
import os
import sys
import time
import glob
import ctypes
import select
import signal

# Close any inherited file descriptors (e.g. D-Bus sockets) from parent process
try:
    os.closerange(3, 4096)
except Exception:
    pass

# Ask kernel to send SIGTERM if parent process dies
try:
    libc = ctypes.CDLL("libc.so.6")
    libc.prctl(1, signal.SIGTERM, 0, 0, 0)
except Exception:
    pass

try:
    import evdev
    from evdev import ecodes
except ImportError:
    sys.exit(0)

def handle_sig(sig, frame):
    sys.exit(0)

signal.signal(signal.SIGINT, handle_sig)
signal.signal(signal.SIGTERM, handle_sig)

def get_led_state(pattern):
    for path in glob.glob(pattern):
        try:
            with open(path, "r") as f:
                if f.read().strip() == "1":
                    return True
        except Exception:
            pass
    return False

def get_keyboards():
    keyboards = []
    try:
        for path in evdev.list_devices():
            try:
                d = evdev.InputDevice(path)
                cap = d.capabilities()
                if ecodes.EV_KEY in cap:
                    keys = cap[ecodes.EV_KEY]
                    if ecodes.KEY_CAPSLOCK in keys or ecodes.KEY_NUMLOCK in keys:
                        keyboards.append(d)
            except Exception:
                pass
    except Exception:
        pass
    return keyboards

def main():
    keyboards = get_keyboards()
    if not keyboards:
        # If no keyboards accessible via evdev right now, exit cleanly
        sys.exit(0)

    dev_map = {d.fd: d for d in keyboards}

    while True:
        try:
            r, _, _ = select.select(list(dev_map.keys()), [], [], 5.0)
            if not r:
                # Periodic device scan for newly plugged USB keyboards
                cur_paths = {d.path for d in dev_map.values()}
                fresh_keyboards = get_keyboards()
                if {d.path for d in fresh_keyboards} != cur_paths:
                    for d in dev_map.values():
                        try:
                            d.close()
                        except Exception:
                            pass
                    dev_map = {d.fd: d for d in fresh_keyboards}
                continue

            for fd in r:
                dev = dev_map.get(fd)
                if not dev:
                    continue
                try:
                    for event in dev.read():
                        if event.type == ecodes.EV_KEY and event.value == 0:  # Key release
                            if event.code == ecodes.KEY_CAPSLOCK:
                                time.sleep(0.04)  # Small wait for kernel led state update
                                state = "ON" if get_led_state("/sys/class/leds/*::capslock/brightness") else "OFF"
                                sys.stdout.write(f"CAPSLOCK:{state}\n")
                                sys.stdout.flush()
                            elif event.code == ecodes.KEY_NUMLOCK:
                                time.sleep(0.04)
                                state = "ON" if get_led_state("/sys/class/leds/*::numlock/brightness") else "OFF"
                                sys.stdout.write(f"NUMLOCK:{state}\n")
                                sys.stdout.flush()
                except (BrokenPipeError, IOError):
                    sys.exit(0)
                except Exception:
                    dev_map.pop(fd, None)
        except (BrokenPipeError, KeyboardInterrupt, SystemExit):
            sys.exit(0)
        except Exception:
            pass

if __name__ == "__main__":
    main()

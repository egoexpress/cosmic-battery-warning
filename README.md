# cosmic-battery-warning

Low-battery warnings for the [COSMIC](https://system76.com/cosmic) desktop that are
hard to miss: sticky notifications, COSMIC's own battery sounds, and reminders that
keep coming back while the charge drops.

COSMIC's normal notification bubbles disappear after a configurable few seconds
(`max_timeout_normal`, 5 s by default), which is exactly when a battery warning has to
compete with whatever else is on screen. This watcher sends its warnings with
*critical* urgency: `cosmic-notifications` advertises the `persistence` capability and
has no maximum timeout for urgent notifications, so they stay on screen until you
dismiss them.

## What it does

The watcher polls the battery every 15 seconds and warns once per threshold on the way
down. Thresholds re-arm when the charger is plugged in, and the sticky warning is
closed automatically.

| Charge | Notification | Sound |
|--------|--------------|-------|
| ≤ 20 % | "Battery low" — 20 s on screen | `battery-caution` |
| ≤ 10 % | "Battery low" — sticky until dismissed | `battery-low` |
| ≤ 5 % | "Battery critical" — sticky, re-shown every 5 min | `battery-low`, twice |
| ≤ 2 % | "Battery almost empty" — sticky | `battery-low` + `alarm-clock-elapsed` |
| back on mains | sticky warning is dismissed, thresholds re-arm | — |

Each message includes the remaining runtime, computed from `energy_now` / `power_now`.

## Requirements

- COSMIC session (sounds and sticky notifications are tested there; on other desktops
  the notifications still work, the sounds are skipped)
- `notify-send` (libnotify), `pw-play` or `paplay` for sound
- systemd user session

## Install

```bash
./install.sh
```

That copies `bin/battery-alert` to `~/.local/bin`, installs the systemd user unit to
`~/.config/systemd/user`, and enables and starts `battery-alert.service`.

```bash
battery-alert --status     # current charge, runtime, thresholds
battery-alert --test 5     # show the 5 % warning right now
./install.sh --uninstall   # stop and remove
```

## Configuration

All settings are environment variables, so they can be set in the unit
(`systemctl --user edit battery-alert.service`) or on the command line:

```ini
[Service]
Environment=POLL=30
Environment=REPEAT=0
Environment="STAGES=25 15 8 3"
```

| Variable | Default | Meaning |
|----------|---------|---------|
| `POLL` | `15` | seconds between samples |
| `STAGES` | `20 10 5 2` | warning thresholds in percent, descending importance |
| `REPEAT` | `300` | re-show the sticky warning every N seconds at or below 5 % (`0` = never) |
| `SOUND` | `1` | play the COSMIC battery sounds |
| `OSD_SHUTDOWN` | `0` | at the last stage also show `cosmic-osd`'s fullscreen "shutting down in N seconds" countdown (cancellable, but it does shut down) |
| `BAT` | first `BAT*` | battery name in `/sys/class/power_supply` |
| `DRY_RUN` | `0` | print notifications instead of sending them |

Quotes matter for `STAGES`: systemd splits unquoted `Environment=` values on spaces.

## How it works

`bin/battery-alert` reads `/sys/class/power_supply/BAT*/{capacity,status,energy_now,
power_now}` and any mains supply, so it needs no daemon and no D-Bus queries. Only a
downward crossing triggers a notification (`stage < announced`), which keeps it from
repeating while the charge drops within a threshold. Below 5 % the sticky warning is
re-sent with the updated runtime every `REPEAT` seconds.

## Tests

```bash
./test/smoke.sh
```

The smoke test runs the watcher against a fake power-supply tree with `DRY_RUN=1` and
muted sound, walks the charge down through all thresholds, and checks that each stage
fires once, that the 5 % warning repeats, and that plugging in clears the state.

## Troubleshooting

- **Nothing appears at all:** check the Do-Not-Disturb toggle in the notification
  panel. If that is off but `notify-send test` still fails, the notification daemon
  may have lost its D-Bus name; `kill $(pgrep -x cosmic-notifications)` lets
  `cosmic-session` restart it.
- **Only some popups are missed:** raise `max_timeout_normal` in
  `~/.config/cosmic/com.system76.CosmicNotifications/v1/` (for example
  `Some(10000)`) to keep ordinary notifications on screen longer.
- **The machine should not die at 0 %:** configure hibernation and set UPower's
  `PercentageAction` / `CriticalPowerAction` in `/etc/UPower/UPower.conf`.

## License

GPL-3.0, see [LICENSE](LICENSE).

<!---
This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.
-->

## How it works

AquaSafe is a digital water-level controller with fault protection. It drives a
fill pump using two level sensors and a water-source status input.

Inputs (1 = condition active):

| Pin     | Signal     | Meaning                              |
|---------|------------|--------------------------------------|
| ui[0]   | low_level  | 1 = water detected at the low sensor |
| ui[1]   | high_level | 1 = water detected at the high sensor|
| ui[2]   | source_ok  | 1 = water source is available        |

Outputs:

| Pin     | Signal  | Meaning                                         |
|---------|---------|-------------------------------------------------|
| uo[0]   | pump    | Turns the pump on                               |
| uo[1]   | alarm   | Sensor fault detected                           |
| uo[2]   | filling | Fill in progress (same as pump)                 |
| uo[3]   | blocked | Filling is blocked (no source, or fault state)  |

A 3-state finite state machine controls the system:

- **IDLE**: not filling. If both sensors are dry (low=0, high=0) and the source
  is available, it moves to FILL.
- **FILL**: pump on. Returns to IDLE when the high sensor detects water (tank
  full) or when the source becomes unavailable.
- **FAULT**: entered when the sensors are inconsistent (high sensor wet while
  the low sensor is dry, which is physically impossible). The pump is off and
  the alarm is on. This state is latched and only cleared by reset or by
  setting `ena` to 0.

Filling starts only when the tank is empty and stops only when it is full, which
gives hysteresis and prevents the pump from toggling at intermediate levels.

Additional safety features:

- The three inputs go through a 2-flip-flop synchronizer to avoid
  metastability, since they come from asynchronous external sensors. This adds
  2 clock cycles of latency.
- An illegal FSM state falls back to FAULT.
- If `ena` = 0 or `rst_n` = 0, the FSM returns to IDLE and the pump is off.

The `SYNC_INPUTS` parameter can disable the synchronizer for a direct
(combinational) input path.

## How to test

1. Apply reset (`rst_n` = 0) and release it. The design starts in IDLE with
   `uo[0]` (pump) = 0.
2. Set `ui[0]` = 0, `ui[1]` = 0, `ui[2]` = 1 (empty tank, source OK). After
   2-3 clock cycles, `uo[0]` (pump) = 1.
3. Set `ui[0]` = 1, then `ui[1]` = 1 (tank full). `uo[0]` goes back to 0.
4. While the pump is on, set `ui[2]` = 0. `uo[0]` = 0 and `uo[3]` (blocked) = 1.
5. Set `ui[1]` = 1 with `ui[0]` = 0 (inconsistent sensors). `uo[1]` (alarm) = 1
   and the design stays in FAULT until the next reset.

## External hardware

- Two digital level sensors (float switches or electrodes) connected to
  `ui[0]` and `ui[1]`.
- A digital "source available" signal connected to `ui[2]`.
- A driver stage (transistor or relay) controlled by `uo[0]` to switch the pump.
  The chip output must not drive the pump directly.
- Optional: LEDs on `uo[1]`, `uo[2]` and `uo[3]` for alarm, filling and blocked
  indication.

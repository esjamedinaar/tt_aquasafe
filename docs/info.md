<!---
Este archivo se usa para generar el datasheet de tu proyecto. Completa la información de abajo y elimina las secciones que no uses.
-->

## How it works

AquaSafe es un controlador digital de nivel de agua con protección contra fallas. Controla una bomba de llenado usando dos sensores de nivel y una entrada que indica si la fuente de agua está disponible.

Entradas (1 = condición activa):

| Pin     | Señal      | Significado                              |
|---------|------------|------------------------------------------|
| ui[0]   | low_level  | 1 = hay agua en el sensor bajo           |
| ui[1]   | high_level | 1 = hay agua en el sensor alto           |
| ui[2]   | source_ok  | 1 = la fuente de agua está disponible    |

Salidas:

| Pin     | Señal   | Significado                                          |
|---------|---------|------------------------------------------------------|
| uo[0]   | pump    | Enciende la bomba                                    |
| uo[1]   | alarm   | Falla de sensores detectada                          |
| uo[2]   | filling | Llenado en curso (igual que pump)                    |
| uo[3]   | blocked | Llenado bloqueado (sin fuente o en estado de falla)  |

Una máquina de estados finita de 3 estados controla el sistema:

- **IDLE**: no se está llenando. Si ambos sensores están secos (low=0, high=0) y la fuente está disponible, pasa a FILL.
- **FILL**: la bomba está encendida. Vuelve a IDLE cuando el sensor alto detecta agua (tanque lleno) o cuando la fuente deja de estar disponible.
- **FAULT**: se entra cuando los sensores son incoherentes (sensor alto mojado con el sensor bajo seco, algo físicamente imposible). La bomba se apaga y la alarma se activa. Este estado es de bloqueo: solo se sale con reset o poniendo `ena` en 0.

El llenado empieza solo cuando el tanque está vacío y termina solo cuando está lleno, lo que da histéresis y evita que la bomba se encienda y apague en niveles intermedios.

Funciones de seguridad adicionales:

- Las tres entradas pasan por un sincronizador de 2 flip-flops para evitar metaestabilidad, ya que provienen de sensores externos asíncronos. Esto agrega 2 ciclos de reloj de latencia.
- Un estado ilegal de la FSM cae automáticamente a FAULT.
- Si `ena` = 0, la FSM vuelve a IDLE y la bomba se apaga.

El parámetro `SYNC_INPUTS` permite desactivar el sincronizador para usar una ruta directa (combinacional) desde las entradas.

## How to test

1. Aplica reset (`rst_n` = 0) y suéltalo. El diseño inicia en IDLE con `uo[0]` (pump) = 0.
2. Pon `ui[0]` = 0, `ui[1]` = 0, `ui[2]` = 1 (tanque vacío, fuente OK). Después de 2 o 3 ciclos de reloj, `uo[0]` (pump) = 1.
3. Pon `ui[0]` = 1 y luego `ui[1]` = 1 (tanque lleno). `uo[0]` vuelve a 0.
4. Con la bomba encendida, pon `ui[2]` = 0. `uo[0]` = 0 y `uo[3]` (blocked) = 1.
5. Pon `ui[1]` = 1 con `ui[0]` = 0 (sensores incoherentes). `uo[1]` (alarm) = 1 y el diseño queda en FAULT hasta el siguiente reset.

## External hardware

- Dos sensores de nivel digitales (interruptores de flotador o electrodos) conectados a `ui[0]` y `ui[1]`.
- Una señal digital de "fuente disponible" conectada a `ui[2]`.
- Una etapa de potencia (transistor o relé) controlada por `uo[0]` para accionar la bomba. La salida del chip no debe alimentar la bomba directamente.
- Opcional: LEDs en `uo[1]`, `uo[2]` y `uo[3]` para indicar alarma, llenado y bloqueo.

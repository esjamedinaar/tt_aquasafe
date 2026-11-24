/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_aquasafe #(
    parameter SYNC_INPUTS = 1   // 1: sincroniza sensores (2 FF). 0: ruta directa (original)
)(
    input  wire [7:0] ui_in,    // [0]=low_level [1]=high_level [2]=source_ok
    output wire [7:0] uo_out,   // [0]=pump [1]=alarm [2]=filling [3]=blocked
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // -------------------------------------------------------------------------
    // 1) Entradas: sincronización opcional (anti-metaestabilidad)
    // -------------------------------------------------------------------------
    wire [2:0] sensors_raw = ui_in[2:0];
    reg  [2:0] sync_ff1, sync_ff2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1 <= 3'b000;
            sync_ff2 <= 3'b000;
        end else begin
            sync_ff1 <= sensors_raw;
            sync_ff2 <= sync_ff1;
        end
    end

    wire [2:0] sensors = SYNC_INPUTS ? sync_ff2 : sensors_raw;

    wire low_level  = sensors[0];
    wire high_level = sensors[1];
    wire source_ok  = sensors[2];

    // -------------------------------------------------------------------------
    // 2) Lógica combinacional: validación de sensores
    // -------------------------------------------------------------------------
    // Alto mojado con bajo seco = combinación físicamente imposible -> falla
    wire invalid_sensors = high_level & ~low_level;

    // -------------------------------------------------------------------------
    // 3) FSM: codificación, siguiente estado (combinacional)
    // -------------------------------------------------------------------------
    localparam [1:0] S_IDLE  = 2'b00,
                     S_FILL  = 2'b01,
                     S_FAULT = 2'b10;

    reg [1:0] state, next_state;

    always @* begin
        next_state = state;                 // valor por defecto: sin latches
        if (invalid_sensors) begin
            next_state = S_FAULT;
        end else begin
            case (state)
                S_IDLE:  if (~low_level & ~high_level & source_ok)
                             next_state = S_FILL;
                S_FILL:  if (high_level | ~source_ok)
                             next_state = S_IDLE;
                S_FAULT: next_state = S_FAULT;   // pegajoso hasta reset/ena=0
                default: next_state = S_FAULT;   // estado ilegal -> seguro
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // 4) Registro de estado
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;
        else if (!ena)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // -------------------------------------------------------------------------
    // 5) Salidas (Moore + gating de seguridad por entradas actuales)
    //    rst_n eliminado de las salidas: con reset, state=IDLE => pump=0.
    //    alarm conserva el gating por ena.
    // -------------------------------------------------------------------------
    wire fill_active = (state == S_FILL);

    wire pump    = ena & fill_active & source_ok & ~high_level & ~invalid_sensors;
    wire alarm   = ena & ((state == S_FAULT) | invalid_sensors);
    wire filling = pump;
    wire blocked = ena & (~source_ok | alarm);

    assign uo_out  = {4'b0000, blocked, filling, alarm, pump};
    assign uio_out = 8'b0000_0000;
    assign uio_oe  = 8'b0000_0000;

    // Señales no usadas
    wire unused = &{1'b0, ui_in[7:3], uio_in};

endmodule
`default_nettype wire

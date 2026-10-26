`timescale 1ns/1ps
// Parallel driver-output model, not a serial/electrical sensor model.
module gmax3412_pattern #(
    parameter integer WIDTH = 4096, HEIGHT = 3072
)(
    input wire clk, resetn, init_cmd, start_cmd, stop_cmd, trigger_cmd,
    input wire [31:0] exposure_cycles, blank_cycles,
    input wire [9:0] seed,
    output reg initialized, armed, busy, exposing,
    output reg fval, lval,
    output reg [191:0] data,
    output reg [9:0] active_seed,
    output reg [31:0] accepted, rejected
);
    localparam IDLE=0, EXPOSE=1, PIXELS=2, BLANK=3, FINISH=4;
    reg [2:0] state;
    reg [5:0] init_count;
    reg [31:0] timer, active_blank;
    reg [15:0] x, y;
    integer i;
    always @(posedge clk) begin
        if (!resetn) begin
            initialized<=0; armed<=0; busy<=0; exposing<=0;
            fval<=0; lval<=0; data<=0; active_seed<=0;
            accepted<=0; rejected<=0; state<=IDLE; init_count<=0;
            timer<=0; active_blank<=1; x<=0; y<=0;
        end else begin
            lval<=0;
            if (init_count!=0) begin
                init_count<=init_count-1;
                if (init_count==1) initialized<=1;
            end
            // INIT disarms and models 32 cycles of initialization, only at idle.
            if (init_cmd && !busy) begin
                initialized<=0; armed<=0; init_count<=32;
            end else if (stop_cmd) armed<=0;
            else if (start_cmd && initialized) armed<=1;
            if (trigger_cmd) begin
                if (initialized && armed && !busy && !stop_cmd && !init_cmd &&
                    exposure_cycles!=0 && blank_cycles!=0) begin
                    busy<=1; exposing<=1; state<=EXPOSE;
                    timer<=exposure_cycles; active_blank<=blank_cycles;
                    active_seed<=seed; accepted<=accepted+1; x<=0; y<=0;
                end else rejected<=rejected+1;
            end
            case (state)
                IDLE: begin fval<=0; end
                EXPOSE: begin
                    if (timer==1) begin
                        exposing<=0; state<=PIXELS;
                    end else timer<=timer-1;
                end
                PIXELS: begin
                    fval<=1; lval<=1;
                    for (i=0;i<16;i=i+1)
                        data[12*i +: 12] <= {2'b00, ((x+i+y+active_seed) & 10'h3ff)};
                    if (x==WIDTH-16) begin
                        x<=0;
                        if (y==HEIGHT-1) state<=FINISH;
                        else begin y<=y+1; timer<=active_blank; state<=BLANK; end
                    end else x<=x+16;
                end
                BLANK: begin
                    if (timer==1) state<=PIXELS;
                    else timer<=timer-1;
                end
                FINISH: begin fval<=0; busy<=0; state<=IDLE; end
                default: state<=IDLE;
            endcase
        end
    end
endmodule

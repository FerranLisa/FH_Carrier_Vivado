`timescale 1ns/1ps
// Independent raster counters check every slot, including the two padding bits.
// Results are published atomically after falling FVAL; no backpressure.
module gmax3412_checker #(
    parameter integer WIDTH=4096, HEIGHT=3072
)(
    input wire clk, resetn, fval, lval,
    input wire [191:0] data,
    input wire [9:0] seed,
    output reg [31:0] frames, errors, last_pixels, last_lines, checksum,
    output reg last_pass
);
    reg pf, pl;
    reg [31:0] row, column, pixels, lines, sum;
    reg [31:0] frame_errors;
    reg [9:0] frame_seed;
    integer i;
    reg [31:0] beat_sum, beat_errors;
    reg [31:0] cx, cy;
    reg [9:0] cs;
    reg [11:0] expected;
    always @* begin
        cx = (!pf || !pl) ? 0 : column;
        cy = !pf ? 0 : row;
        cs = !pf ? seed : frame_seed;
        beat_sum=0; beat_errors=0;
        for (i=0;i<16;i=i+1) begin
            expected = (cx+i+cy+cs) & 32'h3ff;
            beat_sum=beat_sum+data[12*i +: 12];
            if (data[12*i +: 12]!=expected) beat_errors=beat_errors+1;
        end
    end
    always @(posedge clk) begin
        if (!resetn) begin
            pf<=0; pl<=0; row<=0; column<=0; pixels<=0; lines<=0;
            sum<=0; frame_errors<=0; frame_seed<=0;
            frames<=0; errors<=0; last_pixels<=0; last_lines<=0;
            checksum<=0; last_pass<=0;
        end else begin
            pf<=fval; pl<=lval;
            if (fval && !pf) begin
                row<=0; column<=0; pixels<=0; lines<=0; sum<=0;
                frame_errors<=0; frame_seed<=seed;
            end
            if (fval && lval) begin
                column<=cx+16;
                pixels<=(!pf ? 0 : pixels)+16;
                sum<=(!pf ? 0 : sum)+beat_sum;
                frame_errors<=(!pf ? 0 : frame_errors)+beat_errors;
            end
            if (pf && pl && !lval) begin
                row<=row+1; lines<=lines+1;
                if (column!=WIDTH) frame_errors<=frame_errors+1;
            end
            if (!fval && pf) begin
                frames<=frames+1;
                last_pixels<=pixels; last_lines<=lines+(pl ? 1 : 0);
                checksum<=sum;
                last_pass <= frame_errors==0 && pixels==WIDTH*HEIGHT &&
                    lines+(pl ? 1 : 0)==HEIGHT && (!pl || column==WIDTH);
                errors<=errors+frame_errors+(pixels!=WIDTH*HEIGHT)+
                    (lines+(pl ? 1 : 0)!=HEIGHT)+(pl && column!=WIDTH);
            end
            if (lval && !fval) begin errors<=errors+1; last_pass<=0; end
        end
    end
endmodule

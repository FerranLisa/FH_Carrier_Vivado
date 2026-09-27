`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2026 09:30:56 PM
// Design Name: 
// Module Name: i2c_emio_iobuf
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module i2c_emio_iobuf (
    input  wire scl_o,
    input  wire scl_t,
    output wire scl_i,

    input  wire sda_o,
    input  wire sda_t,
    output wire sda_i,

    inout  wire scl_io,
    inout  wire sda_io
);

    IOBUF iobuf_scl (
        .I  (scl_o),
        .O  (scl_i),
        .T  (scl_t),
        .IO (scl_io)
    );

    IOBUF iobuf_sda (
        .I  (sda_o),
        .O  (sda_i),
        .T  (sda_t),
        .IO (sda_io)
    );

endmodule

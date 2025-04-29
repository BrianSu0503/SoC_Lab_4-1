// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 32,
    parameter DELAYS=10
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    wire clk;
    wire rst;

    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;
    
    wire valid, is_mprjaddr, ready_w;
    wire [3:0] bram_we;
    wire bram_en;
    reg ready_r;
    reg [$clog2(DELAYS)-1:0] delay_cnt_w;
    reg [$clog2(DELAYS)-1:0] delay_cnt_r;
    
    assign valid = wbs_stb_i & wbs_cyc_i & is_mprjaddr;
    assign bram_we = {4{wbs_we_i & valid}};
    assign bram_en = 1'b1;
    assign is_mprjaddr = (wbs_adr_i[31-:12] == 12'h380) ? 1 : 0;
    
    assign ready_w = (delay_cnt_r == DELAYS) ? 1 : 0;
    assign wbs_ack_o = ready_r;
    
    assign io_out = wbs_dat_o;
    assign io_oeb = ~wbs_ack_o;
    
    always@(*)begin
      if(delay_cnt_r == DELAYS) delay_cnt_w = 0;
      else if(valid && ~ready_r) delay_cnt_w = delay_cnt_r + 1'b1;
      else delay_cnt_w = delay_cnt_r;
    end
    
    always@(posedge wb_clk_i)begin
      if(wb_rst_i)begin
        ready_r <= 0;
        delay_cnt_r <= 0;
      end else begin
        ready_r <= ready_w;
        delay_cnt_r <= delay_cnt_w;
      end 
    end
    
    bram user_bram (
        .CLK(wb_clk_i),
        .WE0(bram_we),
        .EN0(bram_en),
        .Di0(wbs_dat_i),
        .Do0(wbs_dat_o),
        .A0(wbs_adr_i)
    );

endmodule



`default_nettype wire

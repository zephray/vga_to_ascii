`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:28:19 01/27/2018 
// Design Name: 
// Module Name:    top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module top(
  //Audio
  /*output         AUDIO_SDATA_OUT,
  output         AUDIO_BIT_CLK,
  input          AUDIO_SDATA_IN,
  output         AUDIO_SYNC,
  output         FLASH_AUDIO_RESET_B,*/

  //SRAM & Flash
  //output [30:0]  SRAM_FLASH_A,
  //inout  [15:0]  SRAM_FLASH_D,
  //inout  [31:16] SRAM_D,
  //inout  [3:0]   SRAM_DQP,
  //output [3:0]   SRAM_BW,
  //output         SRAM_FLASH_WE_B,
  //output         SRAM_CLK,
  //output         SRAM_CS_B,
  //output         SRAM_OE_B,
  //output         SRAM_MODE,
  //output         SRAM_ADV_LD_B,
  //output         FLASH_CE_B,
  //output         FLASH_OE_B,
  //output         FLASH_CLK,
  //output         FLASH_ADV_B,
  //output         FLASH_WAIT,
  
  //UART
  /*output         FPGA_SERIAL1_TX,
  input          FPGA_SERIAL1_RX,
  output         FPGA_SERIAL2_TX,
  input          FPGA_SERIAL2_RX,*/
  
  //IIC
  /*output         IIC_SCL_MAIN,
  inout          IIC_SDA_MAIN,*/
  inout          IIC_SCL_VIDEO,
  inout          IIC_SDA_VIDEO,
  /*output         IIC_SCL_SFP,
  inout          IIC_SDA_SFP,*/
  
  //PS2
  /*output         MOUSE_CLK,
  input          MOUSE_DATA,
  output         KEYBOARD_CLK,
  inout          KEYBOARD_DATA,*/
  
  //VGA IN
  input          VGA_IN_DATA_CLK,
  input  [7:0]   VGA_IN_BLUE,
  input  [7:0]   VGA_IN_GREEN,
  input  [7:0]   VGA_IN_RED,
  input          VGA_IN_HSOUT,
  input          VGA_IN_ODD_EVEN_B,
  input          VGA_IN_VSOUT,
  input          VGA_IN_SOGOUT,
  
  //SW
  input          GPIO_SW_C,
  input          GPIO_SW_W,
  input          GPIO_SW_E,
  input          GPIO_SW_S,
  input          GPIO_SW_N,
  input  [7:0]   GPIO_DIP_SW,

  //LED
  output [7:0]   GPIO_LED,
  output         GPIO_LED_C,
  output         GPIO_LED_W,
  output         GPIO_LED_E,
  output         GPIO_LED_S,
  output         GPIO_LED_N,

  //DDR2
  /*inout  [63:0]  DDR2_D,
  output [12:0]  DDR2_A,
  output [1:0]   DDR2_CLK_P,
  output [1:0]   DDR2_CLK_N,
  output [1:0]   DDR2_CE,
  output [1:0]   DDR2_CS_B,
  output [1:0]   DDR2_ODT,
  output         DDR2_RAS_B,
  output         DDR2_CAS_B,
  output         DDR2_WE_B,
  output [1:0]   DDR2_BA,
  output [7:0]   DDR2_DQS_P,
  output [7:0]   DDR2_DQS_N,
  output         DDR2_SCL,
  inout          DDR2_SDA,*/
  
  //Speaker
  //output         PIEZO_SPEAKER,
  
  //DVI
  output [11:0]  DVI_D,
  output         DVI_DE,
  output         DVI_H,
  output         DVI_RESET_B,
  output         DVI_V,
  output         DVI_XCLK_N,
  output         DVI_XCLK_P,
  input          DVI_GPIO1,
  
  //System
  input          FPGA_CPU_RESET_B,
  input          CLK_33MHZ_FPGA,
  input          CLK_27MHZ_FPGA
    );

    //Clock and Reset control   
    wire clk_33;
    wire clk_100;

    wire reset_in;
    wire reset_pll;
    wire reset;
    wire locked_pll;

    assign clk_33 = CLK_33MHZ_FPGA;
    assign reset_in = ~FPGA_CPU_RESET_B;
    
    //Delay Control
    localparam IODELAY_GRP = "IODELAY_MIG";
    localparam RST_SYNC_NUM = 25;
    ddr2_idelay_ctrl_mod #(
      .IODELAY_GRP(IODELAY_GRP),
      .RST_SYNC_NUM(RST_SYNC_NUM)
    ) ddr2_idelay_ctrl_mod (
      .clk_100MHz(clk_100),
      .rst(reset)
    );

    pll pll (
        .CLKIN1_IN(clk_33), 
        .RST_IN(reset_pll), 
        .CLKOUT0_OUT(clk_100),
        .LOCKED_OUT(locked_pll)
    );

    debounce_rst debounce_rst(
        .clk(clk_33),
        .noisy_rst(reset_in),
        .pll_locked(locked_pll),
        .clean_pll_rst(reset_pll),
        .clean_async_rst(reset)
    );
    //
    
    wire iic_done;
    
    wire vs_in = VGA_IN_VSOUT;
    wire hs_in = VGA_IN_HSOUT;
    wire [7:0] r_in = VGA_IN_RED;
    wire [7:0] g_in = VGA_IN_GREEN;
    wire [7:0] b_in = VGA_IN_BLUE;
    wire pclk_in = VGA_IN_DATA_CLK;
    
    //Only use one pixel
    reg [7:0] buf_r [0:99]; 
    reg [7:0] buf_g [0:99];
    reg [7:0] buf_b [0:99];
    reg disp_buffer;
    reg [10:0] x_counter; // 0-2047
    reg [10:0] y_counter; 
    reg hs_last;
    reg vs_last;
    
    localparam x_offset = 11'd220;
    localparam y_offset = 11'd28;
    localparam x_size = 11'd800;
    localparam y_size = 11'd600;
    
    wire x_valid = ((x_counter >= x_offset)&&(x_counter < (x_offset + x_size))) ? 1 : 0;
    wire y_valid = ((y_counter >= y_offset)&&(y_counter < (y_offset + y_size))) ? 1 : 0;
    wire [10:0] x_position = (x_valid) ? (x_counter - x_offset) : 11'd0;
    wire [10:0] y_position = (y_valid) ? (y_counter - y_offset) : 11'd0;
    
    wire [6:0] buf_addr = (x_position / 8);
    wire buf_wr = ((y_position[3:0] == 4'b0000)&&(x_position[2:0] == 3'b000)) ? 1 : 0;
    
    reg [7:0] r_out;
    reg [7:0] g_out;
    reg [7:0] b_out;
    
    always@(negedge pclk_in)
    begin
        if (buf_wr) begin
            buf_r[buf_addr] <= r_in;
            buf_g[buf_addr] <= g_in;
            buf_b[buf_addr] <= b_in;
        end
    end
    
    always@(posedge pclk_in)
    begin
        if (reset) begin
            vs_last <= 0;
            hs_last <= 0;
        end
        else begin
            hs_last <= hs_in;
            vs_last <= vs_in;
            if ((hs_last == 1'b0)&&(hs_in == 1'b1)) begin
                x_counter <= 0;
                y_counter <= y_counter + 1;
                if (y_counter[3:0] == 4'b0000)
                    disp_buffer <= ~disp_buffer;
            end else
                x_counter <= x_counter + 1;
            if ((vs_last == 1'b0)&&(vs_in == 1'b1)) begin
                y_counter <= 0;
            end
            
            r_out <= buf_r[buf_addr];
            g_out <= buf_g[buf_addr];
            b_out <= buf_b[buf_addr];
        end
    end

    dvi_module dvi_module(  
        //Outputs
        .dvi_vs(DVI_V),        
        .dvi_hs(DVI_H), 
        .dvi_d(DVI_D), 
        .dvi_xclk_p(DVI_XCLK_P), 
        .dvi_xclk_n(DVI_XCLK_N),
        .dvi_de(DVI_DE), 
        .dvi_reset_b(DVI_RESET_B),  
        .iic_done(iic_done), 
      
        //Inouts
        .dvi_sda(IIC_SDA_VIDEO),
        .dvi_scl(IIC_SCL_VIDEO),
      
        //Inputs
        .pixel_clk(VGA_IN_DATA_CLK), 
        .gpuclk_rst(reset), 
        .hsync(~VGA_IN_HSOUT),
        .vsync(~VGA_IN_VSOUT),
        .blank_b((x_valid & y_valid)),
        .pixel_r(r_out),
        .pixel_b(b_out),
        .pixel_g(g_out)
    );


    assign GPIO_LED[7:0] = {buf_addr[6:0], buf_wr};
    assign GPIO_LED_C = iic_done;
    assign GPIO_LED_S = r_out[7];
    assign GPIO_LED_W = 0;
    assign GPIO_LED_N = 0;
    assign GPIO_LED_E = 0;
    
    
endmodule

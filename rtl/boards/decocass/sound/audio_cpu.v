//  Based on MAME decocass.cpp, decocass_m.cpp (Juergen Buchmueller, David Haywood, GPL-2.0+)

module audio_cpu (
    input  wire        clk_sys,
    input  wire        reset,
    input  wire        ce_audio,
    input  wire        ce_pix,

    input  wire        audio_irq_set,

    input  wire        hcounter_eq_0,
    input  wire [8:0]  vcounter,

    output wire [11:0] ram_a,
    output wire [7:0]  ram_d,
    output wire        ram_we,
    input  wire [7:0]  ram_q,
    output wire [10:0] rom_a,
    input  wire [7:0]  rom_q,

    output wire        ay1_data_we,
    output wire        ay1_addr_we,
    output wire        ay2_data_we,
    output wire        ay2_addr_we,
    output wire [7:0]  ay_data_out,

    output wire        sound_to_main_we,
    output wire        sound_from_main_re,
    output wire [7:0]  sound_to_main,
    input  wire [7:0]  sound_from_main,

    input  wire        audio_nmi_master_enable,

    output wire [15:0] dbg_pc,
    output wire        dbg_sync,
    output wire        dbg_nmi_n,
    output wire        dbg_nmi_en,

    output wire        t65_res_n,
    output wire        t65_enable,
    output wire        t65_rdy,
    output wire        t65_irq_n,
    output wire        t65_nmi_n,
    output wire [7:0]  t65_di,
    input  wire [15:0] t65_a,
    input  wire [7:0]  t65_do,
    input  wire        t65_rw,
    input  wire        t65_sync
);

    wire [15:0] cpu_addr;
    wire [7:0]  cpu_do;
    wire [7:0]  cpu_di;
    wire        cpu_rw_n;
    wire        cpu_sync;
    wire        nmi_enable_access;
    wire        cpu_nmi_n;

    assign t65_res_n  = ~reset;
    assign t65_enable = ce_audio;
    assign t65_rdy    = 1'b1;
    assign t65_irq_n  = ~audio_irq_set;
    assign t65_nmi_n  = cpu_nmi_n;
    assign t65_di     = cpu_di;
    assign cpu_rw_n   = t65_rw;
    assign cpu_sync   = t65_sync;
    assign cpu_addr   = t65_a;
    assign cpu_do     = t65_do;

    reg audio_nmi_state;
    reg audio_nmi_enabled_r;

    always @(posedge clk_sys) begin
        if (reset) begin
            audio_nmi_state <= 1'b0;
            audio_nmi_enabled_r <= 1'b0;
        end else begin
            if (ce_pix && hcounter_eq_0) begin
                audio_nmi_state <= vcounter[3];
            end

            if (nmi_enable_access) begin
                audio_nmi_enabled_r <= 1'b1;
            end
        end
    end

    assign cpu_nmi_n = ~(audio_nmi_enabled_r & audio_nmi_state);

    wire [11:0] addr_12 = cpu_addr[11:0];

    wire ram_sel         = (cpu_addr[15:12] == 4'h0);
    wire nmi_enable_sel  = (cpu_addr[15:12] == 4'h1);
    wire ay1_data_sel    = (cpu_addr[15:12] == 4'h2);
    wire ay1_addr_sel    = (cpu_addr[15:12] == 4'h4);
    wire ay2_data_sel    = (cpu_addr[15:12] == 4'h6);
    wire ay2_addr_sel    = (cpu_addr[15:12] == 4'h8);
    wire sound_cmd_sel   = (cpu_addr[15:12] == 4'hA);
    wire sound_data_sel  = (cpu_addr[15:12] == 4'hC);
    wire rom_sel         = (cpu_addr[15:11] == 5'h1F);

    wire nmi_enable_reg_sel = (cpu_addr[15:11] == 5'b00010);
    wire sound_ack_rst_sel  = (cpu_addr[15:8] == 8'h18);

    assign nmi_enable_access = (nmi_enable_reg_sel && (cpu_rw_n || ~cpu_rw_n));
    wire sound_ack_rst_access = (sound_ack_rst_sel && (cpu_rw_n || ~cpu_rw_n));

    wire ay1_write = ~cpu_rw_n;
    assign ay1_data_we = ay1_data_sel && ay1_write;
    assign ay1_addr_we = ay1_addr_sel && ay1_write;

    wire ay2_write = ~cpu_rw_n;
    assign ay2_data_we = ay2_data_sel && ay2_write;
    assign ay2_addr_we = ay2_addr_sel && ay2_write;

    assign ay_data_out = cpu_do;

    wire sound_cmd_read = sound_cmd_sel && cpu_rw_n;
    wire sound_data_write = sound_data_sel && ~cpu_rw_n;

    assign sound_from_main_re = sound_cmd_read;
    assign sound_to_main_we   = sound_data_write;
    assign sound_to_main      = cpu_do;

    wire        ram_enable = 1'b1;
    wire        ram_wren = ram_sel && ~cpu_rw_n;
    wire [7:0]  ram_dout = ram_q;

    assign ram_a  = addr_12;
    assign ram_d  = cpu_do;
    assign ram_we = ram_wren;

    wire [10:0] rom_addr_r = cpu_addr[10:0];
    wire [7:0]  rom_dout = rom_q;

    assign rom_a = rom_addr_r;

    assign cpu_di = ram_sel       ? ram_dout :
                    sound_cmd_sel ? sound_from_main :
                    rom_sel       ? rom_dout :
                    8'hFF;

    assign dbg_pc     = cpu_addr;
    assign dbg_sync   = cpu_sync;
    assign dbg_nmi_n  = cpu_nmi_n;
    assign dbg_nmi_en = audio_nmi_enabled_r;

endmodule

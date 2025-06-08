
 `include "alu_design.v"
`define PASS 1'b1
`define FAIL 1'b0

`define no_of_testcase 85

module test_bench_alu;
    parameter N = 8;
    parameter FEATURE_ID_WIDTH = 8;
    parameter CMD_WIDTH = 4;

localparam TOTAL_WIDTH = FEATURE_ID_WIDTH
                           + N + N
                           + CMD_WIDTH
                           + 1 + 1 + 1
                           + 2
                           + (2*N)
                           + 1 + 1 + 1 + 1 + 1 + 1;

reg [TOTAL_WIDTH-1:0] stimulus_mem [0:`no_of_testcase-1];
reg [TOTAL_WIDTH-1:0] curr_test_case;

reg CLK, RST;
reg CE, MODE, CIN;
reg [1:0] INP_VALID;
reg [N-1:0] OPA, OPB;
reg [CMD_WIDTH-1:0] CMD;
integer i;

reg [2*N-1:0] Expected_RES;
reg exp_COUT, exp_G, exp_E, exp_L, exp_OFLOW, exp_ERR;
reg [FEATURE_ID_WIDTH-1:0] Feature_ID;

wire [2*N-1:0] RES;
wire COUT, OFLOW, ERR, E, G, L;

integer stim_mem_ptr;
reg [FEATURE_ID_WIDTH:0] scb_result [`no_of_testcase-1:0];

alu #(.N(N)) dut (
    .CLK(CLK), .RST(RST), .CE(CE),
    .OPA(OPA), .OPB(OPB), .CMD(CMD), .MODE(MODE), .CIN(CIN),
    .INP_VALID(INP_VALID),
    .RES(RES), .ERR(ERR), .OFLOW(OFLOW), .COUT(COUT),
    .E(E), .G(G), .L(L)
);

localparam FID_START     = TOTAL_WIDTH - 1;
localparam FID_END       = FID_START - FEATURE_ID_WIDTH + 1;
localparam OPA_START     = FID_END - 1;
localparam OPA_END       = OPA_START - N + 1;
localparam OPB_START     = OPA_END - 1;
localparam OPB_END       = OPB_START - N + 1;
localparam CMD_START     = OPB_END - 1;
localparam CMD_END       = CMD_START - CMD_WIDTH + 1;
localparam CIN_INDEX     = CMD_END - 1;
localparam CE_INDEX      = CIN_INDEX - 1;
localparam MODE_INDEX    = CE_INDEX - 1;
localparam INP_VALID_START = MODE_INDEX - 1;
localparam INP_VALID_END   = INP_VALID_START - 1;
localparam EXP_RES_START = INP_VALID_END - 1;
localparam EXP_RES_END   = EXP_RES_START - (2*N) + 1;
localparam COUT_INDEX    = EXP_RES_END - 1;
localparam G_INDEX       = COUT_INDEX - 1;
localparam E_INDEX       = G_INDEX - 1;
localparam L_INDEX       = E_INDEX - 1;
localparam OFLOW_INDEX   = L_INDEX - 1;
localparam ERR_INDEX     = OFLOW_INDEX - 1;

always #5 CLK = ~CLK;

task dut_reset;
    begin
        RST = 1; CE = 1;
        #20 RST = 0;
    end
endtask

task read_stimulus;
    begin
        $readmemb("stimulus.txt", stimulus_mem);
    end
endtask

task driver;
    begin
        curr_test_case = stimulus_mem[stim_mem_ptr];

        Feature_ID   = curr_test_case[FID_START     : FID_END];
        OPA          = curr_test_case[OPA_START     : OPA_END];
        OPB          = curr_test_case[OPB_START     : OPB_END];
        CMD          = curr_test_case[CMD_START     : CMD_END];
        CIN          = curr_test_case[CIN_INDEX];
        CE           = curr_test_case[CE_INDEX];
        MODE         = curr_test_case[MODE_INDEX];
        INP_VALID    = curr_test_case[INP_VALID_START : INP_VALID_END];
        Expected_RES = curr_test_case[EXP_RES_START : EXP_RES_END];
        exp_COUT     = curr_test_case[COUT_INDEX];
        exp_G        = curr_test_case[G_INDEX];
        exp_E        = curr_test_case[E_INDEX];
        exp_L        = curr_test_case[L_INDEX];
        exp_OFLOW    = curr_test_case[OFLOW_INDEX];
        exp_ERR      = curr_test_case[ERR_INDEX];

        $display("At time (%0t), Feature_ID = %b, Reserved_bit = 00, OPA = %08b, OPB = %08b, CMD = %04b, CIN = %b, CE = %b, MODE = %b, expected_result = %b, cout = %b, Comparison_EGL = %b%b%b, ov = %b, err = %b",
                 $time, Feature_ID,$signed(OPA), $signed(OPB), CMD, CIN, CE, MODE, $signed(Expected_RES), exp_COUT, exp_E, exp_G, exp_L, exp_OFLOW, exp_ERR);
    end
endtask

task monitor;
    begin
        repeat(25) @(posedge CLK);
        #1;
        $display("Monitor: At time (%0t), RES = %b, COUT = %b, EGL = %b%b%b, OFLOW = %b, ERR = %b",
                 $time, RES, COUT, E, G, L, OFLOW, ERR);
        $display("expected result = %b ,response data = %b", $signed(Expected_RES), $signed(RES));
        $display("stimulus_mem data = %b", curr_test_case);
        $display("packet data = %b\n", curr_test_case);
    end
endtask

task score_board;
    begin
        if (RES == Expected_RES && COUT == exp_COUT &&
            G == exp_G && E == exp_E && L == exp_L &&
            OFLOW == exp_OFLOW && ERR == exp_ERR)
            scb_result[stim_mem_ptr] = {Feature_ID, `PASS};
        else
            scb_result[stim_mem_ptr] = {Feature_ID, `FAIL};
    end
endtask

task gen_report;
    integer file;
    begin
        file = $fopen("results.txt", "w");
        for ( i = 0; i < `no_of_testcase; i=i+1) begin
            if (scb_result[i][0])
                $fdisplay(file, "Feature ID %b : PASS", scb_result[i][FEATURE_ID_WIDTH:1]);
            else
                $fdisplay(file, "Feature ID %b : FAIL", scb_result[i][FEATURE_ID_WIDTH:1]);
        end
        $fclose(file);
    end
endtask

initial begin
    CLK = 0;
    dut_reset();
    read_stimulus();

    for (stim_mem_ptr = 0; stim_mem_ptr < `no_of_testcase; stim_mem_ptr = stim_mem_ptr + 1) begin
        driver();
        monitor();
        score_board();
    end

    gen_report();
    #20 $finish;
end
endmodule

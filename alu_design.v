module alu #(parameter N = 8)
(
    input  [N-1:0] OPA, OPB,
    input CIN, CLK, RST, CE, MODE,
    input [3:0] CMD,
    input [1:0] INP_VALID,
    output reg COUT = 1'b0,
    output reg OFLOW = 1'b0,
    output reg G = 1'b0,
    output reg L = 1'b0,
    output reg E = 1'b0,
    output reg ERR = 1'b0,
    output reg overflow = 1'b0,
   // output reg neg = 1'b0,
   // output reg zero = 1'b0,
    output reg [2*N:0]RES= 1'b0);

    reg [N-1:0] OPA_temp, OPB_temp;
    reg [3:0] CMD_temp;
    reg [1:0] INP_VALID_temp;
    reg MODE_temp, CIN_temp;
    reg [1:0] mul_counter = 0;
    reg mult_in_progress = 0;
    reg [2*N:0]mul_result;

    reg signed [N-1:0] sa, sb;
    reg signed [N:0] sr;

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        OPA_temp <= 0; OPB_temp <= 0; CMD_temp <= 0;
        INP_VALID_temp <= 0; MODE_temp <= 0; CIN_temp <= 0;
mul_counter <= 0;
        mult_in_progress <= 0;
end else if (CE) begin
        OPA_temp <= OPA;
        OPB_temp <= OPB;
        CMD_temp <= CMD;
        INP_VALID_temp <= INP_VALID;
        MODE_temp <= MODE;
        CIN_temp <= CIN;
    end
end

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        RES = 0;
        COUT = 0;
        OFLOW = 0;
        G = 0; L = 0; E = 0; ERR = 0;
        overflow = 0;
        mul_counter = 0;
        mult_in_progress = 0;
    end else if (CE) begin
        COUT = 0;
        OFLOW = 0;
        G = 0; L = 0; E = 0; ERR = 0;
        overflow = 0; //neg = 0; zero = 0;
if (mult_in_progress) begin
            mul_counter = mul_counter + 1;
            if (mul_counter == 1) begin  // 3rd cycle since counting from 0
                RES = mul_result;
                mult_in_progress = 0;
                mul_counter = 0;
            end

 end else if (MODE_temp) begin  // Arithmetic Mode
            if (INP_VALID_temp == 2'b11) begin
                case (CMD_temp)
                    4'b0000: begin // ADD
                        RES[N:0] = OPA_temp + OPB_temp;
                        COUT = RES[N];
                    end
                        4'b0001: begin // SUB
                        RES = OPA_temp - OPB_temp;
                        OFLOW = (OPA_temp < OPB_temp);
                    end
                    4'b0010: begin // ADD + CIN
                        {COUT, RES} = OPA_temp + OPB_temp + CIN_temp;
                    end
                    4'b0011: begin // SUB - CIN
                        RES = OPA_temp - OPB_temp - CIN_temp;
                        OFLOW = (OPA_temp < (OPB_temp + CIN_temp));
                    end


                   4'b1000: begin // COMPARE
                        RES = {N+1{1'b0}};
                        if (OPA_temp == OPB_temp) begin E = 1; end
                        else if (OPA_temp > OPB_temp) begin G = 1; end
                        else L = 1;
                    end
                    4'b1001: begin // (OPA+1)*(OPB+1)
                        mul_result = (OPA_temp + 1) * (OPB_temp + 1);
                        mult_in_progress = 1;
                        mul_counter = 0;
                    end
                    4'b1010: begin // (OPA<<1)*OPB
                        mul_result = (OPA_temp << 1) * OPB_temp;
                        mult_in_progress = 1;
                        mul_counter = 0;
                    end
                    4'b1011: begin // SIGNED ADD
                        sa = OPA_temp; sb = OPB_temp; sr = sa + sb;
                        RES = sr;
                        overflow = (sa[N-1] == sb[N-1]) && (sr[N-1] != sa[N-1]);
                        //neg = (sr < 0);
                        //zero = (sr == 0);
                        if (sa == sb) E = 1;
                        else if (sa > sb) G = 1;
                        else L = 1;
                    end
                    4'b1100: begin // SIGNED SUB
                        sa = OPA_temp; sb = OPB_temp; sr = sa - sb;
                        RES = sr;
                        overflow = (sa[N-1] != sb[N-1]) && (sr[N-1] != sa[N-1]);
                      //  neg = (sr < 0);
                        //zero = (sr == 0);
                        if (sa == sb) E = 1;
                        else if (sa > sb) G = 1;
                        else L = 1;
                    end
                    default: begin
                        RES = 0; ERR = 1;
                    end
                endcase

 end else if (INP_VALID_temp == 2'b01) begin
                case (CMD_temp)
                    4'b0110: //increment b
                    begin
                    if(OPB_temp == {N{1'b1}})begin
                    RES = 0;
                    COUT =0;
                    ERR =1;
                    end else begin
                   RES = OPB_temp + 1;
                    COUT = 0;
                    ERR = 0;
                    end
                    end


                    4'b0111:  //decrement b
                    begin
                    if(OPB_temp == 0)begin
                    RES = {N{1'b1}};
                    OFLOW = 1;
                    ERR =0;
                    end else begin
                   RES = OPB_temp - 1;
                    OFLOW = 0;
                    ERR = 0;
                    end
                    end



                    default: begin RES = 0; ERR = 1; end
                endcase
            end else if (INP_VALID_temp == 2'b10) begin
                case (CMD_temp)
                    4'b0100:   begin  //increment a
                    if(OPA_temp == {N{1'b1}})begin
                    RES = 0;
                    COUT =0;
                    ERR =1;
                    end else begin
                   RES = OPA_temp + 1;
                    COUT = 0;
                    ERR = 0;
                    end
                    end
                    4'b0101:    begin    // decrement a
                    if(OPA_temp == 0)begin
                    RES = {N{1'b1}};
                    OFLOW = 1;
                    ERR =1;
                    end else begin
                   RES = OPA_temp - 1;
                    OFLOW = 0;
                    ERR = 0;
                    end
                    end

                    default: begin RES = 0; ERR = 1; end
                endcase
            end
        end else begin  // Logic Mode
            if (INP_VALID_temp == 2'b11) begin
                case (CMD_temp)
                    4'b0000: RES = (OPA_temp & OPB_temp); //and
                    4'b0001: RES = {1'b0,~(OPA_temp & OPB_temp)};//nand
                    4'b0010: RES = OPA_temp | OPB_temp;//or
                    4'b0011: RES ={1'b0,~(OPA_temp | OPB_temp)};//nor
                    4'b0100: RES = OPA_temp ^ OPB_temp; //xor
                    4'b0101: RES = {1'b0,~(OPA_temp ^ OPB_temp)};//xnor
                    4'b1100: begin  //rol
                        if (OPB_temp >= N) begin RES = 0; ERR = 1; end
                        else begin
                        RES = {1'b0, ((OPA_temp << OPB_temp) | (OPA_temp >> (N - OPB_temp))) & ((1 << N) - 1)};
                        ERR =0;
                        end
                    end
                    4'b1101: begin  //ror
                        if (OPB_temp >= N) begin RES = 0; ERR = 1; end
                        else begin
                        RES = {1'b0, ((OPA_temp >> OPB_temp) | (OPA_temp << (N - OPB_temp))) & ((1 << N) - 1)};
                        ERR = 0;
                        end
                    end
                    default: begin RES = 0; ERR = 1; end
                endcase
            end else if (INP_VALID_temp == 2'b01) begin
                case (CMD_temp)
                    4'b0111: RES ={1'b0, ~(OPB_temp)};//not b
                    4'b1010: RES = OPB_temp >> 1;//shift
                    4'b1011: RES = OPB_temp << 1;//shift
                    default: begin RES = 0; ERR = 1; end
                endcase
            end else if (INP_VALID_temp == 2'b10) begin
                case (CMD_temp)
                    4'b0110: RES ={1'b0, ~(OPA_temp)};//not a
                    4'b1000: RES = OPA_temp >> 1;
                    4'b1001: RES = OPA_temp << 1;
                    default: begin RES = 0; ERR = 1; end
                endcase
            end
        end
    end
end

endmodule

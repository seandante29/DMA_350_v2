module mux (
input logic [31:0] a,b,c,// a- previous value //b- default value // c-cmd fsm
input logic s1,s0,// s1- regclr //s0-header cmd
output logic [31:0] y
);
logic [31:0] w1;
assign w1 = s1 ? b : a;
assign y  = s0? c : w1;
endmodule
 

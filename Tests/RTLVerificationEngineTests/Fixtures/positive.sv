module top(input logic clk, input logic rst_n, input logic async_in, output logic q);
  logic sync1;
  logic sync2;
  always_ff @(posedge clk or negedge rst_n) begin
    sync1 <= async_in;
    sync2 <= sync1;
  end
  assign q = sync2;
endmodule

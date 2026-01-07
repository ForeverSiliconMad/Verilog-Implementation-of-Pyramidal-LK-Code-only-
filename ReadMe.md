Verilog code only, no MATLAB codes.

This project is a work in progress. Majorly, all the memory has been implemented as simulation only, and no BRAMs are used. The integration of BRAMs with the existing multiple point synchronous FIFO logic is being done. Due to this, when the code is synthesized, a high LUT count is observed (121k). 
There are no constraints (except the clock period set to 10ns).
Because of the said reasons, this project is considered simulation only, as of now (though synthesis is possible, it's not accurate). 
To understand the structure of the code, please read through the ReadME file under the testbench folder.

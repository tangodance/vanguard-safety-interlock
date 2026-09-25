// Asynchronous, clock-independent safety interlock latch module
module interlock_core (
    input  wire reset_n,          // Manual active-low system reset / fault clear
    input  wire comp_fault,       // Direct output from high-speed analog comparator
    input  wire estop_sense,      // Physical emergency stop sense line (active-high fault)
    output wire gate_power_en     // High-side power switch enable (1 = ENABLED, 0 = CUT)
);

    // Asynchronous Set-Reset Latch
    // Ensures immediate power cut independent of system clock state.
    // Once tripped, power remains locked OFF until an explicit reset_n signal is pulled low.
    
    reg fault_latched;

    always @(*) begin
        if (!reset_n) begin
            fault_latched = 1'b0; // Active reset clears fault condition
        end else if (comp_fault || estop_sense) begin
            fault_latched = 1'b1; // Immediate latch-on fault
        end
    end

    // Power enable line remains disabled as long as a fault is latched or active
    assign gate_power_en = !fault_latched && reset_n && !comp_fault && !estop_sense;

endmodule

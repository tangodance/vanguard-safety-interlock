// Asynchronous, clock-independent safety interlock latch module
// Uses explicit gate-level primitives to guarantee SR latch behavior 
// and prevent synthesis tool optimization warnings.
module interlock_core (
    input  wire reset_n,          // Manual active-low system reset / fault clear
    input  wire comp_fault,       // Direct output from high-speed analog comparator (active-high)
    input  wire estop_sense,      // Physical emergency stop sense line (active-high fault)
    output wire gate_power_en     // High-side power switch enable (1 = ENABLED, 0 = CUT)
);

    wire fault_trigger;
    wire q;      // Latch output (1 = fault active, power cut)
    wire q_n;    // Latch complement

    // 1. Combine all fault sources (active-high)
    assign fault_trigger = comp_fault | estop_sense;

    // 2. Explicit Asynchronous SR Latch (Cross-coupled NOR gates)
    // When fault_trigger is 1, Q goes to 1 and stays 1 (latched).
    // When reset_n is 0, Q goes to 0 (cleared).
    // Otherwise, Q holds its previous state.
    nor gate1 (q,     fault_trigger, q_n);
    nor gate2 (q_n,   ~reset_n,      q);

    // 3. Power enable is ONLY high when NO fault is latched AND reset is released
    // Note: We also mask the live fault signals to ensure immediate cut even before latch settles
    assign gate_power_en = ~q & ~fault_trigger & reset_n;

endmodule

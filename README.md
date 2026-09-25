## Project Vanguard: Out-of-Band Hardware Safety Interlock

An asynchronous, fail-safe hardware interlock designed to enforce hard physical power limits on kinetic AI systems and industrial actuators, operating completely out-of-band from the main operating system and control clock.

---

## Core Problem
As physical AI models (LLMs, VLMs, and autonomous agents) gain direct control over kinetic machinery, relying on software-layer safety guardrails introduces critical points of failure:
* **OS Execution Jitter:** Non-deterministic latency in high-level control loops.
* **Thermal / Compute Throttling:** Delayed motor kill signals under heavy compute loads.
* **Software State Corruptions:** Inability of untrusted software layers to reliably enforce their own safety limits.

---

## Architectural Principle
Functional physical safety must live **outside the main compute kernel**. 

This interlock places an analog threshold comparator and an asynchronous Set-Reset (SR) latch directly between the main controller outputs and the high-side power driver stage. When an analog over-voltage, over-current, or boundary violation occurs, high-side power is cut at the hardware gate layer—bypassing the CPU, OS, and system clock entirely..

+-------------------+     Command Signal     +-------------------+
|   AI Controller   | ---------------------> |  Motor Driver /   |
|  (Untrusted OS)   |                        |    Power Stage    |
+-------------------+                        +-------------------+
|                                            ^
| Direct Analog Threshold Line               | High-Side
v                                            | Gate Cut
+----------------------------------------------------------------+
| OUT-OF-BAND HARDWARE INTERLOCK                                 |
| Analog Comparator Array -> Asynchronous SR Latch -> Gate Drive |
+----------------------------------------------------------------+


---

## Targeted Propagation Budget
* **Analog Threshold Sensing:** ~50 ns
* **Comparator Response Time:** ~122 ns
* **GaN FET Gate Driver Disconnect:** ~200 ns
* **Total Propagation Target:** $\le 372\text{ ns}$ *(Asynchronous path propagation; hardware bench verification pending)*

---

## Asynchronous Verilog Core (`interlock_core.v`)

```verilog
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


Technical Notes & Implementation Constraints
​Clock Independence: The interlock path uses zero sequential clocked logic. Power-cut response time is bounded strictly by gate propagation delays, ensuring functionality if the main FPGA or CPU clock freezes.
​Latch-Off Guarantee: Temporary signal bounce on input lines cannot toggle motor power back on. Once a boundary violation occurs, the power path remains latched OFF until reset_n is cycled.
​Fail-Safe Operation: The design defaults to a fail-closed power disconnect state during power degradation or system reset events.
​Analog Conditioning: Mechanical inputs (E-stops) and analog comparator outputs must pass through external hardware filtering and de-bouncing prior to logic evaluation to prevent nuisance trips.
​Status & Scope
​Current Phase: Theoretical system architecture and hardware specification.
​Next Steps: Physical prototype assembly and bench verification under thermal and EMI stress.
​License: Open Source (MIT License). Free to inspect, adapt, and build upon..

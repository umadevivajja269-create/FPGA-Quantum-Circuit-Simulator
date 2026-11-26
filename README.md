# FPGA-Based Accelerator for Quantum Circuit Simulation

A configurable, application-specific FPGA accelerator for quantum circuit simulation, implemented using Verilog RTL on the Basys 3 FPGA platform. The project integrates a Python reference model for verification and a UART-based GUI for user-driven circuit configuration and hardware interaction.

## Project Overview

This project explores the hardware implementation of existing quantum circuit simulation operations using a configurable FPGA-based architecture. Users can specify the number of qubits, initial quantum state, gate count, and gate sequence. The accelerator processes these configurations and computes the resulting quantum state amplitudes and probabilities using fixed-point arithmetic.

The implementation integrates Verilog RTL hardware, a Python reference model for functional verification, and a UART-based graphical interface for configuring circuits and retrieving results from the FPGA.

## Technical Scope and Contribution

The primary contribution of this project is the design and implementation of a configurable, application-specific FPGA architecture for quantum circuit simulation. Rather than proposing a new quantum algorithm, the project explores how existing quantum circuit simulation operations can be mapped to dedicated FPGA hardware.

The design focuses on configurability, hardware implementation, numerical accuracy, execution latency, and FPGA resource utilization, with a Python-based reference model supporting functional verification.

## Key Features

- User-configurable quantum circuit simulation for 1 to 4 qubits
- Configurable initial quantum state and gate sequence
- Support for Hadamard (H), Pauli-X (X), Phase (S), S† (SDG), and CNOT gates
- Verilog RTL-based hardware architecture
- Fixed-point arithmetic using Q2.14 representation
- Python reference model for functional verification
- UART-based communication between PC and FPGA
- GUI for circuit configuration and result retrieval
- Computation of final real and imaginary amplitudes and state probabilities
- FPGA execution-cycle measurement and performance evaluation

## System Architecture

The design consists of configurable input handling, initial-state generation, instruction storage, quantum state memory, gate processing, and circuit control.

The Python GUI communicates with the FPGA through UART, enabling user-defined circuit configurations to be transmitted to the hardware and simulation results to be retrieved.

## Hardware Platform

| Parameter | Specification |

| FPGA Board : Basys 3 |
| FPGA Device : Xilinx Artix-7 XC7A35T |
| System Clock: 100 MHz |
| Hardware Description Language : Verilog HDL |
| Design and Implementation Tool : Xilinx Vivado 2023.2 |
| Arithmetic Representation : Signed Fixed-Point Q2.14 |

## Software and Development Tools

- Python – Reference simulation and GUI
- Verilog HDL – Hardware design
- Xilinx Vivado 2023.2 – RTL simulation, synthesis, implementation, and bitstream generation
- UART Serial Communication – PC-to-FPGA communication

## Verification and Evaluation

The FPGA implementation is verified against the Python reference model using configurable quantum circuit test cases.

The project evaluates:

- Functional correctness of quantum gate operations
- Numerical accuracy of FPGA-computed amplitudes
- Comparison between Python reference and FPGA results
- FPGA execution latency in clock cycles
- Hardware resource utilization

## Implementation and Demonstration

The project supports two hardware interaction methods:

- **Method A – Manual FPGA Interface:** Circuit configuration and execution through Basys 3 switches and buttons, with results presented through onboard LEDs.
- **Method B – UART-Based GUI:** Circuit configuration through a Python GUI, communication with the FPGA over UART, and retrieval of simulation results.

Both methods utilize the FPGA quantum circuit simulation hardware core.

## Project Status

RTL design, Python reference model, functional verification, and Basys 3 FPGA implementation have been developed as part of the academic project. Hardware demonstrations include configurable quantum circuit execution and result retrieval.

## Research Scope

This project investigates the implementation of quantum circuit simulation on classical FPGA hardware through a configurable, application-specific hardware architecture. It demonstrates hardware mapping of existing quantum simulation operations and evaluates the implementation through functional verification and hardware performance analysis.


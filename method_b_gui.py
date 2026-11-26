
import tkinter as tk
from tkinter import ttk, messagebox
import serial
import threading

# ==========================================
# METHOD B: PYTHON GUI + FPGA UART
# ==========================================

BAUD_RATE = 115200
PORT = "COM8"
Q_SCALE = 16384

GATES = {
    "H": 0,
    "X": 1,
    "S": 2,
    "SDG": 3,
    "CNOT": 4
}

root = tk.Tk()
root.title("FPGA Quantum Circuit Simulator - Method B")
root.geometry("1100x850")
root.minsize(900, 700)

gate_rows = []

# ==========================================
# CIRCUIT DIAGRAM DRAWING
# ==========================================

def update_circuit_diagram(*args):
    if "circuit_canvas" not in globals():
        return

    circuit_canvas.delete("all")

    try:
        n = int(qubits_var.get())
        initial = int(initial_var.get())
    except (ValueError, tk.TclError):
        return

    if not 1 <= n <= 4:
        return

    # Diagram dimensions
    left = 75
    top = 45
    row_gap = 45
    gate_gap = 75

    gate_total = len(gate_rows)

    canvas_width = max(
        850,
        left + 100 + gate_total * gate_gap
    )
    canvas_height = max(150, top + n * row_gap + 35)

    circuit_canvas.configure(
        scrollregion=(0, 0, canvas_width, canvas_height)
    )

    # Initial state information
    initial_binary = format(initial, f"0{n}b")

    circuit_canvas.create_text(
        12, 15,
        anchor="w",
        text=f"Initial State: |{initial_binary}>",
        font=("Arial", 10, "bold"),
        fill="navy"
    )

    # Draw qubit wires
    for q in range(n):
        y = top + q * row_gap

        circuit_canvas.create_text(
            12, y,
            anchor="w",
            text=f"q{q}",
            font=("Arial", 11, "bold")
        )

        circuit_canvas.create_line(
            left, y,
            canvas_width - 25, y,
            fill="black",
            width=2
        )

    # Draw gate symbols
    for i, (gate_var, target_var, control_var) in enumerate(gate_rows):

        x = left + 65 + i * gate_gap

        try:
            gate_name = gate_var.get()
            target = int(target_var.get())
            control = int(control_var.get())
        except ValueError:
            continue

        if not 0 <= target < n:
            continue

        target_y = top + target * row_gap

        # CNOT gate
        if gate_name == "CNOT":

            if not 0 <= control < n or control == target:
                circuit_canvas.create_text(
                    x, top + n * row_gap + 10,
                    text="Invalid CNOT",
                    fill="red",
                    font=("Arial", 8)
                )
                continue

            control_y = top + control * row_gap

            # Vertical connecting line
            circuit_canvas.create_line(
                x, control_y,
                x, target_y,
                fill="black",
                width=2
            )

            # Control dot
            circuit_canvas.create_oval(
                x - 6, control_y - 6,
                x + 6, control_y + 6,
                fill="black",
                outline="black"
            )

            # Target circle
            circuit_canvas.create_oval(
                x - 14, target_y - 14,
                x + 14, target_y + 14,
                outline="black",
                width=2
            )

            # Plus symbol
            circuit_canvas.create_line(
                x - 8, target_y,
                x + 8, target_y,
                width=2
            )
            circuit_canvas.create_line(
                x, target_y - 8,
                x, target_y + 8,
                width=2
            )

        else:
            # H, X, S, SDG gates
            gate_width = 42
            gate_height = 30

            circuit_canvas.create_rectangle(
                x - gate_width // 2,
                target_y - gate_height // 2,
                x + gate_width // 2,
                target_y + gate_height // 2,
                fill="#DCEBFA",
                outline="navy",
                width=2
            )

            circuit_canvas.create_text(
                x, target_y,
                text=gate_name,
                font=("Arial", 10, "bold"),
                fill="navy"
            )

        # Gate number above the diagram
        circuit_canvas.create_text(
            x, 25,
            text=f"G{i + 1}",
            font=("Arial", 8, "bold")
        )


# ==========================================
# BUILD GATE INPUT ROWS
# ==========================================

def rebuild_gate_rows(*args):
    global gate_rows

    for widget in gate_frame.winfo_children():
        widget.destroy()

    gate_rows.clear()

    try:
        count = int(gate_count_var.get())
        n = int(qubits_var.get())
    except ValueError:
        update_circuit_diagram()
        return

    headers = [
        "Gate No.",
        "Gate Type",
        "Target Qubit",
        "Control Qubit"
    ]

    for col, heading in enumerate(headers):
        ttk.Label(
            gate_frame,
            text=heading,
            font=("Arial", 10, "bold")
        ).grid(row=0, column=col, padx=8, pady=5)

    for i in range(count):

        ttk.Label(
            gate_frame,
            text=str(i + 1)
        ).grid(row=i + 1, column=0, padx=8, pady=3)

        gate_var = tk.StringVar(value="H")
        target_var = tk.StringVar(value="0")
        control_var = tk.StringVar(value="1" if n > 1 else "0")

        gate_box = ttk.Combobox(
            gate_frame,
            textvariable=gate_var,
            values=list(GATES.keys()),
            state="readonly",
            width=12
        )
        gate_box.grid(
            row=i + 1, column=1, padx=8, pady=3
        )

        target_box = ttk.Combobox(
            gate_frame,
            textvariable=target_var,
            values=[str(q) for q in range(n)],
            state="readonly",
            width=12
        )
        target_box.grid(
            row=i + 1, column=2, padx=8, pady=3
        )

        control_box = ttk.Combobox(
            gate_frame,
            textvariable=control_var,
            values=[str(q) for q in range(n)],
            state="readonly",
            width=12
        )
        control_box.grid(
            row=i + 1, column=3, padx=8, pady=3
        )

        gate_rows.append(
            (gate_var, target_var, control_var)
        )

        def update_control(
            *unused,
            g=gate_var,
            cbox=control_box
        ):
            if g.get() == "CNOT":
                cbox.configure(state="readonly")
            else:
                cbox.configure(state="disabled")

        gate_var.trace_add("write", update_control)
        gate_var.trace_add("write", update_circuit_diagram)
        target_var.trace_add("write", update_circuit_diagram)
        control_var.trace_add("write", update_circuit_diagram)

        update_control()

    update_circuit_diagram()


# ==========================================
# VALIDATE AND BUILD REQUEST
# ==========================================

def build_request():

    n = int(qubits_var.get())
    initial = int(initial_var.get())
    count = int(gate_count_var.get())

    if not 1 <= n <= 4:
        raise ValueError(
            "Number of qubits must be 1 to 4."
        )

    if not 0 <= initial < (1 << n):
        raise ValueError(
            "Initial state is invalid for selected qubits."
        )

    if not 1 <= count <= 16:
        raise ValueError(
            "Gate count must be between 1 and 16."
        )

    if len(gate_rows) != count:
        raise ValueError("Gate configuration is incomplete.")

    packet = bytearray([0xA5, n, initial, count])

    for index, (gate_var, target_var, control_var) in enumerate(gate_rows):

        gate_name = gate_var.get()
        target = int(target_var.get())
        control = int(control_var.get())

        if gate_name not in GATES:
            raise ValueError(
                f"Invalid gate at row {index + 1}."
            )

        if not 0 <= target < n:
            raise ValueError(
                f"Invalid target qubit at row {index + 1}."
            )

        if gate_name == "CNOT":
            if n < 2 or not 0 <= control < n or control == target:
                raise ValueError(
                    f"CNOT at row {index + 1} needs "
                    "different valid control and target."
                )

        packet.extend([
            GATES[gate_name],
            target,
            control
        ])

    return bytes(packet), n


# ==========================================
# READ EXACT UART BYTES
# ==========================================

def read_exact(connection, count):

    data = bytearray()

    while len(data) < count:

        chunk = connection.read(count - len(data))

        if not chunk:
            raise TimeoutError(
                "No complete FPGA response received. "
                "Check board, COM port and UART."
            )

        data.extend(chunk)

    return bytes(data)


# ==========================================
# SEND CIRCUIT TO FPGA AND RECEIVE RESULTS
# ==========================================

def run_fpga():

    try:
        packet, n = build_request()
        state_count_expected = 1 << n

        root.after(
            0,
            lambda: status_label.config(
                text="Sending circuit to FPGA..."
            )
        )

        with serial.Serial(
            PORT,
            BAUD_RATE,
            timeout=5,
            write_timeout=5
        ) as connection:

            connection.reset_input_buffer()

            connection.write(packet)
            connection.flush()

            root.after(
                0,
                lambda: status_label.config(
                    text="Waiting for FPGA calculation..."
                )
            )

            # Find response header 0x5A
            while True:

                first = read_exact(connection, 1)[0]

                if first == 0x5A:
                    break

            status = read_exact(connection, 1)[0]
            state_count = read_exact(connection, 1)[0]

            cycle_bytes = read_exact(connection, 4)

            cycles = int.from_bytes(
                cycle_bytes,
                "little"
            )

            if status != 0:
                raise RuntimeError(
                    f"FPGA returned error status: {status}"
                )

            if state_count != state_count_expected:
                raise RuntimeError(
                    f"Expected {state_count_expected} states, "
                    f"but FPGA returned {state_count}."
                )

            results = []

            for address in range(state_count):

                real_bytes = read_exact(connection, 2)
                imag_bytes = read_exact(connection, 2)

                real_fixed = int.from_bytes(
                    real_bytes,
                    "little",
                    signed=True
                )

                imag_fixed = int.from_bytes(
                    imag_bytes,
                    "little",
                    signed=True
                )

                real = real_fixed / Q_SCALE
                imag = imag_fixed / Q_SCALE

                probability = real * real + imag * imag

                results.append(
                    (address, real, imag, probability)
                )

        root.after(
            0,
            lambda: show_results(results, cycles)
        )

    except Exception as error:

        root.after(
            0,
            lambda msg=str(error): show_error(msg)
        )


def start_calculation():

    try:
        build_request()

    except Exception as error:
        messagebox.showerror(
            "Input Error",
            str(error)
        )
        return

    run_button.config(state="disabled")
    status_label.config(text="Connecting to FPGA...")

    threading.Thread(
        target=run_fpga,
        daemon=True
    ).start()


def show_error(message):

    run_button.config(state="normal")

    status_label.config(
        text="Communication or calculation error."
    )

    messagebox.showerror(
        "Method B Error",
        message
    )


def show_results(results, cycles):

    for item in result_tree.get_children():
        result_tree.delete(item)

    for address, real, imag, probability in results:

        result_tree.insert(
            "",
            "end",
            values=(
                address,
                f"{real:.6f}",
                f"{imag:.6f}",
                f"{probability:.6f}"
            )
        )

    total_probability = sum(
        item[3] for item in results
    )

    cycles_label.config(
        text=f"FPGA Execution Cycles: {cycles}"
    )

    probability_label.config(
        text=f"Total Probability: {total_probability:.6f}"
    )

    status_label.config(
        text="FPGA calculation completed successfully."
    )

    run_button.config(state="normal")


# ==========================================
# GUI LAYOUT
# ==========================================

main = ttk.Frame(root, padding=12)
main.pack(fill="both", expand=True)

ttk.Label(
    main,
    text="FPGA-Based Quantum Circuit Simulator",
    font=("Arial", 18, "bold")
).pack(pady=8)

ttk.Label(
    main,
    text="Method B - Python GUI communicates with Basys 3 FPGA",
    font=("Arial", 10)
).pack(pady=3)


# ==========================================
# CIRCUIT CONFIGURATION
# ==========================================

config_frame = ttk.LabelFrame(
    main,
    text="Circuit Configuration",
    padding=10
)
config_frame.pack(fill="x", pady=8)

ttk.Label(
    config_frame,
    text="Number of Qubits:"
).grid(row=0, column=0, padx=8, pady=6)

qubits_var = tk.StringVar(value="2")

qubits_box = ttk.Combobox(
    config_frame,
    textvariable=qubits_var,
    values=["1", "2", "3", "4"],
    state="readonly",
    width=10
)
qubits_box.grid(
    row=0, column=1, padx=8, pady=6
)

ttk.Label(
    config_frame,
    text="Initial State (decimal):"
).grid(row=0, column=2, padx=8, pady=6)

initial_var = tk.StringVar(value="0")

initial_box = ttk.Combobox(
    config_frame,
    textvariable=initial_var,
    values=[str(i) for i in range(16)],
    state="readonly",
    width=10
)
initial_box.grid(
    row=0, column=3, padx=8, pady=6
)

ttk.Label(
    config_frame,
    text="Gate Count:"
).grid(row=1, column=0, padx=8, pady=6)

gate_count_var = tk.StringVar(value="2")

gate_count_box = ttk.Combobox(
    config_frame,
    textvariable=gate_count_var,
    values=[str(i) for i in range(1, 17)],
    state="readonly",
    width=10
)
gate_count_box.grid(
    row=1, column=1, padx=8, pady=6
)


# ==========================================
# GATE INSTRUCTIONS
# ==========================================

gate_frame = ttk.LabelFrame(
    main,
    text="Gate Instructions",
    padding=10
)
gate_frame.pack(fill="x", pady=8)


# ==========================================
# QUANTUM CIRCUIT DIAGRAM
# ==========================================

diagram_frame = ttk.LabelFrame(
    main,
    text="Quantum Circuit Diagram",
    padding=8
)
diagram_frame.pack(fill="x", pady=8)

ttk.Label(
    diagram_frame,
    text="Live circuit representation of selected gate operations",
    font=("Arial", 9, "italic")
).pack(anchor="w", pady=3)

canvas_container = ttk.Frame(diagram_frame)
canvas_container.pack(fill="x", expand=True)

circuit_canvas = tk.Canvas(
    canvas_container,
    height=230,
    width=850,
    background="white",
    highlightthickness=1,
    highlightbackground="gray"
)

horizontal_scroll = ttk.Scrollbar(
    canvas_container,
    orient="horizontal",
    command=circuit_canvas.xview
)

circuit_canvas.configure(
    xscrollcommand=horizontal_scroll.set
)

circuit_canvas.pack(
    side="top",
    fill="x",
    expand=True
)

horizontal_scroll.pack(
    side="bottom",
    fill="x"
)


# Update diagram when configuration changes
qubits_var.trace_add(
    "write",
    rebuild_gate_rows
)

gate_count_var.trace_add(
    "write",
    rebuild_gate_rows
)

initial_var.trace_add(
    "write",
    update_circuit_diagram
)

rebuild_gate_rows()


# ==========================================
# RUN BUTTON
# ==========================================

button_frame = ttk.Frame(main)
button_frame.pack(pady=10)

run_button = ttk.Button(
    button_frame,
    text="SEND CIRCUIT TO FPGA",
    command=start_calculation
)

run_button.pack(side="left", padx=8)


# ==========================================
# STATUS
# ==========================================

status_label = ttk.Label(
    main,
    text="Ready. Select your circuit configuration."
)
status_label.pack(pady=5)


# ==========================================
# FPGA OUTPUT RESULTS
# ==========================================

result_frame = ttk.LabelFrame(
    main,
    text="FPGA Output Results",
    padding=10
)
result_frame.pack(
    fill="both",
    expand=True,
    pady=8
)

columns = (
    "State",
    "Real Amplitude",
    "Imaginary Amplitude",
    "Probability"
)

result_tree = ttk.Treeview(
    result_frame,
    columns=columns,
    show="headings",
    height=6
)

for column in columns:

    result_tree.heading(
        column,
        text=column
    )

    result_tree.column(
        column,
        width=175,
        anchor="center"
    )

result_tree.pack(
    fill="both",
    expand=True
)

cycles_label = ttk.Label(
    result_frame,
    text="FPGA Execution Cycles: --",
    font=("Arial", 11, "bold")
)
cycles_label.pack(pady=5)

probability_label = ttk.Label(
    result_frame,
    text="Total Probability: --",
    font=("Arial", 11, "bold")
)
probability_label.pack(pady=5)


# ==========================================
# START GUI
# ==========================================

root.mainloop()

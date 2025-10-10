# DESIGN BLUEPRINT: Maestro Experimental Control System

## 1. Core Philosophy

Maestro is a MATLAB-based software system for designing, running, and logging complex auditory neurophysiology experiments. The core philosophy is built on three principles:

1.  **Modularity:** Every component of an experiment (stimuli, trials, blocks) is a reusable, self-contained object.
2.  **Extensibility:** The system is designed to be easily expanded with new stimulus types, trial structures, and hardware without rewriting core logic.
3.  **Reproducibility:** Every aspect of an experiment, from stimulus generation to trial order, is logged to ensure perfect replication.

## 2. Architectural Hierarchy

The system is built on a clear hierarchy of objects. Experiments are constructed by composing these objects from the bottom up.

* **`Experiment`:** The top-level container for a session.
    * **Controls:** Defines the order in which blocks are presented (`'fixed'`, `'random'`, custom) and the pacing between them (`'wait_for_click'`, fixed duration).

* **`Block`:** A self-contained experimental context with a specific set of rules.
    * **Controls:** Defines the Inter-Trial Interval (ITI), the list of possible `Trial` types, and the randomization mode (`'On-the-Fly'` or `'Pre-Rolled'`). Pre-rolled trial lists are saved for perfect reproducibility.

* **`Trial`:** A flexible timeline that contains one or more `Presentation` events.
    * **Flexibility:** This timeline structure can represent any trial type, from a simple stimulus presentation (`S1`) to a complex cued-outcome trial (`S1 → Delay → S2`) or an oddball stream.

* **`Presentation`:** A single, atomic sensory event on a trial timeline.
    * **Parameters:** Contains a reference to a `Stimulus Primitive`, its level (dB SPL), duration, envelope ramps, and start time within the trial.

* **`Stimulus Primitive`:** The raw sensory content.
    * **Types:** Can be a reference to a generator function (`make_tone`), an external file (`.wav`), or a pre-loaded object in memory for efficiency.

## 3. Core Technical Principles

### 3.1. Plugin Architecture for Stimuli
The system uses a plugin architecture for stimulus generation. A dedicated package folder (e.g., `+stim/`) holds all generator functions. The GUI will automatically scan this folder at startup, discover available functions, and make them available as options in the stimulus designer. This allows new stimulus types to be added without modifying the main application.

### 3.2. Compile-then-Execute Engine for Timing Precision
To guarantee millisecond-accurate, hardware-timed execution, the software operates in two stages:
1.  **Compile:** Before a block begins, the software pre-generates the entire analog waveform and digital TTL pulse train for the whole block and loads them into the DAQ's buffer.
2.  **Execute:** The hardware's internal clock streams the buffered data, ensuring timing is independent of software or OS-level latency. The GUI's role during execution is purely for monitoring.

### 3.3. Data & Metadata Logging
For every block, the system will save a complete set of files to ensure full reproducibility:
* **Audio:** The exact analog waveform sent to the speaker (`AO.wav`) and the loopback recording (`loopback.wav`).
* **Timing:** A log of all TTL events with their precise sample indices (`TTL.csv`).
* **Trial Logic:** A detailed log of every trial, including its type, parameters, and randomization (`trials.csv`).
* **Metadata:** A file containing a hash of the calibration data, software version, hardware settings, and preset names (`metadata.json`).
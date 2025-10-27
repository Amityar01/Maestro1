# Maestro GUI System Design

Version: 2.0  
Date: 2025-10-16  
Status: Design Phase

---

## Overview

Maestro GUI provides a modular interface for auditory neuroscience experiments:
- Manage reusable block configurations
- Compose sequences of blocks with transition rules
- Run experimental sessions with comprehensive logging
- Synchronize with external recording systems (OpenEphys, etc.)

**Design Principles:**
- Modular: Separate apps for distinct tasks
- File-based: Human-readable JSON configs
- Non-destructive: Never modify originals
- Logging-first: Complete stimulus logs for ephys sync
- Simple triggers: One pulse per trial, distinguish by order

---

## Terminology

| Term | Definition | Example |
|------|-----------|---------|
| **Builder** | Code that generates trial sequences | `oddball`, `frequency_sweep` |
| **Schema** | Defines parameters for a builder | `schema.json` |
| **Block** | Configured instance of a builder | `oddball_1kHz_15pct.json` |
| **Transition** | Rules between blocks | Wait 30s, Press ENTER |
| **Sequence** | Ordered blocks + transitions | `mmn_protocol.json` |
| **Session** | One execution of a sequence | `20251015_S001_sess01/` |

**Component Hierarchy:**
```
Session → Sequence → Block → Builder → Generator
```

---

## File Organization
```
Maestro/
├── +core/
│   ├── MaestroContext.m
│   └── +logging/
│       ├── SessionLogger.m
│       └── BlockLogger.m
│
├── +generators/
│   └── +tone/
│       ├── generate.m
│       └── schema.json
│
├── +builders/
│   └── +oddball/
│       ├── build.m
│       ├── schema.json              ← Defines structure
│       └── example_instance.json    ← Example (optional)
│
├── +engines/
│   └── +audio_only/
│       ├── execute.m
│       └── schema.json
│
├── library/
│   ├── blocks/                      ← User's saved blocks
│   │   ├── oddball_1kHz_15pct.json
│   │   └── oddball_2kHz_20pct.json
│   └── sequences/                   ← User's saved sequences
│       └── mmn_protocol_v1.json
│
├── sessions/                        ← Session data
│   └── 20251015_S001_sess01/
│       ├── metadata.json
│       ├── sequence.json
│       ├── block_001/
│       │   ├── block_config.json
│       │   └── stimuli.csv
│       ├── block_002/
│       │   └── ...
│       ├── events.log
│       └── notes.txt
│
└── +gui/
    ├── +blocks/
    │   ├── BlockManager.m
    │   └── BlockEditor.m
    ├── +sequences/
    │   ├── SequenceComposer.m
    │   └── TransitionEditor.m
    └── +session/
        ├── SessionSetup.m
        └── SessionRunner.m
```

---

## Data Structures

### 1. Builder Schema

**File**: `+builders/+oddball/schema.json`

Defines the "template" - what parameters exist and their constraints.
```json
{
  "builder_type": "oddball",
  "version": "1.0.0",
  "description": "Standard/deviant oddball paradigm",
  
  "parameters": {
    "n_trials": {
      "type": "integer",
      "description": "Number of trials",
      "required": true,
      "min": 1,
      "max": 10000
    },
    "deviant_probability": {
      "type": "float",
      "description": "Probability of deviant trials",
      "required": true,
      "min": 0,
      "max": 1
    },
    "order_constraint": {
      "type": "enum",
      "description": "Trial ordering constraint",
      "required": true,
      "options": ["none", "no_consecutive_deviants"]
    },
    "iti_sec": {
      "type": "array",
      "description": "Inter-trial interval [min, max]",
      "required": true,
      "length": [1, 2]
    },
    "standard_stimulus": {
      "type": "stimulus_spec",
      "required": true
    },
    "deviant_stimulus": {
      "type": "stimulus_spec",
      "required": true
    }
  }
}
```

---

### 2. Block Instance

**File**: `library/blocks/oddball_1kHz_15pct.json`
```json
{
  "block_id": "oddball_1kHz_15pct",
  "builder_type": "oddball",
  "description": "1 kHz standard, 2 kHz deviant, 15%",
  "created": "2025-10-16T14:30:00",
  "created_by": "John Doe",
  
  "parameters": {
    "n_trials": 200,
    "deviant_probability": 0.15,
    "order_constraint": "no_consecutive_deviants",
    "iti_sec": [1.0, 2.0],
    
    "standard_stimulus": {
      "generator": "tone",
      "version": "1.0.0",
      "parameters": {
        "freq_hz": 1000,
        "dur_ms": 50,
        "level_db": 60,
        "ramp_ms": 5
      }
    },
    
    "deviant_stimulus": {
      "generator": "tone",
      "version": "1.0.0",
      "parameters": {
        "freq_hz": 2000,
        "dur_ms": 50,
        "level_db": 60,
        "ramp_ms": 5
      }
    }
  }
}
```

---

### 3. Sequence

**File**: `library/sequences/mmn_protocol_v1.json`
```json
{
  "sequence_id": "mmn_protocol_v1",
  "description": "Standard MMN protocol with 3 blocks",
  "created": "2025-10-16T15:00:00",
  
  "global_settings": {
    "sampling_rate_hz": 192000,
    "engine_type": "audio_only",
    "engine_config": {
      "vendor": "ni",
      "device_id": "Dev1",
      "audio_channels": ["ao0"],
      "trigger_channel": "ao1",
      "trigger_config": {
        "voltage": 5.0,
        "duration_ms": 10
      }
    }
  },
  
  "blocks": [
    {
      "block_file": "oddball_1kHz_15pct.json",
      "transition": {
        "type": "delay",
        "duration_sec": 30
      }
    },
    {
      "block_file": "oddball_2kHz_15pct.json",
      "transition": {
        "type": "button_press",
        "message": "Press ENTER for next block"
      }
    },
    {
      "block_file": "oddball_1kHz_15pct.json",
      "transition": {"type": "none"}
    }
  ]
}
```

**Transition Types:**
- `none`: Proceed immediately
- `delay`: Fixed delay (duration_sec)
- `button_press`: Wait for ENTER

---

### 4. Session Metadata

**File**: `sessions/20251015_S001_sess01/metadata.json`
```json
{
  "session_id": "20251015_S001_sess01",
  "subject_id": "S001",
  "session_number": 1,
  "date": "2025-10-15",
  "start_time": "14:30:00",
  "end_time": "14:57:23",
  "experimenter": "John Doe",
  "sequence_file": "mmn_protocol_v1.json",
  "hardware": {
    "daq_vendor": "ni",
    "daq_device": "Dev1",
    "sampling_rate": 192000
  },
  "notes": "Subject reported good attention",
  "status": "completed",
  "duration_sec": 1643
}
```

---

### 5. Stimulus Log

**File**: `sessions/20251015_S001_sess01/block_001/stimuli.csv`
```csv
trial_index,block_index,trial_type,freq_hz,dur_ms,level_db,onset_time_sec,trigger_sent_sec,iti_sec
1,1,standard,1000,50,60,0.000000,0.000012,1.234
2,1,standard,1000,50,60,1.564123,1.564135,0.987
3,1,deviant,2000,50,60,2.880456,2.880468,1.456
```

**Purpose:** Match OpenEphys TTL times with exact stimuli by trial order.

---

### 6. Event Log

**File**: `sessions/20251015_S001_sess01/events.log`
```
2025-10-15 14:30:00 [INFO] Session started
2025-10-15 14:30:05 [INFO] Starting block 1/3
2025-10-15 14:35:45 [INFO] Block 1 completed (200 trials)
2025-10-15 14:42:30 [WARNING] User paused experiment
2025-10-15 14:43:00 [INFO] User resumed
2025-10-15 14:54:18 [INFO] Session ended: completed
```

---

## GUI Applications

### App 1: BlockManager

**Purpose:** Manage block library

**Launch:** `gui.blocks.BlockManager()`

**Features:**
- Browse blocks in library
- Create new (from builder schema)
- Load & edit existing
- Duplicate blocks
- Delete blocks
- Preview (generate sample trials)

**Workflow:**

1. **New Block**
   - Select builder type
   - Schema generates empty form
   - Fill parameters
   - Save to `library/blocks/`

2. **Load & Edit**
   - Select existing block
   - Pre-filled form
   - Modify parameters
   - Save as new name (non-destructive)

**UI Layout:**
```
┌──────────────────────────────────────────────┐
│ BlockManager                          [X]    │
├──────────────┬───────────────────────────────┤
│ Block List   │ Block Details                 │
│              │ ID: oddball_1kHz_15pct        │
│ □ oddball_1k │ Builder: oddball              │
│ ■ oddball_2k │ Trials: 200                   │
│ □ freq_sweep │ Dev prob: 0.15                │
│              │ ...                            │
│ [Search...]  │                                │
├──────────────┴───────────────────────────────┤
│ [New] [Edit] [Duplicate] [Delete] [Preview] │
└──────────────────────────────────────────────┘
```

---

### App 2: SequenceComposer

**Purpose:** Build sequences from blocks

**Launch:** `gui.sequences.SequenceComposer()`

**Features:**
- Load blocks from library
- Add to sequence (order matters)
- Configure transitions
- Reorder blocks
- Save/load sequences
- Validate (check blocks exist, estimate duration)

**UI Layout:**
```
┌──────────────────────────────────────────────┐
│ SequenceComposer                      [X]    │
├──────────────┬───────────────────────────────┤
│ Sequence     │ Block Library                 │
│              │ □ oddball_1kHz_15pct          │
│ 1. oddball_1k│ □ oddball_2kHz_15pct          │
│    [Delay 30s]                               │
│              │ [Add Selected]                 │
│ 2. oddball_2k│                                │
│    [Button]  │ Transition Config              │
│              │ Type: [Delay      ▼]          │
│ 3. oddball_1k│ Duration: [30] sec            │
│    [None]    │                                │
├──────────────┴───────────────────────────────┤
│ [New] [Load] [Save] [Validate] [▲] [▼]      │
└──────────────────────────────────────────────┘
```

---

### App 3: SessionRunner

**Purpose:** Execute sessions with logging

**Launch:** `gui.session.SessionRunner()`

**Workflow:**

1. **Setup (SessionSetup dialog)**
   - Subject ID, session number, experimenter
   - Select sequence
   - Optional hardware notes
   - Show estimated duration

2. **Execution**
   - Real-time progress (block X/Y, trial X/Y)
   - Timer (elapsed/remaining)
   - Pause/Resume/Stop controls

3. **Transitions**
   - Display message
   - Countdown for delays
   - Wait for button press
   - Allow notes

4. **Completion**
   - Save all data
   - Summary report
   - Option for final notes

**UI Layout - Setup:**
```
┌──────────────────────────────────────────────┐
│ Session Setup                         [X]    │
├──────────────────────────────────────────────┤
│ * Subject ID: [S001_____]                    │
│ * Session #: [1___]                          │
│ * Experimenter: [John Doe__________]        │
│ * Sequence: [mmn_protocol_v1 ▼]             │
│   Blocks: 3                                   │
│   Est. duration: 27 min                       │
│ Notes: [Subject ready___________]           │
├──────────────────────────────────────────────┤
│                    [Cancel] [Start Session]  │
└──────────────────────────────────────────────┘
```

**UI Layout - Running:**
```
┌──────────────────────────────────────────────┐
│ Session: 20251015_S001_sess01        [X]    │
├──────────────────────────────────────────────┤
│ Status: RUNNING                               │
│ Block 2/3: oddball_2kHz_15pct                │
│ ████████████████░░░░ 65%                     │
│ Trial: 130/200                                │
│ ████████████████░░░░ 65%                     │
│ Elapsed: 12:34  Remaining: 6:15              │
├──────────────────────────────────────────────┤
│ [Pause] [Stop] [Add Note]                    │
└──────────────────────────────────────────────┘
```

---

## Logging System

### Overview

Maestro logs **stimulus presentation**, not results. One TTL pulse per trial; trial identity determined by matching pulse order with stimulus log.

### Architecture
```
SessionLogger
  ├── metadata.json
  ├── sequence.json (copy)
  ├── events.log
  ├── notes.txt
  └── BlockLogger (per block)
       ├── block_config.json
       └── stimuli.csv
```

### Hardware Setup
```
DAQ (NI USB-6361):
├── ao0 → Audio (mono)
└── ao1 → TTL (5V pulse to OpenEphys)

OpenEphys:
└── Digital Input → Receives TTL, timestamps
```

**TTL Specs:**
- Voltage: 5.0V
- Duration: 10ms
- Same pulse every trial

### Synchronization
```python
# Load OpenEphys TTL times
ttl_times = load_openephys_events()  # [0.0001, 1.5642, 2.8805, ...]

# Load Maestro log
log = pd.read_csv('stimuli.csv')

# Match by order
assert len(ttl_times) == len(log)

for i, ttl_time in enumerate(ttl_times):
    trial = log.iloc[i]
    # Now you know: TTL at ttl_time was trial of type trial.trial_type
```

---

## Implementation Plan

### Phase 1: Logging Infrastructure (Week 1)
**Priority: CRITICAL**

1. Create `+core/+logging/`
2. Implement `SessionLogger.m`
3. Implement `BlockLogger.m`
4. Modify `+engines/+audio_only/execute.m`:
   - Accept BlockLogger parameter
   - Generate TTL pulse (5V, 10ms)
   - Log each trial to CSV
5. Test with demo

**Deliverable:** Working logging that creates proper session directories

---

### Phase 2: Block Management (Week 2)

1. Create `+gui/+blocks/`
2. Utility functions:
   - `load_schema(builder_type)`
   - `load_block(block_file)`
   - `save_block(block_data, file)`
   - `validate_block(block_data, schema)`
3. Implement `BlockEditor.m` (schema-driven form)
4. Implement `BlockManager.m` (browser + editor)

**Deliverable:** GUI to create/manage blocks

---

### Phase 3: Sequence Composition (Week 3)

1. Create `+gui/+sequences/`
2. Utility functions:
   - `load_sequence(file)`
   - `save_sequence(data, file)`
   - `validate_sequence(data)`
3. Implement `TransitionEditor.m`
4. Implement `SequenceComposer.m`

**Deliverable:** GUI to compose sequences

---

### Phase 4: Session Execution (Week 4)

1. Create `+gui/+session/`
2. Implement `SessionSetup.m` (metadata entry)
3. Implement `SessionRunner.m`:
   - Progress monitoring
   - Transition handling
   - SessionLogger integration
4. Full workflow test

**Deliverable:** Complete session runner with logging

---

### Phase 5: Polish & Documentation (Week 5)

1. User documentation
2. Tutorial
3. Error handling
4. User testing

**Deliverable:** Production-ready system

---

## Testing Strategy

**Unit Tests:**
- Schema validation
- Block save/load
- Sequence save/load
- CSV logging

**Integration Tests:**
- Block → Sequence → Session workflow
- Logging completeness
- TTL verification (oscilloscope)

**User Tests:**
- Can naive user create block?
- Can naive user run session?
- Do TTLs match ephys recordings?

---

## Future Enhancements

**Short Term:**
- Session history browser
- Quick launch (recent sequences)
- Block/sequence templates

**Medium Term:**
- Batch runner (queue sessions)
- Real-time monitoring dashboard
- Data quality checks

**Long Term:**
- Remote monitoring
- Cloud backup
- BIDS export

---

## Summary

Maestro GUI provides:
- ✅ Block library management
- ✅ Sequence composition
- ✅ Session execution
- ✅ Comprehensive stimulus logging
- ✅ OpenEphys synchronization
- ✅ Simple, robust trigger system

**Design Philosophy:** File-based, modular, logging-first, researcher-friendly.
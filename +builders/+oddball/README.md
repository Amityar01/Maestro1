# Oddball Builder

Generates standard/deviant oddball paradigm trial sequences.

## Description

The oddball paradigm is one of the most widely used experimental designs in 
cognitive neuroscience. It consists of frequent "standard" stimuli interspersed 
with rare "deviant" stimuli. This builder creates trial sequences with 
configurable deviant probability and ordering constraints.

## Parameters

**Required:**
- **n_trials** (integer): Total number of trials (1-100000)
- **standard_stimulus** (stimulus_specification): Stimulus for standard trials
- **deviant_stimulus** (stimulus_specification): Stimulus for deviant trials
- **deviant_probability** (float): Probability of deviant trials (0-1)

**Optional:**
- **order_constraint** (enum): Ordering rule
  - `"random"`: Random ordering (default)
  - `"no_consecutive_deviants"`: Prevents back-to-back deviants
- **iti_min_sec** (float): Minimum inter-trial interval in seconds (default: 1.0)
- **iti_max_sec** (float): Maximum inter-trial interval in seconds (default: 2.0)

## Usage Example
```json
{
  "instance_id": "freq_oddball_session1",
  "builder_type": "oddball",
  "builder_version": "1.0.0",
  "parameters": {
    "n_trials": 200,
    "standard_stimulus": {
      "generator": "tone",
      "parameters": {"freq_hz": 1000, "dur_ms": 50, "level_db": 60}
    },
    "deviant_stimulus": {
      "generator": "tone",
      "parameters": {"freq_hz": 2000, "dur_ms": 50, "level_db": 60}
    },
    "deviant_probability": 0.15,
    "order_constraint": "no_consecutive_deviants",
    "iti_min_sec": 1.2,
    "iti_max_sec": 1.8
  }
}
```

## Output

Each trial contains:
- **trial_id**: Unique identifier
- **trial_num**: Sequential number (1-indexed)
- **trial_type**: "standard" or "deviant"
- **presentations**: Single stimulus presentation at onset 0 ms
- **iti_sec**: Inter-trial interval (jittered)
- **metadata**: 
  - `is_deviant`: Boolean flag
  - `trial_type`: Same as trial_type field

## Technical Details

**Trial generation:**
1. Randomly assign deviant status based on probability
2. Apply ordering constraints (if specified)
3. Generate jittered ITI values
4. Create trial structures with stimulus specifications

**no_consecutive_deviants constraint:**
- Shuffles trial order to eliminate consecutive deviants
- Attempts up to 1000 shuffles
- May fail if deviant_probability is too high (>0.5)

## Applications

- **Mismatch Negativity (MMN)** studies
- **P3a/P3b** experiments
- **Prediction error** paradigms
- **Attention** studies
- **Auditory/visual discrimination** tasks

## References

- Näätänen, R., et al. (2007). Mismatch negativity—A unique measure of sensory 
  processing. *International Journal of Neuroscience, 117*(1), 1-41.
- Squires, N. K., et al. (1975). Two varieties of long-latency positive waves 
  evoked by unpredictable auditory stimuli in man. *Electroencephalography and 
  Clinical Neurophysiology, 38*(4), 387-401.

## Testing
```matlab
cd +builders/+oddball
test_builder
```

## Version History

- **1.0.0** (2025-01-15): Initial implementation
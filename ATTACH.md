# Attach Tracking

This file tracks attach-specific behavior separately from the main implementation
plan.

## Current State

- `:CPlugAttach` exists
- `:CPlugGenerateAttach` exists
- Python has a generated server-attach template for `debugpy`
- C/C++ and Rust have generated LLDB process-attach templates using `${command:pickProcess}`
- Attach skips the normal cplug build/scaffold path
- Dedicated demo scripts now exist for:
  - Python server attach
  - C++ process attach

## Still Missing

- Explicit attach-type selection when a backend could reasonably support both process attach and server attach
- Better naming/UX around attach templates so users can see which configs are process attach vs server attach
- Attach-oriented docs that explain adapter-specific prerequisites more directly
- Better errors when an attach config exists but the target server/process is not actually available
- Keymap/story for a one-click attach flow that is simpler than typing `:CPlugAttach`
- Clearer distinction in generated config names between:
  - attach to process
  - attach to server
- Optional prompts or helpers for host/port entry in server-attach flows
- Optional prompts or helpers for process filtering in process-attach flows
- Review whether attach should get its own dedicated `launch.on_missing` policy instead of sharing the general one

## Python Attach

- [x] Generate a basic `debugpy` server-attach config
- [x] Add a real local demo path that bootstraps `debugpy` and walks through attach end-to-end
- [ ] Document exact `debugpy` startup commands for common cases
- [ ] Decide whether Python attach generation should support:
  - fixed `127.0.0.1:5678`
  - prompting for host/port
  - multiple named templates
- [ ] Add stronger checks/messages when `debugpy` is missing locally

## Native Attach

- [x] Generate LLDB process-attach configs for C/C++ and Rust
- [ ] Decide whether native server attach is in scope or whether native attach should stay process-first
- [ ] Test a real local C++ attach-to-process example end-to-end, not just config generation
- [ ] Confirm process attach UX across supported adapters, not just LLDB
- [ ] Decide whether `cppdbg`/`codelldb` need separate attach templates

## Demo / Test Follow-Ups

- [ ] Test the local C++ demo with a long-running process and verify `:CPlugAttach` plus process picker end-to-end
- [ ] Add a dedicated scripted regression for attach config selection when both launch and attach entries exist
- [ ] Add coverage for selected named attach configs that are not the first config in `launch.json`
- [x] Add a real Python attach demo run with `debugpy` installed
- [x] Decide whether `scripts/run-python-demo.sh` should optionally bootstrap or verify `debugpy`

## Product Questions

- Should `<leader>c` ever automatically pivot into attach when the selected config is `request = "attach"`, or should attach stay on its own explicit command?
- Should cplug expose separate commands such as:
  - `:CPlugAttachProcess`
  - `:CPlugAttachServer`
  or keep one `:CPlugAttach` entrypoint and drive everything through config selection?
- Should attach config generation append multiple attach templates by default, or keep generation minimal and singular?

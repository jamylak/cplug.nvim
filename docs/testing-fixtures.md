# Testing fixtures

Fixtures live under `tests/fixtures/projects/` and are always copied to a temp workspace before tests or demos mutate them.

## Coverage

| Fixture | Purpose |
| --- | --- |
| `cpp-empty` | Empty-or-nearly-empty C/C++ repo bootstrap path. |
| `c-source-only` | Source-only C project that should scaffold `CMakeLists.txt`, build, and generate an LLDB launch config. |
| `cpp-existing-cmake` | Existing CMake project that should build without scaffolding and generate `launch.json` only when missing. |
| `cpp-existing-vscode-launch` | Existing `.vscode/launch.json` that must be reused without overwrite. |
| `cpp-multi-launch` | Multiple compatible launch configs plus an attach config for selector and filtering tests. |
| `cpp-broken-vscode-launch` | Invalid `.vscode/launch.json` parse failure path. |
| `cpp-source-only-ambiguous` | Deliberately ambiguous multi-`main` source-only C++ tree that documents the missing target-selection behavior. |
| `rust-bin` | Existing Cargo binary project. |
| `rust-lib-only` | Cargo project with no binary target, used for the clear-error path. |
| `python-single-file` | Single-file Python launch resolution. |
| `python-package-pyproject` | Multi-file Python package where generated launch uses `${file}`. |
| `python-existing-venv` | Python project used to create a fake temp-local `.venv` during tests; no real virtualenv is committed. |
| `python-multi-launch` | Multiple Python launch configs plus an attach config for selector and filtering tests. |
| `mixed-cmake-python` | Mixed project where CMake detection should win over Python detection. |
| `attach-python-debugpy` | Python attach-config generation fixture using `127.0.0.1:5678`. |

## Automated tests

Run the full suite with:

```sh
make test
```

Fixture-focused coverage is currently exercised by:

```sh
sh scripts/test-fixture-launch-selection.sh
sh scripts/test-fixture-projects.sh
```

Tool-dependent integration sections skip cleanly when required binaries are unavailable, including `cmake`, a C/C++ compiler, `cargo`, and `python3`/`python`.

## Manual demo

List available fixtures with:

```sh
make list-fixtures
sh scripts/demo/fixture.sh --list
```

One-line quick start for any fixture:

```sh
make demo-fixture FIXTURE=python-multi-launch
```

Open any fixture in a copied temp workspace with:

```sh
make demo-fixture FIXTURE=cpp-existing-cmake
make demo-fixture FIXTURE=python-multi-launch
sh scripts/demo/fixture.sh python-multi-launch
```

Copy-paste commands for every fixture:

```sh
make demo-fixture FIXTURE=attach-python-debugpy
make demo-fixture FIXTURE=c-source-only
make demo-fixture FIXTURE=cpp-broken-vscode-launch
make demo-fixture FIXTURE=cpp-empty
make demo-fixture FIXTURE=cpp-existing-cmake
make demo-fixture FIXTURE=cpp-existing-vscode-launch
make demo-fixture FIXTURE=cpp-multi-launch
make demo-fixture FIXTURE=cpp-source-only-ambiguous
make demo-fixture FIXTURE=mixed-cmake-python
make demo-fixture FIXTURE=python-existing-venv
make demo-fixture FIXTURE=python-multi-launch
make demo-fixture FIXTURE=python-package-pyproject
make demo-fixture FIXTURE=python-single-file
make demo-fixture FIXTURE=rust-bin
make demo-fixture FIXTURE=rust-lib-only
```

The demo runner loads the local plugin, enables demo-friendly defaults, prints the main commands up front, and never mutates the committed fixture directory. Python fixture demos prepare a temp-local `.venv` with `debugpy` before opening Neovim, then set `python.bootstrap_debugpy = false` inside cplug so `<leader>c` can reach launch selection without doing environment setup inside the editor. `launch.select = "auto"` is preserved, so multi-launch fixtures open the launch picker on `<leader>c`.

To use a specific Python for fixture demos, set:

```sh
CPLUG_DEMO_PYTHON_COMMAND=/path/to/python make demo-fixture FIXTURE=python-multi-launch
```

To skip demo Python setup entirely, set `CPLUG_DEMO_PYTHON_BOOTSTRAP=never`.

If `nvim-dap`, `nvim-dap-ui`, or `nvim-nio` are not already installed in a standard local plugin path, the demo runner tries to fetch temporary copies automatically for the demo session. To force specific local paths instead, set `CPLUG_DEMO_DAP_DIR`, `CPLUG_DEMO_DAPUI_DIR`, and `CPLUG_DEMO_NIO_DIR`.

## Multi-launch fuzzy selection

`launch.select = "auto"` is the default:

- `0` compatible configs: return a clear error
- `1` compatible config: select it directly
- `>1` compatible configs: open the fuzzy picker

Other modes:

- `launch.select = "first"` preserves the old first-compatible behavior
- `launch.select = "picker"` forces the fuzzy picker when more than one compatible config exists
- `launch.configuration = "Name"` bypasses the picker and selects that exact config, with a clear error if the name is missing or incompatible with the current request type

Compatibility filtering is request-kind aware:

- compile/debug includes configs whose `request` is missing or `"launch"`
- attach includes only `"attach"`

## Ambiguous source-only C++ fixture

`cpp-source-only-ambiguous` intentionally contains multiple plausible entrypoints. It exists to catch regressions where cplug would blindly combine unrelated `.cpp` files into one executable target. The fixture is currently documented and asserted as a pending behavior case rather than treated as a fully solved target-selection system.

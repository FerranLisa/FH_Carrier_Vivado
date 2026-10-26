# v20 hardware regression

Uses the existing capture BIT/XSA that passed the user's three-frame DDR test.
No new FPGA build or platform update is required. The current Vitis launch
selects the correct BIT and its FSBL psu_init.c matches the generated source.

## Prepare Vitis

Stop debugging and save/close BringupTest.c in the editor. Run from PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Projects\VIVADO\FH_Carrier_Bringup_Linux\scripts\prepare_vitis_v20.ps1
```

The script checks the platform XSA and FSBL source, backs up source and launch
settings outside the application's source directory, installs v20, selects the
capture BIT, enables reset/programming, and builds with the existing Ninja build.
It does not program or start the board. A failed build is reported, not hidden.
Reload externally changed files if Vitis asks. Launch FH_Carrier_Test_app_hw_1.

Direct modification of the Vitis directory was denied by the execution sandbox;
the installed application remains unchanged until this script is run.

## Run

Choose **T** at the main menu (not the receiver diagnostics submenu).
Options 9 and D remain available. T performs:

- One baseline frame followed by twelve repeated captures, checking every pixel,
  guards, checksum, byte counts, emulator checker and accepted/rejected triggers.
- A 100 ms exposure with longer line blanking, compared with the RTL timing model.
- A trigger while disarmed and a trigger while busy; both must be rejected.
- A deliberately disabled DMA sink to force FIFO overflow; then drain, abort,
  reset DMA, check error flags clear, and verify two new full frames.
- Two frames per blanking value: 512, 384, 320, 288, 256, 192, 128, 16 cycles.
  Stop at the first overflow and report the lowest passing tested blanking.
- Three final baseline frames to verify recovery after the sweep.

The sweep can print a capture FAIL at the expected overflow boundary. Only FIFO
overflow (and the geometry flag caused by truncated FIFO input counting) may be
classified as a boundary. DMA errors, extra frames, pixel mismatches, timeouts
without overflow, or cleanup failures fail the regression. Recovery must pass.

Timing uses the A53 physical counter, from trigger submission to completion.
Expected microseconds = (exposure cycles + 3072*256 + 3071*blank cycles)/120.
Tolerance is 100 us early / 20 ms late, allowing software polling and DMA tail.
This is coarse frame timing validation, not direct exposure-pin or line-edge
measurement. Two sweep frames do not qualify a sustained maximum capture rate.

## Validation

v20 compiled and linked against the current Vitis standalone BSP and application
linker script with -Wall -Wextra -Werror. The resulting ELF is supplied alongside
the C file. No hardware regression has been run by the assistant. Capture hardware
is unchanged; existing physical-receiver framing and CDC limitations remain.

Send the complete T output, especially timing lines, the sweep boundary, and the
final recovery results. Full image verification can take appreciable time with
the application's existing unoptimized debug build.

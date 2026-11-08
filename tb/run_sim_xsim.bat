@echo off
rem ==============================================================================
rem Batch script to run Vivado xsim for KU5P-ETH testbench
rem ==============================================================================

set SCRIPT_DIR=%~dp0
pushd %SCRIPT_DIR%

call vivado -mode batch -source run_sim_xsim.tcl -nolog -nojournal

popd
pause


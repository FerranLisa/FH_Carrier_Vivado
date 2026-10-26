set root [file dirname [file normalize [info script]]]
cd $root
open_project FH_Carrier_Bringup.xpr
open_run synth_1
source insert_receiver_ila.tcl
write_checkpoint -force debug/insertion_check.dcp
puts "Probe connections checked. LTX UUIDs are generated after opt_design in the full build."
close_project

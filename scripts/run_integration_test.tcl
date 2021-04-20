#------------------------------------------------------------------------#
# Copyright (C) Barcelona Supercomputing Center                          #
#               Centro Nacional de Supercomputacion (BSC-CNS)            #
#                                                                        #
# All Rights Reserved.                                                   #
# This file is part of OmpSs@FPGA toolchain.                             #
#                                                                        #
# Unauthorized copying and/or distribution of this file,                 #
# via any medium is strictly prohibited.                                 #
# The intellectual and technical concepts contained herein are           #
# propietary to BSC-CNS and may be covered by Patents.                   #
#------------------------------------------------------------------------#

variable root_dir [lindex $argv 0]
variable num_confs [lindex $argv 1]
variable repeat [lindex $argv 2]
variable task_creation [lindex $argv 3]
variable max_commands [lindex $argv 4]
variable reproduce_conf_seed [lindex $argv 5]
variable reproduce_repeat_seed [lindex $argv 6]
variable hwruntime [lindex $argv 7]
variable prj_dir "$root_dir/test_projects"

proc gen_ran_range {min max} {
   return [expr round(rand()*($max-$min)) + $min]
}

create_project -force ompps_manager_tb $prj_dir/ompps_manager_tb
set_property simulator_language Verilog [current_project]
set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]

add_files $root_dir/src
add_files $root_dir/picos/src
add_files -norecurse $root_dir/test

set_property -name {xsim.compile.xvlog.more_options} -value [list \
  -d CREATOR_GRAPH_PATH_D="$prj_dir/nest_graph.txt" \
  -d TASKTYPE_FILE_PATH_D="$prj_dir/task_types.txt" \
  -d COE_PATH_D="$prj_dir/bitinfo.coe" \
] -objects [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property source_mgmt_mode DisplayOnly [current_project]
reorder_files -front [get_files hwruntime_tb.sv]
reorder_files -front [get_files OmpSsManagerConfig.sv]

for {set c 0} {$c < $num_confs} {incr c} {
   if {$reproduce_conf_seed == 0} {
      set seed [clock seconds]
   } else {
      set seed $reproduce_conf_seed
   }
   expr srand($seed)
   puts "\[RUN TEST\]: Conf $c"
   puts "\[RUN TEST\]: TCL Seed $seed"

   if {$task_creation} {
      set ncreators [gen_ran_range 1 8]
   } else {
      set ncreators 0
   }
   set naccs [gen_ran_range [expr $ncreators+1] 32]
   set ntypes [gen_ran_range [expr $ncreators+1] $naccs]

   set ninstances [lrepeat $ntypes 1]

   puts "\[RUN TEST\]: naccs $naccs ntypes $ntypes ncreators $ncreators"

   for {set i 0} {[expr $i < $naccs-$ntypes]} {incr i} {
      # Only give the remaining instances among non creator accelerators
      set idx [expr round(rand()*($ntypes-$ncreators-1)) + $ncreators]
      lset ninstances $idx [expr [lindex $ninstances $idx] + 1]
   }

   set graph_str ""
   if {$ncreators > 0} {
      set creator_idx_list [lrepeat $ncreators 0]
      for {set i 0} {$i < $ncreators} {incr i} {
         lset creator_idx_list $i $i
      }
      # Shuffle the list
      for {set i 0} {$i < $ncreators} {incr i} {
         set ridx [gen_ran_range 0 [expr $ncreators-1]]
         set tmp [lindex $creator_idx_list $i]
         lset creator_idx_list $i [lindex $creator_idx_list $ridx]
         lset creator_idx_list $ridx $tmp
      }

      set nest_graph [lrepeat $ncreators [lrepeat $ntypes 1]]
      puts $creator_idx_list
      for {set i 0} {$i < $ncreators} {incr i} {
         set i_m  [lindex $creator_idx_list $i]
         lset nest_graph $i $i 0
         for {set j 0} {$j < $i} {incr j} {
            set j_m [lindex $creator_idx_list $j]
            lset nest_graph $i_m $j_m 0
         }
      }
      puts $nest_graph
      foreach node $nest_graph {
         append graph_str "$node "
      }
   }

   set fd [open $prj_dir/nest_graph.txt w]
   puts $fd $graph_str
   close $fd

   set xtasks_str "type\t#ins\tname\tfreq\n"
   set task_types {}
   set max_int [expr int(pow(2, 32))-1]
   for {set i 0} {$i < $ntypes} {incr i} {
      # FIXME: We should check that the task_type never repeats
      set task_type [expr int(rand()*$max_int)]
      lappend task_types $task_type
      append xtasks_str [format "%019d\t%03d\t%32s%03d\n" $task_type [lindex $ninstances $i] "" 100]
   }
   puts -nonewline $xtasks_str

   set bitInfo_coe "memory_initialization_radix=16;\nmemory_initialization_vector=\n"
   append bitInfo_coe [format %08x 0]
   append bitInfo_coe "\nFFFFFFFF\n"
   append bitInfo_coe [format %08x $naccs]
   append bitInfo_coe "\nFFFFFFFF\n"

   for {set i 0} {$i < [string len $xtasks_str]} {incr i 4} {
      foreach char [split [string reverse [string range $xtasks_str $i [expr $i+3]]] ""] {
         append bitInfo_coe [format %02X [scan $char %c]]
      }
      append bitInfo_coe "\n"
   }
   append bitInfo_coe "FFFFFFFF\n;"

   set fd [open $prj_dir/bitinfo.coe w]
   puts $fd $bitInfo_coe
   close $fd

   set task_types_str ""
   for {set i 0} {$i < $ntypes} {incr i} {
      append task_types_str "[lindex $task_types $i] [lindex $ninstances $i]\n"
   }

   set fd [open $prj_dir/task_types.txt w]
   puts -nonewline $fd $task_types_str
   close $fd

   if {$ncreators == 0} {
      set NUM_CMDS $max_commands
      set MAX_NEW_TASKS 1
   } else {
      set NUM_CMDS 1
      set MAX_NEW_TASKS $max_commands
   }

   set_property generic [list \
      NUM_ACCS="$naccs" \
      NUM_CMDS="$NUM_CMDS" \
      MAX_NEW_TASKS="$MAX_NEW_TASKS" \
      NUM_CREATORS="$ncreators" \
      NUM_ACC_TYPES="$ntypes" \
      HWRUNTIME="$hwruntime" \
   ] [get_filesets sim_1]

   launch_simulation -step Compile
   launch_simulation -step Elaborate

   set seed 0
   for {set i 0} {$i < $repeat} {incr i} {
      if {$reproduce_repeat_seed == 0} {
         set seed_aux [clock seconds]
         if {$seed == $seed_aux} {
            after 1000
            set seed_aux [clock seconds]
         }
         set seed $seed_aux
      } else {
         set seed $reproduce_repeat_seed
      }

      puts "\[RUN TEST\]: iteration $i"
      puts "\[RUN TEST\]: Seed: $seed"

      set_property -name {xsim.simulate.xsim.more_options} -value [list -sv_seed $seed -testplusarg sim_seed=$seed] -objects [get_filesets sim_1]
      launch_simulation -step Simulate
      run all
      close_sim
   }
}


#-------------------------------------------------------------------------#
#  Copyright (C) 2020-2023 Barcelona Supercomputing Center                #
#                  Centro Nacional de Supercomputacion (BSC-CNS)          #
#                                                                         #
#  This file is part of OmpSs@FPGA toolchain.                             #
#                                                                         #
#  This program is free software: you can redistribute it and/or modify   #
#  it under the terms of the GNU General Public License as published      #
#  by the Free Software Foundation, either version 3 of the License,      #
#  or (at your option) any later version.                                 #
#                                                                         #
#  This program is distributed in the hope that it will be useful,        #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of         #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                   #
#  See the GNU General Public License for more details.                   #
#                                                                         #
#  You should have received a copy of the GNU General Public License      #
#  along with this program. If not, see <https://www.gnu.org/licenses/>.  #
#-------------------------------------------------------------------------#

variable root_dir [lindex $argv 0]
variable num_confs [lindex $argv 1]
variable repeat [lindex $argv 2]
variable task_creation [lindex $argv 3]
variable max_commands [lindex $argv 4]
variable reproduce_conf_seed [lindex $argv 5]
variable reproduce_repeat_seed [lindex $argv 6]
variable prj_dir "$root_dir/test_projects"

proc gen_ran_range {min max} {
   return [expr round(rand()*($max-$min)) + $min]
}

proc long_int_to_hex {bits num} {
   set result ""
   set div [expr int(ceil($bits/64.))]
   for {set i 0} {$i < $div} {incr i} {
      append result [format %016llX [expr ($num >> ($div-$i-1)*64) & 0xFFFFFFFFFFFFFFFF]]
   }
   set result [string trimleft $result 0]
   if {[string len $result] == 0} {
      set result 0
   }
   return $result
}

create_project -force ompps_manager_tb $prj_dir/ompps_manager_tb
set_property simulator_language Verilog [current_project]
set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]

add_files $root_dir/src
add_files $root_dir/picos/src
add_files -norecurse $root_dir/test

set_property verilog_define [list \
   CREATOR_GRAPH_PATH_D="$prj_dir/nest_graph.txt" \
   TASKTYPE_FILE_PATH_D="$prj_dir/task_types.txt" \
] [get_filesets sim_1]

update_compile_order -fileset sim_1

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

   set sched_count 0
   set sched_accid 0
   set sched_ttype 0
   set accid 0
   set max_int 4294967295
   set task_types [list]
   for {set i 0} {$i < $ntypes} {incr i} {
      # FIXME: We should check that the task_type never repeats
      set task_type [expr int(rand()*$max_int)]
      set ninst [lindex $ninstances $i]
      set sched_count [expr $sched_count | (($ninst-1) << $i*8)]
      set sched_accid [expr $sched_accid | ($accid << $i*8)]
      set sched_ttype [expr $sched_ttype | ($task_type << $i*32)]
      incr accid $ninst
      lappend task_types $task_type
      puts "Acc type $task_type\tnum instances $ninst"
   }
   puts "sched_count $sched_count sched_accid $sched_accid sched_ttype $sched_ttype"
   set count_bits [expr $ntypes*8]
   set accid_bits [expr $ntypes*8]
   set ttype_bits [expr $ntypes*32]
   set sched_count $count_bits\\'h[long_int_to_hex $count_bits $sched_count]
   set sched_accid $accid_bits\\'h[long_int_to_hex $accid_bits $sched_accid]
   set sched_ttype $ttype_bits\\'h[long_int_to_hex $ttype_bits $sched_ttype]
   puts "sched_count $sched_count sched_accid $sched_accid sched_ttype $sched_ttype"

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
      SCHED_COUNT="$sched_count" \
      SCHED_ACCID="$sched_accid" \
      SCHED_TTYPE="$sched_ttype" \
   ] [get_filesets sim_1]

   launch_simulation -step compile
   launch_simulation -step elaborate

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
      launch_simulation -step simulate
      run all
      close_sim
   }
}


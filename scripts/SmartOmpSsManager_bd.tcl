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

################################################################
# This is a generated script based on design: SmartOmpSsManager
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
   proc get_script_folder {} {
      set script_path [file normalize [info script]]
      set script_folder [file dirname $script_path]
      return $script_folder
   }
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2017.3
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   common::send_msg_id "BD_TCL-1002" "WARNING" "This script was generated using Vivado <$scripts_vivado_version> without IP versions in the create_bd_cell commands, but is now being run in <$current_vivado_version> of Vivado. There may have been major IP version changes between Vivado <$scripts_vivado_version> and <$current_vivado_version>, which could impact the parameter settings of the IPs."
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source SmartOmpSsManager_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xczu9eg-ffvc900-1-e-es2
}

# CHANGE DESIGN NAME HERE
variable design_name
set design_name SmartOmpSsManager

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_msg_id "BD_TCL-001" "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_msg_id "BD_TCL-002" "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES:
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_msg_id "BD_TCL-003" "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_msg_id "BD_TCL-004" "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_msg_id "BD_TCL-005" "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_msg_id "BD_TCL-114" "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\
      bsc:ompss:Command_In_wrapper:*\
      bsc:ompss:Command_Out_wrapper:*\
      bsc:ompss:Scheduler_wrapper:*\
      bsc:ompss:Spawn_In_wrapper:*\
      bsc:ompss:Taskwait_wrapper:*\
      bsc:ompss:Lock_wrapper:*\
      bsc:ompss:dual_port_32_bit_memory:*\
      xilinx.com:ip:util_vector_logic:*\
      "

   set list_ips_missing ""
   common::send_msg_id "BD_TCL-006" "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_msg_id "BD_TCL-115" "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

if { $bCheckIPsPassed != 1 } {
   common::send_msg_id "BD_TCL-1003" "WARNING" "Will not continue with creation of design due to the error(s) above."
   return 3
}

##################################################################
# DESIGN PROCs
##################################################################

proc create_inStream_Inter_tree_simple { stream_name max_accs } {

   set n_inter [expr int(ceil($max_accs/16.))]
   set prev_n_inter $max_accs
   set inter_level 0
   set inter_stride 1
   while { $n_inter < $prev_n_inter } {
      for {set i 0} {$i < $n_inter} {incr i} {

         set inter_name ${stream_name}_lvl${inter_level}_$i

         # Last interconnect may need less slaves
         if {$i == $n_inter-1 && [ expr $prev_n_inter%16 ] != 0} {
            set num_si [expr $prev_n_inter%16]
         } else {
            set num_si 16
         } 

         set inter [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect $inter_name ]
         set_property -dict [ list \
            CONFIG.ARB_ON_MAX_XFERS {0} \
            CONFIG.ARB_ON_TLAST {1} \
            CONFIG.M00_AXIS_BASETDEST {0x00000000} \
            CONFIG.M00_AXIS_HIGHTDEST {0x000000FF} \
            CONFIG.NUM_MI {1} \
            CONFIG.NUM_SI $num_si \
         ] $inter

         connect_bd_net [get_bd_ports aclk] [get_bd_pins $inter_name/ACLK]
         connect_bd_net [get_bd_ports interconnect_aresetn] [get_bd_pins $inter_name/ARESETN]
         for {set j 0} {$j < $num_si} {incr j} {
            set inf_num [ format "%02d" $j ]
            connect_bd_net [get_bd_ports peripheral_aresetn] [get_bd_pins $inter_name/S${inf_num}_AXIS_ARESETN]
            connect_bd_net [get_bd_ports aclk] [get_bd_pins $inter_name/S${inf_num}_AXIS_ACLK]
         }
         connect_bd_net [get_bd_ports peripheral_aresetn] [get_bd_pins $inter_name/M00_AXIS_ARESETN]
         connect_bd_net [get_bd_ports aclk] [get_bd_pins $inter_name/M00_AXIS_ACLK]

         if {$inter_level > 0} {
            for {set j 0} {$j < $num_si} {incr j} {
               set master_inter_num [ expr $i*16 + $j ]
               set master_inter_level [ expr $inter_level-1]
               set master_inter ${stream_name}_lvl${master_inter_level}_$master_inter_num
               set slave [ format "%02d" [ expr $j%16 ] ]
               connect_bd_intf_net -intf_net ${inter_name}_S${slave} [get_bd_intf_pins $master_inter/M00_AXIS] [get_bd_intf_pins $inter_name/S${slave}_AXIS]
            }
         }
      }

      set prev_n_inter $n_inter
      set n_inter [ expr int(ceil($n_inter/16.)) ]
      incr inter_level
   }

   return $inter_level
}

proc create_inStream_Inter_tree_perf { stream_name masters max_accs } {

   set n_inter [expr int(ceil($max_accs/16.))]
   set prev_n_inter $max_accs
   set inter_level 0
   set inter_stride 1

   #First level uses interconnects with more than one master if required
   for {set i 0} {$i < $n_inter} {incr i} {
      set inter_name ${stream_name}_lvl${inter_level}_$i

      # Last interconnect may need less slaves
      if {$i == $n_inter-1 && [ expr $prev_n_inter%16 ] != 0} {
         set num_si [expr $prev_n_inter%16]
      } else {
         set num_si 16
      }

      set inter [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect $inter_name ]
      set_property -dict [ list \
         CONFIG.ARB_ON_MAX_XFERS {0} \
         CONFIG.ARB_ON_TLAST {1} \
         CONFIG.NUM_MI $masters \
         CONFIG.NUM_SI $num_si \
      ] $inter

      connect_bd_net [get_bd_ports aclk] [get_bd_pins $inter_name/ACLK]
      connect_bd_net [get_bd_ports interconnect_aresetn] [get_bd_pins $inter_name/ARESETN]
      for {set j 0} {$j < $num_si} {incr j} {
         set inf_num [ format "%02d" $j ]
         connect_bd_net [get_bd_ports peripheral_aresetn] [get_bd_pins $inter_name/S${inf_num}_AXIS_ARESETN]
         connect_bd_net [get_bd_ports aclk] [get_bd_pins $inter_name/S${inf_num}_AXIS_ACLK]
      }
      for {set j 0} {$j < $masters} {incr j} {
         set inf_num [ format "%02d" $j ]
         connect_bd_net [get_bd_ports peripheral_aresetn] [get_bd_pins $inter_name/M${inf_num}_AXIS_ARESETN]
         connect_bd_net [get_bd_ports aclk] [get_bd_pins $inter_name/M${inf_num}_AXIS_ACLK]
      }
   }

   set prev_n_inter $n_inter
   set n_inter [ expr int(ceil($n_inter/16.)) ]
   incr inter_level

   while { $n_inter < $prev_n_inter } {
      for {set m 0} {$m < $masters} {incr m} {
         for {set i 0} {$i < $n_inter} {incr i} {

            set inter_name ${stream_name}_lvl${inter_level}_m${m}_$i

            # Last interconnect may need less slaves
            if {$i == $n_inter-1 && [ expr $prev_n_inter%16 ] != 0} {
               set num_si [expr $prev_n_inter%16]
            } else {
               set num_si 16
            }

            set inter [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect $inter_name ]
            set_property -dict [ list \
               CONFIG.ARB_ON_MAX_XFERS {0} \
               CONFIG.ARB_ON_TLAST {1} \
               CONFIG.M00_AXIS_BASETDEST {0x00000000} \
               CONFIG.M00_AXIS_HIGHTDEST {0x000000FF} \
               CONFIG.NUM_MI {1} \
               CONFIG.NUM_SI $num_si \
            ] $inter

            connect_bd_net [get_bd_ports aclk] [get_bd_pins $inter_name/ACLK]
            connect_bd_net [get_bd_ports interconnect_aresetn] [get_bd_pins $inter_name/ARESETN]
            for {set j 0} {$j < $num_si} {incr j} {
               set inf_num [ format "%02d" $j ]
               connect_bd_net [get_bd_ports peripheral_aresetn] [get_bd_pins $inter_name/S${inf_num}_AXIS_ARESETN]
               connect_bd_net [get_bd_ports aclk] [get_bd_pins $inter_name/S${inf_num}_AXIS_ACLK]
            }
            connect_bd_net [get_bd_ports peripheral_aresetn] [get_bd_pins $inter_name/M00_AXIS_ARESETN]
            connect_bd_net [get_bd_ports aclk] [get_bd_pins $inter_name/M00_AXIS_ACLK]

            for {set j 0} {$j < $num_si} {incr j} {
               set master_inter_num [ expr $i*16 + $j ]
               set master_inter_level [ expr $inter_level-1]
               if {$inter_level == 1} {
                  set master_inf [ format "%02d" $m ]
                  set master_inter ${stream_name}_lvl${master_inter_level}_$master_inter_num
               } else {
                  set master_inf 00
                  set master_inter ${stream_name}_lvl${master_inter_level}_m${m}_$master_inter_num
               }
               set slave [ format "%02d" [ expr $j%16 ] ]
               connect_bd_intf_net -intf_net ${inter_name}_S${slave} [get_bd_intf_pins $master_inter/M${master_inf}_AXIS] [get_bd_intf_pins $inter_name/S${slave}_AXIS]
            }
         }
      }

      set prev_n_inter $n_inter
      set n_inter [ expr int(ceil($n_inter/16.)) ]
      incr inter_level
   }

   return $inter_level
}

proc create_outStream_Inter_tree { stream_name max_accs } {

   set n_inter [expr int(ceil($max_accs/16.))]
   set prev_n_inter $max_accs
   set inter_level 0
   set stride 1
   while { $n_inter < $prev_n_inter } {

      for {set i 0} {$i < $n_inter} {incr i} {

         set inter_name ${stream_name}_lvl${inter_level}_$i

         # Last interconnect may need less masters
         if {$i == $n_inter-1 && [ expr $prev_n_inter%16 ] != 0} {
            set num_mi [ expr $prev_n_inter%16 ]
         } else {
            set num_mi 16
         }

         set inter [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect $inter_name ]
         set inter_conf [ list \
            CONFIG.ARB_ON_MAX_XFERS {1} \
            CONFIG.ARB_ON_TLAST {0} \
            CONFIG.NUM_MI $num_mi \
            CONFIG.NUM_SI {4} \
         ]

         for {set j 0} {$j < $num_mi} {incr j} {
            set master_num [ format "%02d" $j ]
            set base_dest [ format "32\'d%d" [ expr $i*$stride*16 + $j*$stride ] ]
            set high_dest [ format "32\'d%d" [ expr $i*$stride*16 + ($j+1)*$stride - 1 ] ]
            lappend inter_conf CONFIG.M${master_num}_AXIS_BASETDEST $base_dest CONFIG.M${master_num}_AXIS_HIGHTDEST $high_dest
         }

         set_property -dict $inter_conf $inter

         connect_bd_net [get_bd_ports aclk] [get_bd_pins $inter_name/ACLK]
         connect_bd_net [get_bd_ports interconnect_aresetn] [get_bd_pins $inter_name/ARESETN]
         for {set j 0} { $j < $num_mi} {incr j} {
            set inf_num [ format "%02d" $j ]
            connect_bd_net [get_bd_ports peripheral_aresetn] [get_bd_pins $inter_name/M${inf_num}_AXIS_ARESETN]
            connect_bd_net [get_bd_ports aclk] [get_bd_pins $inter_name/M${inf_num}_AXIS_ACLK]
         }
         connect_bd_net [get_bd_ports peripheral_aresetn] [get_bd_pins $inter_name/S00_AXIS_ARESETN]
         connect_bd_net [get_bd_ports aclk] [get_bd_pins $inter_name/S00_AXIS_ACLK]

         if {$inter_level > 0} {
            for {set j 0} {$j < $num_mi} {incr j} {
               set slave_inter_num [ expr $i*16+$j ]
               set slave_inter_level [ expr $inter_level-1]
               set slave_inter ${stream_name}_lvl${slave_inter_level}_$slave_inter_num
               set master [ format "%02d" $j ]
               connect_bd_intf_net -intf_net ${inter_name}_M$master [get_bd_intf_pins $slave_inter/S00_AXIS] [get_bd_intf_pins $inter_name/M${master}_AXIS]
            }
         }
      }

      set prev_n_inter $n_inter
      set n_inter [ expr int(ceil($n_inter/16.)) ]
      set stride [ expr $stride*16 ]
      incr inter_level
   }

   return $inter_level
}

# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell max_accs } {

   variable script_folder
   variable design_name

   if { $parentCell eq "" } {
      set parentCell [get_bd_cells /]
   }

   # Get object for parentCell
   set parentObj [get_bd_cells $parentCell]
   if { $parentObj == "" } {
      catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
      return
   }

   # Make sure parentObj is hier blk
   set parentType [get_property TYPE $parentObj]
   if { $parentType ne "hier" } {
      catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
      return
   }

   # Save current instance; Restore later
   set oldCurInst [current_bd_instance .]

   # Set parent object as current
   current_bd_instance $parentObj

   # Create interface ports
   set bitInfo [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:bram_rtl:1.0 bitInfo ]
      set_property -dict [ list \
      CONFIG.MASTER_TYPE {BRAM_CTRL} \
      CONFIG.READ_WRITE_MODE {READ_ONLY} \
   ] $bitInfo
   set cmdInQueue [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:bram_rtl:1.0 cmdInQueue ]
      set_property -dict [ list \
      CONFIG.MASTER_TYPE {BRAM_CTRL} \
   ] $cmdInQueue
   set cmdOutQueue [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:bram_rtl:1.0 cmdOutQueue ]
      set_property -dict [ list \
      CONFIG.MASTER_TYPE {BRAM_CTRL} \
   ] $cmdOutQueue

   for {set i 0} {$i < $max_accs} {incr i} {
      set inStream_var [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_$i ]
      set_property -dict [ list \
         CONFIG.HAS_TKEEP {0} \
         CONFIG.HAS_TLAST {1} \
         CONFIG.HAS_TREADY {1} \
         CONFIG.HAS_TSTRB {0} \
         CONFIG.LAYERED_METADATA {undef} \
         CONFIG.TDATA_NUM_BYTES {8} \
         CONFIG.TDEST_WIDTH {5} \
         CONFIG.TID_WIDTH [ expr int(ceil(log($max_accs)/log(2))) ] \
         CONFIG.TUSER_WIDTH {0} \
      ] $inStream_var

      create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_$i
   }

   set spawnInQueue [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:bram_rtl:1.0 spawnInQueue ]
   set_property -dict [ list \
      CONFIG.MASTER_TYPE {BRAM_CTRL} \
   ] $spawnInQueue
   set spawnOutQueue [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:bram_rtl:1.0 spawnOutQueue ]
   set_property -dict [ list \
      CONFIG.MASTER_TYPE {BRAM_CTRL} \
   ] $spawnOutQueue

   # Create ports
   set aclk [ create_bd_port -dir I -type clk aclk ]
   set_property -dict [ list \
      CONFIG.ASSOCIATED_RESET {interconnect_aresetn:peripheral_aresetn:ps_rst} \
   ] $aclk
   set interconnect_aresetn [ create_bd_port -dir I -type rst interconnect_aresetn ]
   set managed_aresetn [ create_bd_port -dir O -from 0 -to 0 managed_aresetn ]
   set peripheral_aresetn [ create_bd_port -dir I -type rst peripheral_aresetn ]
   set ps_rst [ create_bd_port -dir I -type rst ps_rst ]
   set_property -dict [ list \
      CONFIG.POLARITY {ACTIVE_HIGH} \
   ] $ps_rst

   # Create instance: Command_In, and set properties
   set Command_In [ create_bd_cell -type ip -vlnv bsc:ompss:Command_In_wrapper Command_In ]
   set_property -dict [ list \
      CONFIG.MAX_ACCS $max_accs
   ] $Command_In

   # Create instance: Command_Out, and set properties
   set Command_Out [ create_bd_cell -type ip -vlnv bsc:ompss:Command_Out_wrapper Command_Out ]
   set_property -dict [ list \
      CONFIG.MAX_ACCS $max_accs
   ] $Command_Out

   # Create instance: Scheduler, and set properties
   set Scheduler [ create_bd_cell -type ip -vlnv bsc:ompss:Scheduler_wrapper Scheduler ]
   set_property -dict [ list \
      CONFIG.MAX_ACCS $max_accs
   ] $Scheduler

   # Create instance: Spawn_In, and set properties
   set Spawn_In [ create_bd_cell -type ip -vlnv bsc:ompss:Spawn_In_wrapper Spawn_In ]

   # Create instance: Taskwait, and set properties
   set Taskwait [ create_bd_cell -type ip -vlnv bsc:ompss:Taskwait_wrapper Taskwait ]
   set_property -dict [ list \
      CONFIG.MAX_ACCS $max_accs 
   ] $Taskwait

   # Create instance: Lock, and set properties
   set Lock [ create_bd_cell -type ip -vlnv bsc:ompss:Lock_wrapper Lock ]
   set_property -dict [ list \
      CONFIG.MAX_ACCS $max_accs 
   ] $Lock

   # Create instance: Taskwait_inStream_Inter, and set properties
   set Taskwait_inStream_Inter [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect Taskwait_inStream_Inter ]
   set_property -dict [ list \
      CONFIG.ARB_ON_MAX_XFERS {0} \
      CONFIG.ARB_ON_TLAST {1} \
      CONFIG.M00_AXIS_BASETDEST {0x00000000} \
      CONFIG.M00_AXIS_HIGHTDEST {0x000000FF} \
      CONFIG.NUM_MI {1} \
      CONFIG.NUM_SI {3} \
   ] $Taskwait_inStream_Inter

   create_inStream_Inter_tree_perf inStream_Inter 4 $max_accs
   set max_level [expr [create_outStream_Inter_tree outStream_Inter $max_accs] - 1]

   if {$max_level == 0} {
      set inStream_Inter_M0 inStream_Inter_lvl0_0/M00_AXIS
      set inStream_Inter_M1 inStream_Inter_lvl0_0/M01_AXIS
      set inStream_Inter_M2 inStream_Inter_lvl0_0/M02_AXIS
      set inStream_Inter_M3 inStream_Inter_lvl0_0/M03_AXIS
   } else {
      set inStream_Inter_M0 inStream_Inter_lvl${max_level}_m0_0/M00_AXIS
      set inStream_Inter_M1 inStream_Inter_lvl${max_level}_m1_0/M00_AXIS
      set inStream_Inter_M2 inStream_Inter_lvl${max_level}_m2_0/M00_AXIS
      set inStream_Inter_M3 inStream_Inter_lvl${max_level}_m3_0/M00_AXIS
   }

   set n_inter [expr int(ceil($max_accs/16.))]
   for {set i 0} {$i < $n_inter} {incr i} {
      set_property -dict [ list \
         CONFIG.M00_AXIS_BASETDEST {0x00000011} \
         CONFIG.M00_AXIS_HIGHTDEST {0x00000011} \
         CONFIG.M01_AXIS_BASETDEST {0x00000012} \
         CONFIG.M01_AXIS_HIGHTDEST {0x00000013} \
         CONFIG.M02_AXIS_BASETDEST {0x00000014} \
         CONFIG.M02_AXIS_HIGHTDEST {0x00000014} \
         CONFIG.M03_AXIS_BASETDEST {0x00000015} \
         CONFIG.M03_AXIS_HIGHTDEST {0x00000015} \
      ] [ get_bd_cell inStream_Inter_lvl0_$i ]
   }

   set outStream_Inter outStream_Inter_lvl${max_level}_0

   # Create instance: intCmdInQueue bram and set properties
   set intCmdInQueue [ create_bd_cell -type ip -vlnv bsc:ompss:dual_port_memory intCmdInQueue ]
   set_property -dict [ list \
      CONFIG.SIZE [expr $max_accs*64 ] \
      CONFIG.WIDTH {64} \
      CONFIG.EN_RST_A {false} \
      CONFIG.EN_RST_B {false} \
      CONFIG.SINGLE_PORT {false}\
   ] $intCmdInQueue

   # Create instance: rst_AND, and set properties
   set rst_AND [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic rst_AND ]
   set_property -dict [ list \
      CONFIG.C_SIZE {1} \
   ] $rst_AND

   # Create instance: rst_NOT, and set properties
   set rst_NOT [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic rst_NOT ]
   set_property -dict [ list \
      CONFIG.C_OPERATION {not} \
      CONFIG.C_SIZE {1} \
      CONFIG.LOGO_FILE {data/sym_notgate.png} \
   ] $rst_NOT

   # Create instance: TW info bram and set properties
   set tw_info [ create_bd_cell -type ip -vlnv bsc:ompss:dual_port_memory tw_info ]
   set_property -dict [ list \
      CONFIG.SIZE {16} \
      CONFIG.WIDTH {112} \
      CONFIG.EN_RST_A {false} \
      CONFIG.EN_RST_B {false} \
      CONFIG.SINGLE_PORT {true} \
   ] $tw_info

   # Create interface connections
   for {set i 0} {$i < $max_accs} {incr i} {
      set inter [ expr $i/16 ]
      set inf_num [ format "%02d" [ expr $i%16 ] ]
      connect_bd_intf_net -intf_net inStream_Inter_lvl0_${inter}_${inf_num} [get_bd_intf_ports inStream_$i] [get_bd_intf_pins inStream_Inter_lvl0_$inter/S${inf_num}_AXIS]
      connect_bd_intf_net -intf_net outStream_Inter_lvl0_${inter}_${inf_num} [get_bd_intf_ports outStream_$i] [get_bd_intf_pins outStream_Inter_lvl0_$inter/M${inf_num}_AXIS]
   }
   connect_bd_net [get_bd_pins Command_In/acc_avail_wr] [get_bd_pins Command_Out/acc_avail_wr]
   connect_bd_net [get_bd_pins Command_In/sched_queue_nempty_address] [get_bd_pins Scheduler/sched_queue_nempty_address]
   connect_bd_net [get_bd_pins Scheduler/sched_queue_nempty_write] [get_bd_pins Command_In/sched_queue_nempty_write]
   connect_bd_net [get_bd_pins Command_In/acc_avail_wr_address] [get_bd_pins Command_Out/acc_avail_wr_address]
   connect_bd_intf_net -intf_net Command_Out_outStream [get_bd_intf_pins Command_Out/outStream] [get_bd_intf_pins Taskwait_inStream_Inter/S01_AXIS]
   connect_bd_intf_net -intf_net Command_In_cmdInQueue [get_bd_intf_ports cmdInQueue] [get_bd_intf_pins Command_In/cmdInQueue]
   connect_bd_intf_net -intf_net Command_In_intCmdInQueue [get_bd_intf_pins intCmdInQueue/portA] [get_bd_intf_pins Command_In/intCmdInQueue]
   connect_bd_intf_net -intf_net Command_In_outStream [get_bd_intf_pins Command_In/outStream] [get_bd_intf_pins $outStream_Inter/S00_AXIS]
   connect_bd_intf_net -intf_net Command_Out_cmdOutQueue [get_bd_intf_ports cmdOutQueue] [get_bd_intf_pins Command_Out/cmdOutQueue]
   connect_bd_intf_net -intf_net Spawn_In_SpawnInQueue [get_bd_intf_ports spawnInQueue] [get_bd_intf_pins Spawn_In/SpawnInQueue]
   connect_bd_intf_net -intf_net Spawn_In_outStream [get_bd_intf_pins Spawn_In/outStream] [get_bd_intf_pins Taskwait_inStream_Inter/S02_AXIS]
   connect_bd_intf_net -intf_net S00_AXIS_3 [get_bd_intf_pins Taskwait_inStream_Inter/S00_AXIS] [get_bd_intf_pins $inStream_Inter_M2]
   connect_bd_intf_net -intf_net inStream_Inter_M03_AXIS [get_bd_intf_pins Lock/inStream] [get_bd_intf_pins $inStream_Inter_M3]
   connect_bd_intf_net -intf_net Scheduler_inStream [get_bd_intf_pins $inStream_Inter_M1] [get_bd_intf_pins Scheduler/inStream]
   connect_bd_intf_net -intf_net Scheduler_bitInfo [get_bd_intf_ports bitInfo] [get_bd_intf_pins Scheduler/bitInfo]
   connect_bd_intf_net -intf_net Scheduler_intCmdInQueue [get_bd_intf_pins Scheduler/intCmdInQueue] [get_bd_intf_pins intCmdInQueue/portB]
   connect_bd_intf_net -intf_net Scheduler_outStream [get_bd_intf_pins Scheduler/outStream] [get_bd_intf_pins $outStream_Inter/S02_AXIS]
   connect_bd_intf_net -intf_net Scheduler_spawnOutQueue [get_bd_intf_ports spawnOutQueue] [get_bd_intf_pins Scheduler/spawnOutQueue]
   connect_bd_intf_net -intf_net Taskwait_outStream [get_bd_intf_pins Taskwait/outStream] [get_bd_intf_pins $outStream_Inter/S01_AXIS]
   connect_bd_intf_net -intf_net Taskwait_twInfo [get_bd_intf_pins Taskwait/twInfo] [get_bd_intf_pins tw_info/portA]
   connect_bd_intf_net -intf_net Lock_outStream [get_bd_intf_pins Lock/outStream] [get_bd_intf_pins $outStream_Inter/S03_AXIS]
   connect_bd_intf_net -intf_net Taskwait_inStream [get_bd_intf_pins Taskwait/inStream] [get_bd_intf_pins Taskwait_inStream_Inter/M00_AXIS]
   connect_bd_intf_net -intf_net inStream_Inter_M00_AXIS [get_bd_intf_pins Command_Out/inStream] [get_bd_intf_pins $inStream_Inter_M0]

   # Create port connections
   connect_bd_net -net aclk_1 [get_bd_ports aclk] [get_bd_pins Command_In/clk] [get_bd_pins Command_Out/clk] [get_bd_pins Scheduler/clk] [get_bd_pins Spawn_In/clk] [get_bd_pins Taskwait/clk] [get_bd_pins Taskwait_inStream_Inter/ACLK] [get_bd_pins Taskwait_inStream_Inter/M00_AXIS_ACLK] [get_bd_pins Lock/clk] [get_bd_pins Taskwait_inStream_Inter/S00_AXIS_ACLK] [get_bd_pins Taskwait_inStream_Inter/S01_AXIS_ACLK] [get_bd_pins Taskwait_inStream_Inter/S02_AXIS_ACLK] [get_bd_pins $outStream_Inter/S01_AXIS_ACLK] [get_bd_pins $outStream_Inter/S02_AXIS_ACLK] [get_bd_pins $outStream_Inter/S03_AXIS_ACLK]
   connect_bd_net -net interconnect_aresetn_1 [get_bd_ports interconnect_aresetn] [get_bd_pins Taskwait_inStream_Inter/ARESETN]
   connect_bd_net -net peripheral_aresetn_1 [get_bd_ports peripheral_aresetn] [get_bd_pins Taskwait_inStream_Inter/M00_AXIS_ARESETN] [get_bd_pins Taskwait_inStream_Inter/S00_AXIS_ARESETN] [get_bd_pins Taskwait_inStream_Inter/S01_AXIS_ARESETN] [get_bd_pins Taskwait_inStream_Inter/S02_AXIS_ARESETN] [get_bd_pins $outStream_Inter/S01_AXIS_ARESETN] [get_bd_pins $outStream_Inter/S02_AXIS_ARESETN] [get_bd_pins $outStream_Inter/S03_AXIS_ARESETN] [get_bd_pins rst_AND/Op1]
   connect_bd_net -net ps_rst_1 [get_bd_ports ps_rst] [get_bd_pins rst_NOT/Op1]
   connect_bd_net -net rst_AND_Res [get_bd_ports managed_aresetn] [get_bd_pins Command_In/rstn] [get_bd_pins Command_Out/rstn] [get_bd_pins Scheduler/rstn] [get_bd_pins Spawn_In/rstn] [get_bd_pins Taskwait/rstn] [get_bd_pins rst_AND/Res] [get_bd_pins Lock/rstn]
   connect_bd_net -net rst_NOT_Res [get_bd_pins rst_AND/Op2] [get_bd_pins rst_NOT/Res]

   # Restore current instance
   current_bd_instance $oldCurInst

   save_bd_design
}
# End of create_root_design()

##################################################################
# MAIN FLOW
##################################################################

create_root_design "" $max_accs

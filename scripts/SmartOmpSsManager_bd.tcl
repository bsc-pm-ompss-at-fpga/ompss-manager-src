
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



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

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
   ] $bitInfo
  set cmdInQueue [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:bram_rtl:1.0 cmdInQueue ]
  set_property -dict [ list \
   CONFIG.MASTER_TYPE {BRAM_CTRL} \
   ] $cmdInQueue
  set cmdOutQueue [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:bram_rtl:1.0 cmdOutQueue ]
  set_property -dict [ list \
   CONFIG.MASTER_TYPE {BRAM_CTRL} \
   ] $cmdOutQueue
  set inStream_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_0 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_0
  set inStream_1 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_1 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_1
  set inStream_2 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_2 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_2
  set inStream_3 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_3 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_3
  set inStream_4 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_4 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_4
  set inStream_5 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_5 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_5
  set inStream_6 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_6 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_6
  set inStream_7 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_7 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_7
  set inStream_8 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_8 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_8
  set inStream_9 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_9 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_9
  set inStream_10 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_10 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_10
  set inStream_11 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_11 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_11
  set inStream_12 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_12 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_12
  set inStream_13 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_13 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_13
  set inStream_14 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_14 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_14
  set inStream_15 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 inStream_15 ]
  set_property -dict [ list \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {1} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {5} \
   CONFIG.TID_WIDTH {8} \
   CONFIG.TUSER_WIDTH {0} \
   ] $inStream_15
  set outStream_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_0 ]
  set outStream_1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_1 ]
  set outStream_2 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_2 ]
  set outStream_3 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_3 ]
  set outStream_4 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_4 ]
  set outStream_5 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_5 ]
  set outStream_6 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_6 ]
  set outStream_7 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_7 ]
  set outStream_8 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_8 ]
  set outStream_9 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_9 ]
  set outStream_10 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_10 ]
  set outStream_11 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_11 ]
  set outStream_12 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_12 ]
  set outStream_13 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_13 ]
  set outStream_14 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_14 ]
  set outStream_15 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 outStream_15 ]
  set spawnInQueue [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:bram_rtl:1.0 spawnInQueue ]
  set_property -dict [ list \
   CONFIG.MASTER_TYPE {BRAM_CTRL} \
   ] $spawnInQueue
  set spawnOutQueue [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:bram_rtl:1.0 spawnOutQueue ]
  set_property -dict [ list \
   CONFIG.MASTER_TYPE {BRAM_CTRL} \
   ] $spawnOutQueue
  set twOutStream_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_0 ]
  set twOutStream_1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_1 ]
  set twOutStream_2 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_2 ]
  set twOutStream_3 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_3 ]
  set twOutStream_4 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_4 ]
  set twOutStream_5 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_5 ]
  set twOutStream_6 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_6 ]
  set twOutStream_7 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_7 ]
  set twOutStream_8 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_8 ]
  set twOutStream_9 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_9 ]
  set twOutStream_10 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_10 ]
  set twOutStream_11 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_11 ]
  set twOutStream_12 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_12 ]
  set twOutStream_13 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_13 ]
  set twOutStream_14 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_14 ]
  set twOutStream_15 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 twOutStream_15 ]

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

  #  Create instance: TW info bram and set properties
  set tw_info [ create_bd_cell -type ip -vlnv bsc:ompss:dual_port_memory tw_info ]
  set_property -dict [ list \
   CONFIG.SIZE {16} \
   CONFIG.WIDTH {112} \
   CONFIG.EN_RST_A {false} \
   CONFIG.EN_RST_B {false} \
   CONFIG.SINGLE_PORT {true} \
 ] $tw_info

  #  Create instance: intCmdInQueue bram and set properties
  set intCmdInQueue [ create_bd_cell -type ip -vlnv bsc:ompss:dual_port_memory intCmdInQueue ]
  set_property -dict [ list \
   CONFIG.SIZE {1024} \
   CONFIG.WIDTH {64} \
   CONFIG.EN_RST_A {false} \
   CONFIG.EN_RST_B {false} \
   CONFIG.SINGLE_PORT {false}\
  ] $intCmdInQueue

  # Create instance: Command_In, and set properties
  set Command_In [ create_bd_cell -type ip -vlnv bsc:ompss:Command_In_wrapper Command_In ]

  # Create instance: Command_Out, and set properties
  set Command_Out [ create_bd_cell -type ip -vlnv bsc:ompss:Command_Out_wrapper Command_Out ]

  # Create instance: Scheduler, and set properties
  set Scheduler [ create_bd_cell -type ip -vlnv bsc:ompss:Scheduler_wrapper Scheduler ]

  # Create instance: Spawn_In, and set properties
  set Spawn_In [ create_bd_cell -type ip -vlnv bsc:ompss:Spawn_In_wrapper Spawn_In ]

  # Create instance: Taskwait, and set properties
  set Taskwait [ create_bd_cell -type ip -vlnv bsc:ompss:Taskwait_wrapper Taskwait ]

  # Create instance: ext_inStream_Taskwait_Inter, and set properties
  set ext_inStream_Taskwait_Inter [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect ext_inStream_Taskwait_Inter ]
  set_property -dict [ list \
   CONFIG.ARB_ON_MAX_XFERS {0} \
   CONFIG.ARB_ON_TLAST {1} \
   CONFIG.M00_AXIS_BASETDEST {0x00000000} \
   CONFIG.M00_AXIS_HIGHTDEST {0x000000FF} \
   CONFIG.NUM_MI {1} \
   CONFIG.NUM_SI {3} \
 ] $ext_inStream_Taskwait_Inter

  # Create instance: inStream_Inter, and set properties
  set inStream_Inter [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect inStream_Inter ]
  set_property -dict [ list \
   CONFIG.ARB_ON_MAX_XFERS {0} \
   CONFIG.ARB_ON_TLAST {1} \
   CONFIG.M00_AXIS_BASETDEST {0x00000011} \
   CONFIG.M00_AXIS_HIGHTDEST {0x00000011} \
   CONFIG.M01_AXIS_BASETDEST {0x00000012} \
   CONFIG.M01_AXIS_HIGHTDEST {0x00000013} \
   CONFIG.M02_AXIS_BASETDEST {0x00000014} \
   CONFIG.M02_AXIS_HIGHTDEST {0x00000014} \
   CONFIG.NUM_MI {3} \
   CONFIG.NUM_SI {16} \
 ] $inStream_Inter

  # Create instance: outStream_Inter, and set properties
  set outStream_Inter [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect outStream_Inter ]
  set_property -dict [ list \
   CONFIG.ARB_ON_MAX_XFERS {1} \
   CONFIG.ARB_ON_TLAST {1} \
   CONFIG.NUM_MI {16} \
   CONFIG.NUM_SI {1} \
 ] $outStream_Inter

  # Create instance: outStream_Inter_Taskwait_Task_Manager, and set properties
  set outStream_Inter_Taskwait_Task_Manager [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect outStream_Inter_Taskwait_Task_Manager ]
  set_property -dict [ list \
   CONFIG.ARB_ON_MAX_XFERS {1} \
   CONFIG.ARB_ON_TLAST {1} \
   CONFIG.NUM_MI {16} \
   CONFIG.NUM_SI {2} \
 ] $outStream_Inter_Taskwait_Task_Manager

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

  # Create interface connections
  connect_bd_net [get_bd_pins Command_In/acc_avail_wr] [get_bd_pins Command_Out/acc_avail_wr]
  connect_bd_net [get_bd_pins Command_In/sched_queue_nempty_address] [get_bd_pins Scheduler/sched_queue_nempty_address]
  connect_bd_net [get_bd_pins Scheduler/sched_queue_nempty_write] [get_bd_pins Command_In/sched_queue_nempty_write]
  connect_bd_net [get_bd_pins Command_In/acc_avail_wr_address] [get_bd_pins Command_Out/acc_avail_wr_address]
  connect_bd_intf_net -intf_net Cmd_Out_Task_Manager_outStream [get_bd_intf_pins Command_Out/outStream] [get_bd_intf_pins ext_inStream_Taskwait_Inter/S01_AXIS]
  connect_bd_intf_net -intf_net Command_In_cmdInQueue [get_bd_intf_ports cmdInQueue] [get_bd_intf_pins Command_In/cmdInQueue]
  connect_bd_intf_net -intf_net Command_In_intCmdInQueue [get_bd_intf_pins intCmdInQueue/portA] [get_bd_intf_pins Command_In/intCmdInQueue]
  connect_bd_intf_net -intf_net Command_In_outStream [get_bd_intf_pins Command_In/outStream] [get_bd_intf_pins outStream_Inter/S00_AXIS]
  connect_bd_intf_net -intf_net Command_Out_cmdOutQueue [get_bd_intf_ports cmdOutQueue] [get_bd_intf_pins Command_Out/cmdOutQueue]
  connect_bd_intf_net -intf_net Scheduler_spawnOutQueue [get_bd_intf_ports spawnOutQueue] [get_bd_intf_pins Scheduler/spawnOutQueue]
  connect_bd_intf_net -intf_net Spawn_In_SpawnInQueue [get_bd_intf_ports spawnInQueue] [get_bd_intf_pins Spawn_In/SpawnInQueue]
  connect_bd_intf_net -intf_net Spawn_In_outStream [get_bd_intf_pins Spawn_In/outStream] [get_bd_intf_pins ext_inStream_Taskwait_Inter/S02_AXIS]
  connect_bd_intf_net -intf_net S00_AXIS_1 [get_bd_intf_ports inStream_0] [get_bd_intf_pins inStream_Inter/S00_AXIS]
  connect_bd_intf_net -intf_net S01_AXIS_1 [get_bd_intf_ports inStream_1] [get_bd_intf_pins inStream_Inter/S01_AXIS]
  connect_bd_intf_net -intf_net S02_AXIS_1 [get_bd_intf_ports inStream_2] [get_bd_intf_pins inStream_Inter/S02_AXIS]
  connect_bd_intf_net -intf_net S03_AXIS_1 [get_bd_intf_ports inStream_3] [get_bd_intf_pins inStream_Inter/S03_AXIS]
  connect_bd_intf_net -intf_net S04_AXIS_1 [get_bd_intf_ports inStream_4] [get_bd_intf_pins inStream_Inter/S04_AXIS]
  connect_bd_intf_net -intf_net S05_AXIS_1 [get_bd_intf_ports inStream_5] [get_bd_intf_pins inStream_Inter/S05_AXIS]
  connect_bd_intf_net -intf_net S06_AXIS_1 [get_bd_intf_ports inStream_6] [get_bd_intf_pins inStream_Inter/S06_AXIS]
  connect_bd_intf_net -intf_net S07_AXIS_1 [get_bd_intf_ports inStream_7] [get_bd_intf_pins inStream_Inter/S07_AXIS]
  connect_bd_intf_net -intf_net S08_AXIS_1 [get_bd_intf_ports inStream_8] [get_bd_intf_pins inStream_Inter/S08_AXIS]
  connect_bd_intf_net -intf_net S09_AXIS_1 [get_bd_intf_ports inStream_9] [get_bd_intf_pins inStream_Inter/S09_AXIS]
  connect_bd_intf_net -intf_net S10_AXIS_1 [get_bd_intf_ports inStream_10] [get_bd_intf_pins inStream_Inter/S10_AXIS]
  connect_bd_intf_net -intf_net S11_AXIS_1 [get_bd_intf_ports inStream_11] [get_bd_intf_pins inStream_Inter/S11_AXIS]
  connect_bd_intf_net -intf_net S12_AXIS_1 [get_bd_intf_ports inStream_12] [get_bd_intf_pins inStream_Inter/S12_AXIS]
  connect_bd_intf_net -intf_net S13_AXIS_1 [get_bd_intf_ports inStream_13] [get_bd_intf_pins inStream_Inter/S13_AXIS]
  connect_bd_intf_net -intf_net S14_AXIS_1 [get_bd_intf_ports inStream_14] [get_bd_intf_pins inStream_Inter/S14_AXIS]
  connect_bd_intf_net -intf_net S15_AXIS_1 [get_bd_intf_ports inStream_15] [get_bd_intf_pins inStream_Inter/S15_AXIS]
  connect_bd_intf_net -intf_net Scheduler_bitInfo [get_bd_intf_ports bitInfo] [get_bd_intf_pins Scheduler/bitInfo]
  connect_bd_intf_net -intf_net Scheduler_intCmdInQueue [get_bd_intf_pins intCmdInQueue/portB] [get_bd_intf_pins Scheduler/intCmdInQueue]
  connect_bd_intf_net -intf_net Taskwait_outStream [get_bd_intf_pins Taskwait/outStream] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/S00_AXIS]
  connect_bd_intf_net -intf_net Scheduler_outStream [get_bd_intf_pins Scheduler/outStream] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/S01_AXIS]
  connect_bd_intf_net -intf_net Taskwait_twInfo [get_bd_intf_pins tw_info/portA] [get_bd_intf_pins Taskwait/twInfo]
  connect_bd_intf_net -intf_net ext_inStream_Taskwait_Inter_M00_AXIS [get_bd_intf_pins Taskwait/inStream] [get_bd_intf_pins ext_inStream_Taskwait_Inter/M00_AXIS]
  connect_bd_intf_net -intf_net inStream_Inter_M00_AXIS [get_bd_intf_pins Command_Out/inStream] [get_bd_intf_pins inStream_Inter/M00_AXIS]
  connect_bd_intf_net -intf_net inStream_Inter_M01_AXIS [get_bd_intf_pins Scheduler/inStream] [get_bd_intf_pins inStream_Inter/M01_AXIS]
  connect_bd_intf_net -intf_net inStream_Inter_M02_AXIS [get_bd_intf_pins inStream_Inter/M02_AXIS] [get_bd_intf_pins ext_inStream_Taskwait_Inter/S00_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M00_AXIS [get_bd_intf_ports outStream_0] [get_bd_intf_pins outStream_Inter/M00_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M01_AXIS [get_bd_intf_ports outStream_1] [get_bd_intf_pins outStream_Inter/M01_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M02_AXIS [get_bd_intf_ports outStream_2] [get_bd_intf_pins outStream_Inter/M02_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M03_AXIS [get_bd_intf_ports outStream_3] [get_bd_intf_pins outStream_Inter/M03_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M04_AXIS [get_bd_intf_ports outStream_4] [get_bd_intf_pins outStream_Inter/M04_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M05_AXIS [get_bd_intf_ports outStream_5] [get_bd_intf_pins outStream_Inter/M05_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M06_AXIS [get_bd_intf_ports outStream_6] [get_bd_intf_pins outStream_Inter/M06_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M07_AXIS [get_bd_intf_ports outStream_7] [get_bd_intf_pins outStream_Inter/M07_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M08_AXIS [get_bd_intf_ports outStream_8] [get_bd_intf_pins outStream_Inter/M08_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M09_AXIS [get_bd_intf_ports outStream_9] [get_bd_intf_pins outStream_Inter/M09_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M10_AXIS [get_bd_intf_ports outStream_10] [get_bd_intf_pins outStream_Inter/M10_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M11_AXIS [get_bd_intf_ports outStream_11] [get_bd_intf_pins outStream_Inter/M11_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M12_AXIS [get_bd_intf_ports outStream_12] [get_bd_intf_pins outStream_Inter/M12_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M13_AXIS [get_bd_intf_ports outStream_13] [get_bd_intf_pins outStream_Inter/M13_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M14_AXIS [get_bd_intf_ports outStream_14] [get_bd_intf_pins outStream_Inter/M14_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_M15_AXIS [get_bd_intf_ports outStream_15] [get_bd_intf_pins outStream_Inter/M15_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M00_AXIS [get_bd_intf_ports twOutStream_0] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M00_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M01_AXIS [get_bd_intf_ports twOutStream_1] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M01_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M02_AXIS [get_bd_intf_ports twOutStream_2] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M02_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M03_AXIS [get_bd_intf_ports twOutStream_3] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M03_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M04_AXIS [get_bd_intf_ports twOutStream_4] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M04_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M05_AXIS [get_bd_intf_ports twOutStream_5] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M05_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M06_AXIS [get_bd_intf_ports twOutStream_6] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M06_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M07_AXIS [get_bd_intf_ports twOutStream_7] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M07_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M08_AXIS [get_bd_intf_ports twOutStream_8] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M08_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M09_AXIS [get_bd_intf_ports twOutStream_9] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M09_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M10_AXIS [get_bd_intf_ports twOutStream_10] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M10_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M11_AXIS [get_bd_intf_ports twOutStream_11] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M11_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M12_AXIS [get_bd_intf_ports twOutStream_12] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M12_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M13_AXIS [get_bd_intf_ports twOutStream_13] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M13_AXIS]
  connect_bd_intf_net -intf_net outStream_Inter_Taskwait_Task_Manager_M14_AXIS [get_bd_intf_ports twOutStream_14] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M14_AXIS]
  connect_bd_intf_net -intf_net twOutStream_Inter_M15_AXIS [get_bd_intf_ports twOutStream_15] [get_bd_intf_pins outStream_Inter_Taskwait_Task_Manager/M15_AXIS]

  # Create port connections
  connect_bd_net -net aclk_1 [get_bd_ports aclk] [get_bd_pins Command_In/clk] [get_bd_pins Command_Out/clk] [get_bd_pins Scheduler/clk] [get_bd_pins Spawn_In/clk] [get_bd_pins Taskwait/clk] [get_bd_pins ext_inStream_Taskwait_Inter/ACLK] [get_bd_pins ext_inStream_Taskwait_Inter/M00_AXIS_ACLK] [get_bd_pins ext_inStream_Taskwait_Inter/S00_AXIS_ACLK] [get_bd_pins ext_inStream_Taskwait_Inter/S01_AXIS_ACLK] [get_bd_pins ext_inStream_Taskwait_Inter/S02_AXIS_ACLK] [get_bd_pins inStream_Inter/ACLK] [get_bd_pins inStream_Inter/M00_AXIS_ACLK] [get_bd_pins inStream_Inter/M01_AXIS_ACLK] [get_bd_pins inStream_Inter/M02_AXIS_ACLK] [get_bd_pins inStream_Inter/S00_AXIS_ACLK] [get_bd_pins inStream_Inter/S01_AXIS_ACLK] [get_bd_pins inStream_Inter/S02_AXIS_ACLK] [get_bd_pins inStream_Inter/S03_AXIS_ACLK] [get_bd_pins inStream_Inter/S04_AXIS_ACLK] [get_bd_pins inStream_Inter/S05_AXIS_ACLK] [get_bd_pins inStream_Inter/S06_AXIS_ACLK] [get_bd_pins inStream_Inter/S07_AXIS_ACLK] [get_bd_pins inStream_Inter/S08_AXIS_ACLK] [get_bd_pins inStream_Inter/S09_AXIS_ACLK] [get_bd_pins inStream_Inter/S10_AXIS_ACLK] [get_bd_pins inStream_Inter/S11_AXIS_ACLK] [get_bd_pins inStream_Inter/S12_AXIS_ACLK] [get_bd_pins inStream_Inter/S13_AXIS_ACLK] [get_bd_pins inStream_Inter/S14_AXIS_ACLK] [get_bd_pins inStream_Inter/S15_AXIS_ACLK] [get_bd_pins outStream_Inter/ACLK] [get_bd_pins outStream_Inter/M00_AXIS_ACLK] [get_bd_pins outStream_Inter/M01_AXIS_ACLK] [get_bd_pins outStream_Inter/M02_AXIS_ACLK] [get_bd_pins outStream_Inter/M03_AXIS_ACLK] [get_bd_pins outStream_Inter/M04_AXIS_ACLK] [get_bd_pins outStream_Inter/M05_AXIS_ACLK] [get_bd_pins outStream_Inter/M06_AXIS_ACLK] [get_bd_pins outStream_Inter/M07_AXIS_ACLK] [get_bd_pins outStream_Inter/M08_AXIS_ACLK] [get_bd_pins outStream_Inter/M09_AXIS_ACLK] [get_bd_pins outStream_Inter/M10_AXIS_ACLK] [get_bd_pins outStream_Inter/M11_AXIS_ACLK] [get_bd_pins outStream_Inter/M12_AXIS_ACLK] [get_bd_pins outStream_Inter/M13_AXIS_ACLK] [get_bd_pins outStream_Inter/M14_AXIS_ACLK] [get_bd_pins outStream_Inter/M15_AXIS_ACLK] [get_bd_pins outStream_Inter/S00_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M00_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M01_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M02_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M03_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M04_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M05_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M06_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M07_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M08_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M09_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M10_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M11_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M12_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M13_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M14_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M15_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/S00_AXIS_ACLK] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/S01_AXIS_ACLK]
  connect_bd_net -net interconnect_aresetn_1 [get_bd_ports interconnect_aresetn] [get_bd_pins ext_inStream_Taskwait_Inter/ARESETN] [get_bd_pins inStream_Inter/ARESETN] [get_bd_pins outStream_Inter/ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/ARESETN]
  connect_bd_net -net peripheral_aresetn_1 [get_bd_ports peripheral_aresetn] [get_bd_pins ext_inStream_Taskwait_Inter/M00_AXIS_ARESETN] [get_bd_pins ext_inStream_Taskwait_Inter/S00_AXIS_ARESETN] [get_bd_pins ext_inStream_Taskwait_Inter/S01_AXIS_ARESETN] [get_bd_pins ext_inStream_Taskwait_Inter/S02_AXIS_ARESETN] [get_bd_pins inStream_Inter/M00_AXIS_ARESETN] [get_bd_pins inStream_Inter/M01_AXIS_ARESETN] [get_bd_pins inStream_Inter/M02_AXIS_ARESETN] [get_bd_pins inStream_Inter/S00_AXIS_ARESETN] [get_bd_pins inStream_Inter/S01_AXIS_ARESETN] [get_bd_pins inStream_Inter/S02_AXIS_ARESETN] [get_bd_pins inStream_Inter/S03_AXIS_ARESETN] [get_bd_pins inStream_Inter/S04_AXIS_ARESETN] [get_bd_pins inStream_Inter/S05_AXIS_ARESETN] [get_bd_pins inStream_Inter/S06_AXIS_ARESETN] [get_bd_pins inStream_Inter/S07_AXIS_ARESETN] [get_bd_pins inStream_Inter/S08_AXIS_ARESETN] [get_bd_pins inStream_Inter/S09_AXIS_ARESETN] [get_bd_pins inStream_Inter/S10_AXIS_ARESETN] [get_bd_pins inStream_Inter/S11_AXIS_ARESETN] [get_bd_pins inStream_Inter/S12_AXIS_ARESETN] [get_bd_pins inStream_Inter/S13_AXIS_ARESETN] [get_bd_pins inStream_Inter/S14_AXIS_ARESETN] [get_bd_pins inStream_Inter/S15_AXIS_ARESETN] [get_bd_pins outStream_Inter/M00_AXIS_ARESETN] [get_bd_pins outStream_Inter/M01_AXIS_ARESETN] [get_bd_pins outStream_Inter/M02_AXIS_ARESETN] [get_bd_pins outStream_Inter/M03_AXIS_ARESETN] [get_bd_pins outStream_Inter/M04_AXIS_ARESETN] [get_bd_pins outStream_Inter/M05_AXIS_ARESETN] [get_bd_pins outStream_Inter/M06_AXIS_ARESETN] [get_bd_pins outStream_Inter/M07_AXIS_ARESETN] [get_bd_pins outStream_Inter/M08_AXIS_ARESETN] [get_bd_pins outStream_Inter/M09_AXIS_ARESETN] [get_bd_pins outStream_Inter/M10_AXIS_ARESETN] [get_bd_pins outStream_Inter/M11_AXIS_ARESETN] [get_bd_pins outStream_Inter/M12_AXIS_ARESETN] [get_bd_pins outStream_Inter/M13_AXIS_ARESETN] [get_bd_pins outStream_Inter/M14_AXIS_ARESETN] [get_bd_pins outStream_Inter/M15_AXIS_ARESETN] [get_bd_pins outStream_Inter/S00_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M00_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M01_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M02_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M03_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M04_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M05_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M06_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M07_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M08_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M09_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M10_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M11_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M12_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M13_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M14_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/M15_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/S00_AXIS_ARESETN] [get_bd_pins outStream_Inter_Taskwait_Task_Manager/S01_AXIS_ARESETN] [get_bd_pins rst_AND/Op1]
  connect_bd_net -net ps_rst_1 [get_bd_ports ps_rst] [get_bd_pins rst_NOT/Op1]
  connect_bd_net -net rst_AND_Res [get_bd_ports managed_aresetn] [get_bd_pins Command_In/rstn] [get_bd_pins Command_Out/rstn] [get_bd_pins Scheduler/rstn] [get_bd_pins Spawn_In/rstn] [get_bd_pins Taskwait/rstn] [get_bd_pins rst_AND/Res]
  connect_bd_net -net rst_NOT_Res [get_bd_pins rst_AND/Op2] [get_bd_pins rst_NOT/Res]

  # Create address segments


  # Restore current instance
  current_bd_instance $oldCurInst

  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""

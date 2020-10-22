variable name_IP [lindex $argv 0]
variable board_part [lindex $argv 1]
variable root_dir [lindex $argv 2]
variable prj_dir [lindex $argv 3]
variable encrypt [lindex $argv 4]

variable vivado_version [regsub -all {\.} [version -short] {_}]

# Create project
create_project -force $name_IP -part $board_part

add_files -norecurse $root_dir/src/extended/Lock.sv

ipx::package_project -root_dir $prj_dir/IP_packager/${name_IP}_${vivado_version}_IP -vendor bsc -library ompss -taxonomy /BSC/OmpSs -generated_files -import_files -set_current false
ipx::unload_core $prj_dir/IP_packager/${name_IP}_${vivado_version}_IP/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory $prj_dir/IP_packager/${name_IP}_${vivado_version}_IP $prj_dir/IP_packager/${name_IP}_${vivado_version}_IP/component.xml

set_property name $name_IP [ipx::current_core]
set_property version 1.0 [ipx::current_core]
set_property display_name $name_IP [ipx::current_core]
set_property description $name_IP [ipx::current_core]
set_property vendor_display_name {Barcelona Supercomputing Center (BSC-CNS)} [ipx::current_core]
set_property company_url https://pm.bsc.es/ompss-at-fpga [ipx::current_core]
set_property supported_families {zynquplus Beta zynq Beta virtex7 Beta kintexu Beta virtexuplus Beta} [ipx::current_core]

update_compile_order -fileset sources_1
ipx::merge_project_changes hdl_parameters [ipx::current_core]

ipx::associate_bus_interfaces -busif inStream -clock clk [ipx::current_core]
ipx::associate_bus_interfaces -busif outStream -clock clk [ipx::current_core]

set_property core_revision 1 [ipx::current_core]

if {$encrypt == 1} {
    foreach hdl_file [glob $prj_dir/IP_packager/${name_IP}_${vivado_version}_IP/src/{{*/*,*}.sv}] {
	    encrypt -key $root_dir/vivado_keyfile_ver.txt -lang verilog $hdl_file
    }
}

update_compile_order -fileset sources_1
ipx::merge_project_changes files [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::check_integrity -quiet [ipx::current_core]

file delete -force {*}[glob $prj_dir/IP_packager/${name_IP}_${vivado_version}_IP/tmp_edit_project*]


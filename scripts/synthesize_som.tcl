variable project_path [lindex $argv 0]
variable name_IP [lindex $argv 1]
variable extended_mode [lindex $argv 2]
variable part [lindex $argv 3]
variable ip_repo_path [lindex $argv 4]

set name_IP_lower [ string tolower $name_IP ]
set mod_name $name_IP_lower
append mod_name "_0"

if { [ glob -nocomplain $project_path/synth_project.xpr ] == "" } {
    create_project synth_project $project_path -part $part

    set_property ip_repo_paths $ip_repo_path [current_project]
    update_ip_catalog

    create_ip -name $name_IP_lower -vendor bsc -library ompss -module_name $mod_name

    set_property generate_synth_checkpoint false [get_files  $project_path/synth_project.srcs/sources_1/ip/$mod_name/$mod_name.xci]
} else {
    open_project $project_path/synth_project.xpr
}

set_property -dict [list CONFIG.extended_mode $extended_mode CONFIG.num_accs {16} CONFIG.num_tc_accs {16} CONFIG.num_tw_accs {16}] [get_ips $mod_name]

reset_run synth_1

launch_runs synth_1

wait_on_run synth_1

# Check if synthesis finished correctly
if {[string match "*ERROR*" [get_property STATUS [get_runs synth_1]]]} {
	error "ERROR: Hardware synthesis failed."
}

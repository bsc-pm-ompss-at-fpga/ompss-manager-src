variable project_path [lindex $argv 0]
variable name_IP [lindex $argv 1]

set project_name [ string tolower $name_IP ]

append project_file $project_path "/" $project_name ".xpr"

open_project $project_file

reset_run synth_1

set_property synth_checkpoint_mode None [get_files  $project_path/$project_name.srcs/sources_1/bd/$name_IP/$name_IP.bd]

launch_runs synth_1

wait_on_run synth_1


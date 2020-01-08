# OmpSs Manager Sources

HLS sources of the Smart OmpSs Manager (SOM)

### CI workflow

##### Pushes to master

The pushes to the master branch of this repo are automatically compiled by Jenkins CI.  
If the build succeeds, the resulting IP zips and resource utilization reports are committed to the [develop_ip/som](https://pm.bsc.es/gitlab/ompss-at-fpga/autoVivado/tree/develop_ip/som) branch of autoVivado repo.
Then, the generated commit can be imported into the desired autoVivado branch by using the `git cherry-pick` command or merging the `develop_ip` branch.
Also, the resource reports are stored into the Grafana data base and they become available in the [Grafana SOM](https://pm.bsc.es/grafana/d/Ou4SuTJZz/som-smart-ompss-manager) page.

##### Merge Requests to master

The Merge Requests that target the master branch are compiled to check their correctness.
Note that the source code is not tested, nor integrated in autoVivado during this step.
Jenkins CI updates the Merge Request status and **increses the minor version of the IP** creating a bump commit in the Merge Request source branch.

# Development and pipeline files
### Table of contents
- [Merging version](#merging-version)
- List of files
    - [build_cluster.ps1](#build_clusterps1)
    - [Dockerfile](#dockerfile)
    - [destroy_cluster.ps1](#destroy_clusterps1)
    - [build_docker_lme_install.sh](#build_docker_lme_installsh)
    - [docker-compose.yml](#docker-composeyml)
    - [install_lme.ps1](#install_lmeps1)
    - [upgrade_lme.sh](#upgrade_lmesh)
- [Workflows](#workflows)
    - [Workflow Environment Vars](#workflow-environment-vars)
    - [Capturing the responses of workflow steps](#capturing-the-responses-of-workflow-steps)
- [Containers in VSCode](#containers-in-vscode)
    - [.vscode directory](#vscode-directory)

## Merging version
In order to have the pipeline run the upgrade on the proper version,
you will need to edit the `testing\merging_version.sh` file and put 
the version you are going to merge into. In other words, the version
that your code will be released with. It is used in the script `upgrade_lme.sh`
in the `upgrade.yml` workflow file.  

## List of files
### build_cluster.ps1
This is a powershell script that will login to an az shell (given that you have the right environment variables) and run the SetupTestbed.ps1 script. It will require that you have 
account credentials from a managed identity to be able to run commands remotely. 
### Dockerfile
This builds a container that is compatible with the version of Ubuntu we are using and includes the necessary apt packages and tools to run builds and tests.  
### destroy_cluster.ps1
This file is used by the pipeline to take down the servers and assets created in Azure.
### build_docker_lme_install.sh
This script is used by the pipeline to install lme inside of a container.
### docker-compose.yml
Creates two containers, one for development and running tests, another for installing lme onto. 
This docker compose file is used in both the local development environment as well as in the pipeline. 
You will want to create a .env file in the development directory that states the UID and GID of the user you want to run as in the container. 
This is vital to make sure you can read and write to all the files. If your host machine is running linux you can just cd to your home directory 
and run an `ls -ln` and it will show you the uid and gid that you are running as. This hasn't been tested in  windows as a host containers, so you will
need either a virtual machine running wsl or virtual box running ubuntu, or a similar option. Since some of the later commands will be docker in  docker, 
you should start with a Ubuntu host with docker installed. 
### install_lme.ps1
This script is used by the pipeline to install LME on a remote cluster.
### upgrade_lme.sh
This script is used by the pipeline to checkout a branch and run an upgrade inside of a running lme instance. 


## Workflows
The pipeline for building the LME workflows consist of three different workflows. 
One is to build a fresh install (cluster.yml), the other is build Linux only (linux_only.yml) and the other one is to build an upgrade (upgrade.yml). 
The linux only version is built on the workflow runner machine in docker. 
The other workflows are built on a cluster in azure. 

All of the builds create a couple of docker containers on the runner machine and then run commands
in the containers. This allows you to run any of the commands from the pipeline on your local 
dev environment by bringing up the docker containers locally. 
In the pipeline it is necessary to run the commands with a -p so that the containers don't step on each other. 

For example:
``` bash
docker compose -p ${{ env.UNIQUE_ID }} -f testing/development/docker-compose.yml build lme --no-cache
```
To run them locally just remove the -p and id:

``` bash
docker compose -f testing/development/docker-compose.yml build lme --no-cache
```
This allows you to run your commands and debug them locally so you don't have to wait for a complete build of the pipeline.

#### Workflow Environment Vars
In the workflows there are many environment vars and they get written to a `$GITHUB_ENV` file to be accessible from
the various workflow steps. Some environment files will be written to a password file or a `.env` file so that 
the various scripts or tests can access them. 
* Be very careful about what you write to the files to make sure that we are not exposing actual secrets as this 
is a public repo 

#### Capturing the responses of workflow steps
It is quite challenging to capture the responses of a command that was run using docker compose and then a script that
may run another script on the cluster. The important thing is to test that if your command fails, it will propagate the
errors up to the pipeline and stop the step. So when building a step, make sure to check it for failure or success. 
In the different steps in the different files, there are various permeations of ways to do this. 
Seemingly, the best one is to output a unique string at the end of your script and check for that upon completion
of the docker compose command. 


## Containers in VSCode
In vscode you can actually run inside of the containers. There is some documentation about how to do this in the 
`testing/tests/README.md` file. 
We are providing a setup that you can put under your `.vscode` directory that will help expedite setting up the
containers from the root directory of the repo. The documentation in the `testing/tests/README.md` file are specifically
for running VSCode environments that mount those test directories. This setup will mount the root directory of the 
repo, which is more useful during normal development. 

### .vscode directory
You can create these files in the .vscode directory in the root of your repo and put the contents in them. `.vscode` is in the gitignore file so you should be ok. Best not to check these ones in. 
* launch.json
```
{
    "version": "0.2.0",
    "configurations": [
      {
        "name": "Python Debugger: Run API Tests",
        "type": "debugpy",
        "request": "launch",
        "module": "pytest",
        "args": [
          "${workspaceFolder}/testing/tests/api_tests"
        ],
        "console": "integratedTerminal",
        "justMyCode": false,
        "cwd": "${workspaceFolder}/testing/tests",
        "envFile": "${workspaceFolder}/testing/tests/.env"
      },
      {
        "name": "Python Debugger: Run Selenium linux only Tests",
        "type": "debugpy",
        "request": "launch",
        "module": "pytest",
        "args": [
          "${workspaceFolder}/testing/tests/selenium_tests/linux_only"
        ],
        "console": "integratedTerminal",
        "justMyCode": false,
        "cwd": "${workspaceFolder}/testing/tests",
        "envFile": "${workspaceFolder}/testing/tests/.env"
      },
      {
        "name": "Python Debugger: Run Selenium Tests",
        "type": "debugpy",
        "request": "launch",
        "program": "${workspaceFolder}/testing/tests/selenium_tests.py",
        "args": [
          "--domain", "lme"
        ],
        "console": "integratedTerminal",
        "justMyCode": false,
        "cwd": "${workspaceFolder}/testing/tests",
        "envFile": "${workspaceFolder}/testing/tests/.env",
      }
    ]
  }
```

* settings.json

```{
    "python.testing.cwd": "${workspaceFolder}/testing/tests",
    "python.testing.unittestEnabled": false,
    "python.testing.nosetestsEnabled": false,
    "python.testing.pytestEnabled": true,
    "yaml.schemas": {
        "https://json.schemastore.org/github-workflow.json": ".github/workflows/*.yml"
    },
    "workbench.colorCustomizations": {
       "tab.activeBackground": "#49215a" 
    },
    "python.defaultInterpreterPath": "${workspaceFolder}/testing/tests/venv/bin/python",
    "terminal.integrated.defaultProfile.linux": "bash"
}

```
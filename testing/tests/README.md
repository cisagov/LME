# Docker and VSCode Setup
### Table of Contents

1. [Introduction](#introduction)
2. [Dev Containers](#dev-containers)
3. [Building Docker Containers](#building-the-docker-containers-to-use-your-local-username)
   - [Options](#options)
     - Python Development Option
     - Python Tests Option
   - [Running Tests in the Development Container](#running-tests-in-the-development-container-option)
4. [VSCode Extensions](#vscode-extensions)
5. [Environment Variables Setup](#environment-variables-setup)
6. [Python Virtual Environment Setup](#python-virtual-environment-setup)
7. [Running the Tests from the Command Line](#running-the-tests-from-the-command-line)
8. [Generating Test HTML Reports](#generating-test-html-reports)


## Introduction
This environment is set up to run on a computer with Docker installed and on Visual Studio Code (VSCode).

## Dev Containers 
On your host machine, you will want to install the Dev Containers extension in VSCode. With Docker installed on your host machine, you should be able to reopen this repository in a container and select different environment options. To open the repository in a container, press the blue connect button at the far bottom left of the VSCode window. This will prompt you with options to open in the different environments.

## Building the docker containers to use your local username
The docker-compose file in the development contianer is set to use the `.env` file in the `/testing/development` folder. 

If you don't have a .env file, it will use the userid 1001 by default. 
Check and see what your userid is in your host machine by running 
```bash
ls -lna ~ 
```
This will tell you your user id and group id of the host machine. Look at what id the files are owned by. 
```bash
drwxr-x--- 1 1000 1000 4096 Mar  1 13:04 .
drwxr-xr-x 1    0    0 4096 Mar  1 12:44 ..
-rw------- 1 1000 1000   21 Mar  1 13:04 .bash_history
-rw-r--r-- 1 1000 1000  220 Jan  6  2022 .bash_logout
-rw-r--r-- 1 1000 1000 3771 Jan  6  2022 .bashrc
drwxr-xr-x 3 1000 1000 4096 Mar  1 13:04 .dotnet
-rw-r--r-- 1 1000 1000  292 Mar  1 13:04 .gitconfig
drwx------ 2 1000 1000 4096 Mar  1 13:04 .gnupg
-rw-r--r-- 1 1000 1000  807 Jan  6  2022 .profile
drwxr-xr-x 2 1000 1000 4096 Mar  1 13:04 .ssh
drwxr-xr-x 6 1000 1000 4096 Mar  1 13:04 .vscode-server
drwxr-xr-x 2    0    0 4096 Mar  1 12:44 LME
```
In this case you can see the files like `.bash_history` are owned by `1000 1000`. 
The first number is your user id and the second is your group id. 
So in the `testing/development` folder make a new file named `.env` and put this in it:
```bash
HOST_UID=1000
HOST_GID=1000
```
Now you will need to build the containers for the first time. Subsequent builds, and up, will
use the prebuilt containers and keep the user id as the correct one in the container. 
```bash
cd testing/development
docker compose build --no-cache 
```
You can follow the rest of the directions on this page and just make sure that when you get into the container, open a new bash shell and do a `ls -la` the files should be owned by `admin.ackbar`


### Options
- **Python Development Option**: This option is for development of the entire codebase and
is not set up for debugging and running tests easily. If you want to run tests and debug 
in this environment, you can manually set it up by making a `launch.json` and a 
`settings.json` in the root of the repo under `.vscode`. 
You can copy the versions in the `testing/tests/.vscode` folder, as a starting point. 
- **Python Tests Option**: This option is for opening only the test environment. You will want to open this one for running your tests as it already has quite a bit of setup for getting the tests to run easily. 

Using Docker helps to avoid polluting your host environment with multiple versions of Python.

### Running tests in the Development Container Option
When you select the Python Tests option to run your container in, there are already
config files for running tests in VSCode so you won't have to set this part up. 

If you want to run tests within the 
Python Development environment option, you will have to make a `.vscode/launch.json` in the root 
of your environment. This folder isn't checked into the repo so it has to be manually
created. 
The easy way to create this file is to click on the play button (triangle) with the little bug on it in your 
VSCode activity bar. There will be a link there to "create a launch.json file". Click on that link and select 
"Python Debugger"->"Python File". This will create a file and open it. Replace its contents with the below 
code to run the `api_tests` in `testing/tests/api_tests`.
After that, the Run and Debug interface will change and have a green arrow in it for running and testing code. 

```
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Python Debugger: Run Tests",
            "type": "debugpy",
            "request": "launch",
            "module": "pytest",
            "args": [
                "${workspaceFolder}/testing/tests/api_tests" // Path to your tests
            ],
            "console": "integratedTerminal",
            "justMyCode": false, // Set this to false to allow debugging into external libraries
            "cwd": "${workspaceFolder}/testing/tests/" // Set the working directory
        }
    ]
}
```
If you want to get the test explorer (beaker icon) to be able to find your tests, you can add
this to your `.vscode/settings.json`, so it knows to look in the `/testing/tests` folder. 
```
"python.testing.pytestArgs": [
    "testing/tests"
],
"python.testing.unittestEnabled": false,
"python.testing.nosetestsEnabled": false,
"python.testing.pytestEnabled": true
```

## VSCode Extensions
The necessary VSCode extensions have been installed, in the Python Tests container, for
running and debugging tests within VSCode. The first time you open the project in a
container, it may take a little time for VSCode to install the necessary extensions. 

## Environment Variables Setup
- There is an example `.env_example` file for setting environment variables for the tests.
- To use it, copy this file and rename it to `.env`.
- The testing environment will then pick up those variables and set them as environment 
variables before running tests.

## Python Virtual Environment Setup
In order for VSCode to use the python modules for the tests, you will want to install a
python virtual environment for it to use. You can make a python virtual environment
folder that is available for both of the development containers by making it in the 
`testing/tests` folder. Then you can have only one copy of the environment for both 
container options. 
You can do this by opening a new terminal in VSCode, within the `testing/tests` 
directory, and running:


`python3 -m venv venv`

This will make a virtual environment for python to install its modules into. 
Once you have made the virtual environment, you then run:

`. venv/bin/activate` 

which will activate the virtual environment for you. 
It will show this in the terminal prompt by prefacing your prompt with `(venv) restofprompt#`. 

Once you have activated the virtual environment, run the installer for the pip modules:

 `pip install -r requirements.txt`

You can now select this environment in VSCode. To do this, open a python file from
within the project explorer. Once the file is open in the editor, VSCode will show 
you which python version you are running in the bottom right of the screen. If you
click that version, you can select the venv version that you installed above. 
The path should be `./testing/tests/venv/bin/python` 


## Running the tests from the command line 
Set up the virtual environment, activate it, and install the modules. Then you can run the tests with pytest

```
cd testing/tests
python3 -m venv venv
. venv/bin/activate 
pip install -r requirements.txt
pytest
```

## Generating Test HTML Reports
After the tests have been executed, run the following command to generate HTML report to view Test Results.

```
pytest --html=report.html
```

Note: pytest-html has been added to requirements.txt. If for any reason pytest-html is not installed on your virtual environment; you may first need to install it with  the following command. 

```
pip install pytest-html
```

After html report is generated, run the following command outside virtual environment to attribute appropriate ownership on the html file so that you can open the file with the browser of choice. Google Chrome browser seems to provide a better display than Firefox.

```
chown 1000.1000 report.html
```

When a test fails, the test result details on the report provide appropriate information on the error message as you would expect to see on console. 


## Development and Docker


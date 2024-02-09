# Docker and VSCode Setup

## Introduction
This environment is set up to run on a computer with Docker installed and on Visual Studio Code (VSCode).

## Dev Containers 
On your host machine, you will want to install the Dev Containers extension in VSCode. With Docker installed on your host machine, you should be able to reopen this repository in a container and select different environment options. To open the repository in a container, press the blue connect button at the far bottom left of the VSCode window. This will prompt you with options to open in the different environments.

### Options
- **Python Development Option**: This option is for development of the entire codebase and
is not set up for debugging and running tests easily. If you want to run tests and debug 
in this environment, you can manually set it up by making a `launch.json` and a 
`settings.json` in the root of the repo under `.vscode`. 
You can copy the versions in the `testing/tests/.vscode` folder, as a starting point. 
- **Python Tests Option**: This option is for opening only the test environment. You will want to open this one for running your tests as it already has quite a bit of setup for getting the tests to run easily. 

Using Docker helps to avoid polluting your host environment with multiple versions of Python.

## VSCode Extensions
The necessary VSCode extensions have been installed, in the Python Tests container, for
running and debugging tests within VSCode. The first time you open the project in a
container, it may take a little time for VSCode to install the necessary extensions. 

## Environment Variables Setup
- There is an example `.env_example` file for setting environment variables for the tests.
- To use it, copy this file and rename it to `.env`.
- The testing environment will then pick up those variables and set them as environment variables before running tests.

## Python Virtual Environment Setup
In order for VSCode to use the python modules for the tests, you will want to install a
python virtual environment for it to use. 
You can do this by opening a new terminal in VSCode, within the `testing/tests` directory, and running:


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
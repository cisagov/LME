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

Outside the virtual env, after html report is generated, run the following command once on the html report to attribute appropriate ownsership on the html file so that you can open the file with the browser of choice. Google Chrome browser seems to provide a better display than Firefox.

```
chown 1000.1000 report.html
```

When a test fails, the test result details on the report provide appropriate information on the error message as you would expect to see on console. 

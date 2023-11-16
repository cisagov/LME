---
name: Bug or Error report
about: Report issues,mistakes,unsolvable or unresolved errors to help improve the
  project
title: "[BUG] ERROR YYYYY in step X.X"
labels: bug
assignees: ''

---

## **BEFORE CREATING THE ISSUE, CHECK THE FOLLOWING GUIDES**: 
 - [ ] [FAQ](https://github.com/cisagov/LME/blob/main/docs/markdown/reference/faq.md)
 - [ ] [Troubleshooting](https://github.com/cisagov/LME/blob/main/docs/markdown/reference/troubleshooting.md)
 - [ ] Searched other issues for my same question, and utilized github/google search to see if an answer exists for my error I'm encountering.  

IF the above did not answered your question, proceed with creating an issue below: 

## Describe the bug
A clear and concise description of what the bug is.

## To Reproduce
Steps to reproduce the behavior. These should be clear enough that our team can understand your running environment, software/operating system versions, and anything else we might need to debug the issue. 

An example of a usable reproducable list is this issue: [Issue1](https://github.com/cisagov/LME/issues/15) [Issue2](https://github.com/cisagov/LME/issues/19). 

To increase the speed and ability of reply we suggest you list down debugging steps you have tried, as well as the following information:

### Please complete the following information
**Desktop:**
 - OS: [e.g. Windows 10]
 - Browser: [e.g. Firefox Version 104.0.1]
 - software version: [e.g. Sysmon v15.0, Winlogbeat 8.11.1]

**Server:**
- OS: [e.g. Ubuntu 22.04]
- Software Versions:
  - ELK: [e.g. 8.7.1]
  - Docker: [e.g. 20.10.23, build 7155243]
- the output of these commands: 
```
free -h
df -h 
uname -a 
lsb_release -a
```
- relevant container logs: 
```
for name in $(sudo docker ps -a --format '{{.Names}}'); do echo -e "\n\n\n-----------$name----------"; sudo docker logs $name | tail -n 20; done
```
Increase the number of lines if your issue is not present, or include a relevant log of the erroring container
- output of the relevant /var/log/cron_logs/ file

## Expected behavior
A clear and concise description of what you expected to happen.

## Screenshots
If applicable, add screenshots to help explain your problem.

## Additional context
Add any other context about the problem here.

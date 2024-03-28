---
name: Bug or Error report
about: Report issues, mistakes, unsolvable, or unresolved errors to help improve the project
title: "[BUG] ERROR YYYYY in step X.X"
labels: bug
assignees: ''

---

## **BEFORE CREATING THE ISSUE, CHECK THE FOLLOWING GUIDES**: 
 - [ ] [FAQ](https://github.com/cisagov/LME/blob/main/docs/markdown/reference/faq.md)
 - [ ] [Troubleshooting](https://github.com/cisagov/LME/blob/main/docs/markdown/reference/troubleshooting.md)
 - [ ] Search current/closed issues for similar questions and utilize github/google search to see if an answer exists for the error you are encountering.

If the above did not answer your question, proceed with creating an issue below: 

## Describe the bug
<!-- A clear and concise description of what the software flaw you are experiencing looks like, or what the behavior is. -->

## Expected behavior
A clear and concise description of what you expected to happen.

## To Reproduce
<!-- Steps to reproduce the behavior. These should be clear enough that our team can understand your running environment, software/operating system versions and anything else we might need to debug the issue.  -->  
<!-- Good examples can be found here: [Issue 1](https://github.com/cisagov/LME/issues/15) [Issue 2](https://github.com/cisagov/LME/issues/19).  --> 

### Please complete the following information

#### **Setup**
- Are you running the LME machines in a virtual environment (i.e. Docker) or are you running natively on the machines?
- Which version of LME are you installing?
- Is this a first-time installation or are you upgrading?  If upgrading, what was your previous version?

#### **Desktop:** (Client Machines)
- OS: [e.g. Windows 10]
- Browser: [e.g. Firefox Version 104.0.1]
- Software version: [e.g. Sysmon v15.0]

#### **Domain Controller:** 
- OS: [e.g. Windows Server]
- Browser: [e.g. Firefox Version 104.0.1]
- Software version: [e.g. Winlogbeat 8.11.1]
 
#### **ElasticSearch/Kibana Server:**
- OS: [e.g. Ubuntu 22.04]
- Software Versions:
  - ELK: [e.g. 8.7.1]
  - Docker: [e.g. 20.10.23, build 7155243]

**OPTIONAL**:
- The output of these commands: 
```
free -h
df -h 
uname -a 
lsb_release -a
```
- Relevant container logs: 
```
for name in $(sudo docker ps -a --format '{{.Names}}'); do echo -e "\n\n\n-----------$name----------"; sudo docker logs $name | tail -n 20; done
```
Increase the number of lines if your issue is not present or include a relevant log of the erroring container
- Output of the relevant /var/log/cron_logs/ file


## Screenshots **OPTIONAL**
If applicable, add screenshots to help explain your problem.

## Additional context
Add any other context about the problem or any unique environment information here.

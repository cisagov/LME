# Welcome #

We're so glad you're thinking about contributing to this open-source project! If you're unsure or hesitant to make a recommendation, just ask, submit the issue, or pull request. The worst that can happen is that you'll be politely asked to change something. We appreciate any sort of contribution(s), and don't want a wall of rules to stifle innovation.

Before contributing, we encourage you to read our CONTRIBUTING policy (you are here), our LICENSE, and our README, all of which are in this repository.

## Issues 

If you want to report a bug or request a new feature, the most direct method is to [create an issue](https://github.com/cisagov/development-guide/issues) in this repository.  
We recommend that you first search through existing issues (both open and closed) to check if your particular issue has already been reported.  

If it has then you might want to add a comment to the existing issue.  

If it hasn't then please create a new one. 

Please follow the provided template and fill out all sections. We have a `BUG` and `FEATURE REQUEST` Template

## Branch naming conventions

If you are planning to submit a pull request, please name your branch using the following naming convention:  
`<githubusername>-<issue #>-<short description>`  

Example:  
`mreeve-22-filter-events`

## Pull Requests (PR)

If you choose to submit a pull request, it will be required to pass various sanity checks in our continuous integration (CI) pipeline, before we merge it. Your pull request may fail these checks, and that's OK. If you want you can stop there and wait for us to make the necessary corrections to ensure your code passes the CI checks, you're more than within your rights; however, it helps our team greatly if you fix the issues found by our CI pipeline. 

Below are some loose requirements we'd like all PR's to follow. Our release process is documented in [Releases](RELEASES.md).

### Quality assurance and code reviews

All PRs will be tested, vetted, and reviewed by our team before being merged with the main code base. All should be pull requested into the `develop` branch. 

### Steps to submit a PR  
  - All PRs should request merges back into LME's `develop` branch.  This will be viewable in the branch list on Github. You can also refer to our [release documentation](https://github.com/cisagov/LME/blob/main/RELEASES.md) for guidance. If the fix fits the requirements for a hotfix, the LME team will modify your PR as is relevant.  
  - If the PR corresponds to an issue we are already tracking on LME's public Github [project](https://github.com/orgs/cisagov/projects/68), please comment the PR in the issue, and we will update the issue. 
  - If the PR does not have an issue, please create a new issue and name your branch according to the conventions [here](#branch-naming-conventions). Add a comment at the top of the pull request describing the PR and how it fits into LME's project/code. If the PR follows our other requirements listed here, we'll add it into our public project linked previously.
  - We'll work with you to mold it to our development goals/process, so your work can be merged into LME and your Github profile gets credit for the contributions. 
  - Before merging we request that all commits be squashed into one commit. This way your changes to the repository are tracked, but our `git log` history does not rapidly expand. 
  - Thanks for wanting to submit and develop improvements for LME!!

## Public domain 

This project is in the public domain within the United States, and
copyright and related rights in the work worldwide are waived through
the [CC0 1.0 Universal public domain
dedication](https://creativecommons.org/publicdomain/zero/1.0/).

All contributions to this project will be released under the CC0
dedication. By submitting a pull request, you are agreeing to comply
with this waiver of copyright interest.

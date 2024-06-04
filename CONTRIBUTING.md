# Welcome #

Users are welcome to contribute to LME. If you're unsure or hesitant to make a recommendation, just ask, submit the issue or pull request. The LME team appreciates any sort of contribution, and does not want to stifle innovation.

Before contributing, please read the CONTRIBUTING policy (you are here), LICENSE, and README, all of which are in this repository.

## Issues 

If you want to report a bug or request a new feature, the most direct method is to [create an issue](https://github.com/cisagov/development-guide/issues) in this repository.  
We recommend that you first search through existing issues (both open and closed) to check if another users has reported your particular issue and there is already an answer.  

If your question is in an existing issue, then you might want to add a comment to the existing issue.  

If it hasn't, then please create a new one. 

Please follow the provided template and fill out all sections. We have a `BUG` and `FEATURE REQUEST` Template

## Branch naming conventions

If you are planning to submit a pull request, please name your branch using the following naming convention:  
`<githubusername>-<issue #>-<short description>`  

Example:  
`mreeve-22-filter-events`

## Pull Requests (PR)

If you choose to submit a pull request, your pull request must pass various sanity checks in the continuous integration (CI) pipeline, before merging it. Your pull request may fail these checks, and that's OK. If you want, you can stop there and wait for us to make the necessary corrections to ensure your code passes the CI checks. It helps our community if you fix the issue found by our CI pipeline. 

Below are some loose requirements we'd like all PR's to follow. Our release process is documented in [Releases](releases.md).

### Quality assurance and code reviews

Our team will test, vet and review all PR's before our team merges a PR with the main code base. All code should be pull requested into the upcoming release branch. You can find that by searching for the highest SEMVER `release-X.Y.Z` branch or following our release documentation.

### Steps to submit a PR
	- All PRs should request merges back into LME's *CLOSEST* Major or Minor upcoming release branch `release-X.Y.Z`. This will be viewable in the branch list on Github. You can also refer to our release documentation for guidance. 
  - If the PR corresponds to an issue we are already tracking on LME's public Github [project](https://github.com/orgs/cisagov/projects/68), please comment the PR in the issue, and we will update the issue. 
  - If the PR does not have an issue, please create a new issue and name your branch according to the conventions [here](#branch-naming-conventions). Add a human readable title describing the PR and how it fits into LME's project/code. If the PR follows our other requirements listed here, we'll add it into our public project linked previously.
  - Add the label `feat` for an added new feature, `update` for an update, **or** `fix` for a fix.
  - We'll work with you to mold it to our development goals/process, so your work can be merged into LME and your Github profile gets credit for the contributions. 
  - Before merging, we request that all commits be squashed into one commit. This way your changes to the repository are tracked, but our `git log` history does not rapidly expand. 
  - Thanks for wanting to submit and develop improvements for LME!!

## Public domain 

This project is in the public domain within the United States, and
copyright and related rights in the work worldwide are waived through
the [CC0 1.0 Universal public domain
dedication](https://creativecommons.org/publicdomain/zero/1.0/).

All contributions to this project will be released under the CC0
dedication. By submitting a pull request, you are agreeing to comply
with this waiver of copyright interest.

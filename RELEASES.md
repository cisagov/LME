# Release Workflow:

## SEMVER Number Decisions

Our versioning scheme for LME adheres to [SEMVER 2.0](https://semver.org/):  X.Y.Z (Major.Minor.Patch). 
The patch versions will generally adhere to the following guidelines:
1. Major SEMVER: Denotes a major release, e.g., a new capability, or LME architecture change.
2. Minor SEMVER: Denotes updates which are less than major but introduces noticeable changes.
3. Patch SEMVER: Fix product breaking bugs, or vulnerabilities, or key documentation issues, but do not introduce new features or updates.

### Timelines

Development lifecycle timelines will vary depending on project goals, tasking, community contributions, and vision.


## Branch Convention:
We are using a Github flow denoted by: 

![git-flow](/docs/imgs/git-flow.png)

The team requests a brief description if you submit a fix for a current issue on the public project, that context will allow us to help determine if it warrants inclusion. If the PR is well documented following our processes in our [CONTRIBUTING.md](https://github.com/cisagov/LME/blob/main/CONTRIBUTING.md), it will most likely be worked into LME. We value inclusion and recognize the importance of the open-source community.

### Branch Naming Explained: 
We have 2 main branches whose names will stay constant:
  1. The `main` branch tracks Major/Minor/Patch releases only, and is only updated with merges from the `develop` or a `hotfix` branch. Releases are tagged appropriate SEMVERs based on their content:  `vX.Y.Z`.
  2. The `develop` branch is our working copy of latest changes, and tracks all feature development. Feature branches are merged into `develop` as features are added, and when ready `develop` will merge into main as documented above.
  
There are 2 other branch naming conventions that change based on the issue/update/content they add to the project. 
  1. A `hotfix` branch is created to "fix" or "patch" a critical issue in the `main` branch of the LME repository. Hotfixes are branched from `main` and merged into `develop`. This way `main` can get fixes, and `develop` will be synced with `main`. This process side-steps the normal `feature` -> `develop` -> commit release -> `main` workflow. Once the hotfix PR is finalized/approved, and merged into main, finally we execute a merge commit of `main` into `develop`.  
    - It uses the convention: `hotfix-<username>-<issue#>-<shortstring>`  
    - An example: `hotfix-cbaxley-222-fix-the-pipeline`  
  2. A feature branch is created from `develop` to add content for issues/work/updates/etc...  
    - It uses the convention: `<username>-<issue #>-shortstring`  
    - An example: `mreeve-22-filter-events`  

**NOTE:** Each branch name will have a short string to describe what it is solving for example `create-new-container`.

### Post merge: 
Any branch other than develop/main should be deleted to preserve readability in github's UI. 

Commands to merge main back into develop: 
```bash
#in a previously cloned LME git repository:
git pull
git checkout develop
git merge main
#push up the new develop branch that is synced with main
git push -f
```
## Content: 

Each release generally notes the Additions, Changes, and Fixes addressed in the release and the contributors that provided code for the release. Additionally, relevant builds of the release will be attached with the release. Tagging the release will correspond with its originating branch's SEMVER number.

## Update Process:

### Code Freeze:
Each code freeze will have an announced end date/time in accordance with our public [project](https://github.com/orgs/cisagov/projects/68). Any PRs with new content will need to be merged into `develop` by the announced time in order to be included into the release.

### Steps:

1. Goals/changes/updates to LME will be tracked in LME's public [project](https://github.com/orgs/cisagov/projects/68). These updates to LME will be tracked by pull requests (and may be backed by corresponding issues for documentation purposes for documentation purposes) into the `develop`  branch.
2. As commits are pushed to the PRs set to pull into the `develop` branch, we will determine a time to cease developments, and mark a period of testing for `development` that will be merged into main.
3. When its determined the features developed meet a goal or publish point, after waiting for feedback and proper testing,  we will merge `develop` with a `vX.Y.Z` semver tag into `main` branch.  

### Caveats:
Major or Minor SEMVER LME versions will only be pushed to `main` with testing and validation of code to ensure stability and compatibility. However, new major changes will not always be backwards compatible.


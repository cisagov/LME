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
We are using a github flow denoted by: 
![git-flow](/docs/imgs/git-flow.png)

The team requests a brief description if you submit a fix for a current issue on the public project, that context will allow us to help determine if it warrants inclusion. If the PR is well documented following our processes in our CONTRIBUTING.md, it will most likely be worked into LME. We value inclusion and recognize the importance of the open-source community.

### branch naming explained: 
We have 2 main branches whose names will stay constant:
  1. The `main` branch tracks Major/Minor/Patch releases only, and is only updated with merges from the `develop` or a `hotfix` branch. Releases are tagged appropriate SEMVERs based on their content:  `vX.Y.Z`.
  2. The `develop` branch is our working copy of latest changes, and tracks all feature development. Feature branches are merged into `develop` as features are added, and when ready `develop` will merge into main as documented above.
  
There are 2 other branch naming conventions that change based on the issue/update/content they add to the project. 
  - A `hotfix` branch is created to "fix" or "patch" a critical issue in the `main` branch of the LME repository. Hotfixes are branched from `main` and merged into `develop`. This way `main` can get fixes, and `develop` will be synced with `main`.
    - It uses the convention: `hotfix-<username>-<issue#>-<shortstring>`
    - An example: `hotfix-cbaxley-222-fix-the-pipeline`
  - A feature branch is created from `develop` to add content for issues/work/updates/etc...
    - It uses the convention: <username>-<issue #>-shortstring
    - An example: `mreeve-22-filter-events`

**NOTE:** Each branch name will have a short string to describe what it is solving for example `create-new-container`:
 

## Content: 

Each release generally notes the Additions, Changes, and Fixes addressed in the release and the contributors that provided code for the release. Additionally, relevant builds of the release will be attached with the release. Tagging the release will correspond with its originating branch's SEMVER number.

## Update Process:
Developments and changes will accrue in a release-X.Y.Z branch according to the level of the release as documented in [Pull Requests](#pull-requests). The process of merging all changes into a release branch and preparing it for release is documented below.

### Code Freeze:
Each code freeze will have an announced end date/time in accordance with our public [project](https://github.com/orgs/cisagov/projects/68). Any PRs with new content will need to be in by the announced time in order to be included into the release.

### Steps:

1. Goals/changes/updates to LME will be tracked in LME's public [project](https://github.com/orgs/cisagov/projects/68). These updates to LME will be tracked by pull requests (and may be backed by corresponding issues for documentation purposes for documentation purposes) to a specific `release-X.Y.Z` branch.
2. As commits are pushed to the PRs set to pull into a release branch, we will determine a time to cease developments. When its determined the features developed in a `release` branch meet a goal or publish point, we will merge all the release's PR's into one combined state onto the `release-.X.Y.Z` branch. This will make sure all testing happens from a unified branch state, and will minimize the number of merge conflicts that occur, easing coordination of merge conflicts. 
3. Once all work has been merged into an initial release, we will mark the pull request for the release with a `code freeze` label to denote that the release is no longer excepting new features/developments/etc...., all PRs that commit to the release branch should only be to fix breaking changes or failed tests. We’ll also invite the community to pull the frozen `release` branch to test and validate if the new changes cause issues in their environment.
4. Finally, when all testing and community feedback is complete we'll merge into main with a new tag denoting the `release-X.Y.Z` SEMVER value `X.Y.Z`.

### Caveats:
Major or Minor SEMVER LME versions will only be pushed to `main` with testing and validation of code to ensure stability and compatibility. However, new major changes will not always be backwards compatible.


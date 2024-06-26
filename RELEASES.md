# Release Workflow:

## SEMVER Number Decisions

Our versioning scheme for LME adheres to [SEMVER 2.0](https://semver.org/):  X.Y.Z (Major.Minor.Patch). 
The patch versions will generally adhere to the following guidelines:
1. Major SEMVER: Denotes a major release, e.g., a new capability, or LME architecture change.
2. Minor SEMVER: Denotes updates which are less than major but introduces noticeable changes.
3. Patch SEMVER: Fix bug issues or vulnerability issues but do not introduce new features or updates.

### Timelines

Development lifecycle timelines will vary depending on project goals, tasking, community contributions and vision.


## Current Release Branch:
To determine the current release branch, it will either be clearly documented in our wiki or on our public [project](https://github.com/orgs/cisagov/projects/68) board. The below example can also be used to determine our current release branch.

- For example, if the current latest release (as seen on the main [README](/README.md)) version `1.1.0`, and the `release-*` branches are: `release-1.1.1` and `release-1.2.0` then the `1.2.0` branch would be the branch where submit the PR, since it is the closest release that is a Major or Minor release, while 1.1.1 is a patch release.

- All `release-*` have various branch protections enabled and will require review by the development team before being merged.
The team requests a brief description if for each submission for a fix for a current issue on the public project, that context will allow us to help determine if it warrants inclusion. If the PR is well documented following our processes in our CONTRIBUTING.md, we will most likely work it into LME. We value inclusion and recognize the importance of the open source community.

## Content: 

Each release generally notes the Additions, Changes and Fixes addressed in the release and the contributors that provided code for the release. Additionally, relevant builds of the release will be attached with the release. Tagging the release will correspond with its originating branch's SEMVER number.

## Update Process:
Developments and changes will accrue in a release-X.Y.Z branch according to the level of the release as documented in [Pull Requests](#pull-requests). The process of merging all changes into a release branch and documents for preparing it for release are below.

### Code Freeze:
We will announce for each code free an end date/time in accordance with our public [project](https://github.com/orgs/cisagov/projects/68). Users must add any PRs with new content by the announced time for us to include in the release.

### Steps:

1. The team will track goals, changes and updates in LME's public [project](https://github.com/orgs/cisagov/projects/68). Pull requests will track updates to LME (and may be backed by corresponding issues for documentation purposes for documentation purposes) to a specific `release-X.Y.Z` branch.
2. As commits are pushed to the PRs set to pull into a release branch, we will determine a time to cease developments. When the team determines that features developed in a `release` branch meet a goal or publish point, we will merge all the release's PR's into one combined state onto the `release-.X.Y.Z` branch. This will ensure all testing happens from a unified branch state and will minimize the number of merge conflicts that occur and ease coordination of merge conflicts. 
3. Once the team has merged all work into an initial release, we will mark the pull request for the release with a `code freeze` label to denote that the release is no longer excepting new features/developments/etc...., all PR's that commit to the release branch should only be to fix breaking changes or failed tests. We’ll also invite the community to pull the frozen `release` branch to test and validate if the new changes cause issues in their environment.
4. Finally, when all testing and community feedback is complete, we'll merge into main with a new tag denoting the `release-X.Y.Z` SEMVER value `X.Y.Z`.

### Caveats:
Major or Minor SEMVER LME versions will only be pushed to `main` with testing and validation of code to ensure stability and compatibility. However, new major changes will not always be backwards compatible.


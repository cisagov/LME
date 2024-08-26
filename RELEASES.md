# Release Workflow
Here you can find information around our release versioning scheme, Gitflow branching model, and steps to undergo when creating a new release. 

## SEMVER Numbering

Our versioning scheme for LME adheres to [SEMVER 2.0](https://semver.org/):  `x.y.z (major.minor.patch)`. 
The patch versions will generally adhere to the following guidelines:
- **Major versions (`x.0.0`)**: Denotes a major release, e.g., a new capability, or LME architecture change.
- **Minor versions (`x.y.0`)**: Denotes updates which are less than major but introduces noticeable changes.
- **Patch versions (`x.y.z`)**: Fix bug issues or vulnerability issues but do not introduce new features or updates.

## Gitflow Branching Model 
The Gitflow model helps standardize how we handle our development workflow. The purpose of branch types are clearly defined which helps to improve collaboration and to simplify release management.

- **Main (`main`)**: Represents the latest production-ready code. Each commit here corresponds to a version release, and it is tagged accordingly.
- **Develop (`develop`)**: An integration branch for new development work. All feature branches branch off from develop and are merged back into it when completed. The `develop` branch represents the code that will be included in the next major or minor release.
- **Feature branches (`427-descriptive-name-xyz`)**: Created from `develop` for new features, new changes are merged back into `develop` upon completion. The feature branch should include a corresponding issue number along with a short description of the work being done.

  ```
  git fetch
  git checkout develop
  git checkout -b 427-descriptive-name-xyz
  ```

  When the feature is complete, open a pull request back into `develop`. In some cases, your feature     branch may be outdated with the current state of `develop`. Rebase the latest changes from `develop`   into your feature branch to maintain a clean commit history.

  ```
  # From your feature branch, run:
  git pull --rebase origin develop
  ```

- **Release branches (`release-1.4.0`)**: Created from `develop`, the release branch represents the upcoming version and is where continuous integration picks up any remaining bug fixes. Once the release is finalized, the release branch is merged into `main`.
- **Hotfix (`hotfix-1.4.1`)**: Created from `main` to address urgent production issues. These are merged into both `main` and `develop` upon completion.

<img src="https://github.com/user-attachments/assets/9c5e959b-5187-4cdc-92a1-66b18bc65068" alt="git-model" width="500"/>

## Release Content: 

When a release is merged into `main`, it is given a tag corresponding to the release's SEMVER number, i.e. `v1.4.0`. Each release contains Additions, Changes, and Fixes addressed in the release notes. A zip file is attached which is available to download after a release is published. 

![Screenshot (183)](https://github.com/user-attachments/assets/7bd771ca-ef41-48a8-a482-de4582b584db)

### Code Freeze:
Each code freeze will have an announced end date/time in accordance with our public [project](https://github.com/orgs/cisagov/projects/68). Any PRs with new content will need to be in by the announced time in order to be included into the release.

### Steps:

1. Goals/changes/updates to LME will be tracked in LME's public [project](https://github.com/orgs/cisagov/projects/68).
2. Feature branches will be created based on the work allocated for a given sprint. When work is complete on a given feature branch, a pull request is opened back into `develop`.
3. Once `develop` is in a state that is release ready, we will create a release branch off of `develop`, denoted by the release's SEMVER value, `release-x.y.z`. For any bugfixes found when testing a release, these updates can be merged back into the `develop` branch. The community is also welcome to pull the frozen `release-x.y.z` branch to test and validate if the new changes cause issues in their environment.
5. Once testing and community feedback is complete, we'll merge the release branch into `main` with a new tag denoting the `release-x.y.z` SEMVER value, `vx.y.z`.

### Caveats:
Major or Minor SEMVER LME versions will only be pushed to `main` with testing and validation of code to ensure stability and compatibility. However, new major changes will not always be backwards compatible.


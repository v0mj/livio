# AI maintenance model

Livio OS is maintained as an AI-assisted distro project.

The goal is not to hide the build process or pretend the system is larger than
it is. The goal is to keep the source readable, reproducible and reviewable:

- changes are committed to Git
- source checks run locally and in GitHub Actions
- release builds follow a checklist
- generated ISO files stay outside the Git repository
- large upstream components are built from documented recipes

Human review is still important before public releases, especially for installer
behavior, package signing, hardware support and destructive disk operations.

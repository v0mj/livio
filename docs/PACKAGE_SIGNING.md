# Package signing

Livio currently builds a local `livio-local` repository inside the ISO so the
installer can install Livio-owned packages without an external mirror.

Unsigned local packages are allowed during the preview phase because the repo is
inside the ISO. Public releases should move toward signed packages and signed
repository metadata.

## Intended release path

1. Create a dedicated Livio package signing key.
2. Keep the private key off normal development machines.
3. Build packages in a clean environment.
4. Sign Livio-owned packages.
5. Sign the `livio-local` repo database.
6. Publish the public key with the release.
7. Document key fingerprint verification.

## Optional build-time repo signing

The build script supports optional local repository database signing through:

```bash
LIVIO_REPO_SIGN_KEY="KEYID" ./scripts/build-iso.sh
```

This only signs repository metadata. A proper public release should also sign
packages and document the public key fingerprint.

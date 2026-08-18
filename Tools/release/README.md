# Shipping Typikey

```sh
./Tools/release/ship.sh              # archive → upload → external review
./Tools/release/ship.sh --internal   # stop after internal testers
```

Bump `CURRENT_PROJECT_VERSION` in `project.yml` first, run `xcodegen generate`,
and put the release notes in `whats-new.txt`.

## Why it does not use Xcode's account

Releases used to go out on Xcode's cloud-managed signing, which mints a
throwaway distribution certificate and needs an Apple ID session that
`xcodebuild` can see. That session is per-machine, expires quietly, and no CI
runner has one. Build 54 was archived and merged before anybody noticed it
could not be exported.

So signing is explicit now:

- **One Apple Distribution certificate**, created 19 Aug 2026 through the App
  Store Connect API. The private key was generated locally and never left the
  machine. Apple allows two of these; this is the first.
- **Four App Store provisioning profiles**, one per bundle id — app, keyboard,
  share, broadcast.

Both live in `~/.appstoreconnect/signing/`, and the profiles are installed in
`~/Library/Developer/Xcode/UserData/Provisioning Profiles/`.

`testflight.py` signs its own ES256 JWT from the `.p8`, so nothing here has a
login to expire.

## Moving to another machine, or to CI

The certificate is the only thing that is hard to replace, because the private
key exists in exactly one place.

```sh
# on this machine
base64 -i ~/.appstoreconnect/signing/distribution.p12 | pbcopy   # → secret
```

A runner needs three secrets — the `.p12`, its password, and the `.p8` — plus
the four profiles, then:

```sh
security create-keychain -p "" build.keychain
security import distribution.p12 -k build.keychain -P "$P12_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -k "" build.keychain
cp *.mobileprovision ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/
./Tools/release/ship.sh
```

## If the certificate is ever lost

Revoke it in App Store Connect and run the four steps in the commit that added
this directory: generate a key and CSR, `POST /v1/certificates`, convert to
`.p12`, then re-create the profiles against the new certificate id. Nothing in
the repo needs to change.

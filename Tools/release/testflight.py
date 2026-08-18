#!/usr/bin/env python3
"""The App Store Connect side of a release: wait, describe, distribute.

Signs its own requests from the .p8 in ~/.appstoreconnect/private_keys, so
there is nothing to log into and nothing that expires between releases.
"""
import base64, hashlib, hmac, json, os, pathlib, subprocess, sys, time, urllib.request

KEY_ID = os.environ.get("ASC_KEY_ID", "YBPKW7X9FV")
ISSUER = os.environ.get("ASC_ISSUER_ID", "980e538b-542f-4311-b6be-3bf4306a0b7f")
APP_ID = os.environ.get("ASC_APP_ID", "6798125679")
API = "https://api.appstoreconnect.apple.com/v1"


def token() -> str:
    """ES256 JWT, twenty minutes, signed by the .p8. Uses openssl so the
    script needs nothing beyond a stock macOS or Linux runner."""
    key = pathlib.Path(os.environ.get(
        "ASC_KEY_PATH",
        pathlib.Path.home() / ".appstoreconnect/private_keys" / f"AuthKey_{KEY_ID}.p8"))
    b64 = lambda d: base64.urlsafe_b64encode(d).rstrip(b"=").decode()
    now = int(time.time())
    header = b64(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
    payload = b64(json.dumps({"iss": ISSUER, "iat": now, "exp": now + 1140,
                              "aud": "appstoreconnect-v1"}).encode())
    signing_input = f"{header}.{payload}".encode()
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", str(key)],
                         input=signing_input, capture_output=True, check=True).stdout
    # DER (r,s) -> the raw 64-byte pair JWS wants.
    def unwrap(b):
        i = 2 if b[1] < 0x80 else 3
        parts = []
        for _ in range(2):
            length = b[i + 1]
            v = b[i + 2:i + 2 + length].lstrip(b"\x00")
            parts.append(v.rjust(32, b"\x00"))
            i += 2 + length
        return b"".join(parts)
    return f"{header}.{payload}.{b64(unwrap(der))}"


def call(method, path, body=None):
    req = urllib.request.Request(
        f"{API}{path}", method=method,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        return {"errors": [{"status": e.code, "detail": e.read().decode()[:300]}]}


def await_build(version, timeout=1800):
    """A build is not addressable until Apple finishes processing it."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        d = call("GET", f"/builds?filter[app]={APP_ID}&limit=10&sort=-version")
        for b in d.get("data", []):
            a = b["attributes"]
            if str(a.get("version")) == str(version) and a.get("processingState") == "VALID":
                return b["id"]
        time.sleep(30)
    sys.exit(f"build {version} did not become VALID within {timeout}s")


def set_notes(build_id):
    """What to Test, taken from the release notes file if there is one."""
    notes = pathlib.Path("Tools/release/whats-new.txt")
    if not notes.exists():
        print("    no whats-new.txt, leaving What to Test alone")
        return
    d = call("GET", f"/builds/{build_id}/betaBuildLocalizations")
    for loc in d.get("data", []):
        r = call("PATCH", f"/betaBuildLocalizations/{loc['id']}",
                 {"data": {"id": loc["id"], "type": "betaBuildLocalizations",
                           "attributes": {"whatsNew": notes.read_text().strip()}}})
        print("    What to Test:", "errors" not in r)


def distribute(build_id, group):
    r = call("POST", f"/betaGroups/{group}/relationships/builds",
             {"data": [{"id": build_id, "type": "builds"}]})
    print("    external group:", "errors" not in r)
    r = call("POST", "/betaAppReviewSubmissions",
             {"data": {"type": "betaAppReviewSubmissions",
                       "relationships": {"build": {"data": {"id": build_id, "type": "builds"}}}}})
    print("    submitted for review:", "errors" not in r)


def status(build_id):
    d = call("GET", f"/builds/{build_id}/buildBetaDetail").get("data", {}).get("attributes", {})
    print(f"    internal: {d.get('internalBuildState')}  external: {d.get('externalBuildState')}")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "await":     print(await_build(sys.argv[2]))
    elif cmd == "notes":   set_notes(sys.argv[2])
    elif cmd == "external": distribute(sys.argv[2], sys.argv[3])
    elif cmd == "status":  status(sys.argv[2])
    else: sys.exit(f"unknown command {cmd}")

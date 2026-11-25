"""HTTP contract tests; the policy oracle mirrors OME, not a running media engine."""

import base64
import copy
import hashlib
import hmac
import http.client
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import threading
import unittest
from contextlib import redirect_stderr
from unittest.mock import patch
from urllib.parse import parse_qs, quote, urlsplit, urlunsplit


SOURCE = Path(__file__).resolve().parents[2] / "apps/ovenmediaengine/files/auth.py"
SPEC = importlib.util.spec_from_file_location("ome_auth", SOURCE)
auth = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = auth
SPEC.loader.exec_module(auth)

NOW = 1700000000
ENV = {
    "OME_STREAM_KEY": "SignKey_7d9f0b21ccad499fa045e9a62eae9e73",
    "OME_API_ACCESS_TOKEN": "ApiToken_387b527c6eed44b2963aa7ee201b21f9",
    "OME_DASHBOARD_PASSWORD": "Dashboard_2d81bd5cae0545398cbf510c4c2d9240",
    "OME_DASHBOARD_USER": "operator",
    "OME_SRT_PASSPHRASE": "Abcdef0123456789Abcdef0123456789",
}
CONFIG = {
    "appName": "app", "publicHost": "catcher.k.kpt.link", "internalHost": "catcher.k.loa.internal",
    "rtmp": {"enabled": False, "port": 1935},
    "rtmps": {"enabled": True, "port": 1936},
    "srt": {"enabled": True, "port": 8890, "playbackPort": 9998},
    "webrtc": {"enabled": True, "port": 3334},
    "policyQueryKeyName": "policy", "signatureQueryKeyName": "signature",
}
POLICY = "eyJ1cmxfZXhwaXJlIjoxNzAwMDg2NDAwMDAwfQ"
VECTORS = {
    "RTMPS Ingest": "rtmps://catcher.k.kpt.link:1936/app/live?policy=" + POLICY + "&signature=rlB_oqNLomzGktcXN2qa0s0AUTA",
    "SRT Ingest": "srt://catcher.k.kpt.link:8890/app/live?policy=" + POLICY + "&signature=WsMpd_V-MUM7uaWbg0UKt19aE6w",
    "WHIP Ingest": "https://catcher.k.kpt.link:3334/app/live?direction=whip&policy=" + POLICY + "&signature=1vxFvUUhsW9dYwYtQqRn_0gpAKY",
}


def basic(user, password):
    return "Basic " + base64.b64encode((user + ":" + password).encode()).decode()


def reference_policy_allows(url, now_ms, key=ENV["OME_STREAM_KEY"]):
    """Check only locally verifiable OME signature and admission-expiry semantics."""
    try:
        parts = urlsplit(url)
        query = parse_qs(parts.query, keep_blank_values=True)
        if len(query.get("signature", [])) != 1 or len(query.get("policy", [])) != 1:
            return False
        signature = query["signature"][0]
        unsigned_query = "&".join(part for part in parts.query.split("&") if part.split("=", 1)[0] != "signature")
        unsigned = urlunsplit((parts.scheme, parts.netloc, parts.path, unsigned_query, ""))
        expected = base64.urlsafe_b64encode(hmac.new(key.encode(), unsigned.encode(), hashlib.sha1).digest()).rstrip(b"=").decode()
        if not hmac.compare_digest(signature, expected):
            return False
        policy = query["policy"][0]
        decoded = base64.b64decode(policy + "=" * (-len(policy) % 4), altchars=b"-_", validate=True)
        expiry = json.loads(decoded)["url_expire"]
        return type(expiry) is int and expiry >= now_ms
    except (ValueError, KeyError, TypeError):
        return False


class AuthenticationHTTPTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = auth.AuthServer(auth.Config.from_dict(CONFIG), auth.Credentials.from_env(ENV),
                                     address=("127.0.0.1", 0), clock=lambda: NOW)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def request(self, method="POST", path="/ingest", body=None, headers=None, extra_headers=()):
        if body is None and method == "POST":
            body = b'{"stream":"live","ttlHours":24}'
        outgoing = {
            "Host": CONFIG["internalHost"],
            "Authorization": basic(ENV["OME_DASHBOARD_USER"], ENV["OME_DASHBOARD_PASSWORD"]),
        }
        if body is not None:
            outgoing.update({"Content-Type": "application/json", "Content-Length": str(len(body))})
        outgoing.update(headers or {})
        client = http.client.HTTPConnection(*self.server.server_address, timeout=5)
        try:
            client.putrequest(method, path, skip_host=True, skip_accept_encoding=True)
            for name, value in outgoing.items():
                if value is not None:
                    client.putheader(name, value)
            for name, value in extra_headers:
                client.putheader(name, value)
            client.endheaders(body)
            response = client.getresponse()
            return response.status, dict(response.getheaders()), response.read()
        finally:
            client.close()

    def assert_private_error(self, response, status):
        code, headers, body = response
        self.assertEqual(code, status)
        self.assertNotIn("X-OME-Authorization", headers)
        self.assertEqual(headers["Cache-Control"], "no-store")
        self.assertFalse(any(name.lower().startswith("access-control-") for name in headers))
        for name, value in ENV.items():
            if name != "OME_DASHBOARD_USER":
                self.assertNotIn(value, str(headers) + body.decode())

    def test_auth_success_returns_api_header_only(self):
        status, headers, body = self.request("GET", "/auth")
        self.assertEqual(status, 204)
        self.assertEqual(body, b"")
        self.assertEqual(headers["X-OME-Authorization"], "Basic " + base64.b64encode(ENV["OME_API_ACCESS_TOKEN"].encode()).decode())
        self.assertEqual(headers["Cache-Control"], "no-store")
        self.assertNotIn(ENV["OME_SRT_PASSPHRASE"], str(headers))
        self.assertNotIn(ENV["OME_STREAM_KEY"], str(headers))

    def test_missing_malformed_and_wrong_credentials_rejected_independently(self):
        invalid = (None, "", "Bearer token", "Basic !!!!", "Basic //8=", "Basic", "Basic YQ== extra",
                   basic("wrong", ENV["OME_DASHBOARD_PASSWORD"]),
                   basic(ENV["OME_DASHBOARD_USER"], "wrong"),
                   basic(ENV["OME_DASHBOARD_USER"], ENV["OME_DASHBOARD_PASSWORD"] + ":extra"))
        for authorization in invalid:
            for method, path in (("GET", "/auth"), ("POST", "/ingest")):
                with self.subTest(authorization=authorization, path=path):
                    response = self.request(method, path, headers={"Authorization": authorization})
                    self.assert_private_error(response, 401)
                    self.assertEqual(response[1]["WWW-Authenticate"], 'Basic realm="OME dashboard"')

    def test_duplicate_authorization_rejected(self):
        self.assert_private_error(self.request(extra_headers=(("Authorization", "Basic invalid"),)), 401)

    def test_signed_encrypted_protocol_vectors_and_no_api_leak(self):
        status, headers, body = self.request()
        self.assertEqual(status, 200)
        self.assertNotIn("X-OME-Authorization", headers)
        self.assertEqual(headers["Content-Type"], "application/json")
        self.assertEqual(headers["Cache-Control"], "no-store")
        self.assertFalse(any(name.lower().startswith("access-control-") for name in headers))
        result = json.loads(body)
        self.assertEqual(result["expiresAt"], 1700086400000)
        items = {item["tag"]: item for item in result["items"]}
        self.assertEqual(set(items), {"RTMPS Ingest", "SRT Ingest", "SRT Playback", "WHIP Ingest"})
        self.assertEqual(items["RTMPS Ingest"]["url"], VECTORS["RTMPS Ingest"])
        self.assertEqual(items["RTMPS Ingest"]["server"], "rtmps://catcher.k.kpt.link:1936/app")
        self.assertEqual(items["RTMPS Ingest"]["streamKey"], "live?" + VECTORS["RTMPS Ingest"].split("?", 1)[1])
        srt_url = items["SRT Ingest"]["url"]
        transport = "&passphrase=" + ENV["OME_SRT_PASSPHRASE"] + "&pbkeylen=32"
        self.assertEqual(srt_url, "srt://catcher.k.kpt.link:8890?streamid=" + quote(VECTORS["SRT Ingest"], safe="") + transport)
        self.assertEqual(parse_qs(urlsplit(srt_url).query)["streamid"], [VECTORS["SRT Ingest"]])
        self.assertEqual(items["SRT Playback"]["url"], "srt://catcher.k.loa.internal:9998?streamid=default%2Fapp%2Flive" + transport)
        self.assertEqual(items["WHIP Ingest"]["url"], VECTORS["WHIP Ingest"])
        for item in items.values():
            if not item["tag"].startswith("SRT "):
                self.assertNotIn(ENV["OME_SRT_PASSPHRASE"], json.dumps(item))
        for secret in ("OME_STREAM_KEY", "OME_API_ACCESS_TOKEN", "OME_DASHBOARD_PASSWORD"):
            self.assertNotIn(ENV[secret], body.decode())
            self.assertNotIn(base64.b64encode(ENV[secret].encode()).decode(), body.decode())
        for url in VECTORS.values():
            self.assertTrue(reference_policy_allows(url, NOW * 1000))
            policy = parse_qs(urlsplit(url).query)["policy"][0]
            self.assertEqual(json.loads(base64.urlsafe_b64decode(policy + "==")), {"url_expire": result["expiresAt"]})

    def test_generated_policy_rejects_missing_invalid_and_expired_credentials_locally(self):
        _, _, body = self.request()
        for item in json.loads(body)["items"]:
            if item["tag"] == "SRT Playback":
                continue
            url = item["url"]
            if item["tag"] == "SRT Ingest":
                url = parse_qs(urlsplit(url).query)["streamid"][0]
            parts = urlsplit(url)
            unsigned_path = urlunsplit((parts.scheme, parts.netloc, parts.path, "", ""))
            with self.subTest(protocol=item["tag"]):
                self.assertFalse(reference_policy_allows(unsigned_path, NOW * 1000))
                self.assertFalse(reference_policy_allows(url.replace("signature=", "signature=x"), NOW * 1000))
                self.assertFalse(reference_policy_allows(url.replace("policy=", "policy=x"), NOW * 1000))
                self.assertFalse(reference_policy_allows(url.replace("/live?", "/other?"), NOW * 1000))
                self.assertFalse(reference_policy_allows(url.replace(parts.netloc, "attacker.example:1234"), NOW * 1000))
                self.assertFalse(reference_policy_allows(url, NOW * 1000, key="different-signing-key"))
                self.assertTrue(reference_policy_allows(url, 1700086400000))
                self.assertFalse(reference_policy_allows(url, 1700086400001))

    def test_permanent_keys_survive_time_changes_but_not_signing_key_rotation(self):
        status, _, body = self.request(body=b'{"stream":"live","ttlHours":0}')
        self.assertEqual(status, 200)
        result = json.loads(body)
        self.assertIsNone(result["expiresAt"])
        regenerated = auth.connection_urls(
            auth.Config.from_dict(CONFIG), auth.Credentials.from_env(ENV), "live", 0, NOW + 100 * 365 * 86400)
        self.assertEqual(regenerated, result)
        for item in result["items"]:
            if item["tag"] == "SRT Playback":
                continue
            url = item["url"]
            if item["tag"] == "SRT Ingest":
                url = parse_qs(urlsplit(url).query)["streamid"][0]
            with self.subTest(protocol=item["tag"]):
                policy = parse_qs(urlsplit(url).query)["policy"][0]
                self.assertEqual(json.loads(base64.urlsafe_b64decode(policy + "==")),
                                 {"url_expire": 18446744073709551615})
                self.assertTrue(reference_policy_allows(url, (NOW + 100 * 365 * 86400) * 1000))
                self.assertFalse(reference_policy_allows(url, NOW * 1000, key="rotated-signing-key"))

    def test_allowed_lifetimes_and_stream_name_boundaries(self):
        for ttl in (0, 1, 24, 168):
            for stream in ("a", "A_9-z", "x" * 64):
                with self.subTest(ttl=ttl, stream=stream):
                    status, _, body = self.request(body=json.dumps({"stream": stream, "ttlHours": ttl}).encode())
                    self.assertEqual(status, 200)
                    result = json.loads(body)
                    self.assertEqual(result["expiresAt"], None if ttl == 0 else NOW * 1000 + ttl * 3600000)
                    self.assertIn("/app/" + stream + "?", result["items"][0]["url"])

    def test_invalid_payloads(self):
        payloads = [None, [], "live", {}, {"stream": "live"}, {"ttlHours": 24},
                    {"stream": "live", "ttlHours": 24, "host": "attacker.example"}]
        payloads += [{"stream": stream, "ttlHours": 24} for stream in
                     ("", "x" * 65, "../live", "live/other", "live?x=y", "live&x=y", "live#x", "live%2f", "a b", "é", "a\n", 1, None)]
        payloads += [{"stream": "live", "ttlHours": ttl} for ttl in
                     (-1, 2, 169, 1.0, True, "24", None, [], {})]
        for payload in payloads:
            with self.subTest(payload=payload):
                self.assert_private_error(self.request(body=json.dumps(payload).encode()), 400)
        for body in (b"", b"{", b"\xff", b'{"stream":"live","stream":"other","ttlHours":24}', b"[" * 1100):
            with self.subTest(body=body[:40]):
                self.assert_private_error(self.request(body=body), 400)

    def test_content_type_framing_and_size(self):
        for content_type in (None, "text/plain", "application/x-www-form-urlencoded"):
            self.assert_private_error(self.request(headers={"Content-Type": content_type}), 415)
        self.assertEqual(self.request(headers={"Content-Type": "application/json; charset=utf-8"})[0], 200)
        self.assert_private_error(self.request(body=b" " * 4097), 413)
        exact_limit = b'{"stream":"live","ttlHours":24}' + b" " * (4096 - len(b'{"stream":"live","ttlHours":24}'))
        self.assertEqual(self.request(body=exact_limit)[0], 200)
        for length in (None, "-1", "abc", "99999999999"):
            self.assert_private_error(self.request(headers={"Content-Length": length}), 400)
        self.assert_private_error(self.request(headers={"Transfer-Encoding": "chunked"}), 400)
        self.assert_private_error(self.request(extra_headers=(("Content-Length", "2"),)), 400)
        self.assert_private_error(self.request(extra_headers=(("Content-Type", "text/plain"),)), 415)

    def test_same_origin_or_authenticated_cli_only(self):
        self.assertEqual(self.request(headers={"Origin": "https://" + CONFIG["internalHost"]})[0], 200)
        self.assertEqual(self.request(headers={"Host": CONFIG["internalHost"] + ":8443", "Origin": "https://" + CONFIG["internalHost"] + ":8443"})[0], 200)
        for origin in ("null", "http://" + CONFIG["internalHost"], "https://attacker.example",
                       "https://" + CONFIG["internalHost"] + ".attacker.example", "https://" + CONFIG["internalHost"] + "/"):
            self.assert_private_error(self.request(headers={"Origin": origin}), 403)
        for host in (None, "attacker.example", CONFIG["internalHost"] + ":0", CONFIG["internalHost"] + ":65536",
                     CONFIG["internalHost"] + ":" + "9" * 100, CONFIG["internalHost"] + ":abc"):
            self.assert_private_error(self.request(headers={"Host": host}), 403)
        self.assert_private_error(self.request(extra_headers=(("Origin", "https://" + CONFIG["internalHost"]), ("Origin", "https://attacker.example"))), 403)
        self.assert_private_error(self.request(extra_headers=(("Host", "attacker.example"),)), 403)

    def test_endpoint_methods_and_no_sensitive_logging(self):
        with redirect_stderr(io.StringIO()) as log:
            self.assert_private_error(self.request("GET", "/ingest"), 404)
            self.assert_private_error(self.request("POST", "/auth"), 404)
            self.assert_private_error(self.request("GET", "/auth?secret=do-not-log"), 404)
            self.assert_private_error(self.request("OPTIONS", "/ingest"), 501)
            self.assert_private_error(self.request(headers={"Authorization": "Basic do-not-log"}), 401)
            self.assertEqual(log.getvalue(), "")


class ConfigurationTests(unittest.TestCase):
    def test_each_required_credential_missing_empty_or_known_default_fails(self):
        for name in ENV:
            for invalid in (None, "", " ", "bad\nvalue"):
                environ = dict(ENV)
                if invalid is None:
                    del environ[name]
                else:
                    environ[name] = invalid
                with self.subTest(name=name, invalid=invalid), self.assertRaises(ValueError):
                    auth.Credentials.from_env(environ)
            if name != "OME_DASHBOARD_USER":
                for default in ("changeme", "secret", "ome-internal-api-token"):
                    with self.subTest(name=name, default=default), self.assertRaises(ValueError):
                        auth.Credentials.from_env({**ENV, name: default})

    def test_credentials_independent_and_srt_encryption_key_validated(self):
        for passphrase in ("short", "x" * 31, "x" * 33, "x" * 31 + "&"):
            with self.assertRaises(ValueError):
                auth.Credentials.from_env({**ENV, "OME_SRT_PASSPHRASE": passphrase})
        with self.assertRaises(ValueError):
            auth.Credentials.from_env({**ENV, "OME_DASHBOARD_USER": "user:other"})
        with self.assertRaises(ValueError):
            auth.Credentials.from_env({**ENV, "OME_API_ACCESS_TOKEN": ENV["OME_STREAM_KEY"]})
        self.assertNotIn(ENV["OME_STREAM_KEY"], repr(auth.Credentials.from_env(ENV)))
        self.assertNotIn(ENV["OME_SRT_PASSPHRASE"], repr(auth.Credentials.from_env(ENV)))

    def test_startup_fails_before_binding_without_credentials(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(auth, "AuthServer") as server:
            with redirect_stderr(io.StringIO()) as errors, self.assertRaises(SystemExit) as exit_status:
                auth.main(["--config", "/not-read-without-credentials.json"])
            self.assertEqual(exit_status.exception.code, 2)
            self.assertIn("Invalid authentication configuration or credentials", errors.getvalue())
            server.assert_not_called()

    def test_config_rejects_injected_hosts_names_and_ports(self):
        for field in ("publicHost", "internalHost"):
            for value in ("", "https://example.com", "example.com:443", "user@example.com", "example.com/path",
                          "example.com?query", "example.com\r\nInjected: yes", "bad_label.example", "example..com", "-example.com", None):
                with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                    auth.Config.from_dict({**CONFIG, field: value})
        for protocol in ("rtmps", "srt", "webrtc"):
            for value in (0, -1, 65536, True, "443", None):
                config = copy.deepcopy(CONFIG)
                config[protocol]["port"] = value
                with self.subTest(protocol=protocol, value=value), self.assertRaises(ValueError):
                    auth.Config.from_dict(config)
        for field in ("appName", "policyQueryKeyName", "signatureQueryKeyName"):
            for value in ("", "../bad", "bad?query", "bad&query", "bad\nvalue"):
                with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                    auth.Config.from_dict({**CONFIG, field: value})
        for field, value in (("signatureQueryKeyName", "POLICY"), ("policyQueryKeyName", "direction")):
            with self.assertRaises(ValueError):
                auth.Config.from_dict({**CONFIG, field: value})
        with self.assertRaises(ValueError):
            auth.Config.from_dict({**CONFIG, "rtmp": {"enabled": True, "port": 1935}})
        with self.assertRaises(ValueError):
            auth.AuthServer(auth.Config.from_dict(CONFIG), auth.Credentials.from_env(ENV), address=("0.0.0.0", 8082))

    def test_disabled_protocols_omitted_and_custom_query_keys_signed(self):
        config = copy.deepcopy(CONFIG)
        config["rtmps"]["enabled"] = False
        config["srt"]["enabled"] = False
        config["policyQueryKeyName"] = "admission"
        config["signatureQueryKeyName"] = "proof"
        result = auth.connection_urls(auth.Config.from_dict(config), auth.Credentials.from_env(ENV), "live", 24, NOW)
        self.assertEqual([item["tag"] for item in result["items"]], ["WHIP Ingest"])
        url = result["items"][0]["url"]
        unsigned, signature = url.rsplit("&proof=", 1)
        self.assertIn("?direction=whip&admission=" + POLICY, unsigned)
        expected = base64.urlsafe_b64encode(hmac.new(ENV["OME_STREAM_KEY"].encode(), unsigned.encode(), hashlib.sha1).digest()).rstrip(b"=").decode()
        self.assertEqual(signature, expected)
        self.assertNotIn(ENV["OME_SRT_PASSPHRASE"], json.dumps(result))


if __name__ == "__main__":
    unittest.main()

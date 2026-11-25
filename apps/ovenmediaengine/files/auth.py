#!/usr/bin/env python3
"""Loopback-only dashboard authentication and encrypted OME connection URLs."""

import argparse
import base64
import binascii
import hashlib
import hmac
import json
import os
import re
import sys
import time
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import quote


STREAM_NAME = re.compile(r"[A-Za-z0-9_-]{1,64}\Z")
QUERY_KEY = re.compile(r"[A-Za-z][A-Za-z0-9_-]{0,63}\Z")
HOST_LABEL = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\Z")
# OME requires an unsigned 64-bit epoch-millisecond expiry, even for permanent keys.
MAX_URL_EXPIRE = (1 << 64) - 1
KNOWN_DEFAULTS = frozenset({
    "password", "secret", "default", "admin", "changeme", "change-me",
    "change_me", "ovenmediaengine", "ome-internal-api-token",
})


def _host(value):
    if (not isinstance(value, str) or not 1 <= len(value) <= 253
            or not all(HOST_LABEL.fullmatch(label) for label in value.split("."))):
        raise ValueError("Invalid host configuration")
    return value.lower()


def _port(value):
    if type(value) is not int or not 1 <= value <= 65535:
        raise ValueError("Invalid port configuration")
    return value


@dataclass(frozen=True)
class Config:
    app_name: str
    public_host: str
    internal_host: str
    rtmps_port: int | None
    srt_port: int | None
    srt_playback_port: int | None
    whip_port: int | None
    policy_key: str
    signature_key: str

    @classmethod
    def from_dict(cls, data):
        if not isinstance(data, dict):
            raise ValueError("Invalid configuration")
        app = data.get("appName")
        if not isinstance(app, str) or not STREAM_NAME.fullmatch(app):
            raise ValueError("Invalid application configuration")
        policy = data.get("policyQueryKeyName")
        signature = data.get("signatureQueryKeyName")
        if (not isinstance(policy, str) or not QUERY_KEY.fullmatch(policy)
                or not isinstance(signature, str) or not QUERY_KEY.fullmatch(signature)
                or len({policy.lower(), signature.lower(), "direction"}) != 3):
            raise ValueError("Invalid policy configuration")
        if data.get("rtmp", {}).get("enabled", False) is not False:
            raise ValueError("Unencrypted publishing is not permitted")
        ports = []
        for protocol in ("rtmps", "srt", "webrtc"):
            settings = data.get(protocol)
            if not isinstance(settings, dict) or type(settings.get("enabled")) is not bool:
                raise ValueError("Invalid protocol configuration")
            port = _port(settings.get("port"))
            ports.append(port if settings["enabled"] else None)
        playback_port = _port(data["srt"].get("playbackPort")) if ports[1] else None
        return cls(app, _host(data.get("publicHost")), _host(data.get("internalHost")),
                   ports[0], ports[1], playback_port, ports[2], policy, signature)


@dataclass(frozen=True)
class Credentials:
    stream_key: bytes = field(repr=False)
    api_authorization: str = field(repr=False)
    dashboard_digest: bytes = field(repr=False)
    srt_passphrase: str = field(repr=False)

    @classmethod
    def from_env(cls, environ):
        names = ("OME_STREAM_KEY", "OME_API_ACCESS_TOKEN", "OME_DASHBOARD_PASSWORD",
                 "OME_DASHBOARD_USER", "OME_SRT_PASSPHRASE")
        values = []
        for name in names:
            value = environ.get(name)
            if (not isinstance(value, str) or not value.strip()
                    or any(ord(character) < 32 or ord(character) == 127 for character in value)
                    or (name != "OME_DASHBOARD_USER" and value.lower() in KNOWN_DEFAULTS)):
                raise ValueError("Required credentials are missing or invalid")
            values.append(value)
        stream_key, api_token, password, user, srt_passphrase = values
        if (":" in user or not re.fullmatch(r"[A-Za-z0-9]{32}", srt_passphrase)
                or len({stream_key, api_token, password, srt_passphrase}) != 4):
            raise ValueError("Required credentials are invalid or reused")
        digest = hashlib.sha256((user + ":" + password).encode("utf-8")).digest()
        api_authorization = "Basic " + base64.b64encode(api_token.encode("utf-8")).decode("ascii")
        return cls(stream_key.encode("utf-8"), api_authorization, digest, srt_passphrase)


def _base64url(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _signed_url(base, policy, config, credentials):
    # OME signs the serialized URL with only the signature query removed; order matters.
    separator = "&" if "?" in base else "?"
    unsigned = base + separator + config.policy_key + "=" + policy
    signature = _base64url(hmac.new(credentials.stream_key, unsigned.encode("ascii"), hashlib.sha1).digest())
    return unsigned + "&" + config.signature_key + "=" + signature


def connection_urls(config, credentials, stream, ttl_hours, now):
    expires_at = None if ttl_hours == 0 else int(now * 1000) + ttl_hours * 60 * 60 * 1000
    # Use OME's maximum expiry for permanent keys; never set stream_expire.
    policy_expiry = MAX_URL_EXPIRE if expires_at is None else expires_at
    policy = _base64url(json.dumps({"url_expire": policy_expiry}, separators=(",", ":")).encode("ascii"))
    path = "/" + config.app_name + "/" + stream
    items = []
    if config.rtmps_port:
        server = "rtmps://{}:{}/{}".format(config.public_host, config.rtmps_port, config.app_name)
        url = _signed_url(server + "/" + stream, policy, config, credentials)
        items.append({"tag": "RTMPS Ingest", "url": url, "server": server,
                      "streamKey": stream + "?" + url.split("?", 1)[1]})
    transport = "&passphrase=" + credentials.srt_passphrase + "&pbkeylen=32"
    if config.srt_port:
        server = "srt://{}:{}".format(config.public_host, config.srt_port)
        inner = _signed_url(server + path, policy, config, credentials)
        items.append({"tag": "SRT Ingest", "url": server + "?streamid=" + quote(inner, safe="") + transport})
        playback = "srt://{}:{}?streamid=".format(config.internal_host, config.srt_playback_port)
        items.append({"tag": "SRT Playback", "url": playback + quote("default" + path, safe="") + transport})
    if config.whip_port:
        base = "https://{}:{}{}?direction=whip".format(config.public_host, config.whip_port, path)
        items.append({"tag": "WHIP Ingest", "url": _signed_url(base, policy, config, credentials)})
    return {"expiresAt": expires_at, "items": items}


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key")
        result[key] = value
    return result


class AuthServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, config, credentials, address=("127.0.0.1", 8082), clock=time.time):
        if address[0] != "127.0.0.1":
            raise ValueError("Authentication service must bind loopback")
        self.config = config
        self.credentials = credentials
        self.clock = clock
        super().__init__(address, AuthHandler)

    def handle_error(self, request, client_address):
        # Never include a request, signed URL, authorization header, or traceback.
        sys.stderr.write("Authentication service request failed\n")


class AuthHandler(BaseHTTPRequestHandler):
    server_version = "OMEAuth"
    sys_version = ""

    def setup(self):
        super().setup()
        self.connection.settimeout(10)

    def log_message(self, format, *args):
        pass

    def send_error(self, code, message=None, explain=None):
        self._respond(code, {"error": "Request rejected"})

    def _respond(self, status, payload=None, headers=()):
        body = b"" if payload is None else json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        if payload is not None:
            self.send_header("Content-Type", "application/json")
        for name, value in headers:
            self.send_header(name, value)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)
        self.close_connection = True

    def _authenticated(self):
        headers = self.headers.get_all("Authorization", [])
        decoded = b""
        valid = False
        if len(headers) == 1:
            parts = headers[0].split()
            if len(parts) == 2 and parts[0].lower() == "basic":
                try:
                    decoded = base64.b64decode(parts[1], validate=True)
                    valid = True
                except (ValueError, binascii.Error):
                    pass
        matches = hmac.compare_digest(hashlib.sha256(decoded).digest(), self.server.credentials.dashboard_digest)
        if valid and matches:
            return True
        self._respond(401, {"error": "Unauthorized"}, (("WWW-Authenticate", 'Basic realm="OME dashboard"'),))
        return False

    def do_GET(self):
        if self.path != "/auth":
            self.send_error(404)
        elif self._authenticated():
            self._respond(204, headers=(("X-OME-Authorization", self.server.credentials.api_authorization),))

    def do_POST(self):
        if self.path != "/ingest":
            self.send_error(404)
            return
        if not self._authenticated():
            return
        hosts = self.headers.get_all("Host", [])
        origins = self.headers.get_all("Origin", [])
        host = hosts[0] if len(hosts) == 1 else ""
        parts = host.split(":")
        valid_host = len(parts) in (1, 2) and parts[0].lower() == self.server.config.internal_host
        if len(parts) == 2:
            valid_host = (valid_host and 1 <= len(parts[1]) <= 5 and parts[1].isascii()
                          and parts[1].isdigit() and 1 <= int(parts[1]) <= 65535)
        if (not valid_host or len(origins) > 1
                or (origins and origins[0] != "https://" + host)):
            self.send_error(403)
            return
        content_types = self.headers.get_all("Content-Type", [])
        if len(content_types) != 1 or content_types[0].split(";", 1)[0].strip().lower() != "application/json":
            self.send_error(415)
            return
        lengths = self.headers.get_all("Content-Length", [])
        if self.headers.get_all("Transfer-Encoding") or len(lengths) != 1 or not re.fullmatch(r"[0-9]{1,10}", lengths[0]):
            self.send_error(400)
            return
        length = int(lengths[0])
        if length > 4096:
            self.send_error(413)
            return
        try:
            body = self.rfile.read(length)
            if len(body) != length:
                raise ValueError("Incomplete body")
            payload = json.loads(body.decode("utf-8"), object_pairs_hook=_unique_object)
            if not isinstance(payload, dict) or set(payload) != {"stream", "ttlHours"}:
                raise ValueError("Invalid payload")
            stream = payload["stream"]
            ttl = payload["ttlHours"]
            if (not isinstance(stream, str) or not STREAM_NAME.fullmatch(stream)
                    or type(ttl) is not int or ttl not in (0, 1, 24, 168)):
                raise ValueError("Invalid payload")
        except (ValueError, UnicodeError, RecursionError):
            self.send_error(400)
            return
        self._respond(200, connection_urls(self.server.config, self.server.credentials, stream, ttl, self.server.clock()))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default="/etc/ome-auth/config.json")
    args = parser.parse_args(argv)
    try:
        credentials = Credentials.from_env(os.environ)
        with open(args.config, encoding="utf-8") as source:
            config = Config.from_dict(json.load(source, object_pairs_hook=_unique_object))
    except (OSError, ValueError, TypeError, AttributeError):
        parser.error("Invalid authentication configuration or credentials")
    with AuthServer(config, credentials) as server:
        server.serve_forever()


if __name__ == "__main__":
    main()

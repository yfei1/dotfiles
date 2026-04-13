# Global Rules

## Proxy: Apple Internal vs External Traffic
Apple corporate proxy is set by default in terminal sessions. It MUST be unset for any traffic going to the public internet.

- **Proxy ON** (default state): Apple-internal destinations (`*.apple.com` internal domains, github.pie, Whisper, Radar, internal APIs, internal PyPI)
- **Proxy OFF**: Everything else — any public internet destination (GCP, AWS, Azure, PyPI, GitHub.com, Docker Hub, npm, public APIs, etc.)

Before running any command that hits the public internet:
```bash
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
```

Common proxy values: `http://localhost:5640`, `http://localhost:3256`

**Rule of thumb: internal destination → proxy on. External destination → proxy off.**

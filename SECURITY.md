# Security Policy

## Supported version

Security fixes target the latest published PocketLLM Lite release. Older builds may not receive fixes.

## Report a vulnerability privately

Do not open a public issue for an unpatched vulnerability. Email **prashantc592114@gmail.com** with:

- the affected version and platform;
- reproducible steps or a minimal proof of concept;
- the expected impact and any known preconditions; and
- a safe way to contact you about remediation.

Please avoid accessing other people's data, disrupting services, or publishing exploit details before a fix is available. Receipt will normally be acknowledged within 48 hours, but remediation time depends on severity and reproducibility.

## Product security boundaries

PocketLLM Lite is local-first, not network-free:

- chats, settings, imported documents, indexes, memories, and local notes are stored in the application sandbox;
- provider API keys and embedded-server keys use platform secure storage;
- encrypted exports use AES-256-GCM with a PBKDF2-derived key and are validated before an import replaces local data;
- local inference stays on the device, while configured Ollama or OpenAI-compatible providers receive the prompt and context needed for a request;
- explicit model/update downloads, Tavily search, GitHub skill installation, and external links contact their displayed destinations; and
- Strict Offline Mode centrally blocks non-loopback app-managed HTTP clients and policy-aware external navigation. It cannot prevent another app from using the network after the user intentionally hands content to it, such as an email composer.

The optional embedded OpenAI-compatible server requires an API key. Binding it beyond loopback exposes the service to the selected network; use a trusted LAN and firewall because v1.0.36 does not provide TLS, trusted-host, or CORS allowlists.

Downloaded models and third-party skills remain third-party content. Review their source, license, checksum, requested capabilities, and output before relying on them.

# Backup fixtures

- `mobile-v3-fixture.pllm`: synthetic mobile-shaped v3 archive. Password: `fixture-password`. Web CI must decrypt it.
- `web-v4-fixture.pllm`: synthetic web-shaped v4 archive with the web extension. Password: `fixture-web-v4`. Flutter CI must decrypt it.

Both use fixed salt/nonce values **only so compatibility regressions are reproducible**. Production exports must always use cryptographically random salt and nonce. No real user data or credentials belong here.

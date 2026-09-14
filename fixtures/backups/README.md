# Backup fixtures

`mobile-v3-fixture.pllm` is deterministic, contains only synthetic data, and uses the password `fixture-password`.

Its salt and nonce are fixed on purpose so browser/mobile compatibility failures are reproducible. Never copy this construction into production backup creation, where salt and nonce must remain random.

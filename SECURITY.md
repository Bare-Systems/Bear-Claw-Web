# Security Policy

BearClawWeb is an operator-facing UI with multiple backend integrations. Treat auth, secret handling, and service-boundary changes as security-sensitive.

## Reporting

Report vulnerabilities privately with:

- affected route or workflow
- environment and deployment shape
- reproduction steps
- token, session, or privilege implications

## Baseline Expectations

- Do not expose service backends by weakening the documented network contract.
- Keep secrets out of source control, fixtures, and logs.
- Security pages should degrade safely when Ursa is unavailable.
- Authentication and authorization changes must update `README.md`, `BLINK.md`, and this file.

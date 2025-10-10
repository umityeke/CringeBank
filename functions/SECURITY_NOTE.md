# Security notice

This repository contained a populated `functions/.env` with SMTP credentials. Secrets should never be committed. Immediate actions:

- Revoke/rotate the leaked SMTP app password in your email provider.
- Remove the secret from Git history (filter-rewrite) if repository is public or shared.
- Keep only .env.example in source control; .env must be in .gitignore (already updated).
- Consider using Secret Manager / environment config (functions:config) for production.

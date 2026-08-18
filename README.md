# TCRMMT Patches

Corrective production patches for the TCRMMT deployment.

## Current patch

- `SUPER-ADMIN-LOGIN-JS-PARSE-FIX-V1/`
  - Fixes the Super Admin login page appearing unresponsive because the delivered inline JavaScript contains a malformed regex literal.
  - Designed for `/var/www/TCRMMT` and PM2 process `tamiyouz-crm`.
  - Does not run `git pull`, `git reset`, database migrations, or Nginx changes.
  - Rebuilds from the existing reviewed source, validates the generated bundle and live inline script, then reloads PM2 only after validation passes.

See the patch folder for the apply script, operator prompt, and diagnosis notes.

# SUPER-ADMIN-LOGIN-JS-PARSE-FIX-V1

## Root cause

Production serves malformed inline JavaScript in `/super-admin`:

```js
replace(//+$/,'')
```

That is a JavaScript parse error. Because the whole inline script fails before execution, the `#loginBtn` click handler is never registered and clicking **Sign In** produces no request.

The diagnosed live source tree already contained the corrected escaped expression in `server/_core/index.ts`, while the running `dist/index.js` and live HTML contained the malformed generated text. Therefore this patch rebuilds from the existing source tree and refuses to reload PM2 unless the generated artifact passes syntax and regression checks.

## Safety boundaries

This patch intentionally does **not**:

- run `git pull`, `git reset`, checkout, or clean the working tree;
- overwrite the user's uncommitted source changes;
- modify `.env`;
- run database migrations;
- modify Nginx;
- change Super Admin credentials.

It records the current Git/PM2 state and backs up the previous `dist/index.js` under `/tmp` before building.

## Apply

From this patch directory on the server:

```bash
bash APPLY.sh /var/www/TCRMMT
```

The script:

1. verifies that the source contains the corrected escaped regex and not the malformed expression;
2. records deployment state and backs up the existing bundle;
3. runs the project's existing `npm run build`;
4. runs `node --check dist/index.js`;
5. refuses deployment if the known malformed regex still exists;
6. reloads PM2 process `tamiyouz-crm` only after checks pass;
7. fetches the live `/super-admin`, syntax-checks its inline JavaScript, confirms the login click wiring exists, and confirms the login API is reachable.

## Expected result

`VERIFY.sh` ends with:

```text
[VERIFY] PASS
```

No valid password is required for the API reachability smoke test; it sends an empty JSON body and accepts the expected authentication/validation statuses only.

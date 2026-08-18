# SUPER-ADMIN-LOGIN-JS-TEMPLATE-ESCAPE-FIX-V2

## Root cause

The Super Admin HTML/JavaScript is embedded inside a JavaScript/TypeScript template literal in `server/_core/index.ts`.

The source currently contains:

```js
replace(/\/+$/,'')
```

That looks like a valid JavaScript regex when viewed as source text, but inside the outer template literal the `\/` escape is cooked to `/`. The generated HTML therefore receives:

```js
replace(//+$/,'')
```

which breaks the browser inline script before the login click handler is registered.

The source template must contain one additional backslash:

```js
replace(/\\/+$/,'')
```

so that the generated HTML contains the intended browser JavaScript:

```js
replace(/\/+$/,'')
```

## Safety

`APPLY.sh`:

- targets `/var/www/TCRMMT` by default;
- backs up `server/_core/index.ts` and the existing `dist/index.js` to `/tmp`;
- changes only the exact known template-literal occurrence and refuses ambiguous matches;
- does not run git pull/reset/checkout/clean;
- does not touch `.env`, DB, Nginx, credentials, or unrelated files;
- runs `npm run build` and `node --check dist/index.js`;
- refuses PM2 reload if the generated bundle still contains the malformed browser text;
- reloads `tamiyouz-crm` only after all pre-reload safeguards pass;
- runs live `/super-admin` inline-script syntax validation and login API smoke testing after reload.

## Run

```bash
bash APPLY.sh /var/www/TCRMMT
```

If any safeguard fails, stop and report the exact output. Do not bypass it.

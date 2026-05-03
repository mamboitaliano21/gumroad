# Pages

A Page is a separate primitive from a Product. It accepts any HTML/Tailwind, is sanitized server-side, renders chromeless at `/pg/:slug`, and can be linked to 0..N products. Use cases: product landing pages, profiles, bundles. v1 ships authoring via the [`gumroad` CLI](https://github.com/antiwork/gumroad-cli) (no dashboard UI).

This doc is for **internal reviewers** verifying the Pages M1 PR chain end-to-end on a fresh checkout. No Claude Code, no agent skills, no Denis-local tooling — every command below is copy-pasteable.

## Reviewer recipe — Browser demo

Verifies: model + migrations, sanitizer, template expansion, public render route, checkout link.

1. Bring the dev stack up. Follow [the standard setup in `README.md`](../README.md#installation) — `bin/setup`, `make local`, `bin/rails db:prepare`. Stop when you have docker containers running and would normally run `bin/dev`.

2. Seed the demo data:

   ```sh
   bin/rails db:seed
   ```

   At the **absolute bottom** of the seed output you should see:

   ```
   ========================================================================
     Pages MacWhisper demo
     Page (chromeless):  https://gumroad.dev/pg/<slug>
     Product page:       https://seller.gumroad.dev/l/<permalink>
   ========================================================================
   ```

   Both URLs are seeded fresh on each `db:seed`. The Page is published, sanitized strictly, and linked to the seeded MacWhisper product.

3. Start the Rails app:

   ```sh
   bin/dev
   ```

4. Open the chromeless Page URL from step 2 in a browser. You should see an Apple-style MacWhisper landing page — full creator canvas, no Gumroad header chrome, all Tailwind classes intact, hero image rendered, three pricing tiers laid out as a grid.

5. Click any tier's "Buy" button. You should land directly on `https://app.gumroad.dev/checkout?product=<permalink>&option=<external_id>` with the **correct tier pre-selected** in the checkout drawer. Token expansion is happening server-side — view the rendered Page source to confirm `{{product.variants[N].checkout_url}}` was substituted to a real URL.

6. (Optional) Complete checkout with a [Stripe test card](https://stripe.com/docs/testing#cards) (`4242 4242 4242 4242`, any future expiry, any CVC) to verify the full purchase flow against a Pages-originated checkout.

## Reviewer recipe — CLI authoring demo

Verifies: cli `pages init|preview|create|list|view|update|delete`, OAuth-token-based auth against the local stack, the new pre-baked-from-permalink init flow.

The cli's OAuth login flow is hardcoded to production (`app.gumroad.com`), so for local dev you bypass OAuth and stuff a Doorkeeper token directly. The seed already creates a "Gumroad CLI" Doorkeeper application under `seller@gumroad.com`.

1. Recipe A above, through step 3 (`bin/dev` running, dev stack live, MacWhisper Page seeded).

2. Clone and build the cli:

   ```sh
   git clone https://github.com/antiwork/gumroad-cli.git
   cd gumroad-cli
   git checkout feature/pages-m1
   go build -o gumroad ./cmd/gumroad
   ```

3. Log into the local app at https://app.gumroad.dev/login as `seller@gumroad.com` / `password` (2FA code: `000000`).

4. Visit https://app.gumroad.dev/settings/advanced. Find the **"Gumroad CLI"** application card and copy its access token.

5. Configure the cli to talk to the local dev API and load the token:

   ```sh
   echo '<paste-token-here>' | GUMROAD_API_BASE_URL=https://api.gumroad.dev/v2 ./gumroad auth login
   ```

   Verify auth:

   ```sh
   GUMROAD_API_BASE_URL=https://api.gumroad.dev/v2 ./gumroad auth status
   ```

   Should print `Logged in as seller@gumroad.com`. Set the env var once for the rest of the session:

   ```sh
   export GUMROAD_API_BASE_URL=https://api.gumroad.dev/v2
   ```

6. List existing Pages — should include the seeded MacWhisper Page from Recipe A:

   ```sh
   ./gumroad pages list
   ```

7. The killer-feature command — pre-bake a starter Page for any product permalink. The seed printed the MacWhisper permalink in step 2 of Recipe A; substitute it below:

   ```sh
   mkdir -p /tmp/pages-demo && cd /tmp/pages-demo
   /path/to/gumroad-cli/gumroad pages init <macwhisper-permalink>
   ```

   You should see:

   ```
   ✓ Wrote gumroad-page.html (MacWhisper Demo — €0)
   ✓ Wrote CLAUDE.md (agent instructions for Gumroad Pages)
   ✓ Wrote .cursor/rules/gumroad-pages.mdc

   Next:
     gumroad pages preview @gumroad-page.html
     gumroad pages create --title "MacWhisper Demo" --content @gumroad-page.html --product <macwhisper-permalink> --publish
   ```

   Open `gumroad-page.html` directly in a browser (no preview server). The page already shows MacWhisper's name, cover, description, and three pricing tiers as concrete values — not `{{product.X}}` placeholders. Only the per-tier Buy button `href`s contain `{{product.variants[N].checkout_url}}` tokens (those resolve at server render time).

8. Hot-reload preview the file — sanitizer feedback shows in a sidebar at http://localhost:7373:

   ```sh
   /path/to/gumroad-cli/gumroad pages preview @gumroad-page.html
   ```

   Edit `gumroad-page.html` in your editor, the browser auto-refreshes, sanitizer errors stream into the sidebar. Ctrl-C to exit.

9. Publish — copy-paste the `Next:` command from step 7:

   ```sh
   /path/to/gumroad-cli/gumroad pages create --title "MacWhisper Demo" --content @gumroad-page.html --product <macwhisper-permalink> --publish
   ```

   Output prints the published Page URL (`https://gumroad.dev/pg/<new-slug>`). Open it — variant Buy buttons now link to `/checkout?product=<permalink>&option=<external_id>` with the correct tier pre-selected.

## Architecture pointers

Read in this order if you want depth:

- `app/models/page.rb`, `app/models/page_product.rb` — model + join table.
- `app/services/pages/html_scrubber.rb` — Loofah-based allowlist sanitizer (strict + lossy modes).
- `app/services/pages/template_expander.rb` — `{{product.X}}` / `{{seller.X}}` token substitution. Runs BEFORE the scrubber so token-produced URLs flow through the URL allowlist.
- `app/controllers/api/v2/pages_controller.rb` — read/write/sanitize endpoints (Doorkeeper-authed).
- `app/controllers/pages_controller.rb` + `app/views/layouts/page.html.erb` — public chromeless render at `/pg/:slug`.
- `db/seeds/030_development/zz_pages.rb` + `db/seeds/030_development/pages/macwhisper_demo.html` — the seeded demo Page.

## Out of v1 scope

- Dashboard UI / WYSIWYG editor (cli only)
- Custom domains for Pages
- Page-level analytics
- Drafts / versioning / scheduled publish
- Different commerce fields per Page — price, refund policy stay locked to the Product
- Creator-controlled JavaScript, forms, iframes (sanitizer strips them all — that IS the security boundary)
- Inline `<style>` or `style=` attributes — Tailwind classes only

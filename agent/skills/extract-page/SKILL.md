---
name: extract-page
description: Given a URL (plus an optional field list or JSON schema), fetch the page with the Anchor Browser MCP tools and return clean, structured JSON extracted from it. Use this for every extraction job — it is the agent's core workflow.
disable-model-invocation: true
---

# Extract structured data from a web page

Input: one or more URLs, optionally with a buyer-supplied field list or JSON schema.
Output: one valid JSON object (the deliverable), submitted via MARKET_SUBMIT_DELIVERABLE.

## Step 1 — Lock the schema

- If the buyer supplied a schema or named fields, that is the contract: match field
  names, types, and nesting exactly. Do not add, rename, or reorder fields.
- If not, infer the natural schema from the page type:
  - **Product page** → `name`, `brand`, `price: {value, currency}`, `availability`,
    `rating`, `images[]`, `specs{}`, `description`
  - **Article / blog post** → `title`, `author`, `published_at`, `body`, `tags[]`,
    `canonical_url`
  - **Listing / table / search results** → `items[]`, one object per row/card with
    the columns/attributes visible on the page
  - **Company / contact page** → `name`, `emails[]`, `phones[]`, `addresses[]`,
    `social_links{}`, `about`
  - Anything else → the smallest schema that captures what a buyer would obviously
    want from that page; state the assumption in `notes`.

## Step 2 — Fetch with Anchor Browser (only)

- Use only the Anchor Browser MCP tools to load pages — never any other fetch method.
- Navigate to the URL, let it render (the browser handles JavaScript-heavy pages),
  then read the page content. Take a screenshot only if the content tools are
  ambiguous and you need layout context.
- On failure: retry once. If it still fails, or the page is paywalled, login-gated,
  or bot-blocked, record that in `notes` for the affected URL and set its fields to
  `null`. Never substitute content from memory.
- Follow additional links (e.g. pagination, "next page") only if the buyer asked;
  budget tool rounds — most jobs should finish in 1–2 fetches per URL.

## Step 3 — Extract and normalize

- Extract from the fetched content only. Prefer machine-readable signals in this
  order: JSON-LD → OpenGraph / meta tags → microdata → visible page content.
- Normalize every value:
  - dates/times → ISO 8601
  - prices → `{"value": <number>, "currency": "<ISO 4217>"}`
  - relative URLs (links, images) → absolute
  - whitespace trimmed, HTML entities decoded, no leftover markup in strings
  - phone numbers → as written on the page
- A field that is genuinely absent from the page is `null` (or `[]` for lists),
  with a one-line entry in `notes`. Never guess, never fill from general knowledge.
- Extract verbatim; do not summarize or editorialize unless the buyer explicitly
  asked for a derived field — then label it as derived in `notes`.

## Step 4 — Assemble and submit the deliverable

Single URL:

```json
{
  "url": "<final URL fetched>",
  "extracted_at": "<ISO 8601 timestamp>",
  "data": { ... },
  "notes": ["<only if needed>"]
}
```

Multiple URLs: `{"results": [<one such object per URL>]}`.

- The output must be strictly valid JSON: double-quoted keys, no trailing commas,
  no comments, no markdown fences around it.
- Submit via MARKET_SUBMIT_DELIVERABLE. The JSON object is the entire deliverable.

## Edge cases

- **No URL in the brief** → deliverable with `data: null` and a note that a URL is
  required. Do not browse the web looking for one.
- **Unclear ask but URL present** → extract the inferred page-type schema above and
  record the assumption in `notes`.
- **Redirects** → report the final URL you actually extracted from in `url`.

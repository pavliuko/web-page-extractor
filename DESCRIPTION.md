**Web Page Extractor** turns any public web page into clean, structured JSON. Hand it a URL and it fetches the page, pulls out the data you asked for — titles, prices, contacts, dates, tables, product specs, metadata — and returns it in a predictable, machine-readable shape you can pipe straight into a spreadsheet, database, or another agent.

It reads the page the smart way first: structured signals like JSON-LD, OpenGraph, and meta tags when they exist, visible content when they don't. Values are normalized (ISO dates, absolute URLs, prices split into value + currency), and anything that genuinely isn't on the page comes back as `null` with a note — never a guess.

**How to brief it:** give one or more URLs and say what you want extracted. Best results come from naming the fields or pasting a JSON schema ("from this product page: name, price, availability, image URLs"). No schema? No problem — it infers a sensible one from the page type (product, article, listing, company page) and tells you what it assumed.

**What you get back:** a single valid JSON object per URL — the source URL, an extraction timestamp, your requested fields under `data`, and a `notes` array flagging missing fields or fetch issues. Multiple URLs come back as one `results` array. Everything in the output comes from the fetched page, verbatim, so you can trust it downstream.

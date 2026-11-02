## Inspiration
I have a home 3D printer and I make figurines — the golden dragon in our logo went exactly this way: a picture, a 3D model, a print. People keep asking me for custom pieces, but every order was the same tiring loop: "what do you mean exactly?", "how much will it cost?", "how do I pay you?". ShapePrompt is my answer: a small online workshop where AI does the talking, code does the math, PayPal does the money — and I do the making.

## What it does
**Three ways to order, all paid with PayPal:**

1. **A ready figurine.** Tell the little golden dragon what you want — *"a shiny dragon figurine as a gift, up to 100 zł"*. He picks the work, material and size from the real catalog and builds the order. You add your own words for the base, confirm the terms and pay with PayPal.
2. **A 3D file.** Have a printer? Buy the STL file and download it right after the payment. The link works for 7 days.
3. **From your picture.** Send a photo or a drawing. The dragon reads it and fills in the order card for you (figures, height, material, color), and warns you if faces or hands are blurred. A **15 zł deposit** sends the request, so the maker gets only real orders.

**For the maker:** after the deposit, an email arrives with the whole order and two signed links — **Return the deposit** (a PayPal refund in one click) and **Block this customer**. A second click on Return is refused: *"the deposit was already returned"*.

**Speaks your language:** English, Ukrainian, Polish, German and French, translated on the fly.

## How I built it
- **Flutter web** app, hosted on GitHub Pages.
- **Cloudflare Worker** as the only server: it holds every key, so the app has none. **Turnstile** lets only real people talk to the dragon, and a **rate limit** protects the free AI quota.
- **Gemini** is the dragon's brain. It chooses only from the real catalog and reads pictures (vision) to fill the order card. It never sets a price.
- **Prices are counted by code** from the maker's real costs — filament price per gram, grams and hours from the slicer, electricity, labor — exported to `catalog.json`. The Worker prices every order again before PayPal sees it.
- **PayPal Orders API v2**: create → the buyer approves → capture. **PayPal Refunds API** for the deposit, idempotent.
- **Cloudflare KV** keeps requests and paid orders; the STL file is served only for a paid order.
- **Cloudflare Email** sends the maker's email with **HMAC-signed links**; a link opens a page with a button, because a mail app opening a link must never move money.
- The plan lived in files: a one-page scope, then a build log for every day (in the repo).

## Challenges I ran into
- The AI wanted to be too helpful: it argued about colors, praised a blurry AI picture as "very sharp", once returned raw JSON instead of words. The fix was always the same — **the AI prepares, code and a person decide**: structured checks, a second try, and a friendly "my words got tangled".
- Language buttons changed the labels but not the chat. Now the dragon speaks English and the screen translates, so one button turns the whole conversation.
- A saved request looked "sent" when it wasn't. Now it says "Step 1 of 2 … Not sent to our master yet … Step 2 of 2: the deposit", and an unpaid request waits on the home page for 48 hours.
- Being a fair shop: 18+ and order terms before any payment, no weapons or hate symbols, and honest legal wording (Art. 38 point 3 of the Polish Consumer Rights Act for made-to-order pieces).

## Accomplishments that I'm proud of
- **Every money path is tested end to end in Sandbox**: ready work, 3D file download, deposit, refund from the email, blocking a customer.
- The AI is useful but never in charge of money.
- It is my real workshop: the figurines, the 3D files and the dragon are mine.

## What I learned
Structured checks beat an AI's first impression. Money flows must be idempotent. And a clear "where is my order now" is as important as the payment itself.

## What's next
Real payments (live PayPal, the paid Gemini tier for EU customers), the maker's own website craftaxi.com, more materials and four-color prints.

## AI tools used
- **Gemini** — inside the app: the dragon's conversation, the order card from a picture, safety checks.
- **Claude (Claude Code)** — my coding partner: we wrote the Flutter app, the Worker, the music for the video and the video edit together.
- **Gemini image generation** — the logo and the dragon art; **Canva** — the little dragon's animation; **MakerWorld image-to-3D** — the first 3D model of the dragon, then finished and printed by me.
- Music in the video: original, composed in code.

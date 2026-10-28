# ShapePrompt — Build Log

How the app changed while we built it, and why. The commit history has the
matching code.

The rule that never changes: **AI understands, code counts, the maker makes.**
Prices come from real costs and real formulas, never from a guess. AI draws
sketches only; the final 3D model is made and refined by a real maker.

## 26 October — name, logo, scope, first screen

| What we decided | What we noticed | Why it matters |
|---|---|---|
| Name **ShapePrompt** | We checked six names: PrintCraft, CraftPrint, Axis3D and PolyForge3D were already used by 3D printing services or tools | A name nobody else in 3D printing uses |
| Logo: a golden **dragon shaped like the letter S** inside a hexagon crystal, with printer nozzles | The first version had an "A" for AI and a small star that looked like another brand's mark | The dragon is the maker's own: it went through exactly this path — picture → 3D model → print |
| Background **"wet asphalt"** #1E2226 with gold, emerald and purple from the logo | Pure black was too much black; lighter grey looked dull and the gold faded | The gold glows like jewelry on velvet, and eyes don't tire |
| Gold flows into emerald and purple **through a highlight**, as on the logo | A straight gold-to-purple blend turned pink in the middle | One visual language with the logo |
| **Three ways to order**: Ready works, I have a picture, I have an idea | A judge must be able to finish a real order alone, without waiting for the maker | Ready works can be paid at once; custom orders go to the maker |
| AI sketches are **only a starting point**, said right on the screen; demo payments are PayPal Sandbox | People often answer questions loosely — "a cat in a hat" can mean ten different things | Honest about what AI does and what the maker does |
| Material price depends on the **material type**, not the color (PLA is cheaper than PETG or heat-resistant ones), taken from the maker's real orders | Filament is bought in different places at different prices | The price is the maker's real cost |
| Start screen: logo, "From a photo or an idea to a real 3D print", a slowly glowing gold Start button; home with the three paths | — | The first look of the app |

## 26 October, evening — Ready works

| What we changed | What we noticed | Why it matters |
|---|---|---|
| Ready works: Golden Dragon and Fire Goat, each with the idea picture and the 3D model side by side | The maker's own pieces show a real path from idea to object | Judges see real work, not only AI pictures |
| The customer sees **one final price** with 23% VAT and delivery as a separate line; the cost breakdown stays with the maker | Electricity, labor and margin lines confuse a customer | A shop shows a price; the maker keeps the math |
| Choice of **material** with a short note, then **color swatches** of that material; "many more on request" | Cheaper filaments often lack some colors; some people want flexible or clear | Choice without overload |
| Fixed sizes with grams and hours from the slicer | Recalculating every size by guess is not honest | Every price comes from real slicer numbers |
| Plan: an **AI shop assistant** that picks a work for the customer's wish and budget and creates the PayPal order itself | "I want a shiny dragon as a gift, up to 100 zł" is how people actually ask | Agentic commerce, while code still sets the price |
| Bug fix: selected chips were invisible | The gold fill was painted under the background | You must see what you chose |
| A friendly **golden baby dragon helper** floats in the corner; tap it and it holds up a sign: "Hi! Let me help you choose" | People ask for a gift in their own words, not by filters | The helper becomes the shop assistant in the next step |
| **3D model you can turn around** next to the idea picture, in one big frame with a switch — neither is cropped | The idea picture was cut off; the small model was hard to see | The customer sees what will actually be printed |
| The model on the page is a **simplified preview** (~0.6 MB instead of 41 MB); the full model stays private | Anything shown in a browser can be copied | A copied preview is useless for printing |
| **Watermarks**: a faint diagonal "ShapePrompt" pattern baked into the pictures and laid over the 3D view, plus the logo mark in the corner | Screenshots can't be blocked on the web | The maker's work stays recognisably hers |
| Credit line: "Powered by MakerWorld-Image-to-3D" | The 3D models were generated with MakerLab from the maker's own pictures | Honest about which tools made what |
| Price shown the Polish way: **Total to pay → incl. VAT 23% → Net** | The maker is a VAT payer; consumers must see the gross price first | Clear for people and correct for the law |

## Day 3 — 27 Oct 2026

| What we changed | What we noticed | Why it matters |
|---|---|---|
| **Language globe** (EN · UA · PL · DE · FR), translated on the fly — no translation files in the app | The maker reads Ukrainian; customers come from everywhere | Everyone reads the shop in their own language |
| Every phrase is checked with the translator **line by line** before it ships | Sent as one block, the translator lost "!" and broke the grammar ("Type" became "тип") | Translations read like a person wrote them |
| An **ice welcome** over the home screen: the dragon introduces itself — talk or type, listen or read, sound can be turned off | Most people ignore corner helpers that pop up questions | The dragon greets like a **host welcoming guests**, not a servant — people listen to a host |
| **Voice**: the dragon reads answers aloud; a mic to speak instead of typing | Chrome on macOS 12 crashed on one long text with no voice for the language | Speech goes in short sentences, waits after "stop", stays silent if the system has no voice |
| The home screen in **metal**: gold, emerald-gold, amethyst-gold cards; the title in Cormorant (it has Cyrillic) | The first font had no Cyrillic, so Ukrainian titles looked broken | One screen with its own character |
| **Living dragon**: a 4-second greeting with the ShapePrompt logo **gold-embossed** on its sign; the dragon and goat come alive when their page opens | Two Canva videos turned out to be still frames; a black plate "bit off" the paws | Frames are cut out by our own script, the logo is placed on every frame |
| **PayPal checkout (Sandbox)**: Pay with PayPal → approve → back to "Thank you! Your order is paid." — first test purchase went through | — | The core of the shop works end to end |
| A tiny **Cloudflare Worker** creates and captures orders; the PayPal secret lives only there, encrypted | Earlier projects leaked keys that were inside the app | The website never sees the secret |
| Least privilege: Payouts and Subscriptions are switched off in the PayPal app | A stolen secret could otherwise send money out | Even in the worst case, money can't leave |

## Day 4 — 28 Oct 2026

| What we changed | What we noticed | Why it matters |
|---|---|---|
| The price now also covers **preparing each order** (slicing, setup, packing — 15 min at the maker's rate), the **PayPal fee** (2.9% + 1.35 zł, from PayPal Poland's fee page) and the **printer's own wear** (its price spread over 5000 print hours) | The maker asked: "we counted the costs — but where is my pay?" The pay was there, but these three were coming out of it | Every order pays the maker fairly; the customer still sees one price |
| **Box choice**: a simple box is included; a gift box costs a little more. A bigger figure gets a bigger box | People often buy figurines as gifts | The customer builds the order the way they want it |
| A card says exactly what "from 98 zł" is: *Small · 10 cm · PLA Basic · incl. VAT, without delivery*; its page opens on that same option | The card said 98 zł, the page opened on Silk at 101 zł — it looked like a mistake | The same number in both places builds trust |
| The "Net" line is gone; the customer sees **Total to pay** and **incl. VAT 23%** | A consumer in Poland pays gross; net is for invoices | Fewer numbers, nothing to misread |
| Plan for the dragon's brain: **Gemini** behind the same Cloudflare Worker; the key lives only in Cloudflare; **Turnstile** lets only real people in; a rate limit per address; the AI picks, **code sets the price** | A key inside a website can be copied by anyone | The AI can talk freely, but never touches money or secrets |
| The demo uses the **Gemini API free tier**. For real sales we switch to the paid tier | Gemini's terms allow only the paid tier for users in the EU, and on the paid tier customer messages are not used for training | Honest about what is demo and what is production |

## Day 4, afternoon — the dragon talks

| What we changed | What we noticed | Why it matters |
|---|---|---|
| **The dragon talks** (Gemini through our Worker): the guest writes or speaks in any language, the dragon picks a work and shows **order cards** with a PayPal button | Free-text wishes like "a golden dragon as a gift, up to 120 zł" are how people really ask | Agentic commerce: from a wish to a paid order in one conversation |
| **The Worker prices every order itself** from a catalog exported from the app's own pricing code; the site only says *what* was chosen | Before, the amount came from the website and could be changed | Nobody can pay 1 zł for a 100 zł piece |
| Budget: the dragon says delivery is counted separately and shows a second card that fits the budget **with** delivery | The maker asked "up to 120 zł" and got 129.99 zł with delivery | People think about the total they pay |
| **Special orders**: another size, material or color — code works out the tallest piece that fits the budget; the guest leaves an email; the maker gets a note from **requests@craftaxi.com** and answers with Reply | "Exactly for 120 zł, in green PETG" is a real wish the catalog can't hold | The AI collects the order; a person confirms the price |
| Things we have never made ("Puss in Boots") get buttons with their name to the **photo** and **idea** pages | One message can ask for a ready goat *and* a new cat | Nothing the guest said is lost |
| The dragon never asks what it already chose: "You didn't name a size, so I prepared it like this…" | It asked "which size?" and showed a finished card at the same time | One clear next step |
| The conversation is kept **in the guest's browser for 24 hours** after the last message | The maker opened the photo page, came back, and the conversation was gone | Shops keep the conversation; so do we |
| The mic listens until **5 seconds of silence** (30 s at most), words appear while you speak | It stopped after two or three words | People pause while they think |
| The maker is "our master" in every public text | — | Neutral and respectful |
| Domain **craftaxi.com** bought; mail **hello@craftaxi.com** works | Cloudflare can send mail only from a domain of our own | The shop gets its own address |

## Day 4, evening — "I have a photo or drawing"

| What we changed | What we noticed | Why it matters |
|---|---|---|
| The guest uploads a picture; the site resizes it to a JPEG (max 1600 px) before sending | Phone photos are 5–10 MB | Fast to send, enough detail for the maker |
| **The dragon looks at the picture** (Gemini vision) and fills in the order card: what it is, description, height, material, color, complexity. Every line can be edited | People don't know which material or size to ask for | The AI does the paperwork; the guest stays in control |
| Two checkboxes: **the picture is mine or I may use it**, and consent to keep email and picture for **90 days** (RODO/GDPR) | Pictures can belong to someone else | Clear rights before any work starts |
| "We don't print film, cartoon or game heroes and logos that belong to companies"; the dragon flags such pictures | Puss in Boots from a fairy tale is free to use — the one from a famous film is not | Respecting other people's work |
| The picture goes to the master **as an attachment**; Reply answers the customer | — | The master can start at once |
| A **3D preview** comes after a prepayment of about **20% of the price (at least 15 zł)**, counted toward the payment | A teaspoon and a carved box can't cost the same prepayment; and a preview takes the master's time | Fair for both sides |
| The dragon writes the picture card **straight in the guest's language**; server answers are marked UTF-8 | Translating four lines one by one failed, and Ukrainian letters came out as "Ð§Ð°Ñ…" | One reliable step instead of five fragile ones |
| **Several figures** in one picture are described one by one (pose, clothing, what each holds); the guest is asked which to make | A character sheet with four poses is not four identical figures | The master gets exactly what to model |
| The dragon thanks the guest for the picture and, if it is blurry, gently asks for a sharper one | Small, blurry pictures make modeling guesswork | Kind and useful at the same time |
| When the free Gemini quota runs out, the dragon says "I'm resting for a minute" in the guest's language, and the guest can fill in the card by hand | After a full day of testing Google answered 429 "quota exceeded" | The shop keeps working without AI — exactly why the demo/production note exists |
| A note from the dragon: *"I am still a young dragon and I learn every day. Your ideas and wishes help me grow — write to us: hello@craftaxi.com"* | — | Honest about being new, and a real way to reach the maker |

### Decided for tomorrow: rights to a customer's own drawing

A customer's drawing is their work; a 3D model made from it is a derivative work (Polish copyright law, *opracowanie*). So:

- **Portfolio is a condition of the order**, said before sending: photos of the finished piece, with the ShapePrompt watermark grid, may appear in the master's portfolio — otherwise the master can't show how they work.
- **Selling copies is the customer's choice.** Allowed → normal price and **10% off the next figure**. Not allowed → the piece is **exclusive, +25–50% to the price, agreed case by case** (a long, complex piece that would sell well is closer to 50%).
- The 3D model file stays with the master and is never sent out.

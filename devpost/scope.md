---
doc: scope
status: approved
---

# ShapePrompt

Turn a photo or an idea into a real 3D print. AI clarifies and sketches, the code calculates a fair price, PayPal handles the payment, the maker makes the real thing.

## The Unique Kernel
AI understands, code counts, the maker makes.

**An honest price, not a guess.** The price is calculated by code from the maker's real costs: the filament she actually bought (price per gram from her order), grams and print hours from her slicer, electricity, her hourly rate for modeling and finishing. AI never invents a price and never pretends to make the model: it talks to the customer, clarifies the order, draws sketches and writes the order card. The 3D model and the print are made by a real person.

## Who It's For
Two people on two sides of one order:
- **The customer** wants a custom object (a figurine, a gift, a small part) but cannot model in 3D and does not know what it should cost.
- **The maker** (the learner herself, with a home 3D printer) loses time on back-and-forth messages, manual price calculations and chasing payments.

## The Core Loop
Customer opens ShapePrompt → picks one of three paths:
- **A. Ready works** — the maker's real printed pieces (dragon, goat, duck, box…) with photos. Pick color and size → the price is calculated at once → pay with PayPal → status **Paid**.
- **B. Custom order from a picture** — upload a photo or drawing and write wishes → AI turns the message into a neat order card → the maker gets a notification → in **My Workshop** she enters grams and print hours → code calculates the price → PayPal invoice → paid.
- **C. Sketch from an idea** — describe the idea in words → pay a small fixed sketch fee with PayPal → AI draws 2–3 sketches → the customer picks one → it becomes a custom order (path B).

On the sketch screen, next to the pay button:
> Sketch is a starting point. The final 3D model is made and refined by the maker.
> Demo mode: this payment uses PayPal Sandbox to show how the service works. No real money is charged.

## Packages
- **Basic** — the 3D file only (worldwide, delivered online).
- **Standard** — file + printed object (Poland only, InPost parcel locker).
- **Premium** — file + print + finishing (painting, urgent order).

## Inspiration & Identity
Logo: a golden dragon shaped like the letter S inside a hexagon crystal, with printer nozzles — the learner's own dragon, which went through exactly this path (picture → 3D model → print). Colors: "wet asphalt" background #1E2226, gold, emerald, purple flowing into each other through highlights. Feel: a jeweler's box — dark velvet, glowing gold.

## Why This Matters to the Learner
Her own way to earn with 3D printing. She has already made custom work for a client abroad and priced it by hand; ShapePrompt turns that into a repeatable service. Later it moves onto her website, under ART & 3D.

## What "Working" Looks Like
A judge can do it alone, without waiting for the maker:
1. Ready works → dragon → color and size → price → pay in PayPal Sandbox → **Paid**.
2. Sketch → "Puss in Boots" → pay the sketch fee → AI shows 2–3 sketches → pick one → the order appears in My Workshop.
3. My Workshop → enter 120 g and 14 h → price → PayPal invoice → **Paid**.

## Build Order
Each step is a working app on its own, so there is always something to submit:
1. Ready works + PayPal payment.
2. My Workshop + fair price calculator + My Materials.
3. Custom order from a picture.
4. Sketch from an idea.

## The POC Boundary
- Start screen with the logo → home screen with the three paths.
- Interface in English with on-the-fly translation (online, no built-in translation files).
- **My Materials**: the maker adds a spool (material type, color, price, weight) → code calculates price per gram. The price depends mostly on the material type, not the color: standard PLA is cheaper than PETG (water-resistant, e.g. for flower pots) or heat-resistant materials. Material prices are taken from the maker's real orders (e.g. Allegro); the app shows "Material prices based on the maker's current suppliers". A color she does not have → "other color, on request", she enters the price of the spool to buy (to be refined later).
- Price calculator: filament (grams × price per gram + ~10% supports/waste), printer time (hours × electricity + wear), labor (hours × rate), packaging, ~10% failed-print risk, margin.
- AI: turns the customer's message into an order card, translates messages, draws sketches.
- Email notification to the maker about a new order.
- PayPal (Sandbox) through a Cloudflare server; no keys inside the app.
- Three packages; shipping rule: prints Poland only, files worldwide.

## Later
- AI reads a screenshot of a filament order and fills in My Materials.
- Book covers as a third service.
- EU shipping; embedding on the website's ART & 3D page.

## Explicitly Cut
- AI-made 3D models presented as the maker's work — AI makes only sketches.
- Customer accounts and login — the order link is enough for the proof of concept.
- Real money — sandbox only during the hackathon.

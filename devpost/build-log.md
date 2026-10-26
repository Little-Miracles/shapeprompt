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

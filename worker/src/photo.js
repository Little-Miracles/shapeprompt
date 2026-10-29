// "I have a photo or drawing": the dragon looks at the guest's picture and
// fills in an order card; the guest checks it and sends it to the maker.
// No price here — the maker answers with one after looking at the picture.

import catalog from './catalog.json';
import { BadRequest, gemini } from './chat.js';

const MAX_IMAGE_BYTES = 2 * 1024 * 1024; // the site sends a resized JPEG

const MATERIALS = catalog.allMaterials
  .map((m) => `- ${m.id} "${m.name}": ${m.about}`)
  .join('\n');

const SYSTEM = `You are the little golden dragon of ShapePrompt, a small 3D printing workshop in Poland, the host of this house. A guest has shown you a photo or drawing of something they want printed as a figure or object (the printer makes pieces up to 25 cm).

First decide "forbidden" — what our workshop never makes, whatever the guest says:
- "weapon": guns, rifles, pistols, combat knives, any weapon or weapon part on its own, replicas included, ammunition;
- "drone": military or attack drones of any kind (for example Shahed/Geran) and their parts;
- "explosive": bombs, grenades, mines, missiles, explosives;
- "nudity": nude or sexual bodies or body parts;
- "violence": blood, gore, cruelty;
- "hate": hate symbols, extremist signs;
- "none": everything else. A fairy-tale or historical figure that only holds a sword, staff or bow as part of its costume is "none".
If forbidden is not "none", the reply is two polite sentences: you thank them, and say that our workshop doesn't make such things, so you can't take this picture. Fill the other fields briefly, they will not be used.

Otherwise look at the picture and fill in the order card:
- name: what it is, two to five words.
- figures: how many separate figures or variants are in the picture (a sheet with several poses or views counts each one).
- description: as a maker would need it. For one figure: one or two sentences about its shape, pose, clothing and details. For several: a short numbered line for each — pose, clothing, what it holds — and note which look like views of the same figure.
- heightCm: a sensible height for a printed piece, 5 to 25.
- material: the best material id from this list:
${MATERIALS}
- color: one color word — the figure is printed in a single color.
- complexity: "simple", "medium" or "detailed" — how many small, thin or delicate parts it has.
- checks: before anything else, look at each figure one by one, as a maker who has to model it. For each figure give "face" and "hands": "clear", "blurred" or "hidden". A part is "blurred" if it is foggy, smeared, washed out, melted or rubbed away, or if you can't tell the eyes, nose and mouth apart. Pictures made by AI often have such foggy patches over a face or hair — treat them as blurred, even if the rest of the figure is sharp. "hidden" means turned away or covered on purpose (a figure seen from the back has a hidden face — that is fine).
- quality: "poor" if any face or hands are "blurred" in checks, or the whole picture is blurry, dark or tiny; otherwise "good".
- brand: true if it is a character, logo or product that clearly belongs to a company (for example Disney, DreamWorks, Pokémon, a car brand); false for people's own drawings, photos of their pets or things, and fairy-tale characters in general.
- reply: two or three warm sentences in the first person. First thank the guest for the picture; if quality is good, say a kind word about it. If quality is poor, don't praise the sharpness: say gently which figure and which part your checks found blurred (for example "the face of the second figure") and ask for a sharper picture if they have one. If there are several figures, say you described each of them and they can choose on the card which one (or all) to make. If complexity is "medium" or "detailed", say honestly that we print with plastic filament, not resin, so the finest details (a face's wrinkles, fingers, thin parts) will come out simpler, and that our master will send pictures of the 3D model before printing so they can see it first. Then say you filled in the card and they can change anything. If brand is true, add kindly that our master can't print characters or logos that belong to companies, but can make something in a similar spirit.

The guest's note, if any, tells you what they want; follow it. Never invent a price.
Write name, description, color and reply in the guest's language, given below; address the guest politely and consistently (in Ukrainian and Polish use the polite plural form).`;

const LANGUAGES = { en: 'English', uk: 'Ukrainian', pl: 'Polish', de: 'German', fr: 'French' };

const SCHEMA = {
  type: 'OBJECT',
  properties: {
    forbidden: {
      type: 'STRING',
      enum: ['none', 'weapon', 'drone', 'explosive', 'nudity', 'violence', 'hate'],
    },
    checks: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          figure: { type: 'NUMBER' },
          face: { type: 'STRING', enum: ['clear', 'blurred', 'hidden'] },
          hands: { type: 'STRING', enum: ['clear', 'blurred', 'hidden'] },
        },
        required: ['figure', 'face', 'hands'],
      },
    },
    name: { type: 'STRING' },
    figures: { type: 'NUMBER' },
    description: { type: 'STRING' },
    heightCm: { type: 'NUMBER' },
    material: { type: 'STRING' },
    color: { type: 'STRING' },
    complexity: { type: 'STRING', enum: ['simple', 'medium', 'detailed'] },
    quality: { type: 'STRING', enum: ['good', 'poor'] },
    brand: { type: 'BOOLEAN' },
    reply: { type: 'STRING' },
  },
  // Gemini writes in this order: it looks at every figure before it
  // judges the picture and before it speaks.
  propertyOrdering: ['forbidden', 'checks', 'quality', 'figures', 'name', 'description', 'heightCm', 'material', 'color', 'complexity', 'brand', 'reply'],
  required: ['forbidden', 'checks', 'name', 'figures', 'description', 'heightCm', 'material', 'color', 'complexity', 'quality', 'brand', 'reply'],
};

/// The picture must be the JPEG the site makes, not anything else.
export function checkImage(b64) {
  const data = String(b64 || '');
  if (!data || data.length > (MAX_IMAGE_BYTES * 4) / 3 + 4) {
    throw new BadRequest('bad image');
  }
  let head;
  try {
    head = atob(data.slice(0, 8));
  } catch {
    throw new BadRequest('bad image');
  }
  const jpeg =
    head.charCodeAt(0) === 0xff && head.charCodeAt(1) === 0xd8 && head.charCodeAt(2) === 0xff;
  if (!jpeg) throw new BadRequest('bad image');
  return data;
}

const clean = (v, n) => String(v || '').replace(/[\r\n]+/g, ' ').trim().slice(0, n);

/// The card as the shop accepts it, from Gemini or from the guest's edits.
export function cleanCard(c) {
  c = c || {};
  const material = catalog.allMaterials.find((m) => m.id === c.material);
  const height = Math.round(Number(c.heightCm));
  return {
    name: clean(c.name, 60),
    figures: Math.min(Math.max(Math.round(Number(c.figures)) || 1, 1), 20),
    description: String(c.description || '').trim().slice(0, 1200),
    heightCm: height >= 5 && height <= 25 ? height : null,
    material: material ? material.id : null,
    materialName: material ? material.name : null,
    color: clean(c.color, 40),
    complexity: ['simple', 'medium', 'detailed'].includes(c.complexity) ? c.complexity : null,
    quality: c.quality === 'poor' ? 'poor' : 'good',
    brand: c.brand === true,
    wishes: clean(c.wishes, 600),
    pick: clean(c.pick, 20),
    base: ['round', 'none', 'master'].includes(c.base) ? c.base : 'master',
    blurred: (Array.isArray(c.blurred) ? c.blurred : [])
      .map((n) => Math.round(Number(n)))
      .filter((n) => n > 0 && n <= 20)
      .slice(0, 20),
    blurAccepted: c.blurAccepted === true,
    copies: c.copies === 'allowed' ? 'allowed' : c.copies === 'exclusive' ? 'exclusive' : null,
  };
}

/// Picture (+ the guest's note) → {card, reply}, in the guest's language.
export async function readPhoto(image, note, lang, env) {
  const language = LANGUAGES[lang] || 'English';
  const contents = [
    {
      role: 'user',
      parts: [
        { inlineData: { mimeType: 'image/jpeg', data: checkImage(image) } },
        { text: `Guest's language: ${language}\nGuest's note: ${clean(note, 300) || '(none)'}` },
      ],
    },
  ];
  const text = await gemini(env, SYSTEM, contents, SCHEMA, 900);
  // Gemini's own safety filter answers with nothing at all.
  if (!text) return { forbidden: 'other', card: null, reply: '' };
  let a;
  try {
    a = JSON.parse(text);
  } catch {
    throw new Error('unreadable answer');
  }
  if (a.forbidden && a.forbidden !== 'none') {
    return { forbidden: a.forbidden, card: null, reply: clean(a.reply, 400) };
  }
  // The checks decide, whatever the dragon felt about the picture.
  const blurred = (a.checks || []).filter((c) => c.face === 'blurred' || c.hands === 'blurred');
  if (blurred.length) a.quality = 'poor';
  const card = cleanCard({ ...a, blurred: blurred.map((c) => c.figure) });
  return { card, reply: clean(a.reply, 600) };
}

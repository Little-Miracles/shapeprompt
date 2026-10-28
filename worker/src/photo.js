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

Look at the picture and fill in the order card:
- name: what it is, two to five words.
- figures: how many separate figures or variants are in the picture (a sheet with several poses or views counts each one).
- description: as a maker would need it. For one figure: one or two sentences about its shape, pose, clothing and details. For several: a short numbered line for each — pose, clothing, what it holds — and note which look like views of the same figure.
- heightCm: a sensible height for a printed piece, 5 to 25.
- material: the best material id from this list:
${MATERIALS}
- color: one or two color words.
- complexity: "simple", "medium" or "detailed" — how many small, thin or delicate parts it has.
- quality: "good" if the picture is sharp and clear enough to model from, "poor" if it is blurry, dark, tiny or cut off.
- brand: true if it is a character, logo or product that clearly belongs to a company (for example Disney, DreamWorks, Pokémon, a car brand); false for people's own drawings, photos of their pets or things, and fairy-tale characters in general.
- reply: two or three warm sentences in the first person. First thank the guest for the picture; if quality is good, say a kind word about it. If quality is poor, say gently that it is hard to see the details and ask for a sharper picture if they have one. If there are several figures, say you described each of them and our master will ask which one (or all) to make — the guest can also write it in their wishes. Then say you filled in the card and they can change anything. If brand is true, add kindly that our master can't print characters or logos that belong to companies, but can make something in a similar spirit.

The guest's note, if any, tells you what they want; follow it. Never invent a price.
Write name, description, color and reply in the guest's language, given below; address the guest politely and consistently (in Ukrainian and Polish use the polite plural form).`;

const LANGUAGES = { en: 'English', uk: 'Ukrainian', pl: 'Polish', de: 'German', fr: 'French' };

const SCHEMA = {
  type: 'OBJECT',
  properties: {
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
  required: ['name', 'figures', 'description', 'heightCm', 'material', 'color', 'complexity', 'quality', 'brand', 'reply'],
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
  let a;
  try {
    a = JSON.parse(text);
  } catch {
    throw new Error('unreadable answer');
  }
  return { card: cleanCard(a), reply: clean(a.reply, 600) };
}

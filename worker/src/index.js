// ShapePrompt × PayPal × Gemini — a tiny server between the site and
// PayPal and Gemini. The site never sees a secret: the PayPal secret and
// the Gemini key live only here, as encrypted Cloudflare secrets.
//
//   POST /chat                 {messages, human | session}
//        → {reply, pick, session}   (pick carries the price, or is null)
//   POST /orders               {item, returnUrl, cancelUrl}
//        → {id, approveUrl}         (the price comes from the catalog)
//   POST /orders/:id/capture   → {id, status, amount, payer, download?}
//   GET  /download?order=…     → the STL file, for 7 days after paying
//   POST /requests             {custom, email, consent, session}
//        → {id}                     (a custom request; the maker gets an
//                                    email and answers the customer)
//   POST /photo/read           {image, note, session | human}
//        → {card, reply, session}   (the dragon fills in a card)
//   POST /photo/requests       {image, card, email, consent, rights, session}
//        → {id, deposit}            (waits for the 15 zł deposit; then the
//                                    maker gets it, the picture attached)
//   GET  /refund?req=…&sig=…   → a page to return a deposit (from the
//   POST /refund                  maker's email; the link is signed)
//   GET  /block?req=…&sig=…    → the same for blocking a customer
//
// Sandbox only for the hackathon: no real money moves.

import { EmailMessage } from 'cloudflare:email';
import { BadRequest, Busy, chat, customPriced, filePriced, priced } from './chat.js';
import { checkImage, cleanCard, readPhoto } from './photo.js';

const SESSION_MINUTES = 30; // one Turnstile check lasts this long
const KEEP_DAYS = 182; // custom requests are deleted after half a year
const PHOTO_KEEP_DAYS = 90; // guests' pictures are deleted sooner
const DOWNLOAD_DAYS = 7; // a paid file can be downloaded this long
const DEPOSIT = 15; // zł: a request reaches the maker only with it
const UNPAID_HOURS = 48; // an unpaid request is forgotten after this
const STRIKES = 3; // forbidden tries in a day before an address is stopped
const STRIKE_HOURS = 24;
const BAN_DAYS = 365; // a customer the maker blocked

// What the workshop never makes. Ideas come in words only, so the words
// are checked here; pictures are checked by the dragon.
const FORBIDDEN_WORDS =
  /(\bguns?\b|pistol|rifle|weapon|ammo|ammunition|bullet|silencer|\bdrones?\b|shahed|geran|\bbombs?\b|grenade|missile|explosive|збро|пістолет|рушниц|набо[їі]|дрон|шахед|бомб|гранат|вибухів|оружи|пистолет|винтовк|патрон|взрывчат|broń|pistolet|karabin|amunic|granat|materiał wybuch)/i;

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';
    const cors = corsHeaders(origin, env);
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
    }
    const url = new URL(request.url);
    // A plain link the browser opens, so it carries no Origin.
    if (request.method === 'GET' && url.pathname === '/download') {
      const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
      const { success } = await env.LIMIT.limit({ key: ip });
      if (!success) return new Response('Too many requests', { status: 429 });
      return await download(url.searchParams.get('order'), env);
    }
    // The maker's own pages from the email, not the site.
    if (url.pathname === '/refund' || url.pathname === '/block') {
      const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
      const { success } = await env.LIMIT.limit({ key: ip });
      if (!success) return new Response('Too many requests', { status: 429 });
      return await makerAction(url.pathname.slice(1), request, url, env);
    }
    if (!cors['Access-Control-Allow-Origin']) {
      return json({ error: 'origin not allowed' }, 403, cors);
    }
    if (request.method !== 'POST') {
      return json({ error: 'POST only' }, 405, cors);
    }

    // A few requests a minute from one address is plenty for a person.
    const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
    const { success } = await env.LIMIT.limit({ key: ip });
    if (!success) return json({ error: 'too many requests' }, 429, cors);

    try {
      if (url.pathname === '/chat') return await talk(request, env, cors, ip);
      if (url.pathname === '/requests') return await saveRequest(request, env, cors);
      if (url.pathname === '/photo/read') return await photoRead(request, env, cors, ip);
      if (url.pathname === '/photo/requests') return await photoRequest(request, env, cors, ip);
      if (url.pathname === '/orders') {
        return await createOrder(request, env, cors);
      }
      const m = url.pathname.match(/^\/orders\/([A-Z0-9]{8,30})\/capture$/);
      if (m) return await captureOrder(m[1], env, cors, url.origin);
      return json({ error: 'not found' }, 404, cors);
    } catch (e) {
      if (e instanceof BadRequest) return json({ error: e.message }, 400, cors);
      if (e instanceof Busy) return json({ error: 'busy' }, 503, cors);
      return json({ error: 'service unavailable', detail: String(e) }, 502, cors);
    }
  },
};

/// Only a person who passed Turnstile talks to Gemini. The first message
/// carries a Turnstile token; the answer gives a signed session, so the
/// next messages within half an hour don't need a new check.
async function talk(request, env, cors, ip) {
  if (!env.GEMINI_KEY || !env.TURNSTILE_SECRET) {
    return json({ error: 'assistant is not set up' }, 503, cors);
  }
  const body = await request.json().catch(() => ({}));
  let session = (await sessionValid(body.session, env)) ? body.session : null;
  if (!session) {
    if (!(await isHuman(body.human, ip, env))) {
      return json({ error: 'human check failed' }, 403, cors);
    }
    session = await newSession(env);
  }
  const answer = await chat(body.messages, env);
  return json({ ...answer, session }, 200, cors);
}

/// A custom request: only from someone who already talked to the dragon
/// (a valid session), with an email and their consent to keep it.
async function saveRequest(request, env, cors) {
  const body = await request.json().catch(() => ({}));
  const ip = request.headers.get('CF-Connecting-IP') || '';
  if (!(await sessionValid(body.session, env)) && !(await isHuman(body.human, ip, env))) {
    return json({ error: 'human check failed' }, 403, cors);
  }
  const email = String(body.email || '').trim();
  if (email.length > 120 || !/^[^\s@<>"',;]+@[^\s@<>"',;]+\.[a-z]{2,}$/i.test(email)) {
    return json({ error: 'bad email' }, 400, cors);
  }
  if (body.consent !== true) return json({ error: 'no consent' }, 400, cors);
  const c = body.custom || {};
  // Priced again here: the site only says what was asked for.
  const item = customPriced({ ...c, heightCm: c.cm, budgetZl: null });
  if (!item) return json({ error: 'unknown item' }, 400, cors);
  const budget = Number(c.budget) > 0 ? Math.round(Number(c.budget) * 100) / 100 : null;

  const id = crypto.randomUUID().slice(0, 8).toUpperCase();
  const saved = { id, createdAt: new Date().toISOString(), email, budget, ...item };
  await env.REQUESTS.put(`request:${saved.createdAt}:${id}`, JSON.stringify(saved), {
    expirationTtl: KEEP_DAYS * 24 * 60 * 60,
  });
  try {
    await tellMaker(saved, env);
  } catch (e) {
    // The request is saved anyway; the maker sees it in the workshop.
    console.log('maker email failed', String(e));
  }
  return json({ id }, 200, cors);
}

/// A plain email to the maker. Reply-To is the customer, so answering is
/// just pressing Reply.
async function tellMaker(r, env) {
  const zl = (v) => `${Number(v).toFixed(2)} zł`;
  const text = [
    `New custom request ${r.id}`,
    '',
    `${r.title}`,
    `Approximate price: ${zl(r.piece)} + delivery ${zl(r.delivery)} = ${zl(r.total)}`,
    r.budget ? `Customer's budget: ${zl(r.budget)}` : 'Customer named no budget',
    `Wish: ${r.wish || '—'}`,
    '',
    `Customer: ${r.email}`,
    'Press Reply to answer the customer.',
    '',
    `Sent by the ShapePrompt dragon, ${r.createdAt}`,
  ].join('\n');
  await sendToMaker(r, `Custom request ${r.id}: ${r.title}`, [
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: base64',
    '',
    wrap(base64(text)),
  ], env);
}

function base64(text) {
  let bin = '';
  for (const b of new TextEncoder().encode(text)) bin += String.fromCharCode(b);
  return btoa(bin);
}

/// A header with non-English letters (RFC 2047).
function encodeWord(text) {
  return `=?UTF-8?B?${base64(text.replace(/[\r\n]+/g, ' '))}?=`;
}

/// A session for a person: the one they have, or a new one after
/// Turnstile. null if neither is good.
async function personSession(body, env, ip) {
  if (await sessionValid(body.session, env)) return body.session;
  if (await isHuman(body.human, ip, env)) return await newSession(env);
  return null;
}

async function photoRead(request, env, cors, ip) {
  if (!env.GEMINI_KEY || !env.TURNSTILE_SECRET) {
    return json({ error: 'assistant is not set up' }, 503, cors);
  }
  const body = await request.json().catch(() => ({}));
  if (await env.REQUESTS.get(`banip:${ip}`)) return json({ error: 'blocked' }, 423, cors);
  const session = await personSession(body, env, ip);
  if (!session) return json({ error: 'human check failed' }, 403, cors);
  const answer = await readPhoto(body.image, body.note, body.lang, env);
  if (answer.forbidden) await strike(ip, env);
  return json({ ...answer, session }, 200, cors);
}

/// A picture or idea order: saved for 90 days and sent to the maker, the
/// picture (if any) attached. The guest confirms a picture is theirs.
async function photoRequest(request, env, cors, ip) {
  const body = await request.json().catch(() => ({}));
  if (await env.REQUESTS.get(`banip:${ip}`)) return json({ error: 'blocked' }, 423, cors);
  if (!(await personSession(body, env, ip))) {
    return json({ error: 'human check failed' }, 403, cors);
  }
  const email = String(body.email || '').trim();
  if (email.length > 120 || !/^[^\s@<>"',;]+@[^\s@<>"',;]+\.[a-z]{2,}$/i.test(email)) {
    return json({ error: 'bad email' }, 400, cors);
  }
  if (await env.REQUESTS.get(`ban:email:${email.toLowerCase()}`)) {
    return json({ error: 'blocked' }, 423, cors);
  }
  if (body.consent !== true || body.portfolio !== true || (body.image && body.rights !== true)) {
    return json({ error: 'no consent' }, 400, cors);
  }
  // No picture: an idea in words, so the words must say something.
  const image = body.image ? checkImage(body.image) : null;
  const card = cleanCard(body.card);
  if (!card.name) return json({ error: 'no name' }, 400, cors);
  if (!card.copies) return json({ error: 'no copies choice' }, 400, cors);
  if (!image && card.description.length < 10) {
    return json({ error: 'no description' }, 400, cors);
  }
  if (FORBIDDEN_WORDS.test(`${card.name} ${card.description} ${card.wishes}`)) {
    await strike(ip, env);
    return json({ error: 'forbidden' }, 400, cors);
  }

  const id = (image ? 'P' : 'I') + crypto.randomUUID().slice(0, 7).toUpperCase();
  const createdAt = new Date().toISOString();
  const saved = { id, createdAt, email, kind: image ? 'photo' : 'idea', ...card };
  // Waits for the deposit: only a paid request goes to the maker.
  const ttl = { expirationTtl: UNPAID_HOURS * 60 * 60 };
  await env.REQUESTS.put(`pending:${id}`, JSON.stringify(saved), ttl);
  if (image) await env.REQUESTS.put(`photo:${id}`, image, ttl);
  return json({ id, deposit: DEPOSIT }, 200, cors);
}

/// The deposit is paid: the request is kept and the maker gets it, with a
/// signed link to return the deposit.
async function requestPaid(id, paypalId, captureId, payerId, env, origin) {
  const raw = await env.REQUESTS.get(`pending:${id}`);
  if (!raw) return;
  const saved = { ...JSON.parse(raw), deposit: DEPOSIT, paypalId, payerId };
  const ttl = { expirationTtl: PHOTO_KEEP_DAYS * 24 * 60 * 60 };
  await env.REQUESTS.put(`request:${saved.createdAt}:${id}`, JSON.stringify(saved), ttl);
  await env.REQUESTS.put(
    `deposit:${id}`,
    JSON.stringify({ captureId, refunded: false, email: saved.email, payerId }),
    ttl,
  );
  saved.refundUrl = `${origin}/refund?req=${id}&sig=${await sign(`refund:${id}`, env)}`;
  saved.blockUrl = `${origin}/block?req=${id}&sig=${await sign(`block:${id}`, env)}`;
  await env.REQUESTS.delete(`pending:${id}`);
  const image = saved.kind === 'photo' ? await env.REQUESTS.get(`photo:${id}`) : null;
  if (image) await env.REQUESTS.put(`photo:${id}`, image, ttl);
  try {
    await tellMakerPhoto(saved, image, env);
  } catch (e) {
    console.log('maker email failed', String(e));
  }
}

/// A deposit for a request that is still waiting for it.
async function depositPriced(pick, env) {
  if (!pick || typeof pick !== 'object' || !pick.deposit) return null;
  const id = String(pick.deposit);
  if (!/^[PI][A-Z0-9]{7}$/.test(id) || !(await env.REQUESTS.get(`pending:${id}`))) return null;
  return { deposit: id, total: DEPOSIT, title: `3D model deposit · request ${id}` };
}

async function tellMakerPhoto(r, image, env) {
  const text = [
    image ? `New picture order ${r.id}` : `New idea order ${r.id} (no picture)`,
    '',
    `What: ${r.name}${r.figures > 1 ? ` (${r.figures} figures in the picture; chosen: ${r.pick || 'not chosen'})` : ''}`,
    `Description: ${r.description || '—'}`,
    r.quality === 'poor'
      ? `⚠ The picture is not very sharp${r.blurred.length ? ` (blurred: figure ${r.blurred.join(', ')})` : ''}.` +
        (r.blurAccepted ? ' The customer saw the warning and sent it anyway.' : '')
      : '',
    `Height: ${r.heightCm ? r.heightCm + ' cm' : 'not given'}`,
    `Material: ${r.materialName || 'not given'} · Color: ${r.color || 'not given'}`,
    `Complexity (the dragon's guess): ${r.complexity || '—'}`,
    r.brand ? '⚠ The dragon thinks this may be a company character or logo.' : '',
    `Base: ${{ round: 'round base', none: 'no base', master: 'master decides' }[r.base]}`,
    r.copies === 'allowed'
      ? 'Copies: the customer allows selling copies → 10% off their next figure.'
      : 'Copies: EXCLUSIVE → name the extra 25–50% in the answer.',
    'The customer agreed: photos of the figure may be in the portfolio.',
    `Wishes: ${r.wishes || '—'}`,
    '',
    image ? 'The customer confirmed the picture is theirs or they may use it.' : '',
    `Customer: ${r.email}`,
    `✅ Deposit paid: ${r.deposit} zł (PayPal ${r.paypalId}). It counts toward the price;`,
    'return it only if you decline before starting work.',
    `Return the deposit: ${r.refundUrl}`,
    `Block this customer for a year (email and PayPal account): ${r.blockUrl}`,
    'Press Reply to answer the customer: the price, then 2–3 pictures of the 3D model.',
    '',
    `Sent by the ShapePrompt dragon, ${r.createdAt}`,
  ]
    .filter((l, i, all) => l !== '' || all[i - 1] !== '')
    .join('\n');
  if (!image) {
    await sendToMaker(r, `Idea order ${r.id}: ${r.name}`, [
      'Content-Type: text/plain; charset=UTF-8',
      'Content-Transfer-Encoding: base64',
      '',
      wrap(base64(text)),
    ], env);
    return;
  }
  const boundary = 'sp-' + crypto.randomUUID();
  const subject = `Picture order ${r.id}: ${r.name}`;
  await sendToMaker(r, subject, [
    `Content-Type: multipart/mixed; boundary="${boundary}"`,
    '',
    `--${boundary}`,
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: base64',
    '',
    wrap(base64(text)),
    `--${boundary}`,
    `Content-Type: image/jpeg; name="${r.id}.jpg"`,
    'Content-Transfer-Encoding: base64',
    `Content-Disposition: attachment; filename="${r.id}.jpg"`,
    '',
    wrap(image),
    `--${boundary}--`,
  ], env);
}

const wrap = (b64) => b64.replace(/.{76}/g, '$&\r\n');

/// Headers every note to the maker shares; Reply-To is the customer.
async function sendToMaker(r, subject, mimeBody, env) {
  const from = 'requests@craftaxi.com';
  const raw = [
    `From: ShapePrompt <${from}>`,
    `To: ${env.MAKER_EMAIL}`,
    `Reply-To: ${r.email}`,
    `Subject: ${encodeWord(subject)}`,
    `Message-ID: <${r.id}.${Date.now()}@craftaxi.com>`,
    `Date: ${new Date().toUTCString()}`,
    'MIME-Version: 1.0',
    ...mimeBody,
  ].join('\r\n');
  await env.MAIL.send(new EmailMessage(from, env.MAKER_EMAIL, raw));
}

async function isHuman(token, ip, env) {
  if (!token) return false;
  const form = new FormData();
  form.append('secret', env.TURNSTILE_SECRET);
  form.append('response', String(token));
  form.append('remoteip', ip);
  const r = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
    method: 'POST',
    body: form,
  });
  const data = await r.json().catch(() => ({}));
  return data.success === true;
}

async function newSession(env) {
  const until = Date.now() + SESSION_MINUTES * 60 * 1000;
  return `${until}.${await sign(String(until), env)}`;
}

async function sessionValid(session, env) {
  const [until, mac] = String(session || '').split('.');
  if (!until || !mac || Number(until) < Date.now()) return false;
  return mac === (await sign(until, env));
}

async function sign(text, env) {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(env.TURNSTILE_SECRET),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(text));
  return [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function createOrder(request, env, cors) {
  const body = await request.json().catch(() => ({}));
  // Only an adult who accepted the order terms pays.
  if (body.adult !== true || body.terms !== true) {
    return json({ error: 'terms not accepted' }, 400, cors);
  }
  // The site says only what was chosen; what it costs is decided here.
  const file = filePriced(body.item);
  const deposit = file ? null : await depositPriced(body.item, env);
  const item = file || deposit || priced(body.item);
  if (!item) return json({ error: 'unknown item' }, 400, cors);
  // A ready work is printed for one person, with their own words on it.
  if (!file && !deposit) {
    const words = String(body.item.words || '').replace(/[\r\n]+/g, ' ').trim().slice(0, 30);
    const place = body.item.place === 'front' ? 'on the front' : 'underneath';
    if (!words || body.item.madeForYou !== 'yes') {
      return json({ error: 'no words' }, 400, cors);
    }
    if (FORBIDDEN_WORDS.test(words)) return json({ error: 'forbidden' }, 400, cors);
    item.title = `Words "${words}" ${place} · ${item.title}`;
  }
  const returnUrl = safeUrl(body.returnUrl, env);
  const cancelUrl = safeUrl(body.cancelUrl, env);
  if (!returnUrl || !cancelUrl) {
    return json({ error: 'bad return url' }, 400, cors);
  }

  const res = await paypal(env, '/v2/checkout/orders', {
    intent: 'CAPTURE',
    purchase_units: [
      {
        description: item.title.slice(0, 120),
        amount: { currency_code: 'PLN', value: item.total.toFixed(2) },
      },
    ],
    payment_source: {
      paypal: {
        experience_context: {
          brand_name: 'ShapePrompt',
          user_action: 'PAY_NOW',
          shipping_preference: file || deposit ? 'NO_SHIPPING' : 'GET_FROM_FILE',
          return_url: returnUrl,
          cancel_url: cancelUrl,
        },
      },
    },
  });
  if (!res.ok) return json({ error: 'create failed', detail: res.data }, 502, cors);
  // Remembered for the capture: which file this payment opens, or which
  // request it sends to the maker.
  const what = file ? file.file : deposit ? `deposit:${deposit.deposit}` : null;
  if (what) {
    await env.REQUESTS.put(`order:${res.data.id}`, what, { expirationTtl: 24 * 60 * 60 });
  }
  const approve = (res.data.links || []).find(
    (l) => l.rel === 'payer-action' || l.rel === 'approve',
  );
  return json(
    { id: res.data.id, approveUrl: approve && approve.href, title: item.title, amount: item.total },
    200,
    cors,
  );
}

async function captureOrder(id, env, cors, origin) {
  // A blocked customer's money is not taken: the order is looked at first.
  const look = await paypalGet(env, `/v2/checkout/orders/${id}`);
  const payerId = ((look.data || {}).payer || {}).payer_id || '';
  if (payerId && (await env.REQUESTS.get(`ban:payer:${payerId}`))) {
    return json({ error: 'blocked' }, 423, cors);
  }
  const res = await paypal(env, `/v2/checkout/orders/${id}/capture`, {});
  if (!res.ok) return json({ error: 'capture failed', detail: res.data }, 502, cors);
  const unit = (res.data.purchase_units || [])[0] || {};
  const capture = ((unit.payments || {}).captures || [])[0] || {};
  const payer = res.data.payer || {};
  // A paid file: its download opens for a week.
  let link;
  let request;
  const what = await env.REQUESTS.get(`order:${id}`);
  if (what && res.data.status === 'COMPLETED') {
    if (what.startsWith('deposit:')) {
      request = what.slice('deposit:'.length);
      await requestPaid(request, id, capture.id, payer.payer_id || payerId, env, origin);
    } else {
      await env.REQUESTS.put(`paid:${id}`, what, { expirationTtl: DOWNLOAD_DAYS * 24 * 60 * 60 });
      link = `${origin}/download?order=${id}`;
    }
  }
  return json(
    {
      id: res.data.id,
      status: res.data.status,
      amount: capture.amount,
      download: link,
      request,
      payer: {
        name: (payer.name || {}).given_name || '',
        email: payer.email_address || '',
      },
    },
    200,
    cors,
  );
}

/// The STL behind a paid order. The files sit in KV as stl:<id>.
async function download(order, env) {
  const id = String(order || '');
  if (!/^[A-Z0-9]{8,30}$/.test(id)) return new Response('Not found', { status: 404 });
  const file = await env.REQUESTS.get(`paid:${id}`);
  if (!file) {
    return new Response('This link has expired or the order is not paid.', { status: 404 });
  }
  const data = await env.REQUESTS.get(`stl:${file}`, 'arrayBuffer');
  if (!data) return new Response('File not found', { status: 404 });
  return new Response(data, {
    headers: {
      'Content-Type': 'model/stl',
      'Content-Disposition': `attachment; filename="ShapePrompt-${file}.stl"`,
      'Cache-Control': 'private, no-store',
    },
  });
}

/// One stop for a forbidden try. Enough of them in a day and the address
/// can't send pictures or requests until the day is over.
async function strike(ip, env) {
  const ttl = { expirationTtl: STRIKE_HOURS * 60 * 60 };
  const n = Number(await env.REQUESTS.get(`strike:${ip}`)) + 1;
  await env.REQUESTS.put(`strike:${ip}`, String(n), ttl);
  if (n >= STRIKES) await env.REQUESTS.put(`banip:${ip}`, '1', ttl);
}

/// The maker returns a deposit or blocks a customer, from the links in the
/// email. GET shows what will happen (mail apps open links on their own,
/// so a GET never changes anything), POST does it.
async function makerAction(kind, request, url, env) {
  let id = url.searchParams.get('req') || '';
  let sig = url.searchParams.get('sig') || '';
  if (request.method === 'POST') {
    const form = await request.formData().catch(() => new FormData());
    id = String(form.get('req') || '');
    sig = String(form.get('sig') || '');
  }
  if (!/^[PI][A-Z0-9]{7}$/.test(id) || sig !== (await sign(`${kind}:${id}`, env))) {
    return page('This link is not valid.', 403);
  }
  const raw = await env.REQUESTS.get(`deposit:${id}`);
  if (!raw) return page(`Request ${id}: nothing found.`, 404);
  const deposit = JSON.parse(raw);
  const keep = { expirationTtl: PHOTO_KEEP_DAYS * 24 * 60 * 60 };
  const button = (question, label) =>
    page(
      `${question}<br><br><form method="post"><input type="hidden" name="req" value="${id}">` +
        `<input type="hidden" name="sig" value="${sig}"><button>${label}</button></form>`,
    );

  if (kind === 'block') {
    if (deposit.blocked) return page(`Request ${id}: this customer is already blocked.`);
    if (request.method !== 'POST') {
      return button(
        `Block the customer of request ${id} for a year? They will not be able to send ` +
          'requests or pay with this email and this PayPal account.',
        'Block the customer',
      );
    }
    const ttl = { expirationTtl: BAN_DAYS * 24 * 60 * 60 };
    if (deposit.email) await env.REQUESTS.put(`ban:email:${deposit.email.toLowerCase()}`, id, ttl);
    if (deposit.payerId) await env.REQUESTS.put(`ban:payer:${deposit.payerId}`, id, ttl);
    await env.REQUESTS.put(`deposit:${id}`, JSON.stringify({ ...deposit, blocked: true }), keep);
    return page(`Done: the customer of request ${id} is blocked for a year.`);
  }

  if (deposit.refunded) return page(`Request ${id}: the deposit was already returned.`);
  if (request.method !== 'POST') {
    return button(`Return the ${DEPOSIT} zł deposit for request ${id}?`, 'Return the deposit');
  }
  const res = await paypal(env, `/v2/payments/captures/${deposit.captureId}/refund`, {}, `refund-${id}`);
  if (!res.ok) return page('PayPal did not return the deposit. Please try again later.', 502);
  await env.REQUESTS.put(`deposit:${id}`, JSON.stringify({ ...deposit, refunded: true }), keep);
  return page(`Done: ${DEPOSIT} zł returned for request ${id}. PayPal tells the customer by email.`);
}

const page = (body, status = 200) =>
  new Response(
    '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width">' +
      '<title>ShapePrompt</title><body style="font:17px system-ui;background:#1d2024;color:#eee;' +
      'max-width:520px;margin:60px auto;padding:0 20px"><h2 style="color:#d9b45a">ShapePrompt</h2>' +
      `<p>${body}</p><style>button{font:inherit;padding:12px 26px;border:0;border-radius:30px;` +
      'background:#d9b45a;color:#1d2024;cursor:pointer}</style></body>',
    { status, headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' } },
  );

async function paypal(env, path, payload, requestId) {
  const token = await accessToken(env);
  const r = await fetch(env.PAYPAL_API + path, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      // The same id twice is one action: a double click refunds once.
      'PayPal-Request-Id': requestId || crypto.randomUUID(),
    },
    body: JSON.stringify(payload),
  });
  return { ok: r.ok, data: await r.json().catch(() => ({})) };
}

async function paypalGet(env, path) {
  const token = await accessToken(env);
  const r = await fetch(env.PAYPAL_API + path, { headers: { Authorization: `Bearer ${token}` } });
  return { ok: r.ok, data: await r.json().catch(() => ({})) };
}

async function accessToken(env) {
  if (!env.PAYPAL_SECRET) throw new Error('PAYPAL_SECRET is not set');
  const r = await fetch(env.PAYPAL_API + '/v1/oauth2/token', {
    method: 'POST',
    headers: {
      Authorization: 'Basic ' + btoa(`${env.PAYPAL_CLIENT_ID}:${env.PAYPAL_SECRET}`),
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
  });
  const data = await r.json();
  if (!r.ok) throw new Error('oauth ' + r.status);
  return data.access_token;
}

/// Return addresses may only point back to our own site.
function safeUrl(value, env) {
  try {
    const u = new URL(String(value));
    return isAllowed(u.origin, env) ? u.toString() : null;
  } catch {
    return null;
  }
}

function isAllowed(origin, env) {
  return (env.ALLOWED_ORIGINS || '')
    .split(',')
    .some((o) => o && (origin === o || (o === 'http://localhost' && origin.startsWith('http://localhost:'))));
}

function corsHeaders(origin, env) {
  if (!isAllowed(origin, env)) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    Vary: 'Origin',
  };
}

function json(obj, status, headers) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...headers },
  });
}

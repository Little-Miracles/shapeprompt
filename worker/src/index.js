// ShapePrompt × PayPal × Gemini — a tiny server between the site and
// PayPal and Gemini. The site never sees a secret: the PayPal secret and
// the Gemini key live only here, as encrypted Cloudflare secrets.
//
//   POST /chat                 {messages, human | session}
//        → {reply, pick, session}   (pick carries the price, or is null)
//   POST /orders               {item, returnUrl, cancelUrl}
//        → {id, approveUrl}         (the price comes from the catalog)
//   POST /orders/:id/capture   → {id, status, amount, payer}
//   POST /requests             {custom, email, consent, session}
//        → {id}                     (a custom request; the maker gets an
//                                    email and answers the customer)
//   POST /photo/read           {image, note, session | human}
//        → {card, reply, session}   (the dragon fills in a card)
//   POST /photo/requests       {image, card, email, consent, rights, session}
//        → {id}                     (the picture goes to the maker attached)
//
// Sandbox only for the hackathon: no real money moves.

import { EmailMessage } from 'cloudflare:email';
import { BadRequest, Busy, chat, customPriced, priced } from './chat.js';
import { checkImage, cleanCard, readPhoto } from './photo.js';

const SESSION_MINUTES = 30; // one Turnstile check lasts this long
const KEEP_DAYS = 182; // custom requests are deleted after half a year
const PHOTO_KEEP_DAYS = 90; // guests' pictures are deleted sooner

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';
    const cors = corsHeaders(origin, env);
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
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

    const url = new URL(request.url);
    try {
      if (url.pathname === '/chat') return await talk(request, env, cors, ip);
      if (url.pathname === '/requests') return await saveRequest(request, env, cors);
      if (url.pathname === '/photo/read') return await photoRead(request, env, cors, ip);
      if (url.pathname === '/photo/requests') return await photoRequest(request, env, cors, ip);
      if (url.pathname === '/orders') {
        return await createOrder(request, env, cors);
      }
      const m = url.pathname.match(/^\/orders\/([A-Z0-9]{8,30})\/capture$/);
      if (m) return await captureOrder(m[1], env, cors);
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
  const session = await personSession(body, env, ip);
  if (!session) return json({ error: 'human check failed' }, 403, cors);
  const answer = await readPhoto(body.image, body.note, body.lang, env);
  return json({ ...answer, session }, 200, cors);
}

/// A picture order: saved for 90 days and sent to the maker with the
/// picture attached. The guest confirms the picture is theirs to use.
async function photoRequest(request, env, cors, ip) {
  const body = await request.json().catch(() => ({}));
  if (!(await personSession(body, env, ip))) {
    return json({ error: 'human check failed' }, 403, cors);
  }
  const email = String(body.email || '').trim();
  if (email.length > 120 || !/^[^\s@<>"',;]+@[^\s@<>"',;]+\.[a-z]{2,}$/i.test(email)) {
    return json({ error: 'bad email' }, 400, cors);
  }
  if (body.consent !== true || body.rights !== true) {
    return json({ error: 'no consent' }, 400, cors);
  }
  const image = checkImage(body.image);
  const card = cleanCard(body.card);
  if (!card.name) return json({ error: 'no name' }, 400, cors);

  const id = 'P' + crypto.randomUUID().slice(0, 7).toUpperCase();
  const createdAt = new Date().toISOString();
  const saved = { id, createdAt, email, kind: 'photo', ...card };
  const ttl = { expirationTtl: PHOTO_KEEP_DAYS * 24 * 60 * 60 };
  await env.REQUESTS.put(`request:${createdAt}:${id}`, JSON.stringify(saved), ttl);
  await env.REQUESTS.put(`photo:${id}`, image, ttl);
  try {
    await tellMakerPhoto(saved, image, env);
  } catch (e) {
    console.log('maker email failed', String(e));
  }
  return json({ id }, 200, cors);
}

async function tellMakerPhoto(r, image, env) {
  const text = [
    `New picture order ${r.id}`,
    '',
    `What: ${r.name}${r.figures > 1 ? ` (${r.figures} figures in the picture — ask which one)` : ''}`,
    `Description: ${r.description || '—'}`,
    r.quality === 'poor' ? '⚠ The picture is not very sharp.' : '',
    `Height: ${r.heightCm ? r.heightCm + ' cm' : 'not given'}`,
    `Material: ${r.materialName || 'not given'} · Color: ${r.color || 'not given'}`,
    `Complexity (the dragon's guess): ${r.complexity || '—'}`,
    r.brand ? '⚠ The dragon thinks this may be a company character or logo.' : '',
    `Wishes: ${r.wishes || '—'}`,
    '',
    'The customer confirmed the picture is theirs or they may use it.',
    `Customer: ${r.email}`,
    'Press Reply to answer the customer: an approximate price, and a',
    '3D preview after a deposit of about 20% (at least 15 zł).',
    '',
    `Sent by the ShapePrompt dragon, ${r.createdAt}`,
  ]
    .filter((l, i, all) => l !== '' || all[i - 1] !== '')
    .join('\n');
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
  // The site says only what was chosen; what it costs is decided here.
  const item = priced(body.item);
  if (!item) return json({ error: 'unknown item' }, 400, cors);
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
          shipping_preference: 'GET_FROM_FILE',
          return_url: returnUrl,
          cancel_url: cancelUrl,
        },
      },
    },
  });
  if (!res.ok) return json({ error: 'create failed', detail: res.data }, 502, cors);
  const approve = (res.data.links || []).find(
    (l) => l.rel === 'payer-action' || l.rel === 'approve',
  );
  return json(
    { id: res.data.id, approveUrl: approve && approve.href, title: item.title, amount: item.total },
    200,
    cors,
  );
}

async function captureOrder(id, env, cors) {
  const res = await paypal(env, `/v2/checkout/orders/${id}/capture`, {});
  if (!res.ok) return json({ error: 'capture failed', detail: res.data }, 502, cors);
  const unit = (res.data.purchase_units || [])[0] || {};
  const capture = ((unit.payments || {}).captures || [])[0] || {};
  const payer = res.data.payer || {};
  return json(
    {
      id: res.data.id,
      status: res.data.status,
      amount: capture.amount,
      payer: {
        name: (payer.name || {}).given_name || '',
        email: payer.email_address || '',
      },
    },
    200,
    cors,
  );
}

async function paypal(env, path, payload) {
  const token = await accessToken(env);
  const r = await fetch(env.PAYPAL_API + path, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'PayPal-Request-Id': crypto.randomUUID(),
    },
    body: JSON.stringify(payload),
  });
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

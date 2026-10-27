// ShapePrompt × PayPal — a tiny server between the site and PayPal.
// The site never sees the PayPal secret: it asks this Worker to create an
// order, sends the customer to PayPal to approve it, and asks the Worker
// to capture it when the customer comes back.
//
//   POST /orders               {title, amount, returnUrl, cancelUrl}
//        → {id, approveUrl}
//   POST /orders/:id/capture   → {id, status, amount, payer}
//
// Sandbox only for the hackathon: no real money moves.

const MAX_PLN = 3000; // a sanity limit for one demo order

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

    const url = new URL(request.url);
    try {
      if (url.pathname === '/orders') {
        return await createOrder(request, env, cors);
      }
      const m = url.pathname.match(/^\/orders\/([A-Z0-9]{8,30})\/capture$/);
      if (m) return await captureOrder(m[1], env, cors);
      return json({ error: 'not found' }, 404, cors);
    } catch (e) {
      return json({ error: 'paypal unavailable', detail: String(e) }, 502, cors);
    }
  },
};

async function createOrder(request, env, cors) {
  const body = await request.json().catch(() => ({}));
  const amount = Number(body.amount);
  if (!Number.isFinite(amount) || amount <= 0 || amount > MAX_PLN) {
    return json({ error: 'bad amount' }, 400, cors);
  }
  const title = String(body.title || 'ShapePrompt order').slice(0, 120);
  const returnUrl = safeUrl(body.returnUrl, env);
  const cancelUrl = safeUrl(body.cancelUrl, env);
  if (!returnUrl || !cancelUrl) {
    return json({ error: 'bad return url' }, 400, cors);
  }

  const res = await paypal(env, '/v2/checkout/orders', {
    intent: 'CAPTURE',
    purchase_units: [
      {
        description: title,
        amount: { currency_code: 'PLN', value: amount.toFixed(2) },
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
  return json({ id: res.data.id, approveUrl: approve && approve.href }, 200, cors);
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
    headers: { 'Content-Type': 'application/json', ...headers },
  });
}

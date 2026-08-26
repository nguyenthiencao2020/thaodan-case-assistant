import { requireUser } from './_auth.js';

const ALLOWED_MODELS = new Set(['openai/gpt-oss-120b']);
const MAX_TOKENS_CAP = 4096;
const MAX_MESSAGES = 20;
const MAX_MSG_CHARS = 20000;

// Validate & giới hạn body của client trước khi forward sang Groq — client không được tự
// chọn model/số token tùy ý (chặn lạm dụng chi phí qua endpoint này).
function sanitizeBody(body) {
  const messages = Array.isArray(body?.messages) ? body.messages : null;
  if (!messages || !messages.length) return { error: 'messages required' };
  if (messages.length > MAX_MESSAGES) return { error: 'Quá nhiều messages' };
  for (const m of messages) {
    if (!m || typeof m.content !== 'string' || m.content.length > MAX_MSG_CHARS) {
      return { error: 'message content không hợp lệ hoặc quá dài' };
    }
    if (!['system', 'user', 'assistant'].includes(m.role)) return { error: 'role không hợp lệ' };
  }
  const model = ALLOWED_MODELS.has(body?.model) ? body.model : 'openai/gpt-oss-120b';
  const temperature = typeof body?.temperature === 'number' ? Math.min(Math.max(body.temperature, 0), 1) : 0.4;
  const max_tokens = Math.min(Number(body?.max_tokens) || 1000, MAX_TOKENS_CAP);
  return { body: { model, temperature, max_tokens, messages } };
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', 'https://thaodan.vercel.app');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const user = await requireUser(req, res);
  if (!user) return; // requireUser đã gửi 401

  const sanitized = sanitizeBody(req.body);
  if (sanitized.error) return res.status(400).json({ error: { message: sanitized.error } });

  // Read keys inside handler so Vercel picks up updated env vars without module cache
  const KEYS = [
    process.env.GROQ_KEY_1,
    process.env.GROQ_KEY_2,
    process.env.GROQ_KEY_3,
  ].filter(Boolean);

  if (KEYS.length === 0)
    return res.status(500).json({ error: { message: 'Chưa cấu hình GROQ_KEY_1/2/3 trên Vercel' } });

  // Round-robin across keys based on current second to spread rate limits
  const apiKey = KEYS[Math.floor(Date.now() / 1000) % KEYS.length];
  const payload = JSON.stringify(sanitized.body);

  try {
    const upstream = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
      body: payload
    });
    const data = await upstream.json();
    // If rate-limited, try remaining keys before giving up
    if (upstream.status === 429 && KEYS.length > 1) {
      for (const key of KEYS.filter(k => k !== apiKey)) {
        const retry = await fetch('https://api.groq.com/openai/v1/chat/completions', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${key}` },
          body: payload
        });
        if (retry.status !== 429) {
          const retryData = await retry.json();
          return res.status(retry.status).json(retryData);
        }
      }
    }
    return res.status(upstream.status).json(data);
  } catch (err) {
    return res.status(502).json({ error: { message: err.message } });
  }
}

import OpenAI from 'openai';
import { requireUser } from './_auth.js';

// Đọc chữ viết tay trong ảnh trang sổ tay của NVXH → trả về văn bản thuần.
// ═══ LƯU Ý BẢO MẬT — KHÁC VỚI /api/chat ═══
// Mọi nơi khác trong app đều CHE tên thật / SĐT / CCCD / địa chỉ trước khi gửi cho AI. Với ảnh
// thì không làm được: thông tin định danh nằm ngay trong nét chữ, không regex nào che được.
// Vì vậy endpoint này gửi dữ liệu ĐỊNH DANH tới OpenAI. Thu hẹp rủi ro bằng cách:
//   - chỉ TRANSCRIBE, không phân tích, không suy diễn → dùng ít token, không sinh nội dung mới;
//   - KHÔNG lưu ảnh ở bất kỳ đâu (không Supabase Storage, không log) — nhận, đọc, bỏ;
//   - văn bản trả về đi qua đúng bộ che của app trước khi tới Groq để phân tích.
// Phía giao diện bắt NVXH xác nhận rõ điều này trước lần dùng đầu tiên.

const MAX_BYTES = 4_000_000;                       // ~4MB, dưới hạn body của Vercel
const ALLOWED = new Set(['image/jpeg', 'image/png', 'image/webp']);
const VISION_MODEL = 'gpt-4o-mini';                // model đọc được ảnh, chi phí thấp

const PROMPT = `Bạn là công cụ chép lại chữ viết tay tiếng Việt.
Nhiệm vụ DUY NHẤT: chép lại NGUYÊN VĂN toàn bộ chữ trong ảnh.

QUY TẮC BẮT BUỘC:
- Chép đúng từng chữ. KHÔNG sửa văn phong, KHÔNG viết lại cho hay hơn.
- KHÔNG thêm bất kỳ thông tin nào không có trong ảnh. KHÔNG suy đoán, KHÔNG diễn giải.
- Chữ nào không đọc được → ghi [không đọc được] tại đúng vị trí đó.
- Giữ nguyên cách xuống dòng, gạch đầu dòng, ngày tháng như trong ảnh.
- KHÔNG thêm lời mở đầu, kết luận, hay nhận xét của bạn.
Chỉ trả về phần văn bản đã chép.`;

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', 'https://thaodan.vercel.app');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const user = await requireUser(req, res);
  if (!user) return; // requireUser đã gửi 401

  if (!process.env.OPENAI_API_KEY) {
    return res.status(503).json({ error: 'Chưa cấu hình OPENAI_API_KEY — tính năng đọc ảnh chưa bật' });
  }

  const { image } = req.body || {};
  if (typeof image !== 'string' || !image.startsWith('data:')) {
    return res.status(400).json({ error: 'Cần ảnh dạng data URL' });
  }
  const m = /^data:([^;,]+);base64,(.+)$/.exec(image);
  if (!m) return res.status(400).json({ error: 'Ảnh không hợp lệ' });
  if (!ALLOWED.has(m[1])) return res.status(400).json({ error: 'Chỉ nhận ảnh JPEG, PNG hoặc WebP' });
  // base64 phình ~4/3 so với dữ liệu gốc
  if (m[2].length * 0.75 > MAX_BYTES) {
    return res.status(413).json({ error: 'Ảnh quá lớn — chụp lại hoặc giảm kích thước' });
  }

  try {
    const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    const r = await openai.chat.completions.create({
      model: VISION_MODEL,
      temperature: 0,
      max_tokens: 2000,
      messages: [{
        role: 'user',
        content: [
          { type: 'text', text: PROMPT },
          { type: 'image_url', image_url: { url: image, detail: 'high' } },
        ],
      }],
    });
    const text = r.choices?.[0]?.message?.content?.trim() || '';
    if (!text) return res.status(200).json({ text: '', warning: 'Không đọc được chữ nào trong ảnh' });
    return res.status(200).json({ text });
  } catch (err) {
    return res.status(502).json({ error: 'Không đọc được ảnh: ' + (err?.message || 'lỗi không rõ') });
  }
}

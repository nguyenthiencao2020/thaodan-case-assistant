import { createClient } from '@supabase/supabase-js';

// Giá trị public (publishable anon key) — không phải secret, nhưng đọc từ env nếu có để dễ đổi mà không sửa code.
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://mlhtvxoricudzstpzquh.supabase.co';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'sb_publishable_SemT5e_eSp8FqkONPGTr0g_HWWtgRT2';

const _authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Chặn truy cập trực tiếp (curl/script) vào các API endpoint gọi Groq/OpenAI —
// bắt buộc phải có access token Supabase hợp lệ của người dùng đã đăng nhập.
// Trả về user nếu hợp lệ, hoặc null nếu không (handler tự trả 401).
export async function requireUser(req, res) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
  if (!token) {
    res.status(401).json({ error: { message: 'Thiếu token đăng nhập' } });
    return null;
  }
  try {
    const { data, error } = await _authClient.auth.getUser(token);
    if (error || !data?.user) {
      res.status(401).json({ error: { message: 'Token không hợp lệ hoặc đã hết hạn' } });
      return null;
    }
    return data.user;
  } catch (e) {
    // Không để lỗi mạng/nội bộ khi xác thực rò rỉ chi tiết ra ngoài
    res.status(401).json({ error: { message: 'Không xác thực được' } });
    return null;
  }
}

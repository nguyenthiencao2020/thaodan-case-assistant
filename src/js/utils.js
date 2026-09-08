// ════════════════════════════════════════════════════════════
// UTILS — Các hàm tiện ích dùng chung (không có side effects)
// ════════════════════════════════════════════════════════════

const esc = s => String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
// esc() chỉ đủ cho phần nội dung giữa hai thẻ. Đặt vào GIÁ TRỊ THUỘC TÍNH thì phải che thêm
// dấu " và ' — thiếu nó, một câu như: Trẻ nói "con không sao" sẽ cắt đứt thuộc tính ngay ở
// dấu ngoặc kép đầu tiên, mất phần còn lại và có thể sinh thuộc tính lạ.
const escAttr = s => esc(s).replace(/"/g, '&quot;').replace(/'/g, '&#39;');
const formatMd = t => esc(t).replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>').replace(/\n/g, '<br>');

function clean(v) {
  if (!v) return '';
  let r = String(v).replace(/\[Cần thu thập thêm\]/gi, '').replace(/\/\//g, '').replace(/\s*[—\-\/|]\s*[—\-\/|]?\s*/g, ' ').replace(/^[\s—\-\/|]+|[\s—\-\/|]+$/g, '').trim();
  if (/^(Lớp|Năm|Trường|Tại)\s*$/i.test(r)) return '';
  return r;
}

function cf(v) {
  const s = String(v || '');
  if (!s || s.includes('[Cần thu thập thêm]') || s === '//') return '';
  return s.trim();
}

function robustJSON(raw) {
  let t = (raw || '').trim()
    .replace(/^```json\s*/im, '').replace(/\s*```\s*$/im, '')
    .replace(/^```\s*/im, '').replace(/\s*```\s*$/im, '').trim();
  try { return JSON.parse(t); } catch (e) {}
  const s = t.indexOf('{');
  if (s < 0) throw new Error('No JSON found');
  let depth = 0, inStr = false, esc2 = false;
  for (let i = s; i < t.length; i++) {
    const c = t[i];
    if (esc2) { esc2 = false; continue; }
    if (c === '\\' && inStr) { esc2 = true; continue; }
    if (c === '"') { inStr = !inStr; continue; }
    if (inStr) continue;
    if (c === '{') depth++;
    else if (c === '}' && --depth === 0) {
      try { return JSON.parse(t.slice(s, i + 1)); } catch (e) { throw new Error('JSON parse error: ' + e.message); }
    }
  }
  // JSON bị cắt cụt (model hết ngân sách token giữa lúc xuất). Trước đây ném lỗi ở đây và cả
  // lượt trích xuất mất trắng — biểu mẫu trống trơn dù 90% dữ liệu đã về. Nay VỚT phần đã
  // nhận: bỏ đoạn dở dang cuối cùng, đóng lại các ngoặc đang mở rồi parse.
  const salvaged = _salvageJSON(t.slice(s));
  if (salvaged) return salvaged;
  throw new Error('Incomplete JSON');
}

// Vớt lại phần đã nhận của một JSON bị cắt giữa dòng.
// Cách làm: đi một lượt, mỗi khi MỘT GIÁ TRỊ kết thúc trọn vẹn thì ghi lại "điểm an toàn" kèm
// ảnh chụp các ngoặc đang mở tại đúng thời điểm đó. Hết chuỗi mà còn ngoặc chưa đóng thì cắt về
// điểm an toàn cuối cùng và đóng đủ ngoặc theo ảnh chụp đó.
// Phân biệt dấu " đóng KHÓA với dấu " đóng GIÁ TRỊ bằng cách nhìn ký tự kế tiếp: nếu là ':'
// thì vừa đóng một khóa (chưa có giá trị, không phải điểm an toàn).
function _salvageJSON(t) {
  const stack = [];
  let inStr = false, esc = false, safeAt = -1, safeStack = null;
  const mark = (i) => { safeAt = i; safeStack = stack.slice(); };
  for (let i = 0; i < t.length; i++) {
    const c = t[i];
    if (esc) { esc = false; continue; }
    if (c === '\\' && inStr) { esc = true; continue; }
    if (c === '"') {
      if (inStr) {
        inStr = false;
        let j = i + 1; while (j < t.length && /\s/.test(t[j])) j++;
        // Hết chuỗi mà chưa thấy ký tự kế tiếp thì KHÔNG kết luận: có thể là khóa vừa đóng mà
        // giá trị chưa kịp tới (VD ...{"nguy_co" ). Coi là chưa an toàn, thà lùi về mốc trước.
        if (j < t.length && t[j] !== ':') mark(i);   // đóng GIÁ TRỊ → điểm an toàn
      } else inStr = true;
      continue;
    }
    if (inStr) continue;
    if (c === '{' || c === '[') stack.push(c === '{' ? '}' : ']');
    else if (c === '}' || c === ']') { stack.pop(); mark(i); }
    else if (c === ',') { if (safeAt < 0) mark(i - 1); }   // số/true/false/null vừa kết thúc
  }
  if (!stack.length || safeAt < 0 || !safeStack) return null;
  let head = t.slice(0, safeAt + 1).replace(/,\s*$/, '');
  for (let i = safeStack.length - 1; i >= 0; i--) head += safeStack[i];
  try {
    const o = JSON.parse(head);
    return (o && typeof o === 'object' && Object.keys(o).length) ? o : null;
  } catch (e) { return null; }
}


// Định dạng lại một giá trị NGÀY.
// CẢNH BÁO đã từng thành lỗi thật: các mẫu ở cuối hàm này trước đây KHÔNG neo đầu/cuối chuỗi,
// nên bất kỳ giá trị nào có chứa một cụm giống ngày đều bị THAY TRẮNG bằng đúng cụm đó:
//   "Khoa đi học lại lớp 6 từ 01/10/2026 tại THCS Hòa Bình" → "01/10/2026"   (mất hết nội dung)
//   "CA-2026-09-0001" (mã hồ sơ)                            → "26/09/0001"  (in sai trên form)
// Bản in .docx chạy fmtDate cho MỌI ô label:value (xem FTBL), nên lỗi này âm thầm xóa nội dung
// của các ô mô tả dài. Nay chỉ định dạng khi TOÀN BỘ giá trị là một ngày; còn lại giữ nguyên văn.
function fmtDate(v) {
  if (!v || typeof v !== 'string') return String(v || '');
  const raw = v.trim();
  // Cho phép từ dẫn ở ĐẦU ("ngày 05/09/2026") và dấu câu ở cuối — không cho chữ ở giữa.
  const core = raw
    .replace(/^(?:ngày|vào|từ|kể từ|đến|trước|sau|bắt đầu|khoảng)\s+/i, '')
    .replace(/[.,;:]+$/, '')
    .trim();
  // Cổng chặn: chỉ số, dấu phân cách, và tối đa một chữ "tháng" ở đầu.
  if (!/^(?:[Tt]háng\s+)?\d{1,4}(?:\s*[.\/\-\s]\s*\d{1,4}){0,2}$/.test(core)) return raw;

  const v2 = core;
  if (/^\d{1,2}\/\d{1,2}\/\d{4}$/.test(v2)) return v2;
  let m = v2.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  if (m) return m[3].padStart(2, '0') + '/' + m[2].padStart(2, '0') + '/' + m[1];
  m = v2.match(/^(\d{1,2})[.\-](\d{1,2})[.\-](\d{4})$/);
  if (m) return m[1].padStart(2, '0') + '/' + m[2].padStart(2, '0') + '/' + m[3];
  m = v2.match(/^(\d{1,2})\s+(\d{1,2})\s+(\d{4})$/);
  if (m) return m[1].padStart(2, '0') + '/' + m[2].padStart(2, '0') + '/' + m[3];
  m = v2.match(/^(\d{4})\/(\d{1,2})\/(\d{1,2})$/);
  if (m) return m[3].padStart(2, '0') + '/' + m[2].padStart(2, '0') + '/' + m[1];
  m = v2.match(/^(\d{1,2})\/(\d{4})$/);
  if (m) return '01/' + m[1].padStart(2, '0') + '/' + m[2];
  m = v2.match(/^[Tt]háng\s+(\d{1,2})[\/\-](\d{4})$/);
  if (m) return '01/' + m[1].padStart(2, '0') + '/' + m[2];
  m = v2.match(/^(\d{4})-(\d{1,2})$/);
  if (m) return '01/' + m[2].padStart(2, '0') + '/' + m[1];
  m = v2.match(/^(\d{1,2})\s+(\d{4})$/);
  if (m) return '01/' + m[1].padStart(2, '0') + '/' + m[2];
  m = v2.match(/^(\d{1,2})-(\d{4})$/);
  if (m) return '01/' + m[1].padStart(2, '0') + '/' + m[2];
  m = v2.match(/^[Tt]háng\s+(\d{1,2})\s+(\d{4})$/);
  if (m) return '01/' + m[1].padStart(2, '0') + '/' + m[2];
  m = v2.match(/^(\d{1,2})[\s\/\-](\d{1,2})[\s\/\-](\d{4})$/);
  if (m) return m[1].padStart(2, '0') + '/' + m[2].padStart(2, '0') + '/' + m[3];
  return raw;
}

function fmtVN(iso) {
  const d = new Date(iso || Date.now());
  return isNaN(d.getTime()) ? '' : d.toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

let notifTimer;
function showNotif(msg, type = 'ok') {
  const el = document.getElementById('notif');
  el.textContent = msg;
  el.className = 'notif notif-' + type;
  el.style.display = 'block';
  if (notifTimer) clearTimeout(notifTimer);
  notifTimer = setTimeout(() => { el.style.display = 'none'; }, 3500);
}

// ════════════════════════════════════════════════════════════
// DEEP MERGE — Sống còn: không ghi đè dữ liệu cũ bằng rỗng
// ════════════════════════════════════════════════════════════

const FIELD_MERGE_KEYS = new Set(['danh_gia', 'vang_gia', 'ket_thuc', 'chuyen_gui', 'tien_trinh']);

function deepMergeFields(target, source) {
  if (!source || typeof source !== 'object') return target;
  const result = Object.assign({}, target);
  for (const key of Object.keys(source)) {
    const sv = source[key];
    if (sv === '' || sv === null || sv === undefined) continue;
    if (typeof sv === 'string' && /\[Cần thu thập thêm\]|\/\/|^Không rõ$/i.test(sv)) continue;
    result[key] = sv;
  }
  return result;
}

// ── Gộp mảng: HỢP hai bên, giữ thứ tự cũ rồi nối phần tử mới ────────────────────────────
// Mảng ở đây là mục tiêu, hoạt động, thành viên gia đình, ngày xem xét — dữ liệu CỘNG DỒN.
// Hai cách làm trước đều sai:
//   v1: chỉ nhận mảng mới khi mảng cũ RỖNG → lần trích xuất đầu là đóng băng vĩnh viễn.
//   v2: so số lượng → NVXH ghi "giữ nguyên 2 mục tiêu cũ, thêm mục tiêu 3 và 4" thì AI chỉ trả
//       về 2 mục tiêu MỚI, 2 so 2 nên vẫn giữ mảng cũ — thêm gì cũng không vào.
// Nay so DANH TÍNH từng phần tử: trùng thì bỏ qua, mới thì nối thêm. Không bao giờ làm ngắn đi.
// Đánh đổi đã biết: nếu AI diễn đạt lại một mục tiêu cũ bằng câu khác thì sinh dòng trùng ý —
// NVXH thấy và xóa được, còn mất mục tiêu mới thì không ai thấy.
function _arrIdent(x) {
  if (x === null || x === undefined) return '';
  if (typeof x !== 'object') {
    return String(x).normalize('NFD').replace(/[\u0300-\u036f]/g, '')
      .toLowerCase().replace(/đ/g, 'd').replace(/[^a-z0-9]+/g, ' ').trim();
  }
  // Lấy chuỗi có nội dung ĐẦU TIÊN làm danh tính (VD hoat_dong.noi_dung, thanh_vien.ho_ten)
  for (const k of Object.keys(x)) {
    const v = x[k];
    if (typeof v === 'string' && v.trim()) return _arrIdent(v);
  }
  try { return JSON.stringify(x); } catch (e) { return ''; }
}

function mergeArrays(tv, sv) {
  if (!Array.isArray(sv) || !sv.length) return Array.isArray(tv) ? tv : [];
  if (!Array.isArray(tv) || !tv.length) return sv;
  const seen = new Set(tv.map(_arrIdent).filter(Boolean));
  const out = tv.slice();
  for (const it of sv) {
    const id = _arrIdent(it);
    if (!id) continue;              // phần tử rỗng (VD xem_xet: [""]) — không nối rác
    if (seen.has(id)) continue;
    seen.add(id);
    out.push(it);
  }
  return out;
}

function deepMerge(target, source) {
  if (source === null || source === undefined) return target;
  if (target === null || target === undefined) {
    return typeof source === 'object' && !Array.isArray(source) ? deepMerge({}, source) : source;
  }
  if (Array.isArray(source)) {
    if (!source.length) return target;
    if (!Array.isArray(target) || !target.length) return source;
    return target;
  }
  if (typeof source === 'object') {
    const result = Object.assign({}, target);
    for (const key of Object.keys(source)) {
      const sv = source[key];
      const tv = target[key];
      if (sv === '' || sv === null || sv === undefined) continue;
      if (typeof sv === 'string' && /\[Cần thu thập thêm\]|\/\/|^Không rõ$/i.test(sv)) continue;
      if (typeof sv === 'object' && !Array.isArray(sv)) {
        result[key] = FIELD_MERGE_KEYS.has(key) ? deepMergeFields(tv || {}, sv) : deepMerge(tv || {}, sv);
      } else if (Array.isArray(sv)) {
        result[key] = mergeArrays(tv, sv);
      } else {
        result[key] = sv;
      }
    }
    return result;
  }
  return (source !== '' && source !== null && source !== undefined) ? source : target;
}

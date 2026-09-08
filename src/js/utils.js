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


function fmtDate(v) {
  if (!v || typeof v !== 'string') return String(v || '');
  v = v.trim();
  if (/^\d{1,2}\/\d{1,2}\/\d{4}$/.test(v)) return v;
  let m = v.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  if (m) return m[3].padStart(2, '0') + '/' + m[2].padStart(2, '0') + '/' + m[1];
  m = v.match(/^(\d{1,2})[.\-](\d{1,2})[.\-](\d{4})$/);
  if (m) return m[1].padStart(2, '0') + '/' + m[2].padStart(2, '0') + '/' + m[3];
  m = v.match(/^(\d{1,2})\s+(\d{1,2})\s+(\d{4})$/);
  if (m) return m[1].padStart(2, '0') + '/' + m[2].padStart(2, '0') + '/' + m[3];
  m = v.match(/^(\d{4})\/(\d{1,2})\/(\d{1,2})$/);
  if (m) return m[3].padStart(2, '0') + '/' + m[2].padStart(2, '0') + '/' + m[1];
  m = v.match(/^(\d{1,2})\/(\d{4})$/);
  if (m) return '01/' + m[1].padStart(2, '0') + '/' + m[2];
  m = v.match(/[Tt]háng\s+(\d{1,2})[\/\-](\d{4})/);
  if (m) return '01/' + m[1].padStart(2, '0') + '/' + m[2];
  m = v.match(/^(\d{4})-(\d{1,2})$/);
  if (m) return '01/' + m[2].padStart(2, '0') + '/' + m[1];
  m = v.match(/^(\d{1,2})\s+(\d{4})$/);
  if (m) return '01/' + m[1].padStart(2, '0') + '/' + m[2];
  m = v.match(/^(\d{1,2})-(\d{4})$/);
  if (m) return '01/' + m[1].padStart(2, '0') + '/' + m[2];
  m = v.match(/[Tt]háng\s+(\d{1,2})\s+(\d{4})/);
  if (m) return '01/' + m[1].padStart(2, '0') + '/' + m[2];
  m = v.match(/(\d{1,2})[\s\/\-](\d{1,2})[\s\/\-](\d{4})/);
  if (m) return m[1].padStart(2, '0') + '/' + m[2].padStart(2, '0') + '/' + m[3];
  return v;
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
        // Mảng (mục tiêu, hoạt động, thành viên gia đình...): trước đây chỉ nhận mảng mới KHI
        // mảng cũ rỗng, nên lần trích xuất đầu tiên là ĐÓNG BĂNG luôn — phân tích lại với ghi
        // chép đầy đủ hơn không bao giờ thêm được mục tiêu/hoạt động nào nữa.
        // Nay: mảng mới dài hơn thì nhận, ngắn hơn hoặc bằng thì giữ mảng cũ. Không bao giờ để
        // một lượt trích xuất nghèo thông tin làm mất bớt dữ liệu đã có.
        result[key] = (Array.isArray(tv) && tv.length >= sv.length) ? tv : sv;
      } else {
        result[key] = sv;
      }
    }
    return result;
  }
  return (source !== '' && source !== null && source !== undefined) ? source : target;
}

#!/usr/bin/env node
// Indexes all .md/.txt files in /docs/ into Supabase pgvector.
// Run: node scripts/index-docs.js
// Env required: SUPABASE_URL, SUPABASE_SERVICE_KEY, OPENAI_API_KEY

import { createClient } from '@supabase/supabase-js';
import OpenAI from 'openai';
import { readFileSync, readdirSync, statSync } from 'fs';
import { join, relative, extname, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const DOCS_DIR = join(ROOT, 'docs');

// --dry-run: chỉ xem tài liệu sẽ được cắt thành những mẩu nào, KHÔNG cần API key,
// KHÔNG gọi OpenAI, KHÔNG ghi vào database. Dùng để kiểm tra trước khi nạp thật.
const DRY_RUN = process.argv.includes('--dry-run');

const { SUPABASE_URL, SUPABASE_SERVICE_KEY, OPENAI_API_KEY } = process.env;
if (!DRY_RUN && (!SUPABASE_URL || !SUPABASE_SERVICE_KEY || !OPENAI_API_KEY)) {
  console.error('❌ Thiếu biến môi trường: SUPABASE_URL, SUPABASE_SERVICE_KEY, OPENAI_API_KEY');
  console.error('   (chạy "node scripts/index-docs.js --dry-run" để xem trước, không cần key)');
  process.exit(1);
}

const supabase = DRY_RUN ? null : createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
const openai = DRY_RUN ? null : new OpenAI({ apiKey: OPENAI_API_KEY });

const CHUNK_SIZE = 800;
const CHUNK_OVERLAP = 150;

function getAllFiles(dir, acc = []) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (entry.startsWith('.') || entry === 'README.md') continue;
    if (statSync(full).isDirectory()) getAllFiles(full, acc);
    else if (['.md', '.txt'].includes(extname(entry))) acc.push(full);
  }
  return acc;
}

// Cắt theo TIÊU ĐỀ và ĐOẠN, không cắt theo số ký tự cứng.
// Cắt cứng 800 ký tự sẽ chặt ngang giữa câu, giữa bảng, và phá vỡ từng mục trong danh bạ
// nguồn lực (tên trường / số điện thoại / người phụ trách bị tách rời nhau) — khi truy xuất
// thì AI nhận được nửa mẩu vô nghĩa. Mỗi chunk nay được gắn kèm đường dẫn tiêu đề để giữ
// ngữ cảnh (VD "Danh bạ nguồn lực > Giáo dục > Quận 8").
function chunkText(text) {
  const lines = String(text).split(/\r?\n/);
  const blocks = [];            // {heading, body}
  let trail = [];               // ngăn xếp tiêu đề đang mở, theo cấp #
  let cur = { heading: '', body: [] };

  const flush = () => {
    const body = cur.body.join('\n').trim();
    if (body) blocks.push({ heading: cur.heading, body });
    cur = { heading: trail.join(' > '), body: [] };
  };

  for (const line of lines) {
    const m = /^(#{1,6})\s+(.*)$/.exec(line);
    if (m) {
      flush();
      const lvl = m[1].length;
      trail = trail.slice(0, lvl - 1);
      trail[lvl - 1] = m[2].trim();
      trail = trail.filter(Boolean);
      cur.heading = trail.join(' > ');
    } else {
      cur.body.push(line);
    }
  }
  flush();

  // Đoạn nào vẫn dài quá thì tách tiếp theo dòng trống, và chỉ khi bất khả kháng mới cắt cứng.
  const out = [];
  for (const blk of blocks) {
    const prefix = blk.heading ? `[${blk.heading}]\n` : '';
    if ((prefix + blk.body).length <= CHUNK_SIZE * 1.6) {
      out.push(prefix + blk.body);
      continue;
    }
    let buf = [];
    const paras = blk.body.split(/\n\s*\n/);
    const push = () => { const t = buf.join('\n\n').trim(); if (t) out.push(prefix + t); buf = []; };
    for (const para of paras) {
      if (buf.join('\n\n').length + para.length > CHUNK_SIZE && buf.length) push();
      if (para.length > CHUNK_SIZE * 2) {
        push();
        for (let i = 0; i < para.length; i += CHUNK_SIZE - CHUNK_OVERLAP) {
          out.push(prefix + para.slice(i, i + CHUNK_SIZE).trim());
        }
      } else buf.push(para);
    }
    push();
  }
  return out.map(c => c.trim()).filter(c => c.length > 60);
}

async function embedBatch(texts) {
  const res = await openai.embeddings.create({ model: 'text-embedding-3-small', input: texts });
  return res.data.map(d => d.embedding);
}

async function indexFile(filePath) {
  const sourceFile = relative(ROOT, filePath);
  const text = readFileSync(filePath, 'utf-8');
  // File khung mẫu chưa điền dữ liệu thật thì bỏ qua — nạp vào chỉ làm nhiễu kho tri thức
  // (AI sẽ truy xuất ra những dòng toàn dấu "..."). Xóa dòng SKIP-INDEX khi đã điền xong.
  if (/<!--\s*SKIP-INDEX\s*-->/.test(text)) {
    console.log(`  ${sourceFile} → BỎ QUA (còn dấu SKIP-INDEX: khung mẫu chưa điền)`);
    return 0;
  }
  const chunks = chunkText(text);
  console.log(`  ${sourceFile} → ${chunks.length} mẩu`);

  if (DRY_RUN) {
    chunks.forEach((c, i) => {
      const head = (/^\[(.+?)\]/.exec(c) || [, '(không có tiêu đề)'])[1];
      console.log(`    ${String(i + 1).padStart(3)}. [${c.length} ký tự] ${head}`);
      console.log(`         ${c.replace(/^\[.*?\]\n/, '').replace(/\s+/g, ' ').slice(0, 110)}...`);
    });
    return chunks.length;
  }

  await supabase.from('documents').delete().eq('source_file', sourceFile);

  for (let i = 0; i < chunks.length; i += 10) {
    const batch = chunks.slice(i, i + 10);
    const embeddings = await embedBatch(batch);
    const rows = batch.map((content, j) => ({
      content,
      embedding: embeddings[j],
      source_file: sourceFile,
      metadata: { chunk_index: i + j },
    }));
    const { error } = await supabase.from('documents').insert(rows);
    if (error) console.error(`    ⚠️  Lỗi ghi mẩu ${i}: ${error.message}`);
  }
  return chunks.length;
}

async function main() {
  const files = getAllFiles(DOCS_DIR);
  console.log(`\n📚 ${DRY_RUN ? 'CHẠY THỬ — xem trước cách cắt mẩu' : 'Đang nạp'} ${files.length} tài liệu từ docs/\n`);
  let total = 0;
  for (const f of files) { total += (await indexFile(f)) || 0; }
  console.log(`\n${DRY_RUN ? '✅ Chạy thử xong' : '✅ Đã nạp'} — tổng ${total} mẩu.`);
  if (DRY_RUN) console.log('   Nếu các mẩu trên trông hợp lý, chạy lại KHÔNG có --dry-run để nạp thật.\n');
  else console.log('');
}

main().catch(err => { console.error(err); process.exit(1); });

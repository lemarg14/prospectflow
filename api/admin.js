// =====================================================================
//  Fonction serverless Vercel — gestion des comptes (admin uniquement)
//  Actions : create | delete | reset (mot de passe) | setrole
//  Sécurité : vérifie que l'appelant est bien admin avant toute action.
//  Variables d'env Vercel requises :
//    SUPABASE_URL                 (ex : https://xxxx.supabase.co)
//    SUPABASE_SERVICE_ROLE_KEY    (clé "service_role" — SECRÈTE, jamais côté client)
// =====================================================================

const URL = process.env.SUPABASE_URL;
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY;

function admHeaders() {
  return { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, 'Content-Type': 'application/json' };
}

async function callerIsAdmin(token) {
  if (!token) return false;
  // 1) qui est l'appelant ?
  const uRes = await fetch(`${URL}/auth/v1/user`, {
    headers: { apikey: SERVICE, Authorization: `Bearer ${token}` },
  });
  if (!uRes.ok) return false;
  const u = await uRes.json();
  if (!u || !u.id) return false;
  // 2) son rôle dans profiles
  const pRes = await fetch(`${URL}/rest/v1/profiles?id=eq.${u.id}&select=role`, { headers: admHeaders() });
  if (!pRes.ok) return false;
  const rows = await pRes.json();
  return rows[0] && rows[0].role === 'admin';
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Méthode non autorisée' });
  }
  if (!URL || !SERVICE) {
    return res.status(500).json({ error: 'Variables SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY manquantes sur Vercel.' });
  }

  const token = (req.headers.authorization || '').replace('Bearer ', '');
  const ok = await callerIsAdmin(token);
  if (!ok) return res.status(403).json({ error: "Accès réservé à l'administrateur." });

  // body peut arriver en string selon la config
  let body = req.body;
  if (typeof body === 'string') { try { body = JSON.parse(body); } catch { body = {}; } }
  const { action } = body || {};

  try {
    if (action === 'create') {
      const { email, password, full_name, role } = body;
      if (!email || !password) return res.status(400).json({ error: 'Email et mot de passe requis.' });
      const cRes = await fetch(`${URL}/auth/v1/admin/users`, {
        method: 'POST',
        headers: admHeaders(),
        body: JSON.stringify({ email, password, email_confirm: true, user_metadata: { full_name: full_name || '' } }),
      });
      const created = await cRes.json();
      if (!cRes.ok) return res.status(400).json({ error: created.msg || created.error_description || created.message || 'Création impossible.' });
      // le trigger a créé le profil ; on force role + nom
      await fetch(`${URL}/rest/v1/profiles?id=eq.${created.id}`, {
        method: 'PATCH',
        headers: { ...admHeaders(), Prefer: 'return=minimal' },
        body: JSON.stringify({ role: role === 'admin' ? 'admin' : 'commercial', full_name: full_name || '' }),
      });
      return res.status(200).json({ ok: true, id: created.id });
    }

    if (action === 'delete') {
      const { user_id } = body;
      if (!user_id) return res.status(400).json({ error: 'user_id requis.' });
      const dRes = await fetch(`${URL}/auth/v1/admin/users/${user_id}`, { method: 'DELETE', headers: admHeaders() });
      if (!dRes.ok) { const e = await dRes.json().catch(() => ({})); return res.status(400).json({ error: e.msg || 'Suppression impossible.' }); }
      return res.status(200).json({ ok: true });
    }

    if (action === 'reset') {
      const { user_id, password } = body;
      if (!user_id || !password) return res.status(400).json({ error: 'user_id et password requis.' });
      const rRes = await fetch(`${URL}/auth/v1/admin/users/${user_id}`, {
        method: 'PUT', headers: admHeaders(), body: JSON.stringify({ password }),
      });
      if (!rRes.ok) { const e = await rRes.json().catch(() => ({})); return res.status(400).json({ error: e.msg || 'Reset impossible.' }); }
      return res.status(200).json({ ok: true });
    }

    if (action === 'setrole') {
      const { user_id, role } = body;
      if (!user_id || !role) return res.status(400).json({ error: 'user_id et role requis.' });
      await fetch(`${URL}/rest/v1/profiles?id=eq.${user_id}`, {
        method: 'PATCH', headers: { ...admHeaders(), Prefer: 'return=minimal' },
        body: JSON.stringify({ role: role === 'admin' ? 'admin' : 'commercial' }),
      });
      return res.status(200).json({ ok: true });
    }

    return res.status(400).json({ error: 'Action inconnue.' });
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
}

# Escala de Funcionários + Ponto

App web (HTML único) de escala e ponto, conectado ao Supabase (Auth + Postgres + RLS + Realtime).

## Estrutura
- `index.html` — o app inteiro (frontend).
- `supabase/schema.sql` — esquema do banco (tabelas, RLS, função `is_gestor`).
- Edge Function `admin-users` — criação/remoção de funcionário e reset de PIN (roda no servidor, com `service_role`).

## Como funciona o acesso
- **Gestor**: e-mail + senha. Vê e gerencia tudo.
- **Funcionário**: login + PIN (mapeado internamente para `login@escala.local`). Vê só os próprios dados e bate ponto.
- Segurança por linha (RLS): o servidor só entrega a cada usuário os dados dele.

## Deploy (GitHub Pages)
1. Crie um repositório no GitHub e suba estes arquivos.
2. Settings → Pages → Source: branch `main`, pasta `/root`.
3. O app fica em `https://SEU-USUARIO.github.io/NOME-DO-REPO/`.

## ⚠️ Antes de publicar
- Troque a senha provisória do gestor (Config → Senha do gestor).
- Apague o funcionário de teste (`teste`).
- A chave `anon` no `index.html` é pública por design (protegida por RLS). **Nunca** comite a `service_role` nem a senha do banco.

## Aviso sobre "ponto legal"
Este app, no estado atual, é uma ferramenta de gestão/registro informal. **Não** é um REP-P em conformidade com a Portaria MTP 671/2021 (falta AFD assinado em CAdES, comprovante PAdES por marcação, imutabilidade certificada, etc.). Ver discussão no chat.

# GitHub App Setup para ekson73/openclaw

Este documento descreve como configurar o GitHub App necessário para os workflows de automação.

## Workflows que Requerem GitHub App

| Workflow | Função |
|----------|--------|
| `auto-response.yml` | Responde automaticamente a issues/PRs com labels específicas |
| `labeler.yml` | Adiciona labels automáticas em PRs baseado em arquivos modificados |

## Passo 1: Criar o GitHub App

1. Acesse: https://github.com/settings/apps/new

2. Preencha os campos:

| Campo | Valor |
|-------|-------|
| **GitHub App name** | `ekson73-openclaw-automation` |
| **Homepage URL** | `https://github.com/ekson73/openclaw` |
| **Webhook** | ❌ Desmarcar "Active" (não precisamos) |

3. **Permissions** (Repository permissions):

| Permission | Access |
|------------|--------|
| **Contents** | Read-only |
| **Issues** | Read and write |
| **Metadata** | Read-only (obrigatório) |
| **Pull requests** | Read and write |

4. **Where can this GitHub App be installed?**
   - ✅ Only on this account

5. Clique em **Create GitHub App**

## Passo 2: Gerar Private Key

1. Após criar, você será redirecionado para a página do App
2. Role até **Private keys**
3. Clique em **Generate a private key**
4. Um arquivo `.pem` será baixado automaticamente
5. **GUARDE ESTE ARQUIVO** - você precisará do conteúdo

## Passo 3: Anotar o App ID

Na página do GitHub App, anote:
- **App ID**: Número mostrado no topo (ex: `1234567`)

## Passo 4: Instalar o App no Repositório

1. Na página do App, clique em **Install App** (menu lateral)
2. Selecione sua conta
3. Escolha **Only select repositories**
4. Selecione `ekson73/openclaw`
5. Clique em **Install**

## Passo 5: Configurar Secrets no Repositório

1. Acesse: https://github.com/ekson73/openclaw/settings/secrets/actions

2. Clique em **New repository secret**

3. Adicione os seguintes secrets:

### Secret 1: APP_ID
- **Name**: `APP_ID`
- **Secret**: O App ID anotado no Passo 3

### Secret 2: APP_PRIVATE_KEY
- **Name**: `APP_PRIVATE_KEY`
- **Secret**: O conteúdo completo do arquivo `.pem` baixado
  - Abra o arquivo `.pem` em um editor de texto
  - Copie TODO o conteúdo (incluindo `-----BEGIN RSA PRIVATE KEY-----` e `-----END RSA PRIVATE KEY-----`)
  - Cole no campo Secret

## Passo 6: Atualizar Workflows

Os workflows precisam usar nosso App ID em vez do upstream:

### auto-response.yml (linha ~20)
```yaml
- uses: actions/create-github-app-token@v1
  id: app-token
  with:
    app-id: ${{ secrets.APP_ID }}  # ← Usar nosso secret
    private-key: ${{ secrets.APP_PRIVATE_KEY }}
```

### labeler.yml (linha ~18)
```yaml
- uses: actions/create-github-app-token@v1
  id: app-token
  with:
    app-id: ${{ secrets.APP_ID }}  # ← Usar nosso secret
    private-key: ${{ secrets.APP_PRIVATE_KEY }}
```

## Passo 7: Verificar Funcionamento

1. Crie uma issue de teste no repositório
2. Verifique se o bot responde (se a issue tiver label apropriada)
3. Crie um PR de teste
4. Verifique se labels são adicionadas automaticamente

## Troubleshooting

### Erro: "Resource not accessible by integration"
- Verifique se o App está instalado no repositório
- Verifique as permissions do App

### Erro: "Could not create token"
- Verifique se APP_ID e APP_PRIVATE_KEY estão corretos
- Verifique se a private key está completa (incluindo headers)

### Workflows não disparam
- Verifique se os workflows estão habilitados em Actions
- Verifique se o App tem as permissions corretas

## Segurança

- ⚠️ **NUNCA** commite a private key no repositório
- ⚠️ **NUNCA** compartilhe a private key
- ✅ Use apenas GitHub Secrets para armazenar credenciais
- ✅ Revogue e regenere a key se suspeitar de vazamento

---

*Criado em 2026-02-08*

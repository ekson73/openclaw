# Configuração do GitHub App para Workflows de Automação

Este documento descreve como configurar o GitHub App necessário para os workflows de automação do fork.

## Workflows que Requerem GitHub App

| Workflow | Função |
|----------|--------|
| `auto-response.yml` | Responde automaticamente a issues/PRs com labels `r:*` |
| `labeler.yml` | Adiciona labels automáticas baseado em arquivos modificados |

## Por que GitHub App?

Os workflows usam `actions/create-github-app-token` ao invés de `GITHUB_TOKEN` porque:
- Tokens de App têm permissões mais granulares
- Podem atuar em nome do App (não do usuário)
- Necessário para algumas operações em `pull_request_target`

## Passo a Passo

### 1. Criar GitHub App

1. Acesse: **Settings** > **Developer settings** > **GitHub Apps** > **New GitHub App**
2. Configure:
   - **GitHub App name:** `ekson73-openclaw-automation` (ou nome único)
   - **Homepage URL:** `https://github.com/ekson73/openclaw`
   - **Webhook:** Desmarque "Active" (não precisamos)

### 2. Configurar Permissões

Em **Permissions & events** > **Repository permissions**:

| Permissão | Acesso |
|-----------|--------|
| Issues | Read & Write |
| Pull requests | Read & Write |
| Contents | Read |

### 3. Instalar no Repositório

1. Após criar, clique em **Install App**
2. Selecione **Only select repositories**
3. Escolha `ekson73/openclaw`
4. Clique **Install**

### 4. Gerar Private Key

1. Na página do App, seção **Private keys**
2. Clique **Generate a private key**
3. Salve o arquivo `.pem` (será baixado automaticamente)

### 5. Adicionar Secret no Repositório

1. Acesse: **Settings** > **Secrets and variables** > **Actions**
2. Clique **New repository secret**
3. Configure:
   - **Name:** `GH_APP_PRIVATE_KEY`
   - **Secret:** Cole o conteúdo completo do arquivo `.pem`
4. Clique **Add secret**

### 6. Atualizar App ID nos Workflows

O upstream usa `app-id: "2729701"`. Precisamos atualizar para o nosso App ID:

```bash
# Encontre seu App ID na página do GitHub App (Settings > Developer settings > GitHub Apps)
# Atualize nos workflows:
sed -i 's/app-id: "2729701"/app-id: "SEU_APP_ID"/' .github/workflows/auto-response.yml
sed -i 's/app-id: "2729701"/app-id: "SEU_APP_ID"/' .github/workflows/labeler.yml
```

## Verificação

Após configurar, os workflows devem passar. Se ainda falharem:

```bash
# Verifique os logs do workflow
gh run view <run-id> --log-failed
```

## Alternativa: Desabilitar Workflows

Se preferir não configurar o GitHub App:

```bash
# Desabilitar via GitHub CLI
gh workflow disable "Auto response" --repo ekson73/openclaw
gh workflow disable "Labeler" --repo ekson73/openclaw
```

Ou remova os arquivos:
```bash
rm .github/workflows/auto-response.yml .github/workflows/labeler.yml
```

## Referências

- [GitHub Apps Documentation](https://docs.github.com/en/apps)
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
- [actions/labeler](https://github.com/actions/labeler)

---

*Criado: 2026-02-08*

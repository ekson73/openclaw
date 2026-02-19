# ADR-003: Zero Trust Upstream — Todo Commit Passa Pelo Nosso Pipeline

**Status:** APROVADO
**Data:** 2026-02-08 (decisão original) | 2026-02-19 (formalização)
**Participantes:** Emilson + Eko
**Contexto:** Fork Harvest Pipeline, upstream sync

---

## Decisão

**Nenhum commit, de nenhuma fonte (incluindo o upstream openclaw/openclaw), entra no nosso fork sem passar pelo pipeline completo de validação.**

## Princípio Fundador (Emilson, 2026-02-08)

> "Cria os PRs no nosso fork primeiro, pois ele é independente... mas colabora com o pai, abre um PR para eles também com nossas sugestões, aí depende deles aceitarem ou não, mas nosso fork vai seguir conforme nossa consciência do que deve ser feito."

## Regras

1. **Zero Trust:** Não importa quem é o autor — upstream, fork irmão, contributor externo — TODO código passa pelo pipeline
2. **Pipeline Completo:** Scanner → Security → Analyst → Architect → Adopter → Tester → Releaser
3. **upstream-sync = Mirror Read-Only:** Branch que espelha upstream/main, nunca alterada por nós
4. **Scanner consome upstream-sync:** Compara com develop, identifica novidades, alimenta fork-queue.json
5. **Nenhum auto-merge em main/develop:** Workflow `sync-n-build.yml` atualiza APENAS `upstream-sync`
6. **Fork First:** PRs sempre no nosso fork primeiro, contribuições upstream são cortesia

## Fluxo

```
upstream/main (openclaw)
       │
       ▼
  upstream-sync (mirror, read-only, auto-sync diário)
       │
       ▼
  Scanner (AI-agent) compara upstream-sync vs develop
       │
       ▼
  fork-queue.json (novidades identificadas)
       │
       ▼
  Pipeline completo (Security → Analyst → Architect → Adopter → Tester → Releaser)
       │
       ▼
  harvest/* branch → PR → develop → staging → main
```

## Justificativa

- **Supply-chain attacks:** Upstream pode ser comprometido (dependência maliciosa, maintainer hijacked)
- **Qualidade:** Nem todo commit upstream é relevante ou compatível com nosso fork
- **Independência:** Fork tem visão própria — adotamos o que se alinha com nossos valores
- **Governança AI:** Agentes precisam de regras claras — "tudo passa pelo pipeline" é inequívoco

## Consequências

- Upstream sync é mais lento (não instantâneo)
- Scanner precisa rodar periodicamente (cron diário)
- Mais trabalho operacional, mas mais segurança e controle
- `sync-n-build.yml` precisa ser adaptado (mirror-only, não push em main)

## Anti-patterns

- ❌ Auto-merge upstream → main (bypass de toda governança)
- ❌ Cherry-pick manual sem registrar no pipeline
- ❌ "Confio no upstream, não precisa review"
- ❌ Merge de 411 commits sem análise (PR #12 foi exceção justificada, não regra)

## Referências

- Decisão original: `memory/2026-02-08.md` (seção "Fork Independente")
- Pipeline: `pipelines/fork-harvest/README.md`
- Absorção externa: `MEMORY.md` (Regra 6)
- PDCA: `pipelines/fork-harvest/PDCA-ANALYSIS.md`

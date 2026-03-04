# Convenção de Nomenclatura — Scripts do Fork

> **Escopo:** Scripts NOSSOS (ekson73/openclaw). Não renomear scripts upstream.
> **Data:** 2026-02-23

## Padrão

```
eko-{verbo}-{objeto}.{ext}
```

| Componente   | Regra                                                     | Exemplos                                   |
| ------------ | --------------------------------------------------------- | ------------------------------------------ |
| **Prefixo**  | `eko-` (distingue de upstream)                            | `eko-build-swap.sh`                        |
| **Case**     | `kebab-case` (consistente com upstream)                   | `eko-check-patches.sh`                     |
| **Verbo**    | Ação primeiro (auto-descritivo)                           | `build`, `check`, `sync`, `deploy`, `test` |
| **Objeto**   | O que é afetado                                           | `swap`, `patches`, `fork`, `health`        |
| **Extensão** | Runtime: `.sh` (bash), `.mjs` (node ESM), `.ts` (ts-node) |                                            |

## Scripts Nossos

| Script              | Propósito                                   |
| ------------------- | ------------------------------------------- |
| `eko-build-swap.sh` | Build fork + swap binário + restart gateway |

## Identificação

Como saber se um script é nosso ou upstream:

- Prefixo `eko-` → NOSSO
- Sem prefixo → UPSTREAM (não modificar nome)

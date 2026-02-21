# Internationalization (i18n) Patterns Reference

**Source:** maydhafer/openArab fork  
**Adoption Date:** 2026-02-21  
**Status:** Pattern extraction for future i18n efforts

## Arabic Localization Patterns

### RTL (Right-to-Left) Text Handling

The Arabic fork demonstrates proper RTL handling in Markdown:

```html
<div dir="rtl" align="right"># Arabic Content Here</div>
```

### Key i18n Elements Identified

1. **README.md** - Full Arabic translation with:
   - `<div dir="rtl" align="right">` wrapper for RTL text
   - Arabic emoji descriptions
   - Localized feature descriptions
   - Regional hosting recommendations (Hostinger UAE)

2. **Documentation Structure** - The fork maintains parallel docs in Arabic

### Implementation Notes

For future i18n implementation:

```markdown
<!-- Use HTML wrapper for RTL languages -->
<div dir="rtl" align="right">

## Arabic Section Title

Content here flows right-to-left naturally.

</div>
```

### Files of Interest

| File          | Purpose                                 |
| ------------- | --------------------------------------- |
| `README.md`   | Arabic translation with RTL wrapper     |
| `docs/.i18n/` | i18n tooling configuration (if present) |

### Upstream Considerations

This pattern is **documentation-only** and doesn't modify core code. Good candidate for:

- i18n contribution guide
- Localization framework reference
- Community translation efforts

### Attribution

- **Fork:** maydhafer/openArab
- **Contributor:** @alraigah (May for Technology)
- **Purpose:** Arabic localization and accessibility

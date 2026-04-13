# hebrew-lint: Focus AI Vale Style

> חבילת [Vale](https://vale.sh) לאכיפה אוטומטית של כללי העברית של Focus AI. מבוססת על עקרונות מ-[focus-playbook](https://github.com/focusai-labs/focus-playbook) ועל מחקר רשמי (האקדמיה ללשון העברית, Microsoft Hebrew Style Guide, W3C HLReq, מחקרי code-switching).

---

## מה זה עושה

אוכפת **25 כללים** של עברית Focus AI, מחולקים ל-5 namespaces:

| Namespace | מה הוא מכסה | # כללים |
|-----------|--------------|---------|
| `FocusAI.Voice` | ציווי רבים, פורמליות, CTAs, perspective | 5 |
| `FocusAI.Terminology` | מונחים טכניים, עקביות, הטיה | 5 |
| `FocusAI.Punctuation` | מקף, em-dash, italics | 5 |
| `FocusAI.Structure` | אחוז אנגלית, אורך משפט | 5 |
| `FocusAI.Localization` | dir/lang, bidi, URLs | 5 |

---

## התקנה מהירה

```bash
# 1. התקינו Vale (homebrew ב-macOS)
brew install vale

# 2. העתיקו את הסגנון ל-project שלכם
git clone https://github.com/focusai-labs/hebrew-lint.git
cp -r hebrew-lint/styles/FocusAI .vale/styles/

# 3. צרו קובץ .vale.ini ב-root של ה-project
cp hebrew-lint/.vale.ini .

# 4. הריצו
vale .
```

או יותר קצר, דרך ה-installer:

```bash
bash <(curl -s https://raw.githubusercontent.com/focusai-labs/hebrew-lint/main/install.sh)
```

## שימוש

```bash
vale README.md                    # בדיקה של קובץ אחד
vale content/                     # בדיקה של תיקייה שלמה
vale --glob='*.md' .              # בדיקה של markdown בלבד
vale --minAlertLevel=error .      # רק errors, לא warnings
```

## אינטגרציה

### Pre-commit hook

`.pre-commit-config.yaml`:
```yaml
repos:
  - repo: https://github.com/errata-ai/vale
    rev: v3.0.0
    hooks:
      - id: vale
        args: [--minAlertLevel=error, --config=.vale.ini]
```

### GitHub Action

`.github/workflows/hebrew-lint.yml`:
```yaml
name: Hebrew Lint
on: [push, pull_request]
jobs:
  vale:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: errata-ai/vale-action@reviewdog
        with:
          version: 3.0.0
          fail_on_error: true
          filter_mode: nofilter
```

### VSCode

התקינו את התוסף [`errata-ai.vale-server`](https://marketplace.visualstudio.com/items?itemName=ChrisChinchilla.vale-vscode). הוא מזהה את `.vale.ini` אוטומטית ומציג alerts ב-Problems panel.

### Claude Code hook

הוסיפו לפרויקט שמותקן עם [`focus-session-logging`](https://github.com/focusai-labs/focus-session-logging):

```bash
# ב-.claude/settings.json, תחת hooks
{
  "PostToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        {
          "type": "command",
          "command": "vale --output=line --minAlertLevel=error '${CLAUDE_FILE_PATH}' || echo 'hebrew-lint found issues, review above'"
        }
      ]
    }
  ]
}
```

---

## ארכיטקטורה

```
hebrew-lint/
├── README.md                    # אתם כאן
├── install.sh                   # installer לפרויקטים
├── .vale.ini                    # template של vale config
├── styles/
│   └── FocusAI/
│       ├── meta.json            # metadata של הסגנון
│       ├── vocabulary/          # word lists
│       │   ├── tech-terms.txt   # מונחים מותרים תמיד
│       │   ├── forbidden.txt    # מילים אסורות
│       │   └── approved-ctas.txt # CTAs מאושרים
│       ├── Voice/               # V1-V5
│       ├── Terminology/         # T1-T5
│       ├── Punctuation/         # P1-P5
│       ├── Structure/           # S1-S5
│       └── Localization/        # L1-L5
└── tests/
    ├── pass/                    # דוגמאות שצריכות לעבור
    └── fail/                    # דוגמאות שצריכות להיכשל
```

## תאימות

- **Vale:** 2.30.0+
- **OS:** macOS, Linux, Windows
- **File types:** Markdown, AsciiDoc, HTML, reStructuredText, plain text, source code comments

## פיתוח

### הוספת כלל חדש

1. הוסיפו YAML חדש תחת `styles/FocusAI/<namespace>/YourRule.yml`
2. הוסיפו דוגמת fail תחת `tests/fail/your-rule.md`
3. הוסיפו דוגמת pass תחת `tests/pass/your-rule-good.md`
4. הריצו את הטסטים: `bash tests/run-tests.sh`
5. עדכנו את [unified-hebrew-principles.md](../design/unified-hebrew-principles.md) עם הכלל החדש
6. PR

### הרצת טסטים

```bash
bash tests/run-tests.sh
```

מצופה: כל קובץ ב-`tests/fail/` מחזיר exit code 1. כל קובץ ב-`tests/pass/` מחזיר exit code 0.

## מקורות ותאוריה

הכללים כאן מגובים במקורות רשמיים:

- **[האקדמיה ללשון העברית](https://hebrew-academy.org.il/topic/hahlatot/grammardecisions/borrowed-words/)**: החלטה 5.1 על כתיב מילים לועזיות + כללי המקף
- **[Microsoft Hebrew Style Guide](https://download.microsoft.com/download/a/2/f/a2ff07cc-afca-4db8-9ed7-fd1b706abf1c/heb-isr-StyleGuide.pdf)**: עקביות מונחים, גוף שני, הימנעות מתרגומים מילוליים
- **[W3C Hebrew Layout Requirements](https://w3c.github.io/hlreq/)**: bidi, italics, dir attributes
- **[Unicode UAX #9](http://www.unicode.org/reports/tr9/)**: Bidirectional Algorithm
- **[Soesman & Walters (2021)](https://journals.sagepub.com/doi/abs/10.1177/13670069211000855)**: Codeswitching within prepositional phrases (מחקר code-switching)

המסמך המלא של הכללים עם כל הציטוטים נמצא ב-[focus-playbook/design/unified-hebrew-principles.md](https://github.com/focusai-labs/focus-playbook/blob/main/design/unified-hebrew-principles.md).

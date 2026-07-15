# Collapse macro with glued content

{{collapse(View details...)

| Name           | Value   |
| -------------- | ------- |
| foo            | bar baz |
| long cell here | x       |

}}

{{collapse(Show the log)

Some leading text.

| Date       | Event   |
| ---------- | ------- |
| 2021-01-01 | started |

}}

Text after.

# Ragged table

| Release | Date       | Notes       |
| ------- | ---------- | ----------- |
| 7.0     | 2021-01-01 |             |
| 7.1     | 2021-06-01 | fixed stuff |

# Star-dot header cells

| Name | Description                  | Acceptable Values |
| ---- | ---------------------------- | ----------------- |
| desc | Provides a brief description | String            |

# Markdown table in textile

| Name       | Description  | Default       |
| ---------- | ------------ | ------------- |
| param.name | What it does | default value |

# Table directly after text

Query plan:

|    |                  |      |
| -- | ---------------- | ---- |
| Id | Operation        | Name |
| 0  | SELECT STATEMENT |      |

next paragraph

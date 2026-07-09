# Pipedream Google Sheets MCP Integration

This reference describes the zero-setup Google Sheets capabilities provided via the Pipedream MCP server. When the main `google-workspace` skill is not authenticated (`setup_needed`), these tools can be used immediately for spreadsheet read/write operations without local credentials.

## Available Tools

- `mcp_pipedream_google_sheets_google_sheets_new_spreadsheet` — Create a new spreadsheet with optional headers and worksheet title. Returns the spreadsheet ID and URL.
- `mcp_pipedream_google_sheets_google_sheets_add_rows` — Append one or more rows to a worksheet.
- `mcp_pipedream_google_sheets_google_sheets_read_rows` — Read rows as objects or raw arrays.
- `mcp_pipedream_google_sheets_google_sheets_find_rows` — Search for rows matching a query in a specific column.
- `mcp_pipedream_google_sheets_google_sheets_get_spreadsheet_info` — Retrieve worksheet structure, names, and column headers.

## Proven Workflows

### 1. Creating a Spreadsheet with Headers
Always call `google_sheets_new_spreadsheet` with a clear title, sheet name, and column headers.
```json
{
  "title": "Most Expensive Cars in the World",
  "sheetName": "Most Expensive Cars",
  "headers": ["Rank", "Brand", "Model", "Price (USD)", "Notes"]
}
```

### 2. Appending Rows (Preferred JSON Format)
Always prefer appending rows as a JSON array of objects where keys match the column headers exactly (case-sensitive).
```json
{
  "spreadsheetId": "1V31Dr_EAW...",
  "sheetName": "Most Expensive Cars",
  "rows": "[\n  {\"Rank\": 1, \"Brand\": \"Mercedes-Benz\", \"Model\": \"300 SLR\", \"Price (USD)\": 142000000, \"Notes\": \"...\"}\n]"
}
```
*Note: The `rows` parameter must be a JSON-stringified array.*

### 3. Verification & Structure Discovery
Before reading or updating an existing sheet, always call `google_sheets_get_spreadsheet_info` first to discover existing worksheets, row counts, and the exact header spelling.
```json
{
  "spreadsheetId": "YOUR_SPREADSHEET_ID"
}
```

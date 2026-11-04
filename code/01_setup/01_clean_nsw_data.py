"""
Clean and reshape BOCSAR NSW-wide incident data (wide -> long).

Input:  Incident_by_NSW.xlsx  (one row per offence type, one column per month)
Output: incidents_by_nsw_long.csv  (one row per offence type + month)

Run each section in order and read the printed checks before moving on.
If read_excel gives an error about 'openpyxl', run:  pip install openpyxl
"""

import datetime
import pandas as pd


# =====================================================================
# SECTION 1: SETUP
# =====================================================================

# Step 1.1 - File names (change these to match your folders)
INPUT_FILE = "Incident_by_NSW.xlsx"
OUTPUT_FILE = "incidents_by_nsw_long.csv"

# Step 1.2 - The columns that describe each row (everything else is a month)
ID_COLUMNS = ["Offence category", "Subcategory"]

# Step 1.3 - Columns to remove (constants that aren't useful for analysis)
DROP_COLUMNS = ["State", "2025 population", "2026 population"]


# =====================================================================
# SECTION 2: LOAD THE RAW DATA
# =====================================================================

# Step 2.1 - Load the Excel file
df = pd.read_excel(INPUT_FILE)

# Step 2.2 - Look at the first few rows
# If the column names look wrong (e.g. "Unnamed: 0"), the real header isn't
# on the first row. Find the right row and use pd.read_excel(INPUT_FILE, header=N)
print("--- RAW DATA ---")
print("Rows:", len(df))
print("Columns:", len(df.columns))
print(df.head())


# =====================================================================
# SECTION 3: CLEAN THE COLUMN NAMES
# =====================================================================

# Step 3.1 - Excel sometimes reads month headers as real dates instead of
# text like "Jan 1995". Convert any date headers back into "Jan 1995" text,
# and remove extra spaces from text headers.
new_names = []
for col in df.columns:
    if isinstance(col, datetime.datetime):
        new_names.append(col.strftime("%b %Y"))
    else:
        new_names.append(str(col).strip())
df.columns = new_names


# =====================================================================
# SECTION 4: DROP UNNEEDED COLUMNS AND ROWS
# =====================================================================

# Step 4.1 - Confirm State only contains NSW before dropping it
print("\n--- STATE VALUES ---")
print(df["State"].unique())   # should only show NSW

# Step 4.2 - Drop State and the two population columns
df = df.drop(columns=DROP_COLUMNS)

# Step 4.3 - Drop rows that are completely empty (common in Excel exports)
df = df.dropna(how="all")

# Step 4.4 - Drop rows with no offence category (e.g. footnotes or notes
# at the bottom of the sheet). Print them first so you can see what goes.
no_category = df[df["Offence category"].isnull()]
print("\n--- ROWS WITH NO OFFENCE CATEGORY (will be dropped) ---")
print(no_category.iloc[:, :3])
df = df[df["Offence category"].notnull()]


# =====================================================================
# SECTION 5: CLEAN THE TEXT COLUMNS
# =====================================================================

# Step 5.1 - Remove extra spaces at the start/end of text values
for col in ID_COLUMNS:
    df[col] = df[col].str.strip()

# Step 5.2 - Check for missing values
# Some offences have no subcategory (e.g. "Arson"), so a few missing
# Subcategory values are expected. They stay blank, which becomes NULL in SQL.
print("\n--- MISSING TEXT VALUES ---")
print(df[ID_COLUMNS].isnull().sum())

# Step 5.3 - Count offence types
print("Offence types (rows):", len(df))   # should be 62


# =====================================================================
# SECTION 6: REMOVE DUPLICATES
# =====================================================================

# Step 6.1 - Exact duplicates (every value in the row is identical)
print("\n--- DUPLICATES ---")
print("Exact duplicate rows:", df.duplicated().sum())
df = df.drop_duplicates()

# Step 6.2 - Key duplicates (same offence type, but different numbers)
# These need a human decision, so we only print them, not delete them
key_dupes = df[df.duplicated(subset=ID_COLUMNS, keep=False)]
print("Rows sharing the same offence type:", len(key_dupes))
if len(key_dupes) > 0:
    print(key_dupes[ID_COLUMNS])


# =====================================================================
# SECTION 7: FIND THE MONTH COLUMNS
# =====================================================================

# Step 7.1 - Every column that isn't an ID column should be a month
month_columns = [col for col in df.columns if col not in ID_COLUMNS]

# Step 7.2 - Check every month column really looks like "Jan 1995"
bad_columns = []
for col in month_columns:
    if pd.isnull(pd.to_datetime(col, format="%b %Y", errors="coerce")):
        bad_columns.append(col)

print("\n--- MONTH COLUMNS ---")
print("Month columns found:", len(month_columns))
print("First month:", month_columns[0])
print("Last month:", month_columns[-1])
print("Columns that aren't months:", bad_columns)   # should be []

# Step 7.3 - Record the total before reshaping (used as a check later)
total_before = df[month_columns].sum().sum()


# =====================================================================
# SECTION 8: RESHAPE FROM WIDE TO LONG
# =====================================================================

long_df = df.melt(
    id_vars=ID_COLUMNS,
    value_vars=month_columns,
    var_name="Month",
    value_name="Incident_Count",
)


# =====================================================================
# SECTION 9: FIX DATA TYPES
# =====================================================================

# Step 9.1 - Convert "Jan 1995" text into a real date (1995-01-01)
long_df["Month"] = pd.to_datetime(long_df["Month"], format="%b %Y")

# Step 9.2 - Check incident counts for problems
print("\n--- INCIDENT COUNT CHECKS ---")
print("Missing counts:", long_df["Incident_Count"].isnull().sum())
print("Negative counts:", (long_df["Incident_Count"] < 0).sum())   # should be 0

# Step 9.3 - Treat missing counts as 0, then store as whole numbers
long_df["Incident_Count"] = long_df["Incident_Count"].fillna(0).astype(int)


# =====================================================================
# SECTION 10: CLEAN COLUMN NAMES FOR SQL
# =====================================================================

# "Offence category" -> "offence_category"
long_df.columns = long_df.columns.str.lower().str.replace(" ", "_")


# =====================================================================
# SECTION 11: FINAL CHECKS BEFORE EXPORT
# =====================================================================

print("\n--- FINAL CHECKS ---")

# Step 11.1 - Row count should equal (wide rows x month columns)
expected_rows = len(df) * len(month_columns)
print("Rows:", len(long_df), "| expected:", expected_rows)

# Step 11.2 - Total incidents should be the same before and after the melt
total_after = long_df["incident_count"].sum()
print("Total before:", total_before, "| total after:", total_after)

# Step 11.3 - Date range
print("Months:", long_df["month"].min().date(), "to", long_df["month"].max().date())


# =====================================================================
# SECTION 12: EXPORT AND CHECK THE FILE
# =====================================================================

# Step 12.1 - Save to CSV
long_df.to_csv(OUTPUT_FILE, index=False)

# Step 12.2 - Count the lines actually written to the file
with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
    lines_written = sum(1 for line in f) - 1   # minus the header row

print("\n--- EXPORT CHECK ---")
print("Rows in dataframe:", len(long_df))
print("Rows in file:", lines_written)   # should match exactly

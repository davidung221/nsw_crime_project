"""
Clean and reshape BOCSAR suburb incident data (wide -> long).

Input:  SuburbData.csv  (one row per suburb + offence, one column per month)
Output: incidents_by_suburb_long.csv  (one row per suburb + offence + month)

Run each section in order and read the printed checks before moving on.
"""

import pandas as pd


# =====================================================================
# SECTION 1: SETUP
# =====================================================================

# Step 1.1 - File names (change these to match your folders)
INPUT_FILE = "SuburbData.csv"
OUTPUT_FILE = "incidents_by_suburb_long.csv"

# Step 1.2 - The columns that describe each row (everything else is a month)
ID_COLUMNS = ["Suburb", "Offence category", "Subcategory"]


# =====================================================================
# SECTION 2: LOAD THE RAW DATA
# =====================================================================

# Step 2.1 - Load the CSV
# thousands="," turns values like "1,234" into the number 1234
df = pd.read_csv(INPUT_FILE, thousands=",")

# Step 2.2 - Look at the raw data before changing anything
print("--- RAW DATA ---")
print("Rows:", len(df))
print("Columns:", len(df.columns))
print("Unique suburbs:", df["Suburb"].nunique())
print("First suburb:", df["Suburb"].min())
print("Last suburb:", df["Suburb"].max())   # should be Zetland


# =====================================================================
# SECTION 3: CLEAN THE TEXT COLUMNS
# =====================================================================

# Step 3.1 - Remove extra spaces at the start/end of text values
# e.g. "Blacktown " becomes "Blacktown", so it matches the census later
for col in ID_COLUMNS:
    df[col] = df[col].str.strip()

# Step 3.2 - Check for missing values in the text columns
# Subcategory can be blank for some offences, so only Suburb and
# Offence category should have zero missing values
print("\n--- MISSING TEXT VALUES ---")
print(df[ID_COLUMNS].isnull().sum())


# =====================================================================
# SECTION 4: REMOVE DUPLICATES
# =====================================================================

# Step 4.1 - Exact duplicates (every value in the row is identical)
exact_dupes = df.duplicated().sum()
print("\n--- DUPLICATES ---")
print("Exact duplicate rows:", exact_dupes)
df = df.drop_duplicates()

# Step 4.2 - Key duplicates (same suburb + offence, but different numbers)
# These need a human decision, so we only print them, not delete them
key_dupes = df[df.duplicated(subset=ID_COLUMNS, keep=False)]
print("Rows sharing the same suburb + offence:", len(key_dupes))
if len(key_dupes) > 0:
    print(key_dupes[ID_COLUMNS].head(10))


# =====================================================================
# SECTION 5: FIND THE MONTH COLUMNS
# =====================================================================

# Step 5.1 - Every column that isn't an ID column should be a month
month_columns = [col for col in df.columns if col not in ID_COLUMNS]

# Step 5.2 - Check every month column really looks like "Jan 1995"
# Anything that fails to convert is printed so you can investigate
bad_columns = []
for col in month_columns:
    if pd.isnull(pd.to_datetime(col, format="%b %Y", errors="coerce")):
        bad_columns.append(col)

print("\n--- MONTH COLUMNS ---")
print("Month columns found:", len(month_columns))
print("First month:", month_columns[0])
print("Last month:", month_columns[-1])   # should be Jun 2026
print("Columns that aren't months:", bad_columns)   # should be []

# Step 5.3 - Record the total before reshaping (used as a check later)
total_before = df[month_columns].sum().sum()


# =====================================================================
# SECTION 6: RESHAPE FROM WIDE TO LONG
# =====================================================================

# Step 6.1 - Turn the ID columns into "category" type first
# This stores each suburb name once instead of millions of times,
# which stops the melt from running out of memory
for col in ID_COLUMNS:
    df[col] = df[col].astype("category")

# Step 6.2 - Melt: one column per month becomes one row per month
long_df = df.melt(
    id_vars=ID_COLUMNS,
    value_vars=month_columns,
    var_name="Month",
    value_name="Incident_Count",
)


# =====================================================================
# SECTION 7: FIX DATA TYPES
# =====================================================================

# Step 7.1 - Convert "Jan 1995" text into a real date (1995-01-01)
long_df["Month"] = pd.to_datetime(long_df["Month"], format="%b %Y")

# Step 7.2 - Check incident counts for problems
print("\n--- INCIDENT COUNT CHECKS ---")
print("Missing counts:", long_df["Incident_Count"].isnull().sum())
print("Negative counts:", (long_df["Incident_Count"] < 0).sum())   # should be 0

# Step 7.3 - Treat missing counts as 0, then store as whole numbers
long_df["Incident_Count"] = long_df["Incident_Count"].fillna(0).astype(int)


# =====================================================================
# SECTION 8: CLEAN COLUMN NAMES FOR SQL
# =====================================================================

# Step 8.1 - Lowercase with underscores, matching the staging table
# "Offence category" -> "offence_category"
long_df.columns = long_df.columns.str.lower().str.replace(" ", "_")


# =====================================================================
# SECTION 9: FINAL CHECKS BEFORE EXPORT
# =====================================================================

print("\n--- FINAL CHECKS ---")

# Step 9.1 - Row count should equal (wide rows x month columns)
expected_rows = len(df) * len(month_columns)
print("Rows:", len(long_df), "| expected:", expected_rows)

# Step 9.2 - Total incidents should be the same before and after the melt
total_after = long_df["incident_count"].sum()
print("Total before:", total_before, "| total after:", total_after)

# Step 9.3 - Every first letter A-Z should appear (catches truncation)
letters = sorted(long_df["suburb"].astype(str).str[0].str.upper().unique())
print("Suburb first letters:", "".join(letters))

# Step 9.4 - Last suburb and date range
print("Last suburb:", long_df["suburb"].astype(str).max())
print("Months:", long_df["month"].min().date(), "to", long_df["month"].max().date())


# =====================================================================
# SECTION 10: EXPORT AND CHECK THE FILE
# =====================================================================

# Step 10.1 - Save to CSV (do NOT open this file in Excel afterwards -
# Excel cuts files off at 1,048,576 rows and would truncate it if saved)
long_df.to_csv(OUTPUT_FILE, index=False)

# Step 10.2 - Count the lines actually written to the file
with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
    lines_written = sum(1 for line in f) - 1   # minus the header row

print("\n--- EXPORT CHECK ---")
print("Rows in dataframe:", len(long_df))
print("Rows in file:", lines_written)   # should match exactly

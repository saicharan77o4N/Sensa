import re


# ============================================================
# NORMALIZATION
# ============================================================

def normalize(text):
    return re.sub(r"\s+", " ", text.lower()).strip()


# ============================================================
# STATUS / STATE WORDS
# ============================================================

STATUS_WORDS = {
    "pending",
    "completed",
    "complete",
    "confirmed",
    "cancelled",
    "canceled",
    "approved",
    "rejected",
    "accepted",
    "declined",
    "overdue",
    "finished",
    "failed",
    "successful",
    "successfully",
    "scheduled",
    "rescheduled",
    "delayed",
    "postponed",
    "blocked",
    "resolved",
    "unresolved",
    "available",
    "unavailable",
    "required",
    "mandatory",
    "optional",
    "urgent",
    "important",
}


# ============================================================
# EXTRACT STATUS CLAIMS
# ============================================================

def extract_status_words(text):

    words = re.findall(
        r"\b[a-zA-Z]{3,}\b",
        normalize(text),
    )

    return {
        word
        for word in words
        if word in STATUS_WORDS
    }


# ============================================================
# CHECK UNSUPPORTED STATUS CLAIMS
# ============================================================

def check_unsupported_status(
    source,
    summary,
):
    source_status = extract_status_words(source)
    summary_status = extract_status_words(summary)

    unsupported = summary_status - source_status

    return sorted(unsupported)


# ============================================================
# OTHER UNSUPPORTED CLAIM PATTERNS
# ============================================================

def extract_numeric_claims(text):

    return set(
        re.findall(
            r"\b\d+(?:[.,]\d+)?\b",
            text,
        )
    )


def extract_time_claims(text):

    return set(
        normalize(match).replace(" ", "")
        for match in re.findall(
            r"\b\d{1,2}(?::\d{2})?\s*(?:am|pm)\b",
            text,
            re.IGNORECASE,
        )
    )


def extract_date_claims(text):

    dates = {
        "today",
        "tomorrow",
        "yesterday",
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday",
    }

    lower = normalize(text)

    return {
        date
        for date in dates
        if re.search(
            r"\b" + date + r"\b",
            lower,
        )
    }


# ============================================================
# CLAIM VALIDATION
# ============================================================

def validate_claims(
    source,
    summary,
):
    problems = []

    # --------------------------------------------------------
    # Status/state claims
    # --------------------------------------------------------

    unsupported_status = check_unsupported_status(
        source,
        summary,
    )

    for status in unsupported_status:
        problems.append(
            f"Unsupported status/state claim: {status}"
        )

    # --------------------------------------------------------
    # Numbers
    # --------------------------------------------------------

    source_numbers = extract_numeric_claims(source)
    summary_numbers = extract_numeric_claims(summary)

    missing_numbers = (
        source_numbers - summary_numbers
    )

    for number in sorted(missing_numbers):
        problems.append(
            f"Source number missing from summary: {number}"
        )

    # --------------------------------------------------------
    # Times
    # --------------------------------------------------------

    source_times = extract_time_claims(source)
    summary_times = extract_time_claims(summary)

    missing_times = source_times - summary_times

    for time in sorted(missing_times):
        problems.append(
            f"Source time missing from summary: {time}"
        )

    # --------------------------------------------------------
    # Dates
    # --------------------------------------------------------

    source_dates = extract_date_claims(source)
    summary_dates = extract_date_claims(summary)

    missing_dates = source_dates - summary_dates

    for date in sorted(missing_dates):
        problems.append(
            f"Source date missing from summary: {date}"
        )

    return problems


# ============================================================
# TESTS
# ============================================================

TESTS = [

    {
        "name": "No invented status",
        "source": """
SHARED:
- sync at 4 PM
""",
        "summary": """
They will sync together at 4 PM.
""",
        "expected_fail": False,
    },

    {
        "name": "Invented pending status",
        "source": """
SHARED:
- sync at 4 PM
""",
        "summary": """
The shared sync is pending at 4 PM.
""",
        "expected_fail": True,
    },

    {
        "name": "Source says completed",
        "source": """
CONTEXT:
- Download completed successfully.
""",
        "summary": """
The download completed successfully.
""",
        "expected_fail": False,
    },

    {
        "name": "Invented completion",
        "source": """
CONTEXT:
- Download is still running.
""",
        "summary": """
The download completed successfully.
""",
        "expected_fail": True,
    },

    {
        "name": "Missing time",
        "source": """
SHARED:
- sync at 4 PM
""",
        "summary": """
They will sync together.
""",
        "expected_fail": True,
    },

    {
        "name": "Preserved time",
        "source": """
SHARED:
- sync at 4 PM
""",
        "summary": """
They will sync together at 4 PM.
""",
        "expected_fail": False,
    },

    {
        "name": "Preserved number",
        "source": """
CONTEXT:
- The table is booked for 15 people.
""",
        "summary": """
The table is booked for 15 people.
""",
        "expected_fail": False,
    },

    {
        "name": "Invented number",
        "source": """
CONTEXT:
- The table is booked for 15 people.
""",
        "summary": """
The table is booked for 20 people.
""",
        "expected_fail": True,
    },

]


# ============================================================
# RUN
# ============================================================

for test in TESTS:

    print("\n" + "=" * 70)
    print(test["name"])
    print("=" * 70)

    problems = validate_claims(
        test["source"],
        test["summary"],
    )

    failed = len(problems) > 0

    if failed == test["expected_fail"]:
        print("TEST RESULT: PASS")
    else:
        print("TEST RESULT: FAIL")

    if problems:
        for problem in problems:
            print(" -", problem)
import re


# ============================================================
# NORMALIZATION
# ============================================================

def normalize(text):
    return re.sub(r"\s+", " ", text.lower()).strip()


# ============================================================
# EXTRACT ANCHORS
# ============================================================

def extract_anchors(facts):
    anchors = {
        "times": set(),
        "dates": set(),
        "numbers": set(),
        "people": set(),
        "urls": set(),
    }

    # --------------------------------------------------------
    # Times
    # --------------------------------------------------------

    for match in re.findall(
        r"\b\d{1,2}(?::\d{2})?\s*(?:AM|PM)\b",
        facts,
        re.IGNORECASE,
    ):
        anchors["times"].add(normalize(match))

    # --------------------------------------------------------
    # Dates
    # --------------------------------------------------------

    date_words = [
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
    ]

    lower_facts = normalize(facts)

    for word in date_words:
        if re.search(r"\b" + word + r"\b", lower_facts):
            anchors["dates"].add(word)

    # --------------------------------------------------------
    # Numbers
    # --------------------------------------------------------

    for match in re.findall(
        r"\b\d+(?:[.,]\d+)*\b",
        facts,
    ):
        anchors["numbers"].add(match)

    # --------------------------------------------------------
    # Named people
    #
    # Extract from original case-sensitive text.
    # --------------------------------------------------------

    ignored_names = {
        "Sender",
        "Recipient",
        "Shared",
        "Thirdparty",
        "Question",
        "Context",
        "Can",
        "Could",
        "Would",
        "Will",
        "Should",
        "Please",
        "The",
    }

    for match in re.findall(
        r"\b[A-Z][a-z]{2,}\b",
        facts,
    ):
        if match not in ignored_names:
            anchors["people"].add(normalize(match))

    # --------------------------------------------------------
    # URLs
    # --------------------------------------------------------

    for match in re.findall(
        r"https?://\S+",
        facts,
        re.IGNORECASE,
    ):
        anchors["urls"].add(normalize(match))

    return anchors


# ============================================================
# CHECK ANCHORS
# ============================================================

def check_anchors(facts, summary):
    anchors = extract_anchors(facts)
    summary_normalized = normalize(summary)

    problems = []

    for category, values in anchors.items():
        for value in values:

            # URLs can contain punctuation, so use direct matching.
            if value not in summary_normalized:
                problems.append(
                    f"Missing {category}: {value}"
                )

    return problems


# ============================================================
# QUESTION PRESERVATION
# ============================================================

def has_question(summary):
    summary_lower = normalize(summary)

    question_mark = "?" in summary

    question_phrases = [
        "asks whether",
        "asks if",
        "asking whether",
        "asking if",
        "whether",
        "if the recipient can",
        "if you can",
        "can the recipient",
        "could the recipient",
        "are you",
        "did you",
        "will you",
    ]

    return (
        question_mark
        or any(
            phrase in summary_lower
            for phrase in question_phrases
        )
    )


def check_questions(facts, summary):
    lower_facts = normalize(facts)

    question_lines = []

    current_role = None

    for line in facts.splitlines():
        line = line.strip()

        if not line:
            continue

        upper = line.upper()

        if upper == "QUESTION:":
            current_role = "question"
            continue

        if upper.endswith(":"):
            current_role = None
            continue

        if current_role == "question" and line.startswith("-"):
            question_lines.append(
                line[1:].strip()
            )

    if not question_lines:
        return []

    if not has_question(summary):
        return [
            "Important question may have been lost."
        ]

    return []


# ============================================================
# SIMPLE FACT PRESENCE CHECK
# ============================================================

def important_words(text):
    words = re.findall(
        r"\b[a-z]{3,}\b",
        normalize(text),
    )

    stop_words = {
        "the",
        "and",
        "for",
        "with",
        "that",
        "this",
        "from",
        "will",
        "can",
        "you",
        "your",
        "they",
        "them",
        "their",
        "sender",
        "recipient",
        "shared",
        "both",
        "after",
        "before",
        "into",
        "about",
        "have",
        "has",
        "had",
        "was",
        "were",
        "are",
        "our",
        "but",
        "then",
    }

    return [
        word
        for word in words
        if word not in stop_words
    ]


def check_action_words(facts, summary):
    summary_lower = normalize(summary)

    problems = []

    roles = [
        "SENDER:",
        "RECIPIENT:",
        "SHARED:",
        "THIRDPARTY:",
    ]

    current_role = None

    for line in facts.splitlines():
        stripped = line.strip()

        if not stripped:
            continue

        upper = stripped.upper()

        if upper in roles:
            current_role = upper
            continue

        if upper.endswith(":"):
            current_role = None
            continue

        if current_role and stripped.startswith("-"):
            fact = stripped[1:].strip()

            words = important_words(fact)

            # Only require a small amount of semantic overlap.
            # We deliberately do NOT infer who performs the action.
            if words:
                overlap = [
                    word
                    for word in words
                    if word in summary_lower
                ]

                if len(overlap) == 0:
                    problems.append(
                        f"Important fact may be missing: {fact}"
                    )

    return problems


# ============================================================
# MAIN VALIDATOR
# ============================================================

def validate(facts, summary):
    problems = []

    problems.extend(
        check_anchors(
            facts,
            summary,
        )
    )

    problems.extend(
        check_questions(
            facts,
            summary,
        )
    )

    problems.extend(
        check_action_words(
            facts,
            summary,
        )
    )

    return problems


# ============================================================
# TESTS
# ============================================================

TESTS = [

    {
        "name": "Correct mixed roles",
        "facts": """
QUESTION:
- Can you send me the report?

RECIPIENT:
- send the report

SENDER:
- review it after lunch
""",
        "summary": """
The sender asks whether the recipient can send the report,
and the sender will review it after lunch.
""",
    },

    {
        "name": "Recipient reversed",
        "facts": """
RECIPIENT:
- submit the timesheet soon

SENDER:
- send the code for review
""",
        "summary": """
The sender will submit the timesheet soon and send the code for review.
""",
    },

    {
        "name": "Shared action",
        "facts": """
SHARED:
- review the changes together at 6 PM
""",
        "summary": """
They will review the changes together at 6 PM.
""",
    },

    {
        "name": "Shared incorrectly made individual",
        "facts": """
SHARED:
- review the changes together at 6 PM
""",
        "summary": """
The sender will review the changes at 6 PM.
""",
    },

    {
        "name": "Missing time",
        "facts": """
SHARED:
- review the changes together at 6 PM
""",
        "summary": """
They will review the changes together.
""",
    },

    {
        "name": "Invented status",
        "facts": """
SHARED:
- sync at 4 PM
""",
        "summary": """
The shared sync is pending at 4 PM.
""",
    },

    {
        "name": "Question converted to action",
        "facts": """
QUESTION:
- Can you send me the report?

RECIPIENT:
- send the report
""",
        "summary": """
The recipient will send the report.
""",
    },

    {
        "name": "Correct multiple people",
        "facts": """
THIRDPARTY:
- Priya: prepare the slides
- Rahul: handle the backend

SENDER:
- test the final build
""",
        "summary": """
Priya will prepare the slides, Rahul will handle the backend,
and the sender will test the final build.
""",
    },
]


# ============================================================
# RUN
# ============================================================

for test in TESTS:

    print("\n" + "=" * 70)
    print(test["name"])
    print("=" * 70)

    problems = validate(
        test["facts"],
        test["summary"],
    )

    if not problems:
        print("VALIDATION: PASS")
    else:
        print("VALIDATION: FAIL")

        for problem in problems:
            print(" -", problem)
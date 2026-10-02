import re


# ============================================================
# NORMALIZATION
# ============================================================

def normalize(text):
    return re.sub(r"\s+", " ", text.lower()).strip()


# ============================================================
# PARSE STRUCTURED FACTS
# ============================================================

def parse_facts(facts):
    result = {
        "sender": [],
        "recipient": [],
        "shared": [],
        "thirdparty": [],
        "question": [],
        "context": [],
    }

    current_role = None

    headers = {
        "SENDER:": "sender",
        "RECIPIENT:": "recipient",
        "SHARED:": "shared",
        "THIRDPARTY:": "thirdparty",
        "QUESTION:": "question",
        "CONTEXT:": "context",
    }

    for raw_line in facts.splitlines():

        line = raw_line.strip()

        if not line:
            continue

        upper = line.upper()

        if upper in headers:
            current_role = headers[upper]
            continue

        if current_role is None:
            continue

        if line.startswith("-"):
            line = line[1:].strip()

        result[current_role].append(line)

    return result


# ============================================================
# WORDS
# ============================================================

STOP_WORDS = {
    "the",
    "and",
    "for",
    "with",
    "that",
    "this",
    "from",
    "will",
    "can",
    "could",
    "would",
    "should",
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
    "whether",
    "asks",
    "asked",
    "need",
    "needs",
    "must",
    "might",
    "may",
}


ACTION_WORDS = {
    "send",
    "submit",
    "finish",
    "complete",
    "prepare",
    "handle",
    "review",
    "check",
    "share",
    "join",
    "attend",
    "include",
    "log",
    "fix",
    "test",
    "deploy",
    "sync",
    "meet",
    "call",
    "update",
    "create",
    "write",
    "upload",
    "download",
    "open",
    "verify",
    "present",
    "discuss",
    "schedule",
    "organize",
    "provide",
    "give",
    "make",
    "go",
    "come",
    "bring",
    "start",
    "look",
    "find",
}


def words(text):
    return set(
        word
        for word in re.findall(
            r"\b[a-zA-Z]{3,}\b",
            normalize(text),
        )
        if word not in STOP_WORDS
    )


def action_words(text):
    return words(text) & ACTION_WORDS


# ============================================================
# IMPORTANT TOKENS
# ============================================================

def meaningful_tokens(text):

    normalized = normalize(text)

    tokens = []

    # Words
    tokens.extend(
        re.findall(
            r"\b[a-zA-Z]{3,}\b",
            normalized,
        )
    )

    # Numbers
    tokens.extend(
        re.findall(
            r"\b\d+(?:[.:]\d+)?\b",
            normalized,
        )
    )

    # Time markers
    if re.search(r"\b\d+(?::\d+)?\s*(?:am|pm)\b", normalized):
        match = re.search(
            r"\b\d+(?::\d+)?\s*(?:am|pm)\b",
            normalized,
        )

        if match:
            tokens.append(
                match.group(0).replace(" ", "")
            )

    return [
        token
        for token in tokens
        if token not in STOP_WORDS
    ]


# ============================================================
# FACT MATCHING
# ============================================================

def fact_tokens(fact):
    return set(meaningful_tokens(fact))


def summary_tokens(text):
    return set(meaningful_tokens(text))


def score_fact_match(
    source_fact,
    summary_segment,
):

    source = fact_tokens(source_fact)
    summary = summary_tokens(summary_segment)

    if not source:
        return 0

    return len(source & summary)


def best_matching_segment(
    source_fact,
    summary,
):

    segments = split_summary(summary)

    best_segment = None
    best_score = 0

    for segment in segments:

        score = score_fact_match(
            source_fact,
            segment,
        )

        if score > best_score:
            best_score = score
            best_segment = segment

    return best_segment, best_score


# ============================================================
# SUMMARY SPLITTING
# ============================================================

def split_summary(summary):

    # First split sentences.
    sentences = re.split(
        r"(?<=[.!?])\s+",
        summary.strip(),
    )

    result = []

    for sentence in sentences:

        # Then split common role/action connectors.
        clauses = re.split(
            r"\s+(?:and|while|but|whereas)\s+",
            sentence,
            flags=re.IGNORECASE,
        )

        for clause in clauses:

            clause = clause.strip()

            if clause:
                result.append(clause)

    return result


# ============================================================
# ROLE MARKERS
# ============================================================

def role_of_clause(clause):

    text = normalize(clause)

    # Shared has highest priority.
    if any(
        marker in text
        for marker in [
            "both",
            "together",
            "jointly",
            "shared",
            "we will",
            "we'll",
            "we can",
            "we should",
            "we need",
            "they will",
            "they can",
            "they should",
        ]
    ):
        return "shared"

    # Recipient.
    if any(
        marker in text
        for marker in [
            "the recipient",
            "recipient will",
            "recipient can",
            "recipient should",
            "you will",
            "you'll",
            "you can",
            "you should",
            "you need",
            "you have to",
            "you must",
        ]
    ):
        return "recipient"

    # Sender.
    if any(
        marker in text
        for marker in [
            "the sender",
            "sender will",
            "sender can",
            "sender should",
            "i will",
            "i'll",
            "i can",
            "i should",
            "i need",
            "i am",
            "i'm",
        ]
    ):
        return "sender"

    return "ambiguous"


# ============================================================
# ROLE VALIDATION
# ============================================================

def validate_role_fact(
    role,
    source_fact,
    summary,
):

    segment, score = best_matching_segment(
        source_fact,
        summary,
    )

    if segment is None:
        return [
            f"Could not match {role} fact: "
            f"{source_fact}"
        ]

    # For very short facts such as:
    #
    # sync at 4 PM
    #
    # two matching tokens are enough.
    minimum_score = 2

    if score < minimum_score:
        return [
            f"Could not reliably match {role} fact: "
            f"{source_fact}"
            f"\n  Best segment: {segment}"
            f"\n  Match score: {score}"
        ]

    summary_role = role_of_clause(segment)

    problems = []

    if role == "sender":

        if summary_role == "recipient":
            problems.append(
                f"Sender fact assigned to recipient: "
                f"{source_fact}"
                f"\n  Summary segment: {segment}"
            )

    elif role == "recipient":

        if summary_role == "sender":
            problems.append(
                f"Recipient fact assigned to sender: "
                f"{source_fact}"
                f"\n  Summary segment: {segment}"
            )

    elif role == "shared":

        if summary_role != "shared":
            problems.append(
                f"Shared fact lost joint responsibility: "
                f"{source_fact}"
                f"\n  Summary segment: {segment}"
            )

    return problems


# ============================================================
# ROLE CHECK
# ============================================================

def check_roles(
    facts,
    summary,
):

    parsed = parse_facts(facts)

    problems = []

    for fact in parsed["sender"]:

        problems.extend(
            validate_role_fact(
                "sender",
                fact,
                summary,
            )
        )

    for fact in parsed["recipient"]:

        problems.extend(
            validate_role_fact(
                "recipient",
                fact,
                summary,
            )
        )

    for fact in parsed["shared"]:

        problems.extend(
            validate_role_fact(
                "shared",
                fact,
                summary,
            )
        )

    return problems


# ============================================================
# QUESTION CHECK
# ============================================================

def check_questions(
    facts,
    summary,
):

    parsed = parse_facts(facts)

    if not parsed["question"]:
        return []

    lower_summary = normalize(summary)

    markers = [
        "?",
        "asks whether",
        "asks if",
        "asking whether",
        "asking if",
        "whether",
        "can you",
        "could you",
        "are you",
        "did you",
        "will you",
    ]

    if not any(
        marker in lower_summary
        for marker in markers
    ):
        return [
            "Important question may have "
            "been converted into a statement."
        ]

    return []


# ============================================================
# VALIDATOR
# ============================================================

def validate(
    facts,
    summary,
):

    problems = []

    problems.extend(
        check_roles(
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

    return problems


# ============================================================
# TESTS
# ============================================================

TESTS = [

    {
        "name": "Correct recipient",
        "facts": """
RECIPIENT:
- submit the timesheet soon

SENDER:
- send the code for review
""",
        "summary": """
The recipient will submit the timesheet soon,
and the sender will send the code for review.
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
The sender will submit the timesheet soon
and send the code for review.
""",
    },

    {
        "name": "Correct sender",
        "facts": """
SENDER:
- prepare the frontend

RECIPIENT:
- finish the backend
""",
        "summary": """
The sender will prepare the frontend,
while the recipient will finish the backend.
""",
    },

    {
        "name": "Sender reversed",
        "facts": """
SENDER:
- prepare the frontend

RECIPIENT:
- finish the backend
""",
        "summary": """
The recipient will prepare the frontend,
while the sender will finish the backend.
""",
    },

    {
        "name": "Correct shared action",
        "facts": """
SHARED:
- review the changes together
""",
        "summary": """
They will review the changes together.
""",
    },

    {
        "name": "Shared made individual",
        "facts": """
SHARED:
- review the changes together
""",
        "summary": """
The sender will review the changes.
""",
    },

    {
        "name": "Mixed roles",
        "facts": """
QUESTION:
- Can you finish the API documentation by tomorrow?

RECIPIENT:
- finish the API documentation by tomorrow

SENDER:
- handle the frontend deck

SHARED:
- sync at 4 PM
""",
        "summary": """
The sender asks whether the recipient can finish
the API documentation by tomorrow.
The sender will handle the frontend deck,
and both will sync at 4 PM.
""",
    },

    {
        "name": "Question converted to action",
        "facts": """
QUESTION:
- Can you send me the report?

RECIPIENT:
- send the report

SENDER:
- review it after lunch
""",
        "summary": """
The recipient will send the report,
and the sender will review it after lunch.
""",
    },

    {
        "name": "Multiple named people",
        "facts": """
THIRDPARTY:
- Priya: prepare the slides
- Rahul: handle the backend

SENDER:
- test the final build
""",
        "summary": """
Priya will prepare the slides,
Rahul will handle the backend,
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
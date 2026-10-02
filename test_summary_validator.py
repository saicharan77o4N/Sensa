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
# WORD FILTERING
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


def meaningful_tokens(text):

    normalized = normalize(text)

    tokens = []

    tokens.extend(
        re.findall(
            r"\b[a-zA-Z]{3,}\b",
            normalized,
        )
    )

    tokens.extend(
        re.findall(
            r"\b\d+(?:[.:]\d+)?\b",
            normalized,
        )
    )

    for match in re.findall(
        r"\b\d{1,2}(?::\d{2})?\s*(?:am|pm)\b",
        normalized,
        re.IGNORECASE,
    ):
        tokens.append(
            match.replace(" ", "")
        )

    return [
        token
        for token in tokens
        if token not in STOP_WORDS
    ]


# ============================================================
# SUMMARY SEGMENTS
# ============================================================

def split_summary(summary):

    sentences = re.split(
        r"(?<=[.!?])\s+",
        summary.strip(),
    )

    result = []

    for sentence in sentences:

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
# FACT MATCHING
# ============================================================

def best_matching_segment(
    source_fact,
    summary,
):

    source_tokens = set(
        meaningful_tokens(source_fact)
    )

    best_segment = None
    best_score = 0

    for segment in split_summary(summary):

        summary_tokens = set(
            meaningful_tokens(segment)
        )

        score = len(
            source_tokens & summary_tokens
        )

        if score > best_score:
            best_score = score
            best_segment = segment

    return best_segment, best_score


# ============================================================
# ROLE CLASSIFICATION
# ============================================================

def role_of_clause(clause):

    text = normalize(clause)

    # --------------------------------------------------------
    # IMPORTANT:
    #
    # "The sender asks whether the recipient can..."
    # contains BOTH roles.
    #
    # We must inspect the relationship before looking for
    # simple sender/recipient markers.
    # --------------------------------------------------------

    # Sender asks recipient to do something.
    if (
        ("sender asks" in text
         or "sender requested" in text
         or "sender wants" in text)
        and "recipient" in text
    ):
        return "recipient"

    # Sender asks whether recipient can do something.
    if (
        ("sender asks whether" in text
         or "sender asks if" in text)
        and (
            "recipient" in text
            or "you" in text
        )
    ):
        return "recipient"

    # --------------------------------------------------------
    # SHARED
    # --------------------------------------------------------

    shared_patterns = [
        r"\bboth\b.*\bwill\b",
        r"\bboth\b.*\bcan\b",
        r"\bboth\b.*\bshould\b",
        r"\bboth\b.*\bneed\b",
        r"\bboth\b.*\btogether\b",

        r"\bthey\b.*\btogether\b",

        r"\bwe\b.*\bwill\b",
        r"\bwe\b.*\bcan\b",
        r"\bwe\b.*\bshould\b",
        r"\bwe\b.*\bneed\b",

        r"\blet's\b",
        r"\blets\b",
    ]

    if any(
        re.search(pattern, text)
        for pattern in shared_patterns
    ):
        return "shared"

    # --------------------------------------------------------
    # SENDER
    # --------------------------------------------------------

    sender_patterns = [
        r"\bthe sender\b.*\bwill\b",
        r"\bthe sender\b.*\bcan\b",
        r"\bthe sender\b.*\bshould\b",
        r"\bthe sender\b.*\bneeds?\b",
        r"\bthe sender\b.*\bmust\b",

        r"\bsender\b.*\bwill\b",

        r"\bi\b.*\bwill\b",
        r"\bi\b.*\bcan\b",
        r"\bi\b.*\bshould\b",
        r"\bi\b.*\bneed\b",
        r"\bi\b.*\bmust\b",

        r"\bi'll\b",
        r"\bi'm\b",
        r"\bi am\b",
    ]

    if any(
        re.search(pattern, text)
        for pattern in sender_patterns
    ):
        return "sender"

    # --------------------------------------------------------
    # RECIPIENT
    # --------------------------------------------------------

    recipient_patterns = [
        r"\bthe recipient\b.*\bwill\b",
        r"\bthe recipient\b.*\bcan\b",
        r"\bthe recipient\b.*\bshould\b",
        r"\bthe recipient\b.*\bneeds?\b",
        r"\bthe recipient\b.*\bmust\b",

        r"\byou\b.*\bwill\b",
        r"\byou\b.*\bcan\b",
        r"\byou\b.*\bshould\b",
        r"\byou\b.*\bneed\b",
        r"\byou\b.*\bmust\b",

        r"\byou'll\b",
    ]

    if any(
        re.search(pattern, text)
        for pattern in recipient_patterns
    ):
        return "recipient"

    return "ambiguous"

    # --------------------------------------------------------
    # EXPLICIT SENDER
    # --------------------------------------------------------

    sender_patterns = [

        r"\bthe sender\b.*\bwill\b",
        r"\bthe sender\b.*\bcan\b",
        r"\bthe sender\b.*\bshould\b",
        r"\bthe sender\b.*\bneeds?\b",
        r"\bthe sender\b.*\bmust\b",

        r"\bsender\b.*\bwill\b",

        r"\bi\b.*\bwill\b",
        r"\bi\b.*\bcan\b",
        r"\bi\b.*\bshould\b",
        r"\bi\b.*\bneed\b",
        r"\bi\b.*\bmust\b",

        r"\bi'll\b",
        r"\bi'm\b",
        r"\bi am\b",

    ]

    if any(
        re.search(pattern, text)
        for pattern in sender_patterns
    ):
        return "sender"

    # --------------------------------------------------------
    # EXPLICIT RECIPIENT
    # --------------------------------------------------------

    recipient_patterns = [

        r"\bthe recipient\b.*\bwill\b",
        r"\bthe recipient\b.*\bcan\b",
        r"\bthe recipient\b.*\bshould\b",
        r"\bthe recipient\b.*\bneeds?\b",
        r"\bthe recipient\b.*\bmust\b",

        r"\byou\b.*\bwill\b",
        r"\byou\b.*\bcan\b",
        r"\byou\b.*\bshould\b",
        r"\byou\b.*\bneed\b",
        r"\byou\b.*\bmust\b",

        r"\byou'll\b",

    ]

    if any(
        re.search(pattern, text)
        for pattern in recipient_patterns
    ):
        return "recipient"

    # --------------------------------------------------------
    # SENDER ASKING ABOUT RECIPIENT
    #
    # Example:
    # "The sender asks whether the recipient can send..."
    #
    # This is still a sender-originated question, but the
    # requested action belongs to the recipient.
    # --------------------------------------------------------

    if (
        "the sender asks" in text
        or "the sender requested" in text
        or "the sender wants" in text
    ):

        if (
            "recipient" in text
            or "you" in text
        ):
            return "recipient"

        return "sender"

    # --------------------------------------------------------
    # RECIPIENT MENTION
    # --------------------------------------------------------

    if (
        "recipient" in text
        and (
            "asks whether" in text
            or "asks if" in text
            or "can finish" in text
            or "can send" in text
            or "can submit" in text
        )
    ):
        return "recipient"

    return "ambiguous"

# ============================================================
# NAMED PERSON VALIDATION
# ============================================================

def extract_named_person_action(fact):
    """
    Extract a named person's responsibility from a third-party fact.

    Example:
        "Priya will prepare the slides"
        -> ("priya", "prepare the slides")

    This is intentionally generic. It does not contain any
    hard-coded names.
    """

    text = normalize(fact)

    match = re.match(
    r"^([a-z][a-z0-9_-]*)\s+"
    r"(?:will|can|should|needs to|must|is going to|has to)\s+"
    r"(.+)$",
    text,
    re.IGNORECASE,
)

    if not match:
        return None, None

    person = match.group(1)
    action = match.group(2).strip()

    return person, action


def validate_named_person_fact(
    source_fact,
    summary,
):
    """
    Validate that a named person's action remains attached
    to the same person in the summary.

    Example:

        Source:
            Priya will prepare the slides

        Good:
            Priya will prepare the slides.

        Bad:
            Rahul will prepare the slides, Priya will handle the backend.
    """

    source_fact = source_fact.strip()

    if not source_fact:
        return None

    # ---------------------------------------------------------
    # Extract source person and action
    # ---------------------------------------------------------

    source_person, source_action = extract_named_person_action(
        source_fact
    )

    if not source_person or not source_action:
        return None

    source_person = source_person.strip()
    source_action = source_action.strip()

    # ---------------------------------------------------------
    # Find the summary segment containing the action
    # ---------------------------------------------------------

    segment, score = best_matching_segment(
        source_action,
        summary,
    )

    if not segment:
        return None

    segment = segment.strip()

    # ---------------------------------------------------------
    # Split the segment into smaller clauses.
    #
    # This is important because a sentence can contain:
    #
    #   Rahul will prepare the slides,
    #   Priya will handle the backend.
    #
    # We must check the person attached to the action,
    # not merely whether the person's name exists somewhere
    # in the whole sentence.
    # ---------------------------------------------------------

    clauses = re.split(
        r",\s+|\s+\band\b\s+|\s+\bbut\b\s+",
        segment,
        flags=re.IGNORECASE,
    )

    # If splitting produced nothing useful, use the
    # original segment.
    clauses = [
        clause.strip()
        for clause in clauses
        if clause.strip()
    ]

    if not clauses:
        clauses = [segment]

    # ---------------------------------------------------------
    # Normalize source action words
    # ---------------------------------------------------------

    source_action_tokens = meaningful_tokens(source_action)
    source_action_tokens = set(source_action_tokens)

    if not source_action_tokens:
        return None

    # ---------------------------------------------------------
    # Look for the clause containing the source action.
    # ---------------------------------------------------------

    best_clause = None
    best_overlap = 0

    for clause in clauses:

        clause_tokens = meaningful_tokens(clause)

        if not clause_tokens:
            continue

        overlap = len(
            source_action_tokens.intersection(
                clause_tokens
            )
        )

        if overlap > best_overlap:
            best_overlap = overlap
            best_clause = clause

    if best_clause is None or best_overlap == 0:
        return None

    # ---------------------------------------------------------
    # Find named people in the action clause.
    # ---------------------------------------------------------

    candidate_people = re.findall(
        r"\b[A-Z][a-zA-Z]{2,}\b",
        best_clause,
    )

    ignored_people = {
        "The",
        "Sender",
        "Recipient",
        "Both",
        "They",
        "This",
        "That",
        "And",
        "But",
        "After",
        "Before",
        "Today",
        "Tomorrow",
    }

    candidate_people = [
        person
        for person in candidate_people
        if person not in ignored_people
    ]

    # ---------------------------------------------------------
    # Correct person is explicitly attached to the action.
    # ---------------------------------------------------------

    if re.search(
        rf"\b{re.escape(source_person)}\b",
        best_clause,
        re.IGNORECASE,
    ):
        return None

    # ---------------------------------------------------------
    # A different named person owns the action.
    # ---------------------------------------------------------

    if candidate_people:

        wrong_person = candidate_people[0]

        return (
            f"Named person action reassigned: "
            f"{source_person} -> {wrong_person} "
            f"for action: {source_action}"
        )

    # ---------------------------------------------------------
    # No named person in the action clause.
    #
    # Don't automatically reject here because the summary
    # may legitimately use a pronoun or another representation.
    # ---------------------------------------------------------

    return None
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

    if segment is None or score < 2:
        return []

    text = normalize(segment)

    problems = []

    # --------------------------------------------------------
    # Special case:
    #
    # "The sender asks whether the recipient can finish X"
    #
    # The action belongs to the recipient.
    # --------------------------------------------------------

    sender_asks_recipient = (
        (
            "sender asks whether" in text
            or "sender asks if" in text
            or "sender requested" in text
            or "sender asks" in text
        )
        and (
            "recipient" in text
            or "you" in text
        )
    )

    if sender_asks_recipient:

        if role == "recipient":
            return []

        if role == "sender":
            # The sender's role is preserved as the person
            # making the request.
            return []

    # --------------------------------------------------------
    # Normal role classification
    # --------------------------------------------------------

    summary_role = role_of_clause(segment)

    if role == "sender":

        if summary_role == "recipient":

            problems.append(
                f"Sender fact assigned to recipient: "
                f"{source_fact}"
            )

    elif role == "recipient":

        if summary_role == "sender":

            problems.append(
                f"Recipient fact assigned to sender: "
                f"{source_fact}"
            )

    elif role == "shared":

        if summary_role not in {
            "shared",
            "ambiguous",
        }:

            problems.append(
                f"Shared fact lost joint responsibility: "
                f"{source_fact}"
            )

    return problems

# ============================================================
# ROLE VALIDATION
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

    # --------------------------------------------------------
    # Validate named third-party responsibilities
    # --------------------------------------------------------

    for fact in parsed["thirdparty"]:

        problem = validate_named_person_fact(
            source_fact=fact,
            summary=summary,
        )

        if problem:
            problems.append(problem)

    return problems
# ============================================================
# QUESTION VALIDATION
# ============================================================

def check_questions(
    facts,
    summary,
):
    parsed = parse_facts(facts)

    questions = parsed["question"]

    if not questions:
        return []

    summary_text = normalize(summary)

    for question in questions:

        question_text = normalize(question)

        # ----------------------------------------------------
        # 1. Explicit question preservation
        # ----------------------------------------------------

        explicit_question_markers = [
            "?",
            "asks whether",
            "asks if",
            "asking whether",
            "asking if",
            "wants to know whether",
            "wants to know if",
        ]

        if any(
            marker in summary_text
            for marker in explicit_question_markers
        ):
            return []

        # ----------------------------------------------------
        # 2. Detect recipient-request questions
        #
        # Example:
        # "Can you send me the report?"
        #
        # A summary saying:
        # "The recipient will send the report."
        #
        # preserves the action but changes a question/request
        # into a confirmed action.
        # ----------------------------------------------------

        recipient_question = any(
            marker in question_text
            for marker in [
                "can you ",
                "could you ",
                "would you ",
                "will you ",
                "are you ",
                "did you ",
                "do you ",
                "have you ",
                "please ",
            ]
        )

        if recipient_question:

            action_tokens = set(
                meaningful_tokens(question_text)
            )

            summary_tokens = set(
                meaningful_tokens(summary_text)
            )

            overlap = (
                action_tokens
                & summary_tokens
            )

            # The action is present, but the question/request
            # structure has disappeared.
            if len(overlap) >= 2:

                confirmed_action_markers = [
                    "the recipient will ",
                    "the recipient can ",
                    "the recipient should ",
                    "the recipient must ",
                    "the sender will ",
                    "the sender can ",
                    "the sender should ",
                    "the sender must ",
                    "you will ",
                    "you can ",
                    "you should ",
                    "you must ",
                ]

                if any(
                    marker in summary_text
                    for marker in confirmed_action_markers
                ):
                    return [
                        "Important question may have "
                        "been converted into a statement."
                    ]

        # ----------------------------------------------------
        # 3. Generic semantic overlap fallback
        # ----------------------------------------------------

        question_tokens = set(
            meaningful_tokens(question_text)
        )

        summary_tokens = set(
            meaningful_tokens(summary_text)
        )

        overlap = (
            question_tokens
            & summary_tokens
        )

        if len(overlap) >= 2:
            continue

        return [
            "Important question may have "
            "been lost."
        ]

    return []


# ============================================================
# CLAIM VALIDATION
# ============================================================

STATUS_PATTERNS = {

    "completed": [
        r"\bcompleted\b",
        r"\bhas been completed\b",
        r"\bhave been completed\b",
    ],

    "complete": [
        r"\bis complete\b",
        r"\bare complete\b",
        r"\bwas complete\b",
        r"\bwere complete\b",
    ],

    "confirmed": [
        r"\bconfirmed\b",
        r"\bis confirmed\b",
        r"\bwas confirmed\b",
    ],

    "cancelled": [
        r"\bcancelled\b",
        r"\bcanceled\b",
        r"\bis cancelled\b",
        r"\bis canceled\b",
    ],

    "approved": [
        r"\bapproved\b",
        r"\bis approved\b",
    ],

    "rejected": [
        r"\brejected\b",
        r"\bis rejected\b",
    ],

    "accepted": [
        r"\baccepted\b",
        r"\bis accepted\b",
    ],

    "declined": [
        r"\bdeclined\b",
        r"\bis declined\b",
    ],

    "overdue": [
        r"\boverdue\b",
        r"\bis overdue\b",
    ],

    "failed": [
        r"\bfailed\b",
        r"\bfailure\b",
        r"\bhas failed\b",
    ],

    "successful": [
        r"\bsuccessful\b",
        r"\bsuccessfully\b",
    ],

    "scheduled": [
        r"\bscheduled\b",
        r"\bis scheduled\b",
        r"\bwas scheduled\b",
    ],

    "rescheduled": [
        r"\brescheduled\b",
    ],

    "delayed": [
        r"\bdelayed\b",
        r"\bwas delayed\b",
    ],

    "postponed": [
        r"\bpostponed\b",
        r"\bwas postponed\b",
    ],

    "blocked": [
        r"\bblocked\b",
        r"\bis blocked\b",
    ],

    "resolved": [
        r"\bresolved\b",
        r"\bis resolved\b",
    ],

    "unresolved": [
        r"\bunresolved\b",
        r"\bis unresolved\b",
    ],
}


def extract_status_words(text):

    lower = normalize(text)

    patterns = {

        "completed": [
            r"\bcompleted\b",
            r"\bcomplete\b",
            r"\bhas been completed\b",
            r"\bhave been completed\b",
        ],

        "pending": [
            r"\bpending\b",
            r"\bis pending\b",
            r"\bare pending\b",
            r"\bwas pending\b",
        ],

        "confirmed": [
            r"\bconfirmed\b",
            r"\bis confirmed\b",
            r"\bwas confirmed\b",
        ],

        "cancelled": [
            r"\bcancelled\b",
            r"\bcanceled\b",
            r"\bis cancelled\b",
            r"\bis canceled\b",
        ],

        "approved": [
            r"\bapproved\b",
            r"\bis approved\b",
        ],

        "rejected": [
            r"\brejected\b",
            r"\bis rejected\b",
        ],

        "accepted": [
            r"\baccepted\b",
            r"\bis accepted\b",
        ],

        "declined": [
            r"\bdeclined\b",
            r"\bis declined\b",
        ],

        "overdue": [
            r"\boverdue\b",
            r"\bis overdue\b",
        ],

        "failed": [
            r"\bfailed\b",
            r"\bfailure\b",
            r"\bhas failed\b",
        ],

        "successful": [
            r"\bsuccessful\b",
            r"\bsuccessfully\b",
        ],

        "scheduled": [
            r"\bscheduled\b",
            r"\bis scheduled\b",
            r"\bwas scheduled\b",
        ],

        "rescheduled": [
            r"\brescheduled\b",
        ],

        "delayed": [
            r"\bdelayed\b",
            r"\bwas delayed\b",
        ],

        "postponed": [
            r"\bpostponed\b",
            r"\bwas postponed\b",
        ],

        "blocked": [
            r"\bblocked\b",
            r"\bis blocked\b",
        ],

        "resolved": [
            r"\bresolved\b",
            r"\bis resolved\b",
        ],

        "unresolved": [
            r"\bunresolved\b",
            r"\bis unresolved\b",
        ],
    }

    found = set()

    for status, status_patterns in patterns.items():

        for pattern in status_patterns:

            if re.search(
                pattern,
                lower,
            ):
                found.add(status)
                break

    return found


# ============================================================
# NUMBERS / TIMES
# ============================================================

def extract_numbers(text):

    return set(
        re.findall(
            r"\b\d+(?:[.,]\d+)?\b",
            text,
        )
    )


def extract_times(text):

    return set(
        normalize(match).replace(" ", "")
        for match in re.findall(
            r"\b\d{1,2}(?::\d{2})?\s*(?:am|pm)\b",
            text,
            re.IGNORECASE,
        )
    )


# ============================================================
# CLAIM VALIDATION
# ============================================================

def check_claims(
    source,
    summary,
):

    problems = []

    # --------------------------------------------------------
    # Unsupported status/state
    # --------------------------------------------------------

    source_status = extract_status_words(source)
    summary_status = extract_status_words(summary)

    for status in sorted(
        summary_status - source_status
    ):

        problems.append(
            f"Unsupported status/state claim: {status}"
        )

    # --------------------------------------------------------
    # Numbers
    #
    # Numbers belonging to a time such as "4 PM" are removed
    # from standalone number checking.
    # --------------------------------------------------------

    source_numbers = extract_numbers(source)
    summary_numbers = extract_numbers(summary)

    source_times = extract_times(source)
    summary_times = extract_times(summary)

    def remove_time_numbers(
        numbers,
        times,
    ):

        cleaned = set(numbers)

        for time in times:

            match = re.match(
                r"(\d{1,2})(?::\d{2})?",
                time,
            )

            if match:

                cleaned.discard(
                    match.group(1)
                )

        return cleaned

    source_standalone_numbers = (
        remove_time_numbers(
            source_numbers,
            source_times,
        )
    )

    summary_standalone_numbers = (
        remove_time_numbers(
            summary_numbers,
            summary_times,
        )
    )

    # --------------------------------------------------------
    # Detect a changed number.
    #
    # Example:
    # source  = 15 people
    # summary = 20 people
    # --------------------------------------------------------

    if (
        len(source_standalone_numbers) == 1
        and len(summary_standalone_numbers) == 1
    ):

        source_number = next(
            iter(source_standalone_numbers)
        )

        summary_number = next(
            iter(summary_standalone_numbers)
        )

        if source_number != summary_number:

            problems.append(
                "Number changed: "
                f"source={source_number}, "
                f"summary={summary_number}"
            )

    else:

        for number in sorted(
            source_standalone_numbers
            - summary_standalone_numbers
        ):

            problems.append(
                f"Source number missing: {number}"
            )

    # --------------------------------------------------------
    # Times
    # --------------------------------------------------------

    for time in sorted(
        source_times - summary_times
    ):

        problems.append(
            f"Source time missing: {time}"
        )

    # --------------------------------------------------------
    # Dates
    #
    # Relative dates such as "today" and "tomorrow" are not
    # hard failures yet because they require contextual
    # temporal reasoning.
    # --------------------------------------------------------

    return problems


# ============================================================
# FULL SUMMARY VALIDATOR
# ============================================================

def validate_summary(
    facts,
    original_notification,
    summary,
):

    problems = []

    # 1. Role preservation
    problems.extend(
        check_roles(
            facts,
            summary,
        )
    )

    # 2. Question preservation
    problems.extend(
        check_questions(
            facts,
            summary,
        )
    )

    # 3. Hard factual claims
    problems.extend(
        check_claims(
            original_notification,
            summary,
        )
    )

    return problems


# ============================================================
# TESTS
# ============================================================

TESTS = [

    # --------------------------------------------------------
    # GOOD - mixed roles
    # --------------------------------------------------------

    {
        "name": "GOOD - mixed roles",

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

        "source": """
Can you finish the API documentation by tomorrow?
I'll handle the frontend deck and we can sync at 4 PM.
""",

        "summary": """
The sender asks whether the recipient can finish
the API documentation by tomorrow.
The sender will handle the frontend deck,
and both will sync at 4 PM.
""",

        "expected_fail": False,
    },


    # --------------------------------------------------------
    # BAD - recipient reversed
    # --------------------------------------------------------

    {
        "name": "BAD - recipient reversed",

        "facts": """
RECIPIENT:
- submit the timesheet soon

SENDER:
- send the code for review
""",

        "source": """
Please submit the timesheet soon.
I'll send the code for review.
""",

        "summary": """
The sender will submit the timesheet soon
and send the code for review.
""",

        "expected_fail": True,
    },


    # --------------------------------------------------------
    # BAD - sender reversed
    # --------------------------------------------------------

    {
        "name": "BAD - sender reversed",

        "facts": """
SENDER:
- prepare the frontend

RECIPIENT:
- finish the backend
""",

        "source": """
I'll prepare the frontend.
You finish the backend.
""",

        "summary": """
The recipient will prepare the frontend,
while the sender will finish the backend.
""",

        "expected_fail": True,
    },


    # --------------------------------------------------------
    # GOOD - shared
    # --------------------------------------------------------

    {
        "name": "GOOD - shared",

        "facts": """
SHARED:
- review the changes together
""",

        "source": """
Let's review the changes together.
""",

        "summary": """
They will review the changes together.
""",

        "expected_fail": False,
    },


    # --------------------------------------------------------
    # BAD - shared became individual
    # --------------------------------------------------------

    {
        "name": "BAD - shared became individual",

        "facts": """
SHARED:
- review the changes together
""",

        "source": """
Let's review the changes together.
""",

        "summary": """
The sender will review the changes.
""",

        "expected_fail": True,
    },


    # --------------------------------------------------------
    # BAD - missing time
    # --------------------------------------------------------

    {
        "name": "BAD - missing time",

        "facts": """
SHARED:
- sync at 4 PM
""",

        "source": """
Let's sync at 4 PM.
""",

        "summary": """
They will sync together.
""",

        "expected_fail": True,
    },


    # --------------------------------------------------------
    # BAD - invented status
    # --------------------------------------------------------

    {
        "name": "BAD - invented status",

        "facts": """
SHARED:
- sync at 4 PM
""",

        "source": """
Let's sync at 4 PM.
""",

        "summary": """
The shared sync is pending at 4 PM.
""",

        "expected_fail": True,
    },


    # --------------------------------------------------------
    # BAD - invented number
    # --------------------------------------------------------

    {
        "name": "BAD - invented number",

        "facts": """
CONTEXT:
- The table is booked for 15 people.
""",

        "source": """
They booked a table for 15 people.
""",

        "summary": """
They booked a table for 20 people.
""",

        "expected_fail": True,
    },


    # --------------------------------------------------------
    # BAD - question lost
    # --------------------------------------------------------

    {
        "name": "BAD - question lost",

        "facts": """
QUESTION:
- Can you send me the report?

RECIPIENT:
- send the report
""",

        "source": """
Can you send me the report?
""",

        "summary": """
The recipient will send the report.
""",

        "expected_fail": True,
    },


    # --------------------------------------------------------
    # GOOD - named people
    # --------------------------------------------------------

    {
        "name": "GOOD - named people",

        "facts": """
THIRDPARTY:
- Priya: prepare the slides
- Rahul: handle the backend

SENDER:
- test the final build
""",

        "source": """
Priya will prepare the slides,
Rahul will handle the backend,
and I'll test the final build.
""",

        "summary": """
Priya will prepare the slides,
Rahul will handle the backend,
and the sender will test the final build.
""",

        "expected_fail": False,
    },

]


# ============================================================
# RUN TESTS
# ============================================================

if __name__ == "__main__":

    total = len(TESTS)
    passed = 0

    for test in TESTS:

        print("\n" + "=" * 70)
        print(test["name"])
        print("=" * 70)

        problems = validate_summary(
            facts=test["facts"],
            original_notification=test["source"],
            summary=test["summary"],
        )

        failed = len(problems) > 0

        if failed == test["expected_fail"]:

            print("VALIDATION RESULT: PASS")
            passed += 1

        else:

            print("VALIDATION RESULT: FAIL")

        if problems:

            for problem in problems:
                print(" -", problem)

    print("\n" + "=" * 70)
    print(f"FINAL RESULT: {passed}/{total} TESTS PASSED")
    print("=" * 70)
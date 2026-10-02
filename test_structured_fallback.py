import re

from test_summary_validator import parse_facts


# ============================================================
# TEXT HELPERS
# ============================================================

def clean_text(text):
    return re.sub(r"\s+", " ", text.strip())


def capitalize_sentence(text):
    text = clean_text(text)

    if not text:
        return ""

    return text[0].upper() + text[1:]


def ensure_period(text):
    text = clean_text(text)

    if not text:
        return ""

    if text.endswith((".", "!", "?")):
        return text

    return text + "."

def format_context(fact):
    fact = clean_text(fact)

    if not fact:
        return ""

    return ensure_period(
        capitalize_sentence(fact)
    )
# ============================================================
# ROLE PREFIX
# ============================================================

def format_role_fact(role, fact):
    """
    Convert structured fact fragments into readable sentences
    without changing their meaning, tense, or responsibility.
    """

    fact = clean_text(fact)

    if not fact:
        return ""

    lower = fact.lower()

    # --------------------------------------------------------
    # Already contains a grammatical subject
    # --------------------------------------------------------

    if role == "sender":

        if lower.startswith(
            (
                "i ",
                "i'm ",
                "i am ",
                "i'll ",
                "i will ",
                "i've ",
                "i have ",
                "the sender ",
            )
        ):
            return ensure_period(
                capitalize_sentence(fact)
            )

    elif role == "recipient":

        if lower.startswith(
            (
                "you ",
                "you'll ",
                "you will ",
                "you can ",
                "you should ",
                "you need ",
                "the recipient ",
            )
        ):
            return ensure_period(
                capitalize_sentence(fact)
            )

    elif role == "shared":

        if lower.startswith(
            (
                "we ",
                "we'll ",
                "we will ",
                "we should ",
                "let's ",
                "lets ",
                "both ",
            )
        ):
            return ensure_period(
                capitalize_sentence(fact)
            )

    # --------------------------------------------------------
    # Sender
    # --------------------------------------------------------

    if role == "sender":

        # Existing tense/state/action markers.
        #
        # Do NOT add "will" because the fact already
        # carries its own grammatical meaning.
        existing_sender_markers = (
            "did ",
            "was ",
            "were ",
            "has ",
            "have ",
            "had ",
            "forgot ",
            "forgotten ",
            "asks ",
            "asked ",
            "is ",
            "am ",
            "are ",
            "can ",
            "could ",
            "should ",
            "must ",
            "needs ",
            "needed ",
            "will ",
            "would ",
            "might ",
            "may ",
        )

        if lower.startswith(existing_sender_markers):
            return ensure_period(
                "The sender " + fact
            )

        # Imperative/action fragment.
        return ensure_period(
            "The sender will " + fact
        )

    # --------------------------------------------------------
    # Recipient
    # --------------------------------------------------------

    if role == "recipient":

        existing_recipient_markers = (
            "did ",
            "was ",
            "were ",
            "has ",
            "have ",
            "had ",
            "forgot ",
            "is ",
            "are ",
            "can ",
            "could ",
            "should ",
            "must ",
            "needs ",
            "needed ",
            "will ",
            "would ",
            "might ",
            "may ",
        )

        if lower.startswith(existing_recipient_markers):
            return ensure_period(
                "The recipient " + fact
            )

        # Imperative/action fragment.
        return ensure_period(
            "The recipient should " + fact
        )

    # --------------------------------------------------------
    # Shared
    # --------------------------------------------------------

    if role == "shared":

        existing_shared_markers = (
            "did ",
            "was ",
            "were ",
            "has ",
            "have ",
            "had ",
            "is ",
            "are ",
            "can ",
            "could ",
            "should ",
            "must ",
            "need ",
            "needs ",
            "needed ",
            "will ",
            "would ",
            "might ",
            "may ",
        )

        if lower.startswith(existing_shared_markers):
            return ensure_period(
                "Both " + fact
            )

        # Imperative/action fragment.
        return ensure_period(
            "Both will " + fact
        )

    # --------------------------------------------------------
    # Third party / unknown
    # --------------------------------------------------------

    return ensure_period(
        capitalize_sentence(fact)
    )


# ============================================================
# FALLBACK
# ============================================================

def generate_structured_fallback(facts):

    parsed = parse_facts(facts)

    parts = []

    # --------------------------------------------------------
    # QUESTIONS
    # --------------------------------------------------------

    for question in parsed["question"]:

        question = clean_text(question)

        if not question:
            continue

        if not question.endswith("?"):
            question += "?"

        parts.append(
            capitalize_sentence(question)
        )

    # --------------------------------------------------------
    # CONTEXT
    # --------------------------------------------------------

    for context in parsed["context"]:

        formatted = format_context(context)

        if formatted:
            parts.append(formatted)

    # --------------------------------------------------------
    # THIRD PARTY
    # --------------------------------------------------------

    for fact in parsed.get("thirdparty", []):

        formatted = format_role_fact(
            "thirdparty",
            fact
        )

        if formatted:
            parts.append(formatted)

    # --------------------------------------------------------
    # SENDER
    # --------------------------------------------------------

    sender = parsed["sender"]

    for fact in sender:

        formatted = format_role_fact(
            "sender",
            fact
        )

        if formatted:
            parts.append(formatted)

    # --------------------------------------------------------
    # RECIPIENT
    # --------------------------------------------------------

    recipient = parsed["recipient"]

    for fact in recipient:

        formatted = format_role_fact(
            "recipient",
            fact
        )

        if formatted:
            parts.append(formatted)

    # --------------------------------------------------------
    # SHARED
    # --------------------------------------------------------

    shared = parsed["shared"]

    for fact in shared:

        formatted = format_role_fact(
            "shared",
            fact
        )

        if formatted:
            parts.append(formatted)

    return " ".join(parts)


# ============================================================
# TEST CASES
# ============================================================

TESTS = [

    {
        "name": "Project Loon",

        "facts": """
QUESTION:
- Did you check the update on Project Loon?

CONTEXT:
- The timeline got pushed by 2 weeks
- They were running behind on backend integration
- The client demo is still scheduled for Friday

RECIPIENT:
- finish the API documentation by tomorrow

SENDER:
- handle the frontend deck

SHARED:
- sync at 4 PM for a quick review
""",
    },

    {
        "name": "OKR planning",

        "facts": """
QUESTION:
- Are you joining the OKR planning meeting at 11?

SENDER:
- did not finish the slides yet
- was looking for the template
- will share the template on Drive

SHARED:
- include the bug fix stats
- join the Google Meet link 5 minutes early
- go through it together

CONTEXT:
- The template is the same one used last quarter
- Priya mentioned the bug fix stats would make progress look more solid
""",
    },

    {
        "name": "Timesheet",

        "facts": """
QUESTION:
- Did you submit the timesheet for this week?

RECIPIENT:
- submit the timesheet soon
- log the cloud credits used for testing
- check the code whenever available

SENDER:
- forgot about logging the cloud credits last time
- send the code over now
- asks if the recipient is free for a code review after lunch

CONTEXT:
- The timesheet is due today by 6 PM
""",
    },

    {
        "name": "Office tomorrow",

        "facts": """
QUESTION:
- Are you coming to the office tomorrow?

SENDER:
- has to come to the office tomorrow
- will attend the team lunch with the new manager

SHARED:
- go together after the standup call

CONTEXT:
- The lunch is at the 5th floor cafeteria
- A table was booked for 15 people
- They will finally meet everyone offline
- They have only been on Google Meet for about 3 months
- It will be nice to meet in person
""",
    },

]


# ============================================================
# RUN
# ============================================================

if __name__ == "__main__":

    for test in TESTS:

        print()
        print("=" * 70)
        print(test["name"])
        print("=" * 70)

        summary = generate_structured_fallback(
            test["facts"]
        )

        print()
        print("FALLBACK SUMMARY:")
        print(summary) 
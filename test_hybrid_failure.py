from test_summary_validator import validate_summary
from test_structured_fallback import generate_structured_fallback


FACTS = """
QUESTION:
- Can you send me the report?

SENDER:
- review the report after lunch

RECIPIENT:
- send the report

SHARED:
- review the results together
"""


SOURCE = """
Can you send me the report?
I'll review it after lunch and we can go through the results together.
"""


# Deliberately BAD Qwen output.
# It reverses the sender/recipient responsibilities.
BAD_QWEN_SUMMARY = """
The sender will send the report and the recipient will review it after lunch.
"""


print("=" * 70)
print("HYBRID FAILURE-INJECTION TEST")
print("=" * 70)

print()
print("SIMULATED QWEN SUMMARY:")
print(BAD_QWEN_SUMMARY)


# ------------------------------------------------------------
# STEP 1 — Validate the deliberately bad Qwen output
# ------------------------------------------------------------

problems = validate_summary(
    facts=FACTS,
    original_notification=SOURCE,
    summary=BAD_QWEN_SUMMARY,
)


print()
print("QWEN VALIDATION:")

if problems:

    print("FAIL")

    for problem in problems:
        print(" -", problem)

else:

    print("PASS")


# ------------------------------------------------------------
# STEP 2 — Trigger fallback if validation fails
# ------------------------------------------------------------

if problems:

    print()
    print("FALLBACK TRIGGERED")

    fallback = generate_structured_fallback(
        FACTS
    )

    print()
    print("STRUCTURED FALLBACK:")
    print(fallback)


    # --------------------------------------------------------
    # STEP 3 — Validate fallback
    # --------------------------------------------------------

    fallback_problems = validate_summary(
        facts=FACTS,
        original_notification=SOURCE,
        summary=fallback,
    )

    print()
    print("FALLBACK VALIDATION:")

    if fallback_problems:

        print("FAIL")

        for problem in fallback_problems:
            print(" -", problem)

    else:

        print("PASS")

        print()
        print("HYBRID SAFETY TEST: PASS")

else:

    print()
    print("ERROR: The deliberately bad Qwen summary was accepted.")

    print()
    print("HYBRID SAFETY TEST: FAIL")
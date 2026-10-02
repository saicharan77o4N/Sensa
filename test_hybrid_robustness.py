from test_summary_validator import validate_summary
from test_structured_fallback import generate_structured_fallback


TESTS = [

    {
        "name": "1. Role reversal",
        "expected_validation": "FAIL",

        "facts": """
RECIPIENT:
- submit the timesheet soon

SENDER:
- review the timesheet after lunch
""",

        "source": """
You should submit the timesheet soon.
I'll review it after lunch.
""",

        "bad_summary": """
The sender will submit the timesheet soon and the recipient will review it after lunch.
""",
    },


    {
        "name": "2. Missing time",
        "expected_validation": "FAIL",

        "facts": """
SENDER:
- send the report

CONTEXT:
- the meeting is at 4 PM
""",

        "source": """
I'll send the report.
The meeting is at 4 PM.
""",

        "bad_summary": """
The sender will send the report.
""",
    },


    {
        "name": "3. Changed number",
        "expected_validation": "FAIL",

        "facts": """
CONTEXT:
- the meeting has 15 attendees
""",

        "source": """
The meeting has 15 attendees.
""",

        "bad_summary": """
The meeting has 20 attendees.
""",
    },


    {
        "name": "4. Invented status",
        "expected_validation": "FAIL",

        "facts": """
SENDER:
- check the deployment
""",

        "source": """
I'll check the deployment.
""",

        "bad_summary": """
The sender successfully completed the deployment.
""",
    },


    {
        "name": "5. Lost question",
        "expected_validation": "FAIL",

        "facts": """
QUESTION:
- Are you joining the meeting at 11?

SENDER:
- share the meeting link
""",

        "source": """
Are you joining the meeting at 11?
I'll share the meeting link.
""",

        "bad_summary": """
The recipient will join the meeting at 11 and the sender will share the meeting link.
""",
    },


    {
        "name": "6. Shared action made individual",
        "expected_validation": "FAIL",

        "facts": """
SHARED:
- review the changes together
""",

        "source": """
Let's review the changes together.
""",

        "bad_summary": """
The sender will review the changes.
""",
    },


    {
        "name": "7. Multiple named people",
        "expected_validation": "FAIL",

        "facts": """
THIRDPARTY:
- Priya will prepare the slides
- Rahul will handle the backend

SENDER:
- test the final build
""",

        "source": """
Priya will prepare the slides.
Rahul will handle the backend.
I'll test the final build.
""",

        "bad_summary": """
Rahul will prepare the slides, Priya will handle the backend, and the sender will test the final build.
""",
    },


    {
        "name": "8. Good summary",
        "expected_validation": "PASS",

        "facts": """
QUESTION:
- Can you send me the report?

RECIPIENT:
- send the report

SENDER:
- review the report after lunch

SHARED:
- review the results together
""",

        "source": """
Can you send me the report?
I'll review it after lunch and we can go through the results together.
""",

        "bad_summary": """
The sender asks whether the recipient can send the report.
The sender will review the report after lunch.
Both will review the results together.
""",
    },

]


print("=" * 70)
print("HYBRID ROBUSTNESS TEST")
print("=" * 70)


total = 0
passed = 0


for test in TESTS:

    total += 1

    print()
    print("=" * 70)
    print(test["name"])
    print("=" * 70)

    print()
    print("SIMULATED QWEN OUTPUT:")
    print(test["bad_summary"])

    problems = validate_summary(
        facts=test["facts"],
        original_notification=test["source"],
        summary=test["bad_summary"],
    )

    actual_validation = "FAIL" if problems else "PASS"

    print()
    print("QWEN VALIDATION:")
    print(actual_validation)

    if problems:

        for problem in problems:
            print(" -", problem)

    expected = test["expected_validation"]

    print()
    print(f"EXPECTED: {expected}")

    # --------------------------------------------------------
    # Expected FAIL → fallback should activate
    # --------------------------------------------------------

    if expected == "FAIL":

        if actual_validation != "FAIL":

            print()
            print("TEST RESULT: FAIL")
            print("Validator incorrectly accepted the bad summary.")

            continue

        print()
        print("FALLBACK TRIGGERED")

        fallback = generate_structured_fallback(
            test["facts"]
        )

        print()
        print("FALLBACK:")
        print(fallback)

        fallback_problems = validate_summary(
            facts=test["facts"],
            original_notification=test["source"],
            summary=fallback,
        )

        print()
        print("FALLBACK VALIDATION:")

        if fallback_problems:

            print("FAIL")

            for problem in fallback_problems:
                print(" -", problem)

            print()
            print("TEST RESULT: FAIL")

        else:

            print("PASS")

            print()
            print("TEST RESULT: PASS")

            passed += 1

    # --------------------------------------------------------
    # Expected PASS → Qwen should be accepted
    # --------------------------------------------------------

    else:

        if actual_validation == "PASS":

            print()
            print("QWEN SUMMARY ACCEPTED")

            print()
            print("TEST RESULT: PASS")

            passed += 1

        else:

            print()
            print("TEST RESULT: FAIL")

            print("Good summary was incorrectly rejected.")

            for problem in problems:
                print(" -", problem)


print()
print("=" * 70)
print("FINAL RESULT")
print("=" * 70)

print()
print(f"{passed}/{total} robustness tests passed.")

if passed == total:

    print()
    print("HYBRID ROBUSTNESS: PASS")

else:

    print()
    print("HYBRID ROBUSTNESS: NEEDS IMPROVEMENT")